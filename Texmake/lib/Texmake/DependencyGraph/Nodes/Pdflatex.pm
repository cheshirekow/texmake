##  @class
#   @brief  a node which uses pdflatex to compile a .tex document
package Texmake::DependencyGraph::Nodes::Pdflatex;

use strict;

use Switch;
use File::stat;
use File::Copy;
use File::Basename qw(dirname);
use Time::localtime;
use Cwd qw(getcwd);

use Texmake qw(BUILD_FAIL BUILD_SUCCESS BUILD_REBUILD);
use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;

use Texmake::Parsers::Pdflatex qw(parse);
use Texmake::DependencyGraph::Node;
 

our @ISA = ('Texmake::DependencyGraph::Node');


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
        $this = new Texmake::DependencyGraph::Node("$outdir/root.pdf");
        
        # we also need to store the source directory of this generated document
        $this->{'srcdir'} = $srcdir;     
        
        # the bibliography node get's a special pointer so that the parser
        # can mark the bibliography dirty if the output shows missing citations
        $this->{'bibNode'} = undef;
    }
    else
    {
        die "Pdflatex node created with wrong argument list";
    }
    
    bless($this);
    return $this;
}



##  @method bool doBuild(void)
#   @return    * 0 if the build was successful
#              * 1 if if the build needs to be performed again
#              * -1 if the build failed 
sub doBuild
{
    my $this        = shift;
    my $outdir      = dirname($this->{'outfile'});
    my $srcdir      = $this->{'srcdir'};
    
    print_n "In pdflatex node's build method";
   
    my $cwd         = getcwd();
    print_n 0, "Changing to working directory $outdir";
    unless(chdir $outdir)
    {
        print_f "Failed to change to build directory $outdir";
        die;
    }
    
    # generate the command to execute
    my $cmd = "export TEXINPUTS=$srcdir:$outdir: "
            ."&& pdflatex -interaction nonstopmode root.tex";   
    my $fh;
    
    # open a pipe from the command to our process
    open( $fh, '-|', $cmd);
    
    # create a parser object, the parser needs to know this node (so that it
    # can append dependencies), the file handle of the process (so that it can 
    # read the output), the output directory (so it knows where to put 
    # generated files which are missing), and the source directory (so it knows
    # where to search for sources of missing dependencies)
    my $result = parse($this,$fh,$outdir,$srcdir);
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


1;