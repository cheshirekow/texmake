package Texmake::Tools::Svg2pdf;

use strict;

use Texmake qw(BUILD_FAIL BUILD_SUCCESS BUILD_REBUILD);
use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use Texmake::Tools::Source;
use Texmake::Tools::Svg2pdf::Node;

sub createTree
{
    my $class   = shift;
    my $target  = shift;
    my $srcfile = $target->{'srcfile'};
    my $outfile = $target->{'outfile'};
    my $pkg     = 'Texmake::Tools::';
    
    print_n 0, "Creating svg2pdf and source nodes for $outfile and $srcfile";
    
    my $node1 = ($pkg.'Svg2pdf::Node')->new($outfile,$srcfile);
    my $node2 = ($pkg.'Source::Node')->new($srcfile);
    
    $node1->dependsOn($node2);
    return $node1;
}
 

1;