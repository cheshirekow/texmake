package Texmake::Tools::Bibtex;

use strict;

use Switch;
use File::stat;
use File::Copy;
use File::Basename qw(dirname);
use Time::localtime;
use Cwd qw(getcwd);

use Texmake ':all';
use Texmake::Printer ':all';
use Texmake::PrintIncrementer;

use Texmake::Node;

sub getSourceTypes
{
    return ();
}

sub getOutputTypes
{
    return qw(bbl);
}



sub parse
{
    my $node    = shift;
    my $fh      = shift;    
    my $outdir  = shift;
    my $srcdir  = shift;
    my $status  = BUILD_SUCCESS;
    my @loaded  = ();
    my @figures = ();
    
    print_n 0, "Parser::Bibtex is reading from fh: $fh";
    
    while(<$fh>)
    {
        chomp;
        print_e $_;
    }
    
    return $status;
}



##  @class
#   @brief  a node which uses bibtex to compile a .bbl document from a .aux 
package Texmake::Tools::Bibtex::Node;

use strict;

use Switch;
use File::stat;
use File::Copy;
use File::Basename qw(dirname);
use Time::localtime;
use Cwd qw(getcwd);

use Texmake ':all';
use Texmake::Printer ':all';
use Texmake::PrintIncrementer;

use Texmake::Node;
 

our @ISA = ('Texmake::Node');


sub new
{
    my $this;

    # first, shift off the class name
    shift;
    
    # this method requires only one parameters
    if( ($#_ +1) == 2 )
    {
        my $outdir      = shift;
        my $srcdir      = shift;
        # create the base class object
        $this = new Texmake::Node("$outdir/root.bbl");
        
        $this->{'srcdir'} = $srcdir;
    }
    else
    {
        die "Bibtex node created with wrong argument list";
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
    my $srcdir      = $this->{srcdir};
    
    print_n "In bibtex's node's build method";
   
    my $cwd         = getcwd();
    print_n 0, "Changing to working directory $outdir";
    unless(chdir $outdir)
    {
        print_f "Failed to change to build directory $outdir";
        die;
    }
    
    my $cmd = "export BIBINPUTS=$srcdir:$outdir: "
                ."&& bibtex root";   
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