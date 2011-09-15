package Texmake::Runner;

use strict;

use Switch;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;

use Texmake::Parser::Latex;
use Texmake::Parser::PDFLatex;
use Texmake::Parser::LateXML;
use Texmake::Parser::Null;

use File::Path qw(make_path);

# creates a new dependency graph node
sub new
{
    # make self a reference to an anonymouse hash
    my $this = 
    {
        'node'   => undef,
    };  
    
    # first, shift off the class name
    shift;
    
    if( $#_ +1 == 1 )
    {
        $this->{'node'} = shift;
    }
    else
    {
        print_f "Runner created with wrong number of arguments";
        die;
    }

    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::Builder object
    return $this;
}


sub go
{
    my $this    = shift;
    my $node    = $this->{'node'};  
    my $fh;
    my $parser;
    my $build   = $node->{'build'};
    my $output  = $node->{'file'};
    my $outdir  = $node->{'outdir'};
    my $rebuild = 1;
    
    if($outdir)
    {
        unless(-e $outdir)
        {
            print_n 0, "$outdir doesn't exist, creating it";
            unless(make_path($outdir))
            {
                print_f "Failed to create directory $outdir";
            }
        }
        
        print_n 0, "changing to $outdir";
        unless(chdir $outdir)
        {
            print_f "Can't change to $outdir";
            die;
        }
    }
    else
    {
        print_n 0, "No outdir specified";
    }

    $/ = "\n";
    while($rebuild)
    {
        $rebuild = 0;
        unless( open( $fh, '-|', $build) )
        {
            print_f "Command $build Failed to open";
            die;
        }
    
        print_n 0, "Runner is executing the following at filehandle $fh:";
        print_e $build;
        
        if($build =~ /pdflatex/)
        {
            $parser = new Texmake::Parser::PDFLatex($node,$fh);
        }
        elsif($build =~ /latexml/)
        {
            $parser = new Texmake::Parser::LateXML($node,$fh);
        }
        elsif($build =~ /latex/)
        {
            $parser = new Texmake::Parser::Latex($node,$fh);   
        }
        else
        {
            $parser = new Texmake::Parser::Null($node,$fh);
        }
        
        my $status = $parser->go();
        close $fh;
        return $status;
    }
}




1;