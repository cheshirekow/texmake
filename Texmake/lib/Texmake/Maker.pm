##  @class
#   @brief  class which builds a project by recursing down the dependency
#           graph and building individual parts
package Texmake::Maker;

use strict;

use Fcntl;
use Proc::Killfam;  #apt-get libproc-processtable-perl
use File::Path qw(make_path);
use Switch;
use XML::Dumper;

use Texmake qw(EVAL_FAIL EVAL_BUILDME);
use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use Texmake::BuilderRegistry;

use Texmake::Tools::Bibtex;
use Texmake::Tools::Copy;
use Texmake::Tools::Imagemagick;
use Texmake::Tools::Pdflatex;
use Texmake::Tools::Source;
use Texmake::Tools::Svg2eps;
use Texmake::Tools::Svg2pdf;
use Texmake::Tools::TexRootMaker;



##  @cmethod    object new(void)
#   @brief      creates a new maker which holds the state of the current 
#               build process
sub new()
{
    Texmake::BuilderRegistry::init();
    
    # first, shift off the class name
    shift;

    my $this = {
        'targets' => undef,  
    };

    # if called with arguments, arguments are assumed to be targets and will
    # look for the dependency graph for each target and build them
    if(@_)
    {
        my @targets;
        
        # iterate over all parameters as targets
        while(@_)
        {
            # shift off the next target
            my $target = shift;
            
            # the build directory is named after the target with .texmake 
            # appended
            my $build = "$target.texmake";
            
            # if the build directory exists and is a directory then we'll add
            # this target to the list of targets to build
            if( -e $build && -d $build )
            {
                push(@targets,$target);
            }
            
            # otherwise we print a warning and move on
            else
            {
                print_w "Sorry, there is no build directory $build for" 
                            ."target $target, perhaps you meant to execute" 
                            ."texmake init?";
            }
        }

        # set the targets datamember to be a reference to the target array
        $this->{'targets'} = \@targets;
    }
    
    # if called with no arguments, will search the current directory for
    # targets identified by their .texmake build directory and will build these
    # targets
    else
    {
        print_n 0, "Maker created with no targets specified, searching cwd";
          
        my @targets;
        
        # iterate over files in the current working directory
        while(<*>)
        {
            my $entry = $_;
            
            # if the entry is named 'something.texmake' and it is a directory
            # then we assume it is a build directory 
            if( $entry=~/(.+)\.texmake$/ && -d $entry )
            {
                print_n 0, "Found a build directory for $1";
                push(@targets,$1);
            }
        }
        
        $this->{'targets'} = \@targets;
    }
    
    bless($this);
    return $this;
}



##  @method void go(void)
#   @brief  iterates over all targets, attempts to load the dependency graph
#           and builds them 
sub go()
{
    my $this    = shift;
    my $targets = $this->{'targets'};
    
    # iterate over all targets
    foreach my $target (@$targets)
    {
        print_n 0, "Target: $target";
        print_n 0, "Loading dependency graph";

        # try to find the dependency graph file
        my $depfile = "$target.texmake/dependencies.xml";
        unless( -e $depfile)
        {
            print_f "$depfile does not exist";
            die;
        }

        #set slurp mode for reads
        local($/) = undef;
        my $fh;
        
        #open the file and dump it's entire contents to a string
        unless( open( $fh, '<', $depfile) )
        {
            print_f "Failed to open dependency graph for reading $!";
            die;
        }
        my $dump    = <$fh>;
        close $fh;
        
        #restore readline mode
        local($/) = "\n";

        # convert the file xml to a perl object (a dependency graph in fact)
        my $xmldump = new XML::Dumper;
        my $node = $xmldump->xml2pl($dump);

        # clear out run counts
        $node->initMake();        
        
        # evaluate/build the node
        my $result = EVAL_BUILDME;
        while( $result == EVAL_BUILDME )
        {
            $result = $node->evaluate();
        }
        
        
        if($node->evaluate() == EVAL_FAIL)
        {
            print_f "Build failed";
            die;
        }
        
        # write out the udpated dependency graph
        unless( open( $fh, '>', $depfile) )
        {
            print_f "Failed to open dependency graph for writing $!";
            die;
        }
        print $fh $xmldump->pl2xml($node);
        close($fh);
    }
}


1;