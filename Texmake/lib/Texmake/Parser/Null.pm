package Texmake::Parser::Null;

use strict;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;



# creates a new dependency graph node
sub new
{
    # make self a reference to an anonymouse hash
    my $this = 
    {
        'node'   => undef,
        'fh'     => undef
    };  
    
    # first, shift off the class name
    shift;
    
    if( $#_ +1 == 2 )
    {
        $this->{'node'} = shift;
        $this->{'fh'}   = shift;        
    }
    else
    {
        print_f "Parser::NULL created with wrong number of arguments";
        die;
    }

    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::Builder object
    return $this;
}


sub go
{
    my $this    = shift;
    my $node    = $this->{'node'};  
    my $fh      = $this->{'fh'};    
    
    while(<$fh>)
    {
        chomp;
        print_e $_;
    }
}




1;