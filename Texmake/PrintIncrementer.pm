package Texmake::PrintIncrementer;

use Texmake::Printer;

use strict;
use warnings;

my $inc = "   ";

sub new
{
    my $this = {};
    
    $Texmake::Printer::tab.=$inc;
    
    bless ($this);
    return $this;
}

sub DESTROY
{
    $Texmake::Printer::tab =~ s/$inc//;
}