##  @class
#   @brief  a node which uses pdflatex to compile a .tex document
package Texmake::Tools::Pdflatex::Node;


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
        my $srcdir      = shift;
        
        # create the base class object
        $this = new Texmake::Node("$outdir/root.pdf");
        
        # we also need to store the source directory of this generated document
        $this->{'srcdir'} = $srcdir;     
        
        # the bibliography node get's a special pointer so that the parser
        # can mark the bibliography dirty if the output shows missing citations
        $this->{'bibNode'}      = undef;
        $this->{'stateFiles'}   = [];
    }
    else
    {
        die "Pdflatex node created with wrong argument list";
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
    my $outdir      = dirname($this->{'outfile'});
    my $srcdir      = $this->{'srcdir'};
    my $result      = BUILD_SUCCESS;
    my $stateNodes  = $this->{'stateFiles'};
    
    # create backup copies of all of latex's state files
    foreach my $state (@$stateNodes)
    {
        $state->backup();
    }
    
    print_n "In pdflatex node's build method";
   
    my $cwd         = getcwd();
    print_n 0, "Changing to working directory $outdir";
    unless(chdir $outdir)
    {
        print_f "Failed to change to build directory $outdir";
        die;
    }
    
    # generate the command to execute
    my $cmd = "export TEXINPUTS=$srcdir:$outdir: "
            ."&& pdflatex -interaction nonstopmode root.tex";   
    my $fh;
    
    print_n 0, "Executing the following command: \n$cmd";
    
    # open a pipe from the command to our process
    open( $fh, '-|', $cmd);
    
    
    
    # create a parser object, the parser needs to know this node (so that it
    # can append dependencies), the file handle of the process (so that it can 
    # read the output), the output directory (so it knows where to put 
    # generated files which are missing), and the source directory (so it knows
    # where to search for sources of missing dependencies)
    my $result = parse($this,$fh,$outdir,$srcdir);
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
    
    # we don't want to do these steps if pdflatex failed
    unless($result == BUILD_FAIL)
    {
        # special bibtex call, wont actually update the .bbl file time
        if($this->{'bibNode'})
        {
            $this->{'bibNode'}->build(1);
        }
        
        # evaluate if any of the state files are still changing
        foreach my $state (@$stateNodes)
        {
            my $stateStatus = $state->evaluate();
            if($stateStatus > EVAL_NOACTION)
            {
                print_n 0, "Determined that a state file ("
                            . $state->{'outfile'} 
                            . ") is still in flux, so rebuilding";
                $result = BUILD_REBUILD;
                last;
            }
        }        
    }
    
    if($result == BUILD_SUCCESS)
    {
        print_n 0, "Document stabelized after " 
                    . ($this->{'run'}+1) . " iterations";
    }
    
    return $result;
}




sub parse
{
    my $node    = shift;
    my $fh      = shift;    
    my $outdir  = shift;
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
    
    print_n 0, "Parser::PDFLatex is reading from fh: $fh";
    
    while(<$fh>)
    {
        chomp;
        
        print_e $_;
        
        if(/^!/)
        {
            print_w $_;
        }
        
        # if underlying pdftex is giving us a warning we need to print it out
        # as well
        if(/pdfTeX warning(.+)/)
        {
            $warnFlag = 1;
            $msgSplit = 0;
            $msgText  = $1;
            $msgContext = "";
        }
        
        # if we're getting a line number then this is the end of a warning or
        # error message
        elsif(/l\.(\d+)/)
        {
            if($warnFlag)
            {
                $warnFlag = 0;
            }
            
            if($errorFlag)
            {
                $errorFlag = 0;
            }
            
            print_w $msgText;
            print_w "context: " . $msgContext;
            print_w "at " . $loaded[-1] . " line $1";
        }
        else
        {
            if($warnFlag)
            {   
                unless( /\S/ ){ $msgSplit = 1;}
                
                if($msgSplit)
                {
                    $msgContext .= $_ . "\n";
                }
                else
                {
                    $msgText .= $_;
                }
            }
        }
        
        # when files are loaded they're printed in parentheses, unfortunately
        # so are a number of other things, in any case, we want a list of all
        # the files that latex needs to build this document so we'll match for
        # any text following a parenthesis
        # so every time we match something following the opening of a 
        # parenthesis, we'll check to see if it exist, and if it does, then
        # we'll say it's a file that was loaded
        if(/\(([^\)\s]+)/ && -e $1)
        {
            print_n 0, "processing file $1";
            
            # if the file is one of the known intermediate types, files used
            # by latex just to maintain state, then we'll store it in a list of
            # intermediates
            my($base,$dir,$suffix) = fileparse($1,@stateTypes);
            if($suffix)
            {
                push(@states,$1);
            }
            
            # otherwise we'll store it in the list of loaded dependencies
            else
            {
                # except for the bibliography file, which belongs to both 
                # lists
                ($base,$dir,$suffix) = fileparse($1,'.bbl');
                if($suffix)
                {
                    push(@states,$1);
                }
                push(@loaded,$1);
            }
        }
        
        # when figures are loaded their printed in angle brackets so we'll match
        # for a string like <use a/b.pdf> to recognize an image a/b.pdf
        if(/<use ([^>]+)>/)
        {
            push(@figures,"$outdir/$1");
        }
        
        # if the document include's content (versus input) then it will write
        # an auxfile for each included file and that included file may be from
        # a subdirectory. If it can't write an auxfile in a relative path to the
        # build directory it will say something like 
        # "I Can't write on file chapters/ch1.aux" so we'll match strings like
        # this to look for missing directories that need to be built
        if(/I can't write on file `([^']+)/)
        {
            # the missing directory will be relative to the current working 
            # directory which should be the build directory for this document
            my $misdir = './' . dirname($1);
            print_n 0, "Detected missing directory $misdir";

            # we attempt to (recursively) make the directory that is required
            # and if successful we will return that this document should be
            # rebuilt, becuase the next time it wont fail for this reason
            if(make_path($misdir))
            {
                $status = BUILD_REBUILD;
            }
            
            # if we can't make the directory then we'll just bail here since
            # that's a pretty fatal problem
            else
            {
                print_f "Failed to create $misdir";
                die;                      
            }
        }

        # if latex is looking for an include file or an image file and it cannot
        # find it in the source directory it will print an error like 
        # "File `fig/a/b' not found" so we'll match strings like this
        if(/File `([^']+)' not found/)
        {
            # pull the matched text out into a variable
            my $missing     = $1;
            
            print_n 0, "Detected missing file $missing";
            
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
                my $outfile= "$outdir/$missing.pdf";
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
        
        # check for rerun suggestion
        if(/rerun/i)
        {
            print_n 0, "Found rerun suggestion, will mark for rerun";
            $status = BUILD_REBUILD;
        }
        
        # check for missing bibliography files
        if(/No file ([^\.]+).bbl/)
        {
            if($node->{'bibNode'})
            {
                print_f "Internal error, detected a missing bibligraphy file "
                        ."but pdflatex node already has a bibtex chidl";
                die;
            }
            
            push(@loaded,"$outdir/$1.bbl");
            push(@states,"$outdir/$1.bbl");
            
            print_n 0, "Found missing bibliography";
            my $bibNode = 
                new Texmake::Tools::Bibtex::Node($outdir,$srcdir);
            $node->dependsOn($bibNode);
            $node->{'bibNode'}  = $bibNode;
            $bibNode->{'dirty'} = 1;
            
            $status = BUILD_REBUILD;
        }
        
        # check for undefined citations
        # Latex reports undefined citations as something like 
        # "LaTeX Warning: Citation `bookc' on page 2 undefined on input line 3."
        # so we'll match strings like this. Whenver a citation is missing, 
        # we should mark bibtex for a run and rerun ourselves (though we'll
        # need some kind of flag to prevent it a second time)
        if(/Citation `[^']+' on page \d+ undefined/ 
                &&  $node->{'bibNode'} 
                &&  $node->{'bibNode'}->{'run'} < 1 )
        {
            $node->{'bibNode'}->{'dirty'} = 1;

            # actually we wont specify the need for a rerun right here, because
            # we'll handle the bibtex node especially
        }
    }
    
    # we don't want to add multiple nodes for a particular source file, so
    # the first thing we'll do is put all the loaded files into a hash to make
    # them unique, and then we'll go through our current dependencies and update
    # the list
    my %depends;
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