##  @class
#   @brief  a node which uses pdflatex to compile a .tex document
package Texmake::Tools::TexRootMaker::Node;

use strict;

use Texmake ':all';
use Texmake::Printer ':all';
use Texmake::PrintIncrementer;

use Texmake::Node;

our @ISA = ('Texmake::Node');


##  @cmethod object new($outdir,$srcfile)
sub new
{
    my $this;

    # first, shift off the class name
    shift;
    
    my $params  = shift;
    my $outdir  = $params->{'outdir'};

    # create the base class object
    $this = new Texmake::Node("$outdir/root.tex");
    $this->{'srcdir'} = $params->{'srcdir'};
    $this->{'inputs'} = $params->{'inputs'};
    $this->{'header'} = $params->{'header'};
    $this->{'footer'} = $params->{'footer'};
    
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
    my $files       = $this->{'inputs'};
    
    print_n "In TexRootMaker node's build method";
   
    # we only actually need to build it if it doesn't exist
    if( -e $outfile )
    {
        return BUILD_SUCCESS;      
    }
    
    # open the file to write to    
    my $fh;
    unless( open( $fh, '>', $outfile) )
    {
        print_f "Failed to open rootfile: $outfile for writing";
        die;
    }
   
    # if the user gave us a header then output it
    if( exists $this->{'header'} )
    {
        print $fh $this->{'header'};
        print $fh "\n";
    }
    
    # for each source file, put the input statement
    foreach my $file (@$files)
    {
        $file = $this->{'srcdir'} . '/' . $file;
        print $fh "\\input{$file}\n";
    }
    
    # if the user gave us a footer then output it
    if( exists $this->{'footer'} )
    {
        print $fh $this->{'footer'};
        print $fh "\n";
    }
    
    close $fh;
    
    return BUILD_SUCCESS;
}





























1;