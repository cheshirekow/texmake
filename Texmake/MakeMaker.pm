package Texmake::MakeMaker;

use strict;

use Cwd 'abs_path';

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
    $this = shift;
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
            print_f "No cachefile found and no project root specified"
            print_e "usage: $0 init path/to/project/root"
            die;
        }
        
        my @failed;
        
        open my $fh_cache, ">texmake.cache";
        
        print $fh_cache "\my %cache={\n";
        
        # now we're going to find the location of all the binaries and scripts that
        # we need, which will depend on the current path (this is so the user 
        # doesn't have to export a new path every time)
        foreach $name (qw(kpsewhich svg2pdf svg2eps convert directoryWatch))
        {
            find_software(\@failed,$fh_cache,$_);
        }
        
        $bin = abs_path($0);
        chomp($bin);
        print $fh_cache "'texmake'  =>  \"" . $bin . "\",\n";
        
        print $fh_cache "'project_root' => \"\"";
        
        print $fh_cache "}\n\n1;";
        close $fh_cache;
        
        if($#failed >= 0)
        {
            print_w "Failed to find the following binaries: \n";
            foreach $fail (@failed)
            {
                print_e "$fail\n";
            }
        }
    }
    
    require "texmake.cache";
    
    # if the script is called with a specified project root, then we need to
    # override the cached one
    if ( $this->{'project_root'} )
        $cache{'project_root'} = $this->{'project_root'};
    
    $this->{cache} = \%cache;  
}


sub find_software
{
    my ($refFailed,$fh,$name) = @_;
    
    $bin = `which $name`;
    chomp($bin);
    print $fh "'$name' =>  \"" . $bin . "\",\n";
    push(@$reffailed, "$name") if(${^CHILD_ERROR_NATIVE} != 0);
}


sub find_texmakefiles
{
    $this = shift;
    
    my $src         = $this->{'project_root'};  # absolute path or project root
    my $rules       = $this->{'rules'};         # hash of rules
    my $processed   = $this->{'makefiles'};     # makefiles processed already
    
    my @directories;        # stack of directories to process
    push(@directories,".");
    
    # now look for the texmakefiles
    while( ($#makefiles + 1) > 0 )
    {
        my $dir         = pop @directories;
        my $rel_path    = "$dir/texmakefile";
        my $abs_path    = "$src/$dir/texmakefile";
        
        if(-e $abs_path)
        {
            print_n "processing $rel_path\n";
            push(@$processed, "$abs_path");

            open my ($fh, '<', "$abs_path") or 
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
                    my $root      = "$rel_path/$1";
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
            print_w "missing $makefile"
        }
    }
}



sub write_roots_d
{
    $this = shift;
    
    my $src       = $this->{'project_root'};
    my $processed = $this->{'makefiles'};
    my $rules     = $this->{'rules'};
    
    my $pwd       = getcwd;
    
    open (my $fh, '>', "roots.d.d") or die "Failed to open ./roots.d.d $!\n";
    print $fh "roots.d: \\\n";
    
    foreach $makefile (@$processed)
    {
        print $fh "    $makefile \\\n";
    }
    
    print $fh "\n";
    print $fh "\t\$(TEXMAKE) init \$<\n\n";
    close $fh;
    
    # these are lists for all the files that need to get added to the 
    # "all" and "clean" targets
    my (@all, @clean)
    
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
        $ref = ${$rules}{$root};
        
        # increases the tabsize of the output printer
        my $tab = Texmake::PrintIncrementer->new();
        
        foreach my $output(@$ref)
        {
            # skip empty entries
            next if( $output =~ /^\s*$/ );
            
            print_n "for output $output\n";
            
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
    open (my $fh, '>', "makefile") or
    {
        print_f "Failed to open makefile $!";
        die;
    }

    print $fh <<END;
    
    SVG2PDF := $svg2pdf
    SVG2EPS := $svg2eps
    CONVERT := $convert
    TEXMAKE := $texmake
    MAKEDEP := $texmakedep
    TEXBUILD:= $texmakebuild
    
END
    
    print $fh <<'END';
    PWD         := $(shell pwd)
    
    
    # rules for when we need to rebuild the root dependencies (and this makefile)
    include roots.d.d
    
    # top level dependency rules for each document, also includes individual
    #dependency files
    include roots.d
    
    %.eps : 
        @echo "Converting $(subst $(PWD),,$@)"
        @$(SVG2EPS) $< $@ 
        
    %.png :
        @echo "Converting $(subst $(PWD),,$@)"
        @$(CONVERT) $< $@
        
    %.pdf : 
        @echo "Converting $(subst $(PWD),,$@)"
        @$(SVG2PDF) $< $@
    
    %.dvi : 
        @echo "Converting $(subst $(PWD),,$@)"
        ${TEXBUILD} $@ $< $(filter *.bib, $^)
    
    %.pdf : %.pdf.d
        @echo "Building $(subst $(PWD),,$@)"
        ${TEXBUILD} $@ $< $(filter *.bib, $^)
    
    %.xhtml: %.xhtml.d
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
