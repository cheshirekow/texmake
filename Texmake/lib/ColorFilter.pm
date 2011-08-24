package Texmake::ColorFilter;

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
        'filters' => undef
    };  
    
    # first, shift off the class name
    shift;
    
    my @filters;
    
    # no shift off filter rules, they should be in the form of 
    # rule color rule color
    while(@_)
    {
        my $rule  = shift;
        my $color = shift;
        my $filter = 
        {
            'rule' => $rule,
            'color'=> $color
        };
        
        push(@filters,$filter);
    }
    
    $this->{'filters'} = \@filters;
    
    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::Builder object
    return $this;
}




sub go()
{
    my $this    = shift;
    my $filters = $this->{'filters'};
    
    while(<STDIN>)
    {
        foreach my $filter(@$filters)
        {
            my $rule    = $filter->{'rule'};
            my $color   = $filter->{'color'};
            my $code    = ${$colors}{'white'};
            
            $code = ${$colors}{$color} if(defined ${$colors}{$color});
            
            if(/$rule/)
            {
                print "\033[" . $code . "m";    
                last;
            }
        }
        
        print $_;
    }
    
        
    system( "tput sgr0" );
}



