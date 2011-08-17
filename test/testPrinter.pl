#!/usr/bin/perl

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;

print_w "This is a warning";
print_f "This is an error";
print_n "This is a notice";
print_e "This is a continuation";

print_n "This is a \nlong multi-line comment\nwhich extends on\nand on\nand on";
sub_a();
print_n "This is back outside";

my $tmp = Texmake::PrintIncrementer->new();
print_n "This should be tabbed";
$tmp = 0;
print_n "This should not";

sub sub_a
{
    my $tmp = Texmake::PrintIncrementer->new();

    print_n "This is a notice inside a submodule";
    sub_b();
}

sub sub_b
{
    my $tmp = Texmake::PrintIncrementer->new();
    
    print_n "This is a notice inside \nanotehr submodule";
}