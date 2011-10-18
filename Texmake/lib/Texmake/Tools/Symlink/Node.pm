##  @class
#   @brief  a node which creates the an output by softlinking to a file in
#           the build directory
package Texmake::Tools::Symlink::Node;

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
        die "Softlink node created with wrong argument list";
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
    my $dobuild     = 1;
    
    print_n 0, "Symlinking" . $this->{'srcfile'} . " to " . $this->{'outfile'};
    
    if( -e $this->{'outfile'} )
    {
        print_n 0, "output file already exists";
        if( -l $this->{'outfile'} )
        { 
            print_n 0, "and it's a symbolic link";
            if( readlink($this->{'outfile'}) eq $this->{'srcfile'} )
            {
                print_n 0, "and it points to the correct location, so we're fine";
                $dobuild = 0;                
            }
            else
            {
                print_n 0, "but it points to the wrong location, I'll try to delete it";
                unlink($this->{'outfile'});
            }
        }
        else
        {
            print_w 0, "but it's not a symbolic link, I'll try to delete it";
            unlink($this->{'outfile'});
        }
    }
    
    if($dobuild)
    {
        symlink($this->{'srcfile'},$this->{'outfile'});
    }
}


1;