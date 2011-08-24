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
our $ten     = "          ";
our $debug   = 0;
our $levelcache = 1;

sub print_w
{
    unshift(@_,0);
    unshift(@_,"[WARNING] $tab");
    _print(@_);
}

sub print_f
{
    unshift(@_,0);
    unshift(@_,"[FATAL]   $tab");
    _print(@_);
}

sub print_n
{
    unshift(@_,"[NOTICE]  $tab");
    _print(@_);
}

sub print_e
{
    unshift(@_,$levelcache);
    unshift(@_,"$ten$tab");
    _print(@_);  
}



sub _print
{
    my $prefix  = shift;

    my $level   = shift;
    
    # if the first parameter passed to the public print method contains non
    # numeric characters, then no level was provided
    if($level=~/\D/ || length($level) < 1)
    {
        unshift(@_,$level);
        $level = $levelcache;
    }
    
    $levelcache = $level;
    
    # if the level passed to this method is a high level debugging message, 
    # then don't print it
    return if($level > $debug);
    
    # print the prefix
    print STDERR $prefix;

    my @array   = @_;
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

