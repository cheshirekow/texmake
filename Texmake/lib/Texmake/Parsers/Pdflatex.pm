package Texmake::Parsers::Pdflatex;

use strict;

use Switch;
use File::Basename;
use File::Path qw(make_path);
use Cwd qw(abs_path);

use Texmake qw(
        BUILD_FAIL
        BUILD_SUCCESS
        BUILD_REBUILD);
use Texmake::Printer qw(
        print_w 
        print_f 
        print_n 
        print_e);
use Texmake::PrintIncrementer;
use Texmake::DependencyGraph::Nodes::Source;
use Texmake::Initializers::Graphics qw(generate); 

use constant DEP_DROP => -1;
use constant DEP_KEEP => 0;
use constant DEP_NEW  => 1;

require Exporter;
our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration       use Foo::Bar ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
    parse
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);



sub parse
{
    my $node    = shift;
    my $fh      = shift;    
    my $outdir  = shift;
    my $srcdir  = shift;
    my $status  = BUILD_SUCCESS;
    my @loaded  = ();
    my @figures = ();
    
    print_n 0, "Parser::PDFLatex is reading from fh: $fh";
    
    while(<$fh>)
    {
        chomp;
        print_e $_;
        
        if(/^!/)
        {
            print_w $_;
        }
        
        # when files are loaded they're printed in parentheses, unfortunately
        # so are a number of other things, in any case, we want a list of all
        # the files that latex needs to build this document so we'll match for
        # any text following a parenthesis
        if(/\(([^\)]+)/)
        {
            # so every time we match something following the opening of a 
            # parenthesis, we'll check to see if it exist, and if it does, then
            # we'll say it's a file that was loaded
            if(-e $1)
            {
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
            
            print_n 0, "Searching for it in $srchdir";

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
                my $subtree= generate($outfile,$srcfile);
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
            $status = BUILD_REBUILD;
        }
        
        # check for missing bibliography files
        if(/No file ([^\.]+).bbl/)
        {
            print_n 0, "Found missing bibliography";
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
            my $newNode= new Texmake::DependencyGraph::Nodes::Source($file);
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
    
    # just to make sure
    print_n 0, "There are $#newDepends dependencies identified in this build";
    
    return $status;
}




1;