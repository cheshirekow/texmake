package Texmake::Colorizer;

use strict;


my $colors = 
{
    'black'     => 30,
    'red'       => 31,
    'green'     => 32,
    'yellow'    => 33,
    'blue'      => 34,
    'magenta'   => 35,
    'cyan'      => 36,
    'white'     => 37
};

# creates a new maker which holds the state of the current build process
sub new()
{
    # make self a reference to an anonymouse hash
    my $this = 
    {
        'code' => undef
    };  
    
    # first, shift off the class name
    shift;
    
    # then get the color requested
    my $color = shift;
    
    if(defined ${$colors}{$color})
    {
        $this->{'code'} = ${$colors}{$color};
    }
    else
    {
        my @list = (keys %$colors);
        $this->{'code'} = ${$colors}{'white'};
    }
    
    
    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::Builder object
    return $this;
}




sub go()
{
    my $this = shift;
    my $code = $this->{'code'};
    
    while(<STDIN>)
    {
        print "\033[" . $code . "m$_";
        system( "tput sgr0" );
    }
}



