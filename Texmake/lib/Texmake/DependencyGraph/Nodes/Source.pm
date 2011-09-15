##  @class
#   @brief  a node which texmake doesn't actually build, but which is a
#           dependency for some other node
package Texmake::DependencyGraph::Nodes::Source;

use strict;

use Switch;
use File::stat;
use File::Copy;
use Time::localtime;
 
use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use Texmake::DependencyGraph::Node;


our @ISA = ('Texmake::DependencyGraph::Node');


##  @cmethod object new($source)
#   @brief   constructor, creates a new source node
#   @param[in]  source  the source file to watch
sub new
{
    my $this;

    # first, shift off the class name
    shift;
    
    # this method requires one parameters
    if( ($#_ +1) == 1 )
    {
        my $srcfile     = shift;
        
        # create the base class object
        $this = new Texmake::DependencyGraph::Node($srcfile);
    }
    else
    {
        die "Source node created with wrong argument list";
    }
    
    bless($this);
    return $this;
}



##  @method bool doBuild(void)
#   @return    * 0 if the build was successful
#              * 1 if if the build needs to be performed again
#              * -1 if the build failed 
sub doBuild
{
    return -1;
}


1;