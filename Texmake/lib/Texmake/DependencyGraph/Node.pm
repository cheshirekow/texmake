package Texmake::DependencyGraph::Node;

use strict;

use Switch;
use File::stat;
use Time::localtime;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use Texmake::Runner;



# creates a new dependency graph node
sub new
{
    # make self a reference to an anonymouse hash
    my $this = 
    {
        'file'      => undef,
        'build'     => undef,
        'depends'   => undef,
    };  
    
    # first, shift off the class name
    shift;

    # this method requires two parameters
    if( ($#_ +1) == 2 )
    {
        my $file        = shift;
        my $build       = shift;
        my @depends;
        
        $this->{'file'}     = $file;
        $this->{'build'}    = $build;
        $this->{'depends'}  = \@depends;
    }
    else
    {
        die "Node created with wrong argument list";
    }

    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::Builder object
    return $this;
}



sub dependsOn
{
    my $this    = shift;
    my $child   = shift;
    
    my $depends = $this->{'depends'};
    push(@$depends,$child);
}


sub build
{
    my $this        = shift;
    my $parenttime  = (@_ ? shift : 0);
    my $depends     = $this->{'depends'};
    my $dirty       = 0;
    my $file        = $this->{'file'};
    my $mtime       = 0;
    
    print_n 0, "Considering $file";
    
    if(-e $file)
    {
        $mtime = stat($file)->mtime;
    }

    foreach my $child( @$depends )
    {
        if($child->build($mtime))
        {
            $dirty = 1;
        }
    }
    
    if($dirty)
    {
        print_n 0, "$file is dirty";
        my $runner = new Texmake::Runner($this);
        $runner->go();
        return 1;
    }
    
    elsif($mtime > $parenttime)
    {
        print_n 0, "$file is newer than parent";
        return 1;
    }
    
    else
    { 
        return 0; 
    }
}


1;