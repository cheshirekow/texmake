##  @class
#   @brief  a node which uses pdflatex to compile a .tex document
package Texmake::Tools::Latexml::Xml::Node;


use strict;

use Switch;
use File::stat;
use File::Copy;
use File::Path qw(make_path);
use File::Basename qw(dirname basename fileparse);
use Time::localtime;
use Cwd qw(getcwd realpath);

use Texmake ':all';
use Texmake::Printer ':all';
use Texmake::PrintIncrementer;

use Texmake::Node;
use Texmake::Tools::Source::Node;
use Texmake::Tools::Copy::Node;
use Texmake::Tools::Bibtex::Node;
use Texmake::Tools::TexRootMaker::Node; 
use Texmake::Tools::TexState::Node;

our @ISA = ('Texmake::Node');


# file types that indicate an unstable document, but who shouldn't 
# instigate an intial build
our @stateTypes = qw(.aux .toc);


##  @cmethod object new($output,$srcdir)
#   @brief   constructor, creates a new pdflatex node
#   @param[in]  output  the output file which is created
#   @param[in]  srcdir  the directory where the sources are located
#
#   The pdf builder makes a lot of assumptions. It assumes that there is a
#   directory called $output.texmake which contains a file called root.tex
#   which references the actual source document. The only piece of 
#   extra information the builder needs is the source directory where it 
#   should point pdflatex in addition to the build directory. This source 
#   directory is also where the parser will look for missing dependencies
#    
sub new
{
    my $this;

    # first, shift off the class name
    shift;
    
    # this method requires two parameters
    if( ($#_ +1) == 2 )
    {
        my $outdir      = shift;
        my $srcdir      = shift;
        
        # create the base class object
        $this = new Texmake::Node("$outdir/root.xhtml");
        
        # we also need to store the source directory of this generated document
        $this->{'srcdir'} = $srcdir;     
        
        # the bibliography node get's a special pointer so that the parser
        # can mark the bibliography dirty if the output shows missing citations
        $this->{'bibNode'}      = undef;
    }
    else
    {
        die "Latexml node created with wrong argument list";
    }
    
    bless($this);
    return $this;
}



##  @method bool doBuild(void)
#   @return    * 0 if the build was successful
#              * 1 if if the build needs to be performed again
#              * -1 if the build failed 
sub build
{
    my $this        = shift;
    my $outdir      = dirname($this->{'outfile'});
    my $srcdir      = $this->{'srcdir'};
    my $result      = BUILD_SUCCESS;
    
    print_n "In latexml node's build method";
   
    my $cwd         = getcwd();
    print_n 0, "Changing to working directory $outdir";
    unless(chdir $outdir)
    {
        print_f "Failed to change to build directory $outdir";
        die;
    }
    
    # generate the command to execute
    my $cmd = "latexml --destination=root.xml ".
                            "--path=$outdir ". 
                            "--path=$srcdir ".
                            " --verbose --verbose ".
                            " root.tex 2>&1";   
    my $fh;
    
    print_n 0, "Executing the following command: \n$cmd";
    
    # open a pipe from the command to our process
    open( $fh, '-|', $cmd);
    
    # create a parser object, the parser needs to know this node (so that it
    # can append dependencies), the file handle of the process (so that it can 
    # read the output), the output directory (so it knows where to put 
    # generated files which are missing), and the source directory (so it knows
    # where to search for sources of missing dependencies)
    $result = parse($this,$fh,$outdir,$srcdir);
    close $fh;
    
    # if the pdflatex process returned an error code but the parser did not
    # figure out any problems that it knows how to correct, then we'll actually
    # need to fail here
    if( ${^CHILD_ERROR_NATIVE} 
            && $result != BUILD_REBUILD )
    {
        $result = BUILD_FAIL;
    }
    
    print_n 0, "restoring CWD to $cwd";
    unless(chdir $cwd)
    {
        print_f "Failed to restore cwd: $cwd";
        die;
    }
    
    return $result;
}




sub parse
{
    my $node    = shift;
    my $fh      = shift;    
    my $outdir  = shift;
    my $srcdir  = shift;
    my $status  = BUILD_SUCCESS;
    my @loaded  = ();
    my @states  = ();
    my @figures = ();
    my $warnFlag    = 0;
    my $errorFlag   = 0;
    
    my $msgSplit    = 0;
    my $msgText     = "";
    my $msgContext  = "";
    
    print_n 0, "Parser::Latexml::Xml::Node is reading from fh: $fh";
    
    while(<$fh>)
    {
        chomp;
        
        print_e $_;
        
        if(/^Error:/)
        {
            print_f $_;
        }
        
        # if we get a trace with the bibliography files we'll need to add those
        # to our dependency list
        if(/Texmake Bibliographies: (.+)/)
        {
            print_n 0, <<"HERE"
            
            
        Bibliographies: $1        
            
            
HERE
        }
        
        
        # when files are loaded they're printed in parentheses, unfortunately
        # so are a number of other things, in any case, we want a list of all
        # the files that latex needs to build this document so we'll match for
        # any text following a parenthesis
        # so every time we match something following the opening of a 
        # parenthesis, we'll check to see if it exist, and if it does, then
        # we'll say it's a file that was loaded
        if(/(Loading|Processing) (.+)\.\.\./ && -e $2)
        {
            print_n 0, "$1 file $2";
            
            my $realPath = realpath($2);
            
            print_n 0, "   realpath: $realPath";
            
            # we'll store it in the list of loaded dependencies
            push(@loaded,$realPath);
        }
    }
        
    
    # we don't want to add multiple nodes for a particular source file, so
    # the first thing we'll do is put all the loaded files into a hash to make
    # them unique, and then we'll go through our current dependencies and update
    # the list
    my %depends;
    foreach my $load (@loaded)
    {
        $depends{$load} = {
            'state' => DEP_NEW,
            'node'  => undef
        };
    }
    
    foreach my $fig (@figures)
    {
        $depends{$fig} = {
            'state' => DEP_NEW,
            'node'  => undef
        }
    }
    
    # now we'll iterate over current dependencies and see how many of them were
    # in the list of files loaded
    my $nodeDepends = $node->{'depends'};
    foreach my $node (@$nodeDepends)
    {
        if( exists $depends{$node->{'outfile'}} )
        {
            $depends{$node->{'outfile'}}->{'state'} = DEP_KEEP;
            $depends{$node->{'outfile'}}->{'node'}  = $node;
        }
        else
        {
            $depends{$node->{'outfile'}} = {
                'state' => DEP_DROP,
                'node'  => $node
            };
        }
    }
    
    
    print_n 0, "Dependency List:\n---------------";
    # now print a list of all the files that were (or were not) loaded and 
    # their status as a dependency, also create new source nodes for new
    # dependencies
    my @newDepends;
    foreach my $file (keys %depends)
    {
        my $status = $depends{$file}->{'state'};
        my $symbol = "[?]";

        if($status == DEP_NEW)
        {
            $symbol = "[+]";
            my $newNode= new Texmake::Tools::Source::Node($file);
            push(@newDepends,$newNode);
        }
        
        elsif($status == DEP_KEEP)
        {
            $symbol = "[ ]";
            push(@newDepends,$depends{$file}->{'node'});
        }
        
        else
        {
            $symbol = "[x]";
        }
        
        print_e $symbol . "   $file";
    }
    
    # now reassign the dependency list for this node
    $node->{'depends'} = \@newDepends;
    
    
    
    
    
    my %stateFiles;
    foreach my $file (@states)
    {
        $stateFiles{$file} = {
            'state' => DEP_NEW,
            'node'  => undef,  
        };
    }
    
    
    my $nodeStates = $node->{'stateFiles'};
    foreach my $node (@$nodeStates)
    {
        if( exists $stateFiles{$node->{'outfile'}} )
        {
            $stateFiles{$node->{'outfile'}}->{'state'} = DEP_KEEP;
            $stateFiles{$node->{'outfile'}}->{'node'}  = $node;
        }
        else
        {
            $stateFiles{$node->{'outfile'}} = {
                'state' => DEP_DROP,
                'node'  => $node
            };
        }
    }
    
    print_n 0, "Intermediate Files:\n---------------";
    my @newStates;
    foreach my $file (keys %stateFiles)
    {
        my $status = $stateFiles{$file}->{'state'};
        my $symbol = "[?]";

        if($status == DEP_NEW)
        {
            $symbol = "[+]";
            my $newNode= new Texmake::Tools::TexState::Node($file);
            push(@newStates,$newNode);
        }
        
        elsif($status == DEP_KEEP)
        {
            $symbol = "[ ]";
            push(@newStates,$stateFiles{$file}->{'node'});
        }
        
        else
        {
            $symbol = "[x]";
        }
        
        print_e $symbol . "   $file";
    }
    
    $node->{'stateFiles'} = \@newStates;
    
    
    
    
    # just to make sure
    my $nDepends    = $#newDepends + 1;
    my $nStates     = $#newStates + 1;
    print_n 0, "There are $nDepends dependent files and "
                ."$nStates state files identified in this build";
    
    return $status;
}























1;