package Texmake::Printer;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration       use Foo::Bar ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
    print_w
    print_f
    print_n
    print_e
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);

our $VERSION = '0.01';




our $tab    = "";
my $ten     = "          ";
my $debug   = 0;

sub print_w
{
    print STDERR "[WARNING] $tab";
    _print(@_);
}

sub print_f
{
    print STDERR "[FATAL]   $tab";
    _print(@_);
}

sub print_n
{
    if($debug)
    {
        print STDERR "[NOTICE]  $tab";
        _print(@_);
    }
}

sub print_e
{
    if($debug)
    {
        print STDERR "$ten$tab";
        _print(@_);
    }
}



sub _print
{
    my @array = @_;
    foreach (@array)
    {
        s/\n/\n$ten$tab/g;
        print STDERR $_;
    }
    print STDERR "\n";
}

sub setDebug
{
    # shift off the class name
    shift;
    
    my $value = shift;
    $debug = $value;
}



1;

