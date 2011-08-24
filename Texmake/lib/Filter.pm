package Texmake::Filter;

use strict;


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
    
    # then copy all the filters that are passed in
    my @filters = @_;
    
    # then store a reference to this in the object
    $this->{'filters'} = \@filters;
    
    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::Builder object
    return $this;
}




sub go()
{
    my $this        = shift;
    my $filters     = $this->{'filters'};
    my $matched;
    while(<STDIN>)
    {
        
        $matched = 0;
        foreach my $filter (@$filters)
        {
            if(/$filter/)
            {
                print STDOUT $_;
                $matched = 1;
                last;
            }
        }
        
        next if($matched);
        print STDERR $_;
    }
}



1;