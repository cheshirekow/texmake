##  @class
#   @brief  a node which uses pdflatex to compile a .tex document
package Texmake::Tools::Latexml::Bib::Node;


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
        my $outfile     = shift;
        my $srcfile     = shift;
        
        # create the base class object
        $this = new Texmake::Node($outfile);
        
        # we also need to store the bibtex source file
        $this->{'srcfile'} = $srcfile;     
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
    my $outfile     = $this->{'outfile'};
    my $srcfile     = $this->{'srcfile'};
    my $outdir      = dirname($outfile);
    my $srcdir      = dirname($srcfile);
    my $result      = BUILD_SUCCESS;
    
    print_n "In latexml node's build method";
    
    # first make sure that the output directory exists
    if( -e $outdir )
    {
        unless( -d $outdir )
        {
            print_f "$outdir exists but is not a directory";
            die;
        }
    }
    
    else
    {
        unless( make_path($outdir) )
        {
            print_f "Failed to make directory for output file $outfile";
            die;
        }
        
        print_n 0, "Created output directory for $outfile";
    }
   
    my $cwd         = getcwd();
    print_n 0, "Changing to working directory $outdir";
    unless(chdir $outdir)
    {
        print_f "Failed to change to build directory $outdir";
        die;
    }
    
    # generate the command to execute
    my $cmd = "latexml --destination=$outfile ".
                            "--bibtex " .
                            " --verbose --verbose ".
                            " $srcfile 2>&1";   
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
    my @bibs    = ();
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
    }
        
    
    return $status;
}























1;