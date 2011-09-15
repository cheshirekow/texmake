##  @class
#   @brief  contains generator for building nodes that generate an output
#           graphics file from some input graphics file
package Texmake::Initializers::Graphics;

use strict;
use File::Basename;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;

use Texmake::DependencyGraph::Nodes::Svg2pdf;
use Texmake::DependencyGraph::Nodes::Svg2eps;
use Texmake::DependencyGraph::Nodes::Imagemagick;





require Exporter;
our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration       use Foo::Bar ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
    generate
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);






our $buildMap = 
{
    '.svg' => 
    {
        '.pdf'  => \&generateSvg2Pdf,
        '.eps'  => \&generateSvg2Eps,
        '.png'  => \&generateConvert, 
    },  
    
    '.png' =>
    {
        '.pdf'  => \&generateConvert,
        '.eps'  => \&generateConvert,
        '.png'  => \&generateConvert,
    }
};

##  @method node generate($outfile,$srcfile)
#   @brief  creates a new graphics builder node generating the output graphics
#           from the specified input file
#   @note   this method merely dispatches the appropriate method which does
#           the real work
sub generate
{
    my $outfile = shift;
    my $srcfile = shift;
    
    my ($dummy1,$dummy2,$outext)  = fileparse($outfile,qr/\.[^.]+/);
    my ($dummy3,$dummy4,$srcext)  = fileparse($srcfile,qr/\.[^.]+/);
    
    unless( exists $buildMap->{$srcext} )
    {
        print_f "no know graphics converter that reads " 
                . "files with extension $srcext";
        die;
    }
    
    unless ( exists $buildMap->{$srcext}->{$outext} )
    {
        print_f "no known graphics converter that reads $srcext and outputs "
                ."$outext files";
        die;
    }
    
    my $dispatch= $buildMap->{$srcext}->{$outext};
    return &$dispatch($outfile,$srcfile);
}




sub generateSvg2Pdf
{
    my $outfile = shift;
    my $srcfile = shift;
    
    my $node1 = new Texmake::DependencyGraph::Nodes::Svg2pdf($outfile,$srcfile);
    my $node2 = new Texmake::DependencyGraph::Nodes::Source($srcfile);
    
    $node1->dependsOn($node2);
    return $node1;
}

sub generateSvg2Eps
{
    my $outfile = shift;
    my $srcfile = shift;
    
    my $node1 = new Texmake::DependencyGraph::Nodes::Svg2eps($outfile,$srcfile);
    my $node2 = new Texmake::DependencyGraph::Nodes::Source($srcfile);
    
    $node1->dependsOn($node2);
    return $node1;
}

sub generateSvg2Convert
{
    my $outfile = shift;
    my $srcfile = shift;
    
    my $node1 = new Texmake::DependencyGraph::Nodes::Imagemagik($outfile,$srcfile);
    my $node2 = new Texmake::DependencyGraph::Nodes::Source($srcfile);
    
    $node1->dependsOn($node2);
    return $node1;
}





1;