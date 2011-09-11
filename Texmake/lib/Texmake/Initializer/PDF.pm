package Texmake::Initializer::PDF;

use strict;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use XML::Dumper;
use File::Basename;


# creates a new dependency graph node
sub new
{
    # make self a reference to an anonymouse hash
    my $this = 
    {
        'output' => undef,
        'source' => undef
    };  
    
    # first, shift off the class name
    shift;
    
    if( $#_ +1 == 2 )
    {
        $this->{'output'} = shift;
        $this->{'source'} = shift;        
    }
    else
    {
        print_f "Initializer::PDF created with wrong number of arguments";
        die;
    }

    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::Builder object
    return $this;
}

sub go
{
    my $this    = shift;
    my $output  = $this->{'output'};
    my $source  = $this->{'source'};
    my $build   = "$output.texmake";
    my $srcdir  = dirname($source);
    
    my $fh;
    print_n 0, "Generating $build/root.tex";
    open ($fh, '>', "$build/root.tex");
    print $fh <<"HERE";
\\newif\\ifpdfoutput
\\newif\\ifxhtmloutput
\\newif\\ifdvioutput

\\pdfoutputtrue
\\listfiles

\\input{$source}
HERE
    close $fh;
    
    my $rootFile= "$build/root.tex";
    my $buildOut= "$build/root.pdf";
    
    my $outNode = new Texmake::DependencyGraph::Node($output,
                                                        "cp $buildOut $output");

    my $buildCMD= <<"HERE";
    export TEXINPUTS=".:$build:$srcdir:" \\
    && pdflatex \\
        -interaction nonstopmode \\
        -output-directory $build \\
        root.tex 2>&1    
HERE
    my $bldNode = new Texmake::DependencyGraph::Node($buildOut, $buildCMD);
                                                        
    my $rootNode= new Texmake::DependencyGraph::Node($rootFile,"");

    $bldNode->dependsOn($rootNode);
    $outNode->dependsOn($bldNode);

    my $xmldump = new XML::Dumper();
    
    print_e "Generating $build/dependencies.xml";
    open($fh, '>', "$build/dependencies.xml");
    print $fh $xmldump->pl2xml($outNode);
    close $fh;
}




1;