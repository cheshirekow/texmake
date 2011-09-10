package Texmake::Initializer;

use strict;

use Cwd qw(getcwd abs_path);

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use File::Basename;
use Switch;
use File::Path qw(make_path);


our $singleton;


# creates a new initializer which generates the output directory structure
# and the initial rules for building documents
sub new
{
    my $this = 
    {
        'srcdir'  => undef,
        'outdir'  => abs_path('.'),
        'srcdir'  => undef,
        'csrcdir' => undef,
        'coutdir' => undef,
        'stack'   => undef,
        'targets' => undef
    };  # make self a reference to an anonymouse hash
    
    # first, shift off the class name
    shift;

    # if we have been passed the project root, then we need to to store it
    unless( @_ )
    {
        print_f "No path passed to Initializer";
        die;
    }
    
    my $path = shift;
    $this->{'srcdir'}  = abs_path($path);
    
    my $stackframe = {
        'outdir'   => $this->{'outdir'} . "/.",
        'srcdir'   => $this->{'srcdir'} . "/.",  
    };
    
    my @stack;
    push(@stack,$stackframe);
    $this->{'stack'} = \@stack;
    
    
    my $target = {
        'output' => $this->{'outdir'}."/texmake.cache",
        'intput' => '', 
    };
    
    my @targets;
    push(@targets, $target);
    $this->{'targets'} = \@targets;
    
    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::Initializer object
    $singleton = $this;
    return $this;
}




sub go
{
    my $this = shift;
    
    print_n 0, "Initializer is starting";
    print_n 0, "Changing to " . $this->{'srcdir'};

    my $stack = $this->{'stack'};
    
    while( $#$stack +1 > 0 )
    {
        print_n 0, "Popping a directory off the search stack";
        my $stackframe = pop(@$stack);
        my $srcdir = $stackframe->{'srcdir'};
        my $outdir = $stackframe->{'outdir'};
        
        print_n 0, <<"HERE";
   source: $srcdir
   output: $outdir
HERE
        
        # copy the source and output directory to the value of the current
        # source directory in the initializer object
        $this->{'csrcdir'} = $srcdir;
        $this->{'coutdir'} = $outdir;
        
        print_n 0, "Changing to $srcdir";
        unless(chdir $srcdir)
        {
            print_f "Failed to change to $srcdir";
            die;
        }
        
        unless(-e 'texmake.pl')
        {
            print_f "No texmake.pl in $srcdir";
            die;
        }
        
        print_n 0, "Executing texmake.pl";
        my $fh;
        open( $fh, '<', './texmake.pl');
        local $/;
        my $wholefile = <$fh>;
        close $fh;
        eval $wholefile;
    }
    
    print_n 0, "Nothing left in the search stack";
    
    my $targets = $this->{'targets'};
    
    print_n 0, "Targets found:\n------------------";
    foreach my $target( @$targets )
    {
        my $output = $target->{'output'};
        my $source = $target->{'source'};
        
        print_e "($output,$source)";
    }
    
    print_n 0, "Creating directories and rootfiles";
    foreach my $target( @$targets )
    {
        my $output = $target->{'output'};
        my $source = $target->{'source'};
        my $build  = "$output.texmake";
        print_e "Creating $build";
        
        unless(-e $build)
        {
            unless(make_path($build))
            {
                print_f "Failed to create $build";
                die;
            }
        }
        
        my ($filename,$directories,$suffix) = 
            fileparse($output,qw(pdf dvi html xhtml));
            
        my $cmd;
        switch($suffix)
        {
            case "pdf"      {$cmd = "\\pdfoutputtrue";}
            case "dvi"      {$cmd = "\\pdfoutputtrue";}
            case "html"     {$cmd = "\\pdfoutputtrue";}
            case "xhtml"    {$cmd = "\\pdfoutputtrue";}
        }
        
        
        my $fh;
        open ($fh, '>', "$build/root.tex");
print $fh <<"HERE";
\\newif\\ifpdfoutput
\\newif\\ifxhtmloutput
\\newif\\ifdvioutput

$cmd

\\listfiles

\\input{$source}
HERE
        close $fh;
    }
}



sub doAddTarget
{
    my $this    = shift;
    my $targets = $this->{'targets'};
    my $output  = $this->{'coutdir'}."/".shift;
    my $source  = $this->{'csrcdir'}."/".shift;
    
    my $target = {
        'output' => $output,
        'source' => $source, 
    };
    
    push(@$targets, $target);
    
    print_n 0, <<"HERE";
Adding Target
    output:  $output
    source:  $source
HERE
}


sub doAddSubdirectory
{
    my $this    = shift;
    my $dir     = shift;
    my $srcdir  = $this->{'csrcdir'} . "/$dir";
    my $outdir  = $this->{'coutdir'} . "/$dir";
   
    print_n 0, <<"HERE";
Pushing a new node onto the search stack
   source: $srcdir
   output: $outdir
HERE

    my $stackframe = {
        'outdir'   => $outdir,
        'srcdir'   => $srcdir,  
    };
    
    my $stack = $this->{'stack'};
    push(@$stack,$stackframe);
}



sub addTarget
{
    $singleton->doAddTarget(@_);
}

sub addSubdirectory
{
    $singleton->doAddSubdirectory(@_);
}


1;