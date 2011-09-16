##  @class
#   @brief  a node which texmake doesn't actually build, but which is a
#           dependency for some other node
package Texmake::Tools::Source::Node;

use strict;

use Switch;
use File::stat;
use File::Copy;
use Time::localtime;

use Texmake ':all'; 
use Texmake::Printer ':all';
use Texmake::PrintIncrementer;
use Texmake::Node;


our @ISA = ('Texmake::Node');


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
        $this = new Texmake::Node($srcfile);
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
sub build
{
    my $this = shift;
    print_w "Somehow found my way into the build method of a source "
                ."node for file " . $this->{'outfile'};
    return BUILD_FAIL;
}


1;