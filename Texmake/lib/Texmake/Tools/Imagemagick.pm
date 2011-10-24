package Texmake::Tools::Imagemagick;
require Texmake::Tools::Imagemagick::Node;
require Texmake::Tools::Source;

sub createTree
{
    my $classname   = shift;
    my $hash        = shift;
    my $outfile     = $hash->{'outfile'};
    my $srcfile     = $hash->{'srcfile'};
    my $pkg         = 'Texmake::Tools::';
    
    my $node1 = ($pkg.'Imagemagick::Node')->new($outfile,$srcfile);
    my $node2 = ($pkg.'Source::Node')->new($srcfile);
    
    $node1->dependsOn($node2);
    return $node1;
}


1;