##  @class
#   @brief  an object which iterates over texmake.pl files and builds the
#           initial dependency graphs
#
#   @note   the initializer is a singleton object
package Texmake::Initializer;

use strict;

use Cwd qw(getcwd abs_path realpath);

use Module::Load;

use File::Basename;
use Switch;
use File::Path qw(make_path);
use XML::Dumper;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use Texmake::Node;
use Texmake::BuilderRegistry;
       
our $singleton = undef;


##  @cmethod    object new($srcpath)
#   @brief      creates a new initializer which generates the output directory 
#               structure and the initial dependency graph for all generated
#               documents
sub new
{
    Texmake::BuilderRegistry::init();
    
    my $this = 
    {
        'srcdir'  => undef,
        'outdir'  => realpath('.'),
        'csrcdir' => undef,
        'coutdir' => undef,
        'stack'   => undef,
        'targets' => undef,
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
    $this->{'srcdir'}  = realpath($path);

    # we'll store the current directory in a LIFO queue (stack) so that we do
    # depth first search over the input directories    
    my $stackframe = {
        'outdir'   => $this->{'outdir'},
        'srcdir'   => $this->{'srcdir'},  
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
        my $output = $target->{'outfile'};
        my $source = $target->{'srcfile'};
        
        print_e "($output,$source)";
    }
    
    print_n 0, "Creating directories, and dependency graphs";
    foreach my $target( @$targets )
    {
        my $output = $target->{'outdir'} . '/' . $target->{'outfile'};
        my $source = $target->{'srcdir'} . '/' . $target->{'srcfile'};
        
        
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
            print_e "Creating buildir $build";
        }

        my $builder;
        
        # unless the user specified a builder, we need to search for one
        if( $target->{'builder'})
        {
            $builder = $target->{'builder'};
        }
        else
        {
            $builder = Texmake::BuilderRegistry::findBuilder(
                                                    $target->{'srcfile'},
                                                    $target->{'outfile'});
            if($builder)
            {
                print_n 0, "Resolved builder $builder to generate "
                            . $target->{'outfile'} . " from "
                            . $target->{'srcfile'};
            }
            else
            {
                print_f "Failed to find builder to generate "
                            . $target->{'outfile'} . " from "
                            . $target->{'srcfile'}
                            . " and no user builder specified";
                die;
            }
        }
        
        eval "require $builder";
        my $tree    = ${builder}->createTree($target);

        my $xmldump = new XML::Dumper();
    
        print_e "Generating $build/dependencies.xml";
        my $fh;
        open($fh, '>', "$build/dependencies.xml") 
                or die "Failed to open $build/dependencies.xml $!";
        
        print $fh $xmldump->pl2xml($tree);
        close $fh;
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
    my $param   = shift;
    my $buildMap= $this->{'buildMap'};
    my $target  = {};
    
    if( ref($param) eq "HASH" )
    {
        $target = $param;
    }
    else
    {
        $target->{'outfile'} = $param;
        $target->{'srcfile'} = shift;        
    }
    
    $target->{'outdir'} = $this->{'coutdir'};
    $target->{'srcdir'} = $this->{'csrcdir'};
    
    my $output = $target->{'outfile'};
    my $source = $target->{'srcfile'};
    
    push(@$targets,$target);
    
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



sub registerBuilder
{
    Texmake::BuilderRegistry::registerBuilder(@_);
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