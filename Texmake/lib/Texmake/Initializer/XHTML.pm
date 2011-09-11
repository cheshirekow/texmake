package Texmake::Initializer::XHTML;

use strict;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;



# creates a new dependency graph node
sub new
{
    # make self a reference to an anonymouse hash
    my $this = 
    {

    };  
    
    # first, shift off the class name
    shift;

    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::Builder object
    return $this;
}






1;