package Texmake::MakeMaker;

use strict;

use Cwd qw(getcwd abs_path);

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;






# creates a new maker which holds the state of the current build process
sub new()
{
    my $this = 
    {
        'cache'         => undef,
        'project_root'  => undef,
        'rules'         => {}, 
        'makefiles'     => (),
    };  # make self a reference to an anonymouse hash
    
    # first, shift off the class name
    shift;

    # if we have been passed the project root, then we need to to store it
    if( @_ )
    {
        my $path = shift;
        $this->{'project_root'} = abs_path($path);
    }

    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::Initializer object
    return $this;
}




sub go()
{
    my $this = shift;
    $this->check_for_cachefile();
    $this->find_texmakefiles();
    $this->write_roots_d();
    $this->write_makefile();
}



sub check_for_cachefile()
{
    my $this = shift;
    
    # next, check to see if we've already built a cache file, and if so, add all
    # the variables from it
    if( -e "./texmake.cache" )
    {
        print "Found texmake cache\n";
    }
    
    # if there is no cache file then we need to make one
    else
    {
        if( !$this->{'project_root'} )
        {
            print_f "No cachefile found and no project root specified";
            print_e "usage: $0 init path/to/project/root";
            die;
        }
        
        my @failed;
        
        open my $fh_cache, ">texmake.cache";
        
        # now we're going to find the location of all the binaries and scripts that
        # we need, which will depend on the current path (this is so the user 
        # doesn't have to export a new path every time)
        foreach my $name ( qw( 
            latex       pdflatex    latexml     kpsewhich 
            bibtex      find        tee
            svg2pdf     svg2eps     convert     directoryWatch
            ))
        {
            find_software(\@failed,$fh_cache,$name);
        }
        
        my $bin = abs_path($0);
        chomp($bin);
        print $fh_cache "texmake,$bin\n";
        
        print $fh_cache "project_root," . $this->{'project_root'} . "\n";
        print $fh_cache "\n\n";
        close $fh_cache;
        
        if($#failed >= 0)
        {
            print_w "Failed to find the following binaries: \n";
            foreach my $fail (@failed)
            {
                print_e "$fail\n";
            }
        }
    }
    
    my %cache;
    
    my $fh;
    unless ( open ($fh, "<", "texmake.cache") )
    {
        print_f "Failed to open texmake.cache $!";
        die;
    }
    
    while(<$fh>)
    {
        # skip blank lines
        next if (/^\s*$/); 

        if( /([^,]+),(.+)/ )
        {
            $cache{$1} = $2;
        }   
        else
        {
            print_w "Malformed cache entry $_";
        }
    }
    
    close $fh;
    
    # if the script is called with a specified project root, then we need to
    # override the cached one
    if ( $this->{'project_root'} )
    {
        $cache{'project_root'} = $this->{'project_root'};
    }
    else
    {
        $this->{'project_root'} = $cache{'project_root'};
    }
    
    $this->{cache} = \%cache;  
}


sub find_software
{
    my ($refFailed,$fh,$name) = @_;
    
    my $bin = `which $name`;
    chomp($bin);
    print $fh "$name,$bin\n";
    push(@$refFailed, "$name") if(${^CHILD_ERROR_NATIVE} != 0);
}


sub find_texmakefiles
{
    my $this = shift;
    
    my $src         = $this->{'project_root'};  # absolute path or project root
    my $rules       = $this->{'rules'};         # hash of rules
    
    my @processed;      # makefiles processed already
    my @directories;    # stack of directories to process
    push(@directories,".");
    
    # now look for the texmakefiles
    while( ($#directories + 1) > 0 )
    {
        my $dir         = pop @directories;
        my $rel_dir     = "$dir/";
        my $rel_path    = "$dir/texmakefile";
        my $abs_dir     = "$src/$dir";
        my $abs_path    = "$src/$dir/texmakefile";
        
        if(-e $abs_path)
        {
            print_n "processing $rel_path ";
            push(@processed, "$abs_dir");

            my $fh;
            unless ( open ($fh, '<', "$abs_path") )
            {
                print_f "Failed to open $abs_path $!";
                die;
            }
            
            while(<$fh>)
            {
                chomp;
                
                # skip lines starting with the comment characters
                next if( /^\s*#/ );
                next if( /^\s*%/ );
                
                # skip blank lines
                next if( /^\s*$/ );
                
                # append children to the search list
                if( /^\s*\+(.+)$/ )
                {
                    my $nextmake = "$rel_path/$1";
                    print_n "Appending $rel_path/$1 to the stack\n";
                    push(@directories, $nextmake);
                }
                
                # process the rule if it matches the syntax "input: outputs"
                elsif( /([^:]+):(.+)/ )
                {
                    my $root      = "$rel_dir/$1";
                    my @outputs   = split /\s+/, $2;
                    
                    if( exists ${$rules}{$root} )
                    {
                        my $ref = ${$rules}{$root};
                        push(@$ref, @outputs);
                    }
                    else
                    {
                        ${$rules}{$root} = \@outputs;
                    }
                }
                
                # if it didn't match then this line is improperly formatted
                else
                {
                    print_w "unrecognized rule $_\n";
                }
            }
            
            close $fh;        
        }
        
        else
        {
            print_w "missing $abs_path";
        }
    }
    
    $this->{'makefiles'} = \@processed;
}



sub write_roots_d
{
    my $this      = shift;
    my $src       = $this->{'project_root'};
    my $processed = $this->{'makefiles'};
    my $rules     = $this->{'rules'};
    
    my $pwd       = getcwd;
    my $fh;
    
    print_n "Building roots.d.d";
    
    open ($fh, '>', "roots.d.d") or die "Failed to open ./roots.d.d $!\n";
    print $fh "roots.d: \\\n";
    
    foreach my $makefile (@$processed)
    {
        print $fh "    $makefile \\\n";
    }
    
    print $fh "\n";
    print $fh "\t\$(TEXMAKE) init \$(<D)\n\n";
    close $fh;
    
    # these are lists for all the files that need to get added to the 
    # "all" and "clean" targets
    my (@all, @clean);
    
    open ($fh, '>', "roots.d") or die "Failed to open ./roots.d $!\n";
    
    # the first rule needs to be "all" so that make without rules turns into make
    # with all
    
    print $fh <<END;
# Note that the include files are only included if they exist. They will be
# generated automatically by texmakebuild if they do not already exist, and if
# they don't exist they don't need to be included because it is already clear
# that the output needs to be generated
# likewise the clean rules don't need to be included if they don't exist,
# because there is no output to clean
END
    print $fh "all: \n\n";
    
    print_n "processing rules";
    
    # increases the tabsize of the output printer
    my $tab = Texmake::PrintIncrementer->new();
    
    # iterate over all the rules we've stored so far, remember all paths are
    # relative to the project root so we need the pwd here as well
    foreach my $root (keys %$rules)
    {
        print_n "for root $root";
        my $ref = ${$rules}{$root};
        
        # increases the tabsize of the output printer
        my $tab = Texmake::PrintIncrementer->new();
        
        foreach my $output(@$ref)
        {
            # skip empty entries
            next if( $output =~ /^\s*$/ );
            
            print_n "for output $output";
            
            my $path;
            my $file;
            if( $output =~ /(.+)\/([^\/]+)/ )
            {
                $path =  "$pwd/" . $1;
                $file = $2;
            }
            else
            {
                $path = "$pwd/";
                $file = $output;
            }
            
            # create the output directory if it doesn't exist
            `mkdir -p $path` unless ( -e $path );
            
            # print the dependency rules for all of the targets
            print $fh <<END;
$path/$file : $src/$root
-include $path/$file.d
-include $path/clean_$file.d
END
    
            push(@all,"$path/$file");
            push(@clean,"$path/$file","$path/$file.d");
        }       
    }
    
    # dereference the incrementer so the extra tab in the outupt is removed
    $tab = 0;
    
    print $fh "\n\n";
    print $fh "all : \\\n";
    foreach my $output ( @all )
    {
        print $fh "    $output \\\n";
    }
    
    close $fh;    
    
}



sub write_makefile
{
    my $this = shift;
    
    my $fh;
    unless( open ($fh, '>', "makefile") )
    {
        print_f "Failed to open makefile $!";
        die;
    }

    my $refCache = $this->{'cache'};
    my %cache = %$refCache;
    
    my $svg2pdf = $cache{'svg2pdf'};
    my $svg2eps = $cache{'svg2eps'};
    my $convert = $cache{'convert'};
    my $texmake = $cache{'texmake'};
    my $tee     = $cache{'tee'};

    print $fh <<END;
SVG2PDF := $svg2pdf
SVG2EPS := $svg2eps
CONVERT := $convert
TEXMAKE := $texmake
TEXBUILD:= $texmake build
COLOR   := $texmake color
TEE     := $tee
    
END
    
    print $fh <<'END';
PWD     := $(shell pwd)

all : 


# rules for when we need to rebuild the root dependencies (and this makefile)
include roots.d.d

# top level dependency rules for each document, also includes individual
#dependency files
include roots.d

# even though we have a dependency list for specific .dvi files included, 
# since there is no dependency in this particular rule, the file will be 
# rebuilt every invocation of make unless we make it depend on at least
# something
%.dvi : roots.d
	@echo "Building $(subst $(PWD),,$@)" | $(COLOR) green
	@echo "( ${TEXBUILD} $@ $(word 2,$^) $(filter *.bib, $^) 2>&1 1>&3 | ${COLOR} red ) 3>&1 1>&2 | ${COLOR} yellow" >> make.log
	@( ${TEXBUILD} $@ $(word 2,$^) $(filter *.bib, $^) 2>&1 1>&3 | ${COLOR} red ) 3>&1 1>&2 | $(COLOR) yellow 
	@cp $*_dvi.dvi $@

%.pdf : roots.d
	@echo "Building $(subst $(PWD),,$@) | $(COLOR) green"
	@echo "( ${TEXBUILD} $@ $(word 2,$^) $(filter *.bib, $^) 2>&1 1>&3 | ${COLOR} red ) 3>&1 1>&2 | ${COLOR} yellow" >> make.log
	@( ${TEXBUILD} $@ $(word 2,$^) $(filter *.bib, $^) 2>&1 1>&3 | ${COLOR} red ) 3>&1 1>&2 | $(COLOR) yellow
	@cp $*_pdf.pdf $@

%.xhtml: roots.d
	@echo "Bulding Root Document $*_xhtml.tex"
	cat $(SOURCE_DIR)/conditionals.tex > $*_xhtml.tex
	echo "\xhtmloutputtrue" >> $*_xhtml.tex
	echo "" >> $*_xhtml.tex
	cat $(word 2,$^) >> $*_xhtml.tex
	@echo "Running latexml on $*_xhtml.tex"
	@latexml $*_xhtml.tex --path=xhtml/ --path=$(SOURCE_DIR) --dest=$*.xml > $*.xml.log 2>&1
	@BIBSTRING=""; \
    BIB="$(filter *.bib, $^)"; \
    for BIBFILE in $$BIB; do \
        echo "Running latexml on $$BIBFILE"; \
        XMLFILE=`basename "$$BIBFILE" .bib`.xml; \
        LOGFILE=`basename "$$BIBFILE" .bib`.xml.log; \
        latexml $$BIBFILE --dest=$$XMLFILE > $$LOGFILE 2>&1; \
        BIBSTRING="$$BIBSTRING --bibliography=$$XMLFILE"; \
    done; \
    echo $$BIBSTRING > bibstring.txt
	@echo "postprocessing with `cat bibstring.txt`"
	@latexmlpost $*.xml `cat bibstring.txt` --dest=$@ --css=navbar-left.css

clean:
	@rm -rvf $^
    
END
    
    close $fh; 
}


1;
