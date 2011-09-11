package Texmake::Parser::PDFLatex;

use strict;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use File::Basename;
use File::Path qw(make_path);


# creates a new dependency graph node
sub new
{
    # make self a reference to an anonymouse hash
    my $this = 
    {
        'node'   => undef,
        'fh'     => undef
    };  
    
    # first, shift off the class name
    shift;
    
    if( $#_ +1 == 2 )
    {
        $this->{'node'} = shift;
        $this->{'fh'}   = shift;        
    }
    else
    {
        print_f "Parser::PDF created with wrong number of arguments";
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
    my $fh      = $this->{'fh'};    
    my $status  = 0; #OK
    
    print_n 0, "Parser::PDFLatex is reading from fh: $fh";
    
    while(<$fh>)
    {
        chomp;
        print_e $_;
        
        if(/^!/)
        {
            print_w $_;
        }
        
        if(/I can't write on file `([^']+)/)
        {
            my $output = $node->{'file'};
            my $blddir = dirname($output);
            my $misdir = $blddir . '/' . dirname($1);
            print_n 0, "Detected missing directory $misdir";
            
            if(make_path($misdir))
            {
                $status = 1; #REBUILD
            }
            
            else
            {
                print_f "Failed to create $misdir";
                $status = -1; #Epic FAIL                                
            }
        }
        
        if(/File `([^']+)' not found/)
        {
            print_n 0, "Detected missing file $1";
            $status = -1;
        }
    }
    
    return $status;
}




1;