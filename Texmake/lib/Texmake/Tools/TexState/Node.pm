##  @class
#   @brief  a node which texmake doesn't actually build, but which is a
#           dependency for some other node
package Texmake::Tools::TexState::Node;

use strict;

use Switch;
use File::stat;
use File::Copy;
use File::Compare;
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
        my $file     = shift;
        
        # create the base class object
        $this = new Texmake::Node($file);
    }
    else
    {
        die "TexState node created with wrong argument list";
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
    print_w "Somehow found my way into the build method of a TexState "
                ."node for file " . $this->{'outfile'};
    return BUILD_FAIL;
}



sub evaluate
{
    my $this = shift;
    my $file = $this->{'outfile'};
    my $copy = "$file.old";
    
    if(-e $copy)
    {
        if( compare($file,$copy) == 0 )
        {
            return EVAL_NOACTION;
        }
        else
        {
            return EVAL_NEWER;
        }
    }
    else
    {
        return EVAL_NEWER;
    }
}


sub backup
{
    my $this = shift;
    my $file = $this->{'outfile'};
    copy($file,"$file.old");
}



1;