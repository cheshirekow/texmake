package Texmake::Tools::Copy;

##  @class
#   @brief  a node which creates the output by copying another file
package Texmake::Tools::Copy::Node;

use strict;

use Switch;
use File::stat;
use File::Copy;
use Time::localtime;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use Texmake::Node;

our @ISA = ('Texmake::Node');


##  @cmethod object new($output,$source)
#   @brief   constructor, creates a new copy node
#   @param[in]  output  the output file which is created
#   @param[in]  source  the source file to copy
sub new
{
    my $this;

    # first, shift off the class name
    shift;
    
    # this method requires two parameters
    if( ($#_ +1) == 2 )
    {
        my $outfile     = shift;
        my $srcfile     = shift;
        
        # create the base class object
        $this = new Texmake::Node($outfile);
        
        # add the data members that are required
        $this->{'srcfile'}      = $srcfile;
    }
    else
    {
        die "Copy node created with wrong argument list";
    }
    
    bless($this);
    return $this;
}



##  @method bool build(void)
#   @return    * 0 if the build was successful
#              * 1 if if the build needs to be performed again
#              * -1 if the build failed 
sub build
{
    my $this        = shift;
    
    print_n 0, "Copying " . $this->{'srcfile'} . " to " . $this->{'outfile'};
    copy($this->{'srcfile'},$this->{'outfile'});
}


1;