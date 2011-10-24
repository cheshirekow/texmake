##  @class
#   @brief  a node which uses pdflatex to compile a .tex document
package Texmake::Tools::Latexml::Xhtml::Node;


use strict;

use Switch;
use File::stat;
use File::Copy;
use File::Path qw(make_path);
use File::Basename qw(dirname basename fileparse);
use Time::localtime;
use Cwd qw(getcwd);

use Texmake ':all';
use Texmake::Printer ':all';
use Texmake::PrintIncrementer;

use Texmake::Node;
use Texmake::Tools::Source::Node;
use Texmake::Tools::Copy::Node;
use Texmake::Tools::Bibtex::Node;
use Texmake::Tools::TexRootMaker::Node; 
use Texmake::Tools::TexState::Node;

our @ISA = ('Texmake::Node');


# file types that indicate an unstable document, but who shouldn't 
# instigate an intial build
our @stateTypes = qw(.aux .toc);


##  @cmethod object new($output,$srcdir)
#   @brief   constructor, creates a new pdflatex node
#   @param[in]  output  the output file which is created
#   @param[in]  srcdir  the directory where the sources are located
#
#   The pdf builder makes a lot of assumptions. It assumes that there is a
#   directory called $output.texmake which contains a file called root.tex
#   which references the actual source document. The only piece of 
#   extra information the builder needs is the source directory where it 
#   should point pdflatex in addition to the build directory. This source 
#   directory is also where the parser will look for missing dependencies
#    
sub new
{
    my $this;

    # first, shift off the class name
    shift;
    
    # this method requires two parameters
    if( ($#_ +1) == 2 )
    {
        my $outdir      = shift;
        my $builddir    = "$outdir.texmake";
        my $srcdir      = shift;
        
        # create the base class object
        $this = new Texmake::Node("$outdir");
        
        # we also need to store the source directory of this generated document
        $this->{'builddir'} = $builddir;     
        $this->{'srcdir'} = $srcdir;
        
        # the bibliography node get's a special pointer so that the parser
        # can mark the bibliography dirty if the output shows missing citations
        $this->{'bibNode'}      = undef;
    }
    else
    {
        die "Latexml::Xhtml node created with wrong argument list";
    }
    
    bless($this);
    return $this;
}



##  @method bool doBuild(void)
#   @return    * 0 if the build was successful
#              * 1 if if the build needs to be performed again
#              * -1 if the build failed 
sub build
{
    my $this        = shift;
    my $outdir      = $this->{'outfile'};
    my $builddir    = $this->{'builddir'};
    my $srcdir      = $this->{'srcdir'};
    my $result      = BUILD_SUCCESS;
    
    print_n "In Latexml::Xhtml node's build method";
   
    my $cwd         = getcwd();
    print_n 0, "Changing to working directory $outdir";
    unless ( -e $outdir )
    {
        print_n 0, "Directory doesn't exist, attempting to create";
        unless( make_path ($outdir) )
        {
            print_f "cannot create directory $outdir";
            die;
        }
    }
    
    unless( -d $outdir )
    {
        print_f "$outdir exists but is not a directory";
        die;
    }
    
    unless( -w $outdir )
    {
        print_f "$outdir exists but is not writable";
        die;
    }
    
    unless(chdir $outdir)
    {
        print_f "Failed to change to build directory $outdir";
        die;
    }
    
    # generate the command to execute
    my $cmd = "latexmlpost --destination=index.xhtml ".
                            "--verbose --verbose ".
                            "$builddir/root.xml 2>&1";   
    my $fh;
    
    print_n 0, "Executing the following command: \n$cmd";
    
    # open a pipe from the command to our process
    open( $fh, '-|', $cmd);
    
    # create a parser object, the parser needs to know this node (so that it
    # can append dependencies), the file handle of the process (so that it can 
    # read the output), the output directory (so it knows where to put 
    # generated files which are missing), and the source directory (so it knows
    # where to search for sources of missing dependencies)
    $result = parse($this,$fh,$outdir,$builddir,$srcdir);
    close $fh;
    
    # if the pdflatex process returned an error code but the parser did not
    # figure out any problems that it knows how to correct, then we'll actually
    # need to fail here
    if( ${^CHILD_ERROR_NATIVE} 
            && $result != BUILD_REBUILD )
    {
        $result = BUILD_FAIL;
    }
    
    print_n 0, "restoring CWD to $cwd";
    unless(chdir $cwd)
    {
        print_f "Failed to restore cwd: $cwd";
        die;
    }
    
    return $result;
}




sub parse
{
    my $node    = shift;
    my $fh      = shift;    
    my $outdir  = shift;
    my $builddir= shift;
    my $srcdir  = shift;
    my $status  = BUILD_SUCCESS;
    my @loaded  = ();
    my @states  = ();
    my @figures = ();
    my $warnFlag    = 0;
    my $errorFlag   = 0;
    
    my $msgSplit    = 0;
    my $msgText     = "";
    my $msgContext  = "";
    
    print_n 0, "Parser::Latexml is reading from fh: $fh";
    
    while(<$fh>)
    {
        chomp;
        
        print_e $_;
        
        if(/Warning:/)
        {
            print_w $_;
        }
        
        
        # if processing an image file it will match these two
        if(/LaTeXML::Post::Graphics/ && /Processing (\S+)/ && -e $1)
        {
            push(@figures,$1);
        }
        
        # if latex is looking for an include file or an image file and it cannot
        # find it in the source directory it will print an error like 
        # "File `fig/a/b' not found" so we'll match strings like this
        if(/Missing graphic for <graphics graphic="([^"]+)"/)
        {
            # pull the matched text out into a variable
            my $missing     = $1;
            
            print_n 0, "Detected missing graphic $missing";
            
            # we assume that there is in fact a similarly named file somewhere
            # relative to the source directory for this document, but that 
            # perhaps it has a different file extension (i.e. needs to be
            # converted). So, we start our search in the relative path of the
            # source directory
            my $srchdir = dirname("$srcdir/$missing");
            
            # the file we're loking for is one with the same basename as the
            # file which is missing 
            my $srchbase= basename($missing);
            
            print_n 0, "Searching for it as $srchbase in $srchdir";

            # open the search directory and read in a list of files in it
            my $dh;
            opendir( $dh, $srchdir );
            my @files = grep {! -d} readdir($dh);
            closedir($dh);
            
            my $found = undef;
            
            # iterate over files and try to match one which has the same
            # basename but a different extension, for now we'll stop at the
            # first match
            foreach my $file(@files)
            {
                # match files against the basename of the missing file
                if($file=~/^$srchbase\.([^.]+)/)
                {
                    print_n 0, "Found: $srchdir/$file";
                    
                    # store the name of the found file in a variable, note it
                    # does not include any directory parts
                    $found = $file;
                    last;
                }
            }

            # if we found a matching source file, then we'll add a new entry
            # to build a pdf image out of whatever the source file is
            if($found)
            {
                my $srcdir = $srchdir;
                my $outfile= "$builddir/$missing.png";
                my $srcfile= "$srcdir/$found";
                print_n 0, "Generating a new dependency";
                print_e "   source: $srcfile";
                print_e "   output: $outfile";                
                
                push(@figures,$outfile);
                my $builder = Texmake::BuilderRegistry::findBuilder(
                                                        $srcfile,$outfile);
                unless($builder)
                {
                    print_f "Failed to find a suitable builder to generate " 
                            ."graphics file $outfile from $srcfile";
                    die;
                }
                
                eval "require $builder";
                my $subtree = 
                    $builder->createTree( {
                        'srcfile'=>$srcfile, 
                        'outfile'=>$outfile} );
                        
                $node->dependsOn($subtree);
                $status = BUILD_REBUILD;
            }
            
            else
            {
                print_f "No candidates found";
                die;
            }
        }
    }
        
    
    # we don't want to add multiple nodes for a particular source file, so
    # the first thing we'll do is put all the loaded files into a hash to make
    # them unique, and then we'll go through our current dependencies and update
    # the list
    my %depends;
    my $srcfile = $node->{'builddir'} . "/root.xhtml";
    $depends{$srcfile} = {
            'state' => DEP_NEW,
            'node'  => undef
    };
        
    foreach my $load (@loaded)
    {
        $depends{$load} = {
            'state' => DEP_NEW,
            'node'  => undef
        };
    }
    
    foreach my $fig (@figures)
    {
        $depends{$fig} = {
            'state' => DEP_NEW,
            'node'  => undef
        }
    }
    
    
    
    # now we'll iterate over current dependencies and see how many of them were
    # in the list of files loaded
    my $nodeDepends = $node->{'depends'};
    foreach my $node (@$nodeDepends)
    {
        if( exists $depends{$node->{'outfile'}} )
        {
            $depends{$node->{'outfile'}}->{'state'} = DEP_KEEP;
            $depends{$node->{'outfile'}}->{'node'}  = $node;
        }
        else
        {
            $depends{$node->{'outfile'}} = {
                'state' => DEP_DROP,
                'node'  => $node
            };
        }
    }
    
    
    print_n 0, "Dependency List:\n---------------";
    # now print a list of all the files that were (or were not) loaded and 
    # their status as a dependency, also create new source nodes for new
    # dependencies
    my @newDepends;
    foreach my $file (keys %depends)
    {
        my $status = $depends{$file}->{'state'};
        my $symbol = "[?]";

        if($status == DEP_NEW)
        {
            $symbol = "[+]";
            my $newNode= new Texmake::Tools::Source::Node($file);
            push(@newDepends,$newNode);
        }
        
        elsif($status == DEP_KEEP)
        {
            $symbol = "[ ]";
            push(@newDepends,$depends{$file}->{'node'});
        }
        
        else
        {
            $symbol = "[x]";
        }
        
        print_e $symbol . "   $file";
    }
    
    # now reassign the dependency list for this node
    $node->{'depends'} = \@newDepends;
    
    
    
    
    
    my %stateFiles;
    foreach my $file (@states)
    {
        $stateFiles{$file} = {
            'state' => DEP_NEW,
            'node'  => undef,  
        };
    }
    
    
    my $nodeStates = $node->{'stateFiles'};
    foreach my $node (@$nodeStates)
    {
        if( exists $stateFiles{$node->{'outfile'}} )
        {
            $stateFiles{$node->{'outfile'}}->{'state'} = DEP_KEEP;
            $stateFiles{$node->{'outfile'}}->{'node'}  = $node;
        }
        else
        {
            $stateFiles{$node->{'outfile'}} = {
                'state' => DEP_DROP,
                'node'  => $node
            };
        }
    }
    
    print_n 0, "Intermediate Files:\n---------------";
    my @newStates;
    foreach my $file (keys %stateFiles)
    {
        my $status = $stateFiles{$file}->{'state'};
        my $symbol = "[?]";

        if($status == DEP_NEW)
        {
            $symbol = "[+]";
            my $newNode= new Texmake::Tools::TexState::Node($file);
            push(@newStates,$newNode);
        }
        
        elsif($status == DEP_KEEP)
        {
            $symbol = "[ ]";
            push(@newStates,$stateFiles{$file}->{'node'});
        }
        
        else
        {
            $symbol = "[x]";
        }
        
        print_e $symbol . "   $file";
    }
    
    $node->{'stateFiles'} = \@newStates;
    
    
    
    
    # just to make sure
    my $nDepends    = $#newDepends + 1;
    my $nStates     = $#newStates + 1;
    print_n 0, "There are $nDepends dependent files and "
                ."$nStates state files identified in this build";
    
    return $status;
}























1;