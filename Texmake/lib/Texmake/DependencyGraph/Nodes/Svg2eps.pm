##  @class
#   @brief  a node which uses Svg2pdf to convert image types
package Texmake::DependencyGraph::Nodes::Svg2pdf;

use strict;

use Switch;
use File::stat;
use File::Copy;
use File::Basename qw(dirname);
use File::Path     qw(make_path);
use Time::localtime;
use Cwd qw(getcwd);

use Texmake qw(BUILD_FAIL BUILD_SUCCESS BUILD_REBUILD);
use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;

use Texmake::DependencyGraph::Node;
 

our @ISA = ('Texmake::DependencyGraph::Node');


##  @cmethod object new($outfile,$srcfile)
#   @brief   constructor, creates a new imagemagick node
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
        $this = new Texmake::DependencyGraph::Node("$outfile");
        
        # we also need to store the source directory of this generated document
        $this->{'srcfile'} = $srcfile;     
    }
    else
    {
        die "Svg2pdf node created with wrong argument list";
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
    my $outfile     = $this->{'outfile'};
    my $srcfile     = $this->{'srcfile'};
    my $result      = BUILD_SUCCESS;
    
    print_n "In svg2pdf node's build method";
    
     # first make sure that the output directory exists
    my $outdir      = dirname($outfile);
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
   
    # generate the command to execute
    my $cmd = "svg2pdf $srcfile $outfile";   
    
    # call the command without a parser
    system($cmd);
    
    # if the process returned an error code then we'll report failure here
    if( ${^CHILD_ERROR_NATIVE}  )
    {
        $result = BUILD_FAIL;
    }
    
    return $result;
}


1;