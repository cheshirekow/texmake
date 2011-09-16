## @class
#  @brief   A node in the dependency graph
#
package Texmake::Node;

use strict;

use Switch;
use File::stat;
use Time::localtime;

use Texmake qw( EVAL_FAIL 
                EVAL_NOACTION 
                EVAL_NEWER 
                EVAL_BUILDME 
                BUILD_FAIL 
                BUILD_SUCCESS 
                BUILD_REBUILD);
use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;


##  @cmethod object new($outfile)
#   @brief  creates the base object for derived dependency graph nodes
#   @param[in]  outfile     the file that that is represented by this node
sub new
{
    # make self a reference to an anonymouse hash
    my $this = 
    {
        'outfile'   => undef,
        'depends'   => undef,
        'dirty'     => 0,
    };  
    
    # create an empty array and point to it as a data member
    my @depends = ();
    $this->{'depends'} = \@depends;
    
    # shift off the class name
    shift;
    
    unless(@_)
    {
        print_f "Node base object built with no file";
        die;
    }
    
    $this->{'outfile'} = shift;
    
    bless($this);
    return $this;
}


##  @method void dependsOn($childNode)
#   @brief  adds a new node which this node depends on
sub dependsOn
{
    my $this    = shift;
    my $child   = shift;
    
    my $depends = $this->{'depends'};
    push(@$depends,$child);
}


##  @method retVal evaluate($time,$force)
#   @brief  evaluates the nodes children, determines if the output file needs 
#           to be rebuilt, rebuilds it if necessary, and returns the status of 
#           the output file
#   @param[in]  time    the last modified time of the parent
#   @param[in]  force   forces rebuilding the child even if it's dependencies
#                       aren't younger
#   @return     one of NOACTION, NEWER, BUILDME
#
#   This method is a member of the base class because it's common to all nodes.
#   It evaluates all of it's children, 
#
#
sub evaluate
{
    my $this        = shift;
    my $parenttime  = shift;
    my $force       = shift; 
    my $depends     = $this->{'depends'};
    my $file        = $this->{'outfile'};
    my $retval      = EVAL_NOACTION;
    my $mtime       = 0;
    
    if($force)
    {
        $this->{'dirty'} = 1;
    }
    
    print_n 0, "Checking modified time of $file";
    
    # if the file exists, compare it's modified time with that which was passed
    # to ass
    if(-e $file)
    {
        $mtime = stat($file)->mtime;
        if($mtime > $parenttime)
        {
            print_n 0, "$file is newer than parent";
            $retval = EVAL_NEWER;
        }
        print_e     "   mytime: $mtime\n" 
                   ."   parent: $parenttime\n"
                   ."   force:  $force";
    }
    
    #otherwise, clearly it needs to be rebuilt
    else
    {
        print_n 0, "Does not exist";
        $this->{'dirty'} = 1;
        $retval = EVAL_NEWER; 
    }

    # recurse into each child, evaluating (and possibly building) them
    foreach my $child( @$depends )
    {
        print_n 0, "evaluating child, passing mtime of $mtime";
        my $status = $child->evaluate($mtime);
        if($status > EVAL_NOACTION)
        {
            $this->{'dirty'} = 1;
        }
        
        # if the child wants to be rebuilt, then oblige
        while($status == EVAL_BUILDME)
        {
            print_n 0, "Child returned status BUILDME, so I'm rebuilding";
            $status = $child->evaluate($mtime,1);
        }
        
        # if the child evaluation/build failed, then we should just stop here
        # with a failure
        if($status == EVAL_FAIL)
        {
            return EVAL_FAIL;
        }
        
    }
    
    # if this file is dirty, either because one of it's dependencies is newer
    # or because it's dependency was just rebuilt (naturally, meaning it's 
    # newer) then do the build (this method is defined by subclass)
    if($this->{'dirty'})
    {
        print_n 0, "$file is dirty";
    
        my $status = $this->doBuild();    
        if( $status == BUILD_FAIL)
        {
            $retval = EVAL_FAIL;
        }
        
        elsif( $status == BUILD_REBUILD)
        {
            $retval = EVAL_BUILDME;
        }
        
        $this->{'dirty'} = 0;
    }
    
    return $retval;
}


1;