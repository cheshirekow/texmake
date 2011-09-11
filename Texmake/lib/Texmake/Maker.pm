package Texmake::Maker;

use strict;

use Fcntl;
use Proc::Killfam;  #apt-get libproc-processtable-perl
use File::Path qw(make_path);
use Switch;
use XML::Dumper;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use Texmake::Builder;





# creates a new maker which holds the state of the current build process
sub new()
{
    # first, shift off the class name
    shift;

    my $this = {
        'targets' => undef,  
    };
    
    if(@_)
    {
        my @targets;
        while(@_)
        {
            my $target = shift;
            my $build = "$target.texmake";
            if( -e $build && -d $build )
            {
                push(@targets,$target);
            }
            else
            {
                print_w "Sorry, there is no build directory $build for" 
                            ."target $target, perhaps you meant to execute" 
                            ."texmake init?";
            }
        }
        
        $this->{'targets'} = \@targets;
    }
    else
    {
        print_n 0, "Maker created with no targets specified, searching cwd";
          
        my @targets;
        while(<*>)
        {
            my $entry = $_;
            if( $entry=~/(.+)\.texmake$/ && -d $entry )
            {
                print_n 0, "Found a build directory for $1";
                push(@targets,$1);
            }
        }
        $this->{'targets'} = \@targets;
    }
    
    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::LatexBuilder object
    return $this;
}




sub go()
{
    my $this    = shift;
    my $targets = $this->{'targets'};
    
    foreach my $target (@$targets)
    {
        print_n 0, "Target: $target";
        print_n 0, "Loading dependency graph";
        
        my $depfile = "$target.texmake/dependencies.xml";
        unless( -e $depfile)
        {
            print_f "$depfile does not exist";
            die;
        }

        #set slurp mode for reads
        local($/) = undef;
        my $fh;
        open( $fh, '<', $depfile);
        my $dump    = <$fh>;
        close $fh;

        my $xmldump = new XML::Dumper;
        my $node = $xmldump->xml2pl($dump);
        $node->build();
    }
}


1;