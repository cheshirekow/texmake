package Texmake::LatexBuilder;

use strict;

use Fcntl;
use Proc::Killfam;  #apt-get libproc-processtable-perl
use File::Path qw(make_path);
use Switch;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use Texmake::Builder;


our @ISA = ("Texmake::Builder");


# creates a new maker which holds the state of the current build process
sub new()
{
    # first, shift off the class name
    shift;

    # we are passed a pointer to the Texmake::Builder object
    my $parent = shift;
    
    # copy the hash and make it this object as well
    my %copy    = %$parent;
    my $this    = \%copy;
    
    switch($this->{'out'}->{'ext'})
    {
        case "pdf"
        {
            $this->{'cmd'}      = $this->{'cache'}->{'pdflatex'};
            $this->{'figext'}   = "pdf";
            $parent->create_rootfile("\\pdfoutputtrue");
        }
        
        case "dvi"
        {
            $this->{'cmd'} = $this->{'cache'}->{'latex'};
            $this->{'figext'}   = "eps";
            $parent->create_rootfile("\\dvioutputtrue");
        }
    }
    
    $this->{'do'} = 
    {
        'latex' => 1,
        'bibtex'=> 0
    };
    
    # this flag gets set to true if we need to recurse on make becuase latex
    # failed due to missing graphics files that we now know about
    $this->{'recurse'} = 0;
    
    # this flag gets set to true if we need ot exit with an unsuccessful code
    # due to a failed build
    $this->{'fail'}    = 0;
    
    # this is where the bibtex scanner will stores bibliography files that
    # bibtex generates
    $this->{'bib_files'}    = ();
    
    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::LatexBuilder object
    return $this;
}




sub go()
{
    my $this = shift;
    $this->fork_watcher();
    
    my $texflag = \$this->{'do'}->{'latex'};
    my $bibflag = \$this->{'do'}->{'bibtex'};
    
    # after running latex, we may need to run it again so we'll run until
    # the flag gets turned off
    print_n 0, "Running latex (1)";
    $this->run_latex();
    print_n 1, "Bibtex do flag: " . $$bibflag;
    
    $this->resolve_dependencies();
    
    print_n 1, "Bibtex do flag: " . $$bibflag;
    if( $$bibflag )
    {
        print_n 0, "Running bibtex";
        $this->run_bibtex();
        $this->resolve_bib_dependencies();
        $$texflag = 1;
    }
    
    my $i = 2;
    while($$texflag)
    {
        print_n 0, "Running latex ($i)";
        $this->run_latex();
        $this->resolve_dependencies();    
        $i++;
    }
    
    $this->process_exit_code();
    
    $this->kill_watcher();
    $this->make_cleanfile();
    $this->recurse_if_necessary();
    
    die if( $this->{'fail'} );
}



sub fork_watcher()
{
    my $this = shift;
    my ($fh_toparent, $fh_fromwatch);
    
    # create read/write pipes so that the child process can communicate with
    # the parent process
    unless (pipe($fh_fromwatch, $fh_toparent))
    {
        print_f "Failed to open pipes for watcher $!";
        die;
    }  
    
    select($fh_toparent);   
    $| = 1; 
    select(STDOUT);

    my $pid_watch;

    # fork the process once to create the directory watch
    if($pid_watch = fork)
    {
        # this is the parent, process, he doesn't need to own pipes to
        # himself so we close the pipe
        close $fh_toparent;
        
        # the parent process waits for the child process to signal it's 
        # started
        # wait for signal from watcher before starting to build
        print_n "parent is waiting for child to be ready";
        while(<$fh_fromwatch>)
        {
            chomp;
            print_n "from child: $_";
            last if( /start/i );
        }

        # the parent process returns from this method back to the go()
        print_n "parent got the signal, returning to go()";
        $this->{'fh_watch'}     = $fh_fromwatch;
        $this->{'pid_watch'}    = $pid_watch;
        return;
    }
    
    elsif($pid_watch == 0)
    {
        # this is the child process, he doesn't need to own pipes from
        # himself so we close them
        close $fh_fromwatch;
        
        # call the submodule which starts the directory watcher 
        $this->watch_child($fh_toparent);
        
        # once the submodule completes, we can kill this process
        exit;
    }
    
    else
    {
        print_f "Failed to fork for directory watcher $!";
        die;
    }
}


sub watch_child
{
    my $this        = shift;
    my $fh_toparent = shift;

    # makes all child processes spawned from here on out a member of the
    # process group of this process
    setpgrp(0,0);
    
    my $outdir     = $this->{'out'}->{'dir'};
    my $dirwatch   = $this->{'cache'}->{'directoryWatch'};
    
    print_n "forked watcher to observe $outdir with $dirwatch";
    
    print $fh_toparent "start\n";
    exec("$dirwatch $outdir > $outdir/touchlist.txt");
}


sub kill_watcher
{
    my $this        = shift;
    my $pid_watch   = $this->{'pid_watch'};
    
    # now that the builder is done we can stop the watcher
    print_n "Killing watcher $pid_watch";
    my $result = killfam "SIGINT", $pid_watch;
    
    print_n "Successfully passed signal to $result children";
    print_n "Waiting for watcher to stop";
    waitpid($pid_watch,0);
    
    print_n "Process tree has been killed";
}


sub run_latex
{
    my $this    = shift;
    $this->{'do'}->{'latex'}    = 0;
       
    my $srcdir = $this->{'src'}->{'dir'};
    my $outdir = $this->{'out'}->{'dir'};
    my $outjob = $this->{'out'}->{'job'};
    my $outext = $this->{'out'}->{'ext'};
    
    my $rootfile    = "$outjob\_$outext.tex";
    
    my $latex       = $this->{'cmd'};   # absolute path to latex binary
    my $latexreturn = 0;                # exit status of (pdf)latex
    my $atFilelist  = 0;                # scanner is at the filelist
    
    my @missing;    # a list of all missing files
    my @filelist;   # a list of all files
    my $fh;
    
    # this is the command we'll pass to the shell to spawn the latex process
    my $cmd = <<END;
export TEXINPUTS=".:$outdir:$srcdir:" \\
    && $latex \\
        -interaction nonstopmode \\
        -output-directory $outdir \\
        $outjob\_$outext.tex 2>&1
END

    print_n 1, "Build command:\n $cmd ";
    
    # now we spawn the builder in a child process and pipe the output back
    # to this process
    unless( open($fh, "-|", $cmd) )
    {
        print_f "Failed to spawn latex process $!";
        die;
    }
    
    print_n "Scanning latex output";
    
    while(<$fh>)
    {
        chomp;
        
        # if the output is currently printing the file list then we need
        # to store the names of all the files loaded
        if($atFilelist)
        {
            # the file list ends with a line of astrices (*******)
            if(/^\s*\*+\s*$/)
            {
                $atFilelist=0;
                next;
            }
            
            # otherwise this is a file, but it may be printed with version
            # numbers and things so we only want the actual file name
            elsif(/^\s*(\S+)\s*/)
            {
                push(@filelist,$1);
            }
        }
        
        # if the output is not printing the file list then we need to check
        # for missing files, unresolved citations, and bibliography files
        else
        {
            # if this regex matches, then latex is telling us about a missing 
            # file
            if(/^! LaTeX Error: File `([^']+)' not found.$/)
            {
                chomp;
                push(@missing,$1);
                next;        
            }
            
            # if this regex matches, then latex is telling us the following
            # lines compose a list of loaded files
            elsif(/^\s*\*File List\*\s*$/)
            {
                $atFilelist=1;
                next;
            }
            
            # if this regex matches, then latex is telling us that there is a
            # citation which was not found in the bibliography
            elsif(/^! LaTeX Error: Missing citation $/)
            {
                
            }
            
            # if this regex matches, then latex is telling us it's expecting
            # a bibliography file from bibtex, but that there is none here
            elsif(/No file (.+)\.bbl/)
            {
                $this->{'do'}->{'bibtex'} = 1;
                print_n "Found missing .bbl file, need to run bibtex";
            }
            
            # if this regex matches, then latex is telling us to rerun to 
            # get cross references correct
            elsif(/Rerun/)
            {
                $this->{'do'}->{'latex'} = 1;
                print_n "Found rerun suggestion";
            }
        }
    }
    
    close $fh;
    
    $latexreturn = ${^CHILD_ERROR_NATIVE};
    
    print_n 1, "Latex return code: $latexreturn";
    
    print_n "Missing files:\n--------------------------";
    foreach (@missing)
    {
        print_e $_;
    }
    print_e "";
    
    print_n "File list:\n------------------------";
    foreach (@filelist)
    {
        print_e $_;
    }
    print_e "";
 
    $this->{'latex_exit'}    = $latexreturn;   
    $this->{'missing_files'} = \@missing;
    $this->{'loaded_files'}  = \@filelist;
}






sub run_bibtex
{
    my $this    = shift;
    $this->{'do'}->{'bibtex'}    = 0;
       
    my $srcdir = $this->{'src'}->{'dir'};
    my $outdir = $this->{'out'}->{'dir'};
    my $outjob = $this->{'out'}->{'job'};
    my $outext = $this->{'out'}->{'ext'};
    
    my $auxfile     = "$outdir/$outjob\_$outext";
    
    my $bibtex      = $this->{'cache'}->{'bibtex'}; # absolute path to binary
    my $bibtexreturn= 0;                            # exit status of bibtex
    
    my @filelist;   # a list of all bib files 
    my $fh;
    
    # this is the command we'll pass to the shell to spawn the latex process
    my $cmd = <<END;
export BIBINPUTS=".:$outdir:$srcdir:" \\
    && $bibtex  $auxfile 2>&1
END

    print_n 1, "Bibtex command:\n $cmd ";
    
    # now we spawn bibtex in a child process and pipe the output back
    # to this process
    unless( open($fh, "-|", $cmd) )
    {
        print_f "Failed to spawn bibtex process $!";
        die;
    }
    
    print_n "Scanning bibtex output";
    
    while(<$fh>)
    {
        chomp;
        if(/^Database file #\d+: (.+)/)
        {
            push(@filelist,$1);
        }
    }
    
    close $fh;
    
    $bibtexreturn = ${^CHILD_ERROR_NATIVE};
    
    print_n "Bibtex return code: $bibtexreturn";
    
    $this->{'bibtex_exit'}  = $bibtexreturn;   
    $this->{'bib_files'}    = \@filelist;  
}




sub resolve_dependencies
{
    my $this    = shift;
    
    my $srcdir = $this->{'src'}->{'dir'};
    my $outdir = $this->{'out'}->{'dir'};
    my $outjob = $this->{'out'}->{'job'};
    my $outext = $this->{'out'}->{'ext'};
    my $fig    = $this->{'figext'};
    
    my $depfile     = "$outdir/$outjob.$outext.d";
    my $depcache    = "$outdir/$outjob.$outext.cache";
    
    my $filelist    = $this->{'loaded_files'};  # files that latex loaded
    my $missing     = $this->{'missing_files'}; # files that latex couldn't find
    my $latexreturn = $this->{'latex_exit'};    # exit status of (pdf)latex
    
    # this flag will get set to true if we discover that latex is missing a 
    # graphic file but that we know how to build it
    my $isMissingGraphic    = 0;
    
    # this flag will 
    my $usesBibtex          = 0;
    
    my %cache;      # previously resolved dependencies
    my %depends;    # dependencies mapping to their full path
    my %path;       # maps file extensions to their kpsewhich path
    my %ignore;     # file extensions for which we will not resolve a path
    
    my @graphics;   # array of graphics included   
    
    my $resolved;   # temporary for resolved names
    
    my $fh_dep;     # file handle for the dependency file
    my $fh_cache;   # file handle for the cache file
    
    my $kpsewhich   = $this->{'cache'}->{'kpsewhich'};
    my $find        = $this->{'cache'}->{'find'};
    my $latex       = $this->{'cache'}->{'latex'};
    
    if($this->{'out'}->{'ext'} == "pdf")
    {
        $latex = $this->{'cache'}->{'pdflatex'};
    }
    
    # iterate over file extensions we expect we might need to search for, and
    # add to the search path the output directory and the source directory
    foreach my $ext ( qw(sty cls tex bib cnf clo def fd) )
    {
        $path{$ext} = "$outdir:$srcdir:".
                        `$kpsewhich -progname $latex -show-path .$ext`;
        chomp($path{$ext});
    }
    
    # iterate over file extensions we explicitly want to exclude from the 
    # dependency list
    foreach my $ext( qw(cfg mkii out) )
    {
        $ignore{$ext} = 1;
    }
    
    # now we open the cachefile it exists, and load all files that we've 
    # resolved on previous iterations
    if( -e $depcache )
    {
        unless( open($fh_cache, "<", $depcache) )
        {
            print_f "Failed to open dependency cache $depcache $!";
            die;
        }
        
        while(<$fh_cache>)
        {
            chomp;
            
            # cached dependencies should be in the form of name : abs_path
            if(/^([^:\s]+)\s*:\s*([\s]+)/)
            {
                $cache{$1} = $2;
            }
            
            else
            {
                print_w "Malformed cache line: $_"
            }
        }
        
        close $fh_cache;
    }
    
    
    # we open up the output files for the dependency list (that make understand)
    # and for the cachefile (which we understand)
    unless( open($fh_dep, ">", $depfile) )
    {
        print_f "Failed to open $depfile for writing $!";
        die;
    }
    
    unless( open($fh_cache, ">", $depcache) )
    {
        print_f "Failed to open $depcache for writing $!";
        die;
    }
    
    print $fh_dep "$outdir/$outjob.$outext : \\\n";
    
    # now we start going through the file list that latex generated and we
    # resolve any files that aren't already cached
    foreach my $file (@$filelist)
    {
        # if the file has an extension, then we can use kpsewhich to find its
        # absolute path 
        if($file=~/(.+)\.([^\.]+)$/)
        {
            my $base    =$1;
            my $ext     =$2;
            
            # if the extension is one of the ones we ignore, then we stop here
            # and move on to the next file
            next if( defined $ignore{$ext} );
            
            # if the file is a .bbl file then it means this document requires
            # bibtex
            if($ext eq "bbl")
            {
                $usesBibtex =  1;
            }
            
            # if we have already resolved this files absolute path, then we
            # don't need to resolve it again
            if(defined $cache{$file})
            {
                $resolved = $cache{$file};
            }
            
            # otherwise, we actually have to do the slow search to find out
            # where the file is stored
            else
            {
                print_n "resolving dependency $file";
                
                # if the file is one of the known extension types, then we
                # use the modified path that kpsewhich reports, otherwise we
                # use only our local paths
                my $path = "$outdir:$srcdir:";
                $path = $path{$ext} if(defined $path{$ext});

                # call kpsewhich to find the absolute path of the the file
                # in question                
                $resolved = `$kpsewhich -progname $latex -path $path $file`;
                chomp($resolved);
            }
            
            # if the file was found, then print it to the cache and to the 
            # dependency file
            if(length($resolved) > 0)
            {
                print $fh_dep   "   $resolved \\\n";
                print $fh_cache "$file : $resolved\n";
            }
            
            # if the file was not found then print a warning, but hope that
            # latex is ok
            else
            {
                print_w "Failed to find file $file : $resolved\n";
            }
        }
        
        # if the file does not have an extension then it is a graphics file, 
        # so we just add the graphics extension
        else
        {
            push (@graphics,$file);
            
            # if it's a graphics file and it's in the file list then it should
            # already be in the cache, otherwise it would not have previously
            # been resolved, meaning it should be in the missing file list
            unless( defined($cache{$file}) )
            {
                print_f "cannot find graphics $file in the cache, even though latex found it";
                die;
            }
            
            $resolved = $cache{$file};
            print $fh_dep   "   $outdir/$file.$fig \\\n";
            print $fh_cache "$outdir/$file.$fig : $resolved\n";
        }
    }
    
    # now we iterate through all the files that latex says it couldn't find, 
    # and add them to the dependency list, after we find them
    foreach my $file (@$missing)
    {
        # if the file has an extension, then we're screwed, since we only know
        # how to fix missing graphics files, which wont have extensions
        if($file=~/(.+)\.([^\.]+)$/)
        {
            print_w "Dont know how to resolve missing non-graphics file $file";
        }
        
        # otherwise it's a graphics file and we can add it to the list of
        # graphics files we need to resolve
        else
        {
            $isMissingGraphic = 1;
            push (@graphics,$file);
            print $fh_dep "   $outdir/$file.$fig \\\n";
        }
    }
    
    
    # now we're done printing the dependency list for the actual output, so 
    # we need to insert some space before the graphics rules are added
    print $fh_dep "\n\n";
    
    # now we iterate over all of the graphics files that are required by this
    # output and we create rules for how to build them
    foreach my $file (@graphics)
    {
        # if the file has a relative path part, then we need to strip it out
        if($file=~/(.+)\/([^\/]+)/)
        {
            my $dir="$outdir/$1";
            
            # if the relative path doesn't exist in the output directory, then
            # we need to create it
            unless (-e $dir)
            {
                print_n "making output directory $dir";
                unless( make_path($dir) )
                {
                    print_f "Failed to make directory $dir $!";
                    die;
                }
            }
        }
        
        # now we need to find the actual source file that is used to create the
        # required file. We start by checking for it in our cachefile
        if( defined ($cache{$file}) )
        {
            $resolved = $cache{$file};
        }
        
        # if we haven't found it before, then we need to look for it now 
        else
        {
            print_n "Resolving dependency $file";
            
            my $find    = "find $srcdir -path \"*$file.*\"";
            my $found   = 0;
            my $fh_find;
            
            # spawn a new process to run find and pipe its output to us 
            unless( open ($fh_find, "-|", $find) )
            {
                print_f "Failed to open find pipe $!";
                die;
            }
            
            while(<$fh_find>)
            {
                chomp;
                print $fh_dep   "$outdir/$file.$fig : $_\n";
                print $fh_dep   "\t\@echo \"Generating figure $file.$fig\" | \$(COLOR) green \n";
                print $fh_dep   figure_rule($fig,$_);

                # TODO put the actual rule here depending on the source and 
                # output file type
                
                print $fh_cache "$outdir/$file.$fig : $_\n";
                $found = 1;
                last;
            }
            
            print_w "Failed to find graphics source for $file.$fig\n" 
                unless ($found);    
        }
    }
    
    # if we found a dependency on the bibliography file, then we'll go ahead
    # and include the bibliography makefile
    if($usesBibtex)
    {
        print $fh_dep <<END;

-include $outdir/$outjob\_$outext.bbl.d
END
    }

    # now we're all done building the dependency and cachefiles    
    close $fh_dep;
    close $fh_cache;
    
    $this->{'is_missing_graphic'}   = $isMissingGraphic;
    
    # we cannot just set the do flag to usesBibtex because if this is the first
    # time we run bibtex then the .bbl file wont be among the missing
    if($usesBibtex)
    {
        $this->{'do'}->{'bibtex'}       = $usesBibtex;
    }
}




sub figure_rule
{
    my $outext = shift;
    my $infile = shift;
    
    unless($infile=~/(.+)\.([^\.]+)$/)
    {
        print_w "Cannot determine extension of figure $infile";
        return "\n";
    }
    
    my $inext = $2;
    
    switch($outext)
    {
        case "pdf"
        {
            switch($inext)
            {
                case "svg"
                {
                    return "\t\@ echo \"\$(SVG2PDF) \$< \$@\" >> make.log\n".
                            "\t\@\$(SVG2PDF) \$< \$@\n"
                }
                
                else
                {
                    print_w "unrecognized figure input $infile for output $outext";                
                }
            }
        }
        
        case "eps"
        {
            switch($inext)
            {
                case "svg"
                {
                    return "\t\@ echo \"\$(SVG2EPS) \$< \$@\" >> make.log\n".
                            "\t\@\$(SVG2EPS) \$< \$@\n";
                }
                
                else
                {
                    print_w "unrecognized figure input $infile for output $outext";                
                }
            }
        }
        
        case "png"
        {
            return  "\t\@ echo \"\$(CONVERT) \$< \$@\" >> make.log\n".
                    "\t\@\$(CONVERT) \$< \$@\n";            
        }
        
        else
        {
            print_w "unrecognized figure output $outext";
        }
        
    }
    
    return "\@echo \"Warning: no rule defined\" | \$(COLOR) yellow \n";
}


sub resolve_bib_dependencies
{
    my $this    = shift;
    
    my $srcdir = $this->{'src'}->{'dir'};
    my $outdir = $this->{'out'}->{'dir'};
    my $outjob = $this->{'out'}->{'job'};
    my $outext = $this->{'out'}->{'ext'};
    my $fig    = $this->{'figext'};
    
    my $depfile     = "$outdir/$outjob\_$outext.bbl.d";
    my $depcache    = "$outdir/$outjob\_$outext.bbl.cache";
    
    my $filelist    = $this->{'bib_files'};     # files that bibtex loaded
    my $missing     = $this->{'bib_missing'};   # files that bibtex couldn't find
    
    my %cache;      # previously resolved dependencies
    my %depends;    # dependencies mapping to their full path
    my %path;       # maps file extensions to their kpsewhich path
    my %ignore;     # file extensions for which we will not resolve a path
    
    my @graphics;   # array of graphics included   
    
    my $resolved;   # temporary for resolved names
    
    my $fh_dep;     # file handle for the dependency file
    my $fh_cache;   # file handle for the cache file
    
    my $kpsewhich   = $this->{'cache'}->{'kpsewhich'};
    my $find        = $this->{'cache'}->{'find'};
    my $bibtex      = $this->{'cache'}->{'bibtex'};

    # add the source and build directories to the list of paths for kpsewhich
    my $path        = "$outdir:$srcdir:".
                        `$kpsewhich -progname latex -show-path .bib`;
    chomp($path);
    
    # now we open the cachefile it exists, and load all files that we've 
    # resolved on previous iterations
    if( -e $depcache )
    {
        unless( open($fh_cache, "<", $depcache) )
        {
            print_f "Failed to open dependency cache $depcache $!";
            die;
        }
        
        while(<$fh_cache>)
        {
            chomp;
            
            # cached dependencies should be in the form of name : abs_path
            if(/^([^:\s]+)\s*:\s*([\s]+)/)
            {
                $cache{$1} = $2;
            }
            
            else
            {
                print_w "Malformed cache line: $_"
            }
        }
        
        close $fh_cache;
    }
    
    
    # we open up the output files for the dependency list (that make understand)
    # and for the cachefile (which we understand)
    unless( open($fh_dep, ">", $depfile) )
    {
        print_f "Failed to open $depfile for writing $!";
        die;
    }
    
    unless( open($fh_cache, ">", $depcache) )
    {
        print_f "Failed to open $depcache for writing $!";
        die;
    }
    
    print $fh_dep "$outdir/$outjob\_$outext.bbl : \\\n";
    
    print_n "Resolving bib dependencies";
    
    # now we start going through the file list that latex generated and we
    # resolve any files that aren't already cached
    foreach my $file (@$filelist)
    {
        # if the file has an extension, then we can use kpsewhich to find its
        # absolute path 
        if($file=~/(.+)\.bib$/)
        {
            my $base    =$1;
            
            # if we have already resolved this files absolute path, then we
            # don't need to resolve it again
            if(defined $cache{$file})
            {
                $resolved = $cache{$file};
            }
            
            # otherwise, we actually have to do the slow search to find out
            # where the file is stored
            else
            {
                print_n "resolving dependency $file";
                
                # call kpsewhich to find the absolute path of the the file
                # in question                
                print_n "$kpsewhich -progname latex -path $path $file";
                $resolved = `$kpsewhich -progname latex -path $path $file`;
                chomp($resolved);
            }
            
            # if the file was found, then print it to the cache and to the 
            # dependency file
            if(length($resolved) > 0)
            {
                print $fh_dep   "   $resolved \\\n";
                print $fh_cache "$file : $resolved\n";
            }
            
            # if the file was not found then print a warning, but hope that
            # latex is ok
            else
            {
                print_w "Failed to find file $file : $resolved\n";
            }
        }
        
        # if the file is not a .bib file than I have no idea what to do
        else
        {
            print_w "Not a bibliography file $file";
        }
    }
    
    # now we iterate through all the files that latex says it couldn't find, 
    # and add them to the dependency list, after we find them
    foreach my $file (@$missing)
    {
        print_w "$file was marked as missing";
    }
    
    
    # now we're done printing the dependency list for the actual output, so 
    # we need to insert some space before the graphics rules are added
    print $fh_dep "\n";
    print $fh_dep "\t\$(TEXBUILD) $outdir/$outjob.$outext \n\n";
    
    # now we're all done building the dependency and cachefiles    
    close $fh_dep;
    close $fh_cache;
}






sub process_exit_code
{
    my $this = shift;
    
    my $exitcode            = $this->{'latex_exit'};
    my $isMissingGraphic    = $this->{'is_missing_graphic'};
    
    if($exitcode && $isMissingGraphic)
    {
        print_n 0, "Build failed but we found ".
                "missing graphics files so we'll recurse make";
        $this->{'recurse'} = 1;
    }
    
    elsif($exitcode)
    {
        print_f 0, "Build failed but we didn't find missing graphics files ".
                "so the only thing we can do is fail";
        $this->{'fail'} = 1;
    }
    
    else
    {
        print_n "Latex build successful";
    }
}



sub make_cleanfile
{
    my $this    = shift;
    
    my $srcdir = $this->{'src'}->{'dir'};
    my $outdir = $this->{'out'}->{'dir'};
    my $outjob = $this->{'out'}->{'job'};
    my $outext = $this->{'out'}->{'ext'};
    my $outfile= $this->{'out'}->{'file'};
    
    my $cleanfile   = "$outdir/clean_$outjob.$outext.d";
    my $cleancache  = "$outdir/clean_$outjob.$outext.cache";
    my $touchfile   = "$outdir/touchlist.txt";
    my $rootfile    = "$outdir/$outjob\_$outext.tex";
    
    # note that we'll use a hash for output files so that we can easily 
    # eliminate repeats
    my %outputs;    # output files reported by the directory watcher
    my $fh_cache;   # file handle for clean cache
    my $fh_touch;
    my $fh_clean;   # file handle for clean file
    
    # if the cachefile for outputs exists, then load it
    if( -e $cleancache )
    {
        unless(open ($fh_cache, '<', $cleancache))
        {
            print_f "Failed to open cachefile: $cleancache  $!";
            die;  
        } 

        while(<$fh_cache>)
        {
            chomp;
            next if /^\s*$/;    #skip blank lines
            $outputs{$_} = 1;
        }
        
        close $fh_cache;
    }
    
    # then open the touchfile from directoryWatch
    unless ( open($fh_touch, '<', $touchfile) )
    {
        print_f "Failed to open $touchfile $!";
        die;
    }
    
    while(<$fh_touch>)
    {
        chomp;
        
        # skip empty lines
        next if(/^\s*$/);
        
        # if the touchfile has a known notification then process it
        if( /([^,]+),(.+)/ )
        {
            my $file   = $1;
            my $notify = $2;
            
            # if the notification is one of the ones that indicate a write, then
            # record the file as an output
            if($notify eq "IN_MODFIY" 
                    || $notify eq "IN_CLOSE_WRITE" 
                    || $notify eq "IN_CREATE")
            {
                $outputs{$file} = $_;
            }
        }
        
        # otherwise just log a warning that we're skipping it
        else
        {
            print_w "bad touchfile entry: $_";
        }
    }
    
    close $fh_touch;
    
    
    # now we combine outputs from the cache and from the touchfile, and write
    # them all to the clean rules and the cachefile
    
    unless( open($fh_clean, '>', $cleanfile) )
    {
        print_f "Failed to open $cleanfile $!";
        die;
    }
    
    unless( open($fh_cache, '>', $cleancache) )
    {
        print_f "Failed to open $cleancache $!";
        die;
    }
    
    print $fh_clean <<END;
clean: clean_$outfile

clean_$outfile : 
END

    print_n 2, "Touched files\n          ------------------------\n";
    
    foreach my $file (keys %outputs)
    {
        print_e "$file " . $outputs{$file};
        
        if($file=~/\.[^.]+/)
        {
            print $fh_clean "\t\@rm -fv $outdir/$file \n";
        }
        else
        {
            print $fh_clean "\t\@rm -rfv $outdir/$file \n";
        }
        print $fh_cache "$file \n";
    }
    
    print $fh_clean <<END;
	\@rm -fv $cleanfile 
	\@rm -fv $cleancache 
	\@rm -fv $rootfile 
	\@rm -fv $touchfile 
	\@rm -fv $outfile
	
END

    close $fh_clean;
    close $fh_cache;
}


sub recurse_if_necessary
{
    my $this    = shift;
    my $should  = $this->{'recurse'};
    my $outfile = $this->{'out'}->{'file'};
    
    if($should)
    {
        print_n 0, "At the end of parent process, recursing on make";
        system( "make $outfile" );
    }
    else
    {
        print_n 0, "At the end of parent process, no need to recurse";
    }
}