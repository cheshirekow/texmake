package Texmake::Parsers::Bibtex;

use strict;

use Switch;
use File::Basename;
use File::Path qw(make_path);
use Cwd qw(abs_path);


use Texmake qw(
        BUILD_FAIL
        BUILD_SUCCESS
        BUILD_REBUILD);

use Texmake::Printer qw(
        print_w 
        print_f 
        print_n 
        print_e);

use Texmake::PrintIncrementer;
use Texmake::DependencyGraph::Nodes::Source;
use Texmake::Initializers::Graphics qw(generate); 

use constant DEP_DROP => -1;
use constant DEP_KEEP => 0;
use constant DEP_NEW  => 1;

require Exporter;
our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration       use Foo::Bar ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
    parse
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);



sub parse
{
    my $node    = shift;
    my $fh      = shift;    
    my $outdir  = shift;
    my $srcdir  = shift;
    my $status  = BUILD_SUCCESS;
    my @loaded  = ();
    my @figures = ();
    
    print_n 0, "Parser::Bibtex is reading from fh: $fh";
    
    while(<$fh>)
    {
        chomp;
        print_e $_;
    }
    
    return $status;
}




1;