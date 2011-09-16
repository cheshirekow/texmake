package Texmake::Tools::Svg2eps;
use     Texmake::Tools::Svg2eps::Node;
require Texmake::Tools::Source;

sub createTree
{
    my $outfile = shift;
    my $srcfile = shift;
    my $pkg     = 'Texmake::Tools::';
    
    my $node1 = ($pkg.'Svg2eps::Node')->new($outfile,$srcfile);
    my $node2 = ($pkg.'Source::Node')->new($srcfile);
    
    $node1->dependsOn($node2);
    return $node1;
}

1;