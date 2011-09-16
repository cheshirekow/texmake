package Texmake::Tools::TexRootMaker;

use     Texmake::Node;
require Texmake::Tools::Source;

sub createTree
{
    my $outdir      = shift;
    my $srcdir      = shift;
    my $entries     = shift;
    my $files       = $entries->{'inputs'};
    
    for($i=0; $i <= $#$files; $i++ )
    {
        $files[$i] = "$srcdir/".$files[$i];
    }
    
    my $texNode     = new Texmake::Tools::TexRootMaker::Node($outdir,$entries);
}


1;