##  @class
#   @brief  an object which iterates over texmake.pl files and builds the
#           initial dependency graphs
#
#   @note   the initializer is a singleton object
package Texmake::Initializer;

use strict;

use Cwd qw(getcwd abs_path);

use Module::Load;

use File::Basename;
use Switch;
use File::Path qw(make_path);

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use Texmake::DependencyGraph::Node;
use Texmake::Initializers::Pdflatex;
use Texmake::Initializers::Latex;
use Texmake::Initializers::Latexml;



our $singleton = undef;


##  @cmethod    object new($srcpath)
#   @brief      creates a new initializer which generates the output directory 
#               structure and the initial dependency graph for all generated
#               documents
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
    };
    
    # first, shift off the class name
    shift;

    # if we have been passed the project root, then we need to to store it
    # otherwise we just fail
    unless( @_ )
    {
        print_f "No path passed to Initializer";
        die;
    }

    # the parameter is the source path   
    my $path = shift;
    $this->{'srcdir'}  = abs_path($path);

    # we'll store the current directory in a LIFO queue (stack) so that we do
    # depth first search over the input directories    
    my $stackframe = {
        'outdir'   => $this->{'outdir'} . "/.",
        'srcdir'   => $this->{'srcdir'} . "/.",  
    };
    
    my @stack;
    push(@stack,$stackframe);
    $this->{'stack'} = \@stack;
    
    my @targets;
    $this->{'targets'} = \@targets;
    
    bless($this); 
    
    # initialize the singleton
    $singleton = $this;
    
    return $this;
}



##  @method     void go(void)
#   @brief      performs the initialization
#   @return     nothing
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
        
        unless(-e './texmake.pl' && -f './texmake.pl')
        {
            print_f "No texmake.pl in $srcdir (or its not a regular file)";
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
    
    print_n 0, "Creating directories, rootfiles, and dependency graphs";
    foreach my $target( @$targets )
    {
        my $output = $target->{'output'};
        
        # the build directory is a folder with the same name as the output and
        # the literal string ".texmake" appended to it
        my $build  = "$output.texmake";

        # if the build directory exists, then we do not need to create it
        if(-e $build)
        {
            # but if it exists and is not a directory, then we have a problem,
            # because we shouldn't flat out overwrite it
            unless( -d $build )
            {
                print_f "$build exists but is not a directory, please attend 
                            to that before continuing";
                die;
            }   
            print_e "build directory $build exists";
        }
        
        # if the build directory does not exist then we need to make it
        else
        {
            # the program will die if we fail to create the build directory,
            # note that make_path is recursive like mkdir -p
            unless(make_path($build))
            {
                print_f "Failed to create $build";
                die;
            }
            print_e "Creatined buildir $build";
        }

        # parse the output file name into basename, directory, and suffix        
        my ($basename,$directory,$suffix) = 
            fileparse($output,qw(pdf dvi html xhtml));
            
        my $init;
        # switch over the suffixes and create a dependency graph builder object
        # for whichever one is actually needed
        switch($suffix)
        {
            case "pdf"      {$init = new Texmake::Initializers::Pdflatex;}
            case "dvi"      {$init = new Texmake::Initializers::Latex;}
            case "html"     {$init = new Texmake::Initializers::Latexml;}
            case "xhtml"    {$init = new Texmake::Initializers::Latexml;}
        }
        
        # tell the initializer to do it's thing
        $init->go($target);
    }
}


##  @method void doAddTarget($output,$source,$header,$footer)
#   @brief  adds a new target to the target generating the baseline dependency
#           graph for it's builder, selected according to it's file extension
#   @param[in]  output  the output file to generate, a local path, relative to
#                       the build directory as the current texmake.pl file is 
#                       relative to the source directory
#   @param[in]  source  the root file that the document is built from
#   @param[in]  header  (optional)  latex code to prepend prior to including
#                       the root .tex file in the build directory
#   @param[in]  footer  (optional)  latex code to post-pend after including the
#                       root .tex file in the build directory
sub doAddTarget
{
    my $this    = shift;
    my $targets = $this->{'targets'};
    my $output  = $this->{'coutdir'}."/".shift;
    my $source  = $this->{'csrcdir'}."/".shift;
    my $header  = @_ ? shift : "";
    my $footer  = @_ ? shift : "";
    
    my $target = {
        'output' => $output,
        'source' => $source, 
        'header' => $header,
        'footer' => $footer
    };
    
    push(@$targets, $target);
    
    print_n 0, <<"HERE";
Adding Target
    output:  $output
    source:  $source
HERE
}


##  @method void doAddSubdirectory($subdirectory)
#   @brief  pushes a new directory onto the search stack for where to read in
#           texmake.pl files
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


##  @method void addTarget($output,$source,$header,$footer)
#   @brief  adds a new target to the target generating the baseline dependency
#           graph for it's builder, selected according to it's file extension
#   @param[in]  output  the output file to generate, a local path, relative to
#                       the build directory as the current texmake.pl file is 
#                       relative to the source directory
#   @param[in]  source  the root file that the document is built from
#   @param[in]  header  (optional)  latex code to prepend prior to including
#                       the root .tex file in the build directory
#   @param[in]  footer  (optional)  latex code to post-pend after including the
#                       root .tex file in the build directory
sub addTarget
{
    $singleton->doAddTarget(@_);
}

##  @method void addSubdirectory($subdirectory)
#   @brief  pushes a new directory onto the search stack for where to read in
#           texmake.pl files
sub addSubdirectory
{
    $singleton->doAddSubdirectory(@_);
}


1;