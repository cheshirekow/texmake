package Texmake::LatexmlBuilder;

use strict;

use Fcntl;
use Proc::Killfam;  #apt-get libproc-processtable-perl
use File::Path qw(make_path);
use Switch;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use Texmake::Builder;


# creates a new maker which holds the state of the current build process
sub new()
{
    # first, shift off the class name
    shift;

    # we are passed a pointer to the Texmake::Builder object
    my $parent = shift;
    
    # copy the hash and make it this object as well
    my %copy    = %$parent;
    my $this    = \%copy;
    
    $parent->create_rootfile("\\htmloutputtrue")
    switch($this->{'out'}->{'ext'})
    {
        case "html"
        {
            $parent->create_rootfile("\\htmloutputtrue");
        }
        
        case "xhtml"
        {
            $parent->create_rootfile("\\xhtmloutputtrue");
        }
    }
    
    # this is where the bibtex scanner will stores bibliography files that
    # bibtex generates
    $this->{'bib_files'}    = ();
    
    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::LatexBuilder object
    return $this;
}


sub go()
{
    
}


my @ISA = ("Texmake::Builder");


