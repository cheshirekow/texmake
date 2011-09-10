package Texmake::DependencyGraph::Node

use strict;

use Fcntl;
use Proc::Killfam;  #apt-get libproc-processtable-perl
use File::Path qw(make_path);
use Switch;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;



# creates a new dependency graph node
sub new()
{
    # make self a reference to an anonymouse hash
    my $this = 
    {
        'file'      => undef,
        'build'     => undef,
        'depends'   => undef
    };  
    
    # first, shift off the class name
    shift;

    # this method requires at least two parameters
    if( ($#_ +1) >= 1 )
    {
        #blah
    }
    else
    {
        die "Node created with not enough arguments";
    }

    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::Builder object
    return $this;
}