package Texmake::LatexmlBuilder;

use strict;

use Fcntl;
use Proc::Killfam;  #apt-get libproc-processtable-perl
use File::Path      'make_path';
use File::Basename  'dirname';
use Cwd             'abs_path';
use Switch;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use Texmake::Builder;




my @ISA = ("Texmake::Builder");




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
        case "html"
        {
            $parent->create_rootfile("\\htmloutputtrue");
        }
        
        case "xhtml"
        {
            $parent->create_rootfile("\\xhtmloutputtrue");
        }
    }
    
    # this is where the bibtex scanner will stores bibliography files that
    # bibtex generates
    $this->{'inc_files'}    = ();
    $this->{'bib_files'}    = ();
    $this->{'fig_files'}    = ();
    $this->{'bnd_files'}    = ();
    
    $this->{'recurse'}      = 0;
    
    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::LatexBuilder object
    return $this;
}


sub go()
{
    my $this = shift;
    
    $this->fork_watcher();
    $this->process_rootfile();
    $this->find_bibliography();
    $this->process_bibfiles();
    $this->postprocess();
    $this->resolve_dependencies();
    $this->kill_watcher();
    $this->make_cleanfile();
    $this->recurse_if_necessary();
}


sub process_rootfile
{
    my $this = shift;
    print_n 2, "Running latexml";
    
    my $srcdir = $this->{'src'}->{'dir'};
    my $outdir = $this->{'out'}->{'dir'};
    my $outjob = $this->{'out'}->{'job'};
    my $outext = $this->{'out'}->{'ext'};
    
    my $rootfile    = "$outjob\_$outext.tex";
    
    my $latexml     = $this->{'cache'}->{'latexml'};
                                        # absolute path to latex binary
    my $exitCode    = 0;                # exit status of (pdf)latex
    
    my @filelist;   # a list of included files
    my @bindings;   # a list of binding files

    my $fh;
    
    my $cmd         = "$latexml $outdir/$rootfile "
                        ."--verbose "
                        ."--verbose "
                        ."--path=$outdir "
                        ."--path=$srcdir "
                        ."--dest=$outdir/$outjob\_$outext.xml "
                        ." 2>&1 ";
    print_n 0, "Processing source for $outjob.xhtml";
    
    print_n 2, "Using command: $cmd";
    
    open($fh, '-|', $cmd);
    
    while(<$fh>)
    {
        chomp;
        print_n 3, $_;
        if(/\(Processing (.+)\.\.\./)
        {
            push(@filelist,$1);
        }
        
        if(/\(Loading (.+.ltxml)/)
        {
            push(@bindings,$1);
        }
    }
    
    close($fh);   
    $exitCode = ${^CHILD_ERROR_NATIVE};
    
    print_n 2, "File list\n----------------------";
    foreach my $file (@filelist)
    {
        print_e $file;
    }
    
    foreach my $file (@bindings)
    {
        print_e $file;
    }
    
    $this->{'inc_files'} = \@filelist;
    $this->{'bnd_files'} = \@bindings;
}
 
 
 
 
 
 
 
 
 
 
 
sub find_bibliography
{ 
    my $this = shift;
    print_n 2, "Running latexml";
    
    my $srcdir = $this->{'src'}->{'dir'};
    my $outdir = $this->{'out'}->{'dir'};
    my $outjob = $this->{'out'}->{'job'};
    my $outext = $this->{'out'}->{'ext'};
    
    my $rootfile    = "$outjob\_$outext.tex";
    
    my $latexml     = $this->{'cache'}->{'latexml'};
                                        # absolute path to latex binary
    my $exitCode    = 0;                # exit status of (pdf)latex
    
    my @missing;    # a list of all missing files
    my @bibfiles;   
    my $fh;
    
    
    print_n 2, "Scanning for bibliographies";
    
    open($fh, '<', "$outdir/$outjob\_$outext.xml");
    
    while(<$fh>)
    {
        if(/\s+<bibliography files="([^"]+)"/)
        {
            @bibfiles = split(/,/, $1);
        }
    }
    
    close($fh);
    
    print_n 2, "Bibliography list\n-----------------------";
    foreach my $file (@bibfiles)
    {
        print_e $file;
    }
    
    $this->{'bib_files'} = \@bibfiles;
}









sub process_bibfiles
{
    my $this = shift;
    print_n 2, "Processing bib files";
    
    my $srcdir = $this->{'src'}->{'dir'};
    my $outdir = $this->{'out'}->{'dir'};
    my $outjob = $this->{'out'}->{'job'};
    my $outext = $this->{'out'}->{'ext'};
    
    my $rootfile    = "$outjob\_$outext.tex";
    
    my $latexml     = $this->{'cache'}->{'latexml'};
                                        # absolute path to latex binary
    my $exitCode    = 0;                # exit status of (pdf)latex
    
    my $bibfiles    = $this->{'bib_files'};
    
    my $fh;
    
    foreach my $bibfile (@$bibfiles)
    {
        print_n 0, "Processing bibliography $bibfile";
        
        my $cmd     = "$latexml $srcdir/$bibfile.bib "
                        ."--verbose "
                        ."--verbose "
                        ."--path=$outdir "
                        ."--path=$srcdir "
                        ."--dest=$outdir/$bibfile.xml "
                        ." 2>&1 ";
        
        print_n 2, "Using command: $cmd";
        
        open($fh, '-|', $cmd);
        
        while(<$fh>)
        {
            chomp;
            print_n 3, $_;
        }
        
        close($fh);   
        $exitCode = ${^CHILD_ERROR_NATIVE};
    }
}







sub postprocess
{
    my $this = shift;
    print_n 2, "Running latexmlpost";
    
    my $srcdir = $this->{'src'}->{'dir'};
    my $outdir = $this->{'out'}->{'dir'};
    my $outjob = $this->{'out'}->{'job'};
    my $outext = $this->{'out'}->{'ext'};
    
    my $latexmlpost = $this->{'cache'}->{'latexmlpost'};
                                        # absolute path to latex binary
    my $exitCode    = 0;                # exit status of (pdf)latex
    
    my $fh;
    
    my $cmd         = "$latexmlpost "
                        ."--verbose "
                        ."--verbose "
                        ."--sourcedirectory=$srcdir "
                        ."--format=$outext "
                        ."--dest=$outdir/$outjob.$outext ";
    
    print_n 0, "Postprocessing $outjob.$outext";
    
    my $bibfiles    = $this->{'bib_files'};
    
    my @graphics_missing;
    my @graphics_found;
    
    foreach my $bibfile (@$bibfiles)
    {
        $cmd .="--bibliography=$outdir/$bibfile.xml ";
    }
    
        $cmd       .= "$outdir/$outjob\_$outext.xml"
                        ." 2>&1 ";
    
    print_n 2, "Using command: $cmd";
    
    open ($fh, '-|', $cmd);
    
    while(<$fh>)
    {
        chomp;
        print_n 3, $_;
        
        if(/Warning: Missing graphic for / && /graphic="([^"]+)"/)
        {
            push(@graphics_missing,$1);
        }
        
        if(/LaTeXML::Post::Graphics/ && /Processing (\S+)/)
        {
            push(@graphics_found,$1);
        }
    }
    
    close ($fh);
    $exitCode = ${^CHILD_ERROR_NATIVE};

    print_n "Found Graphics\n----------------------";
    foreach (@graphics_found)
    {
        print_n $_;
    }
    
    print_n "Missing Graphics\n--------------------";
    foreach (@graphics_missing)
    {
        print_n $_;
    }
    
    $this->{'fig_missing'}  = \@graphics_missing;
    $this->{'fig_found'}    = \@graphics_found;
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

    my $incFiles    = $this->{'inc_files'};
    my $bndFiles    = $this->{'bnd_files'};
    my $figFiles    = $this->{'fig_found'};
    my $figMissing  = $this->{'fig_missing'};
    my $bibFiles    = $this->{'bib_files'};
    
    my $missingFound= 0;
    
    my %figRules;
    my @files;
    
    print_n 2, "Resolving dependencies";
    
    # first, we'll go through the missing figures and find their sources
    foreach my $file (@$figMissing)
    {
        my $cmd     = "find $srcdir -path \"*/$file*\"";
        my $found   = 0;
        my $fh;
        
        open ($fh, '-|', $cmd) or die "Failed to open find $!\n";
        
        while(<$fh>)
        {
            chomp;
            my $output          = "$outdir/$file.png";
            my $dir             = dirname($output);
            my $path            = abs_path($_);
            make_path($dir);
            $figRules{$output}  = $path;
            $found              = 1;
            $missingFound       = 1;
            
            push(@files,$output);
            
            print_n "Found source for $file at $path";
            
            last;            
        }
        
        close($fh);
        
        unless($found)
        {
            print_w "Failed to find source for figure $file";
        }
    }
    
    # then we'll go through the bibliography files and add their full path
    foreach my $file (@$bibFiles)
    {
           push(@files,"$srcdir/$file.bib");
    }
    
    # then we'll go through the include files, binding files, and fig files, and
    # make sure they have absolute paths
    my @filesToAbsolutize;
    push(@filesToAbsolutize, @$bndFiles);
    push(@filesToAbsolutize, @$incFiles);
    push(@filesToAbsolutize, @$figFiles);
    
    # and put them into the big list
    foreach my $file (@filesToAbsolutize)
    {
        push(@files, abs_path($file) );
    }
     
    # now we open the cache file and load in any more figure rules
    my $fh_cache;
    if( -e $depcache )
    {
        unless (open ($fh_cache, '<', $depcache))
        {
            print_f "Failed to open $depcache $!\n";
            die;
        } 
        
        while(<$fh_cache>)
        {
            chomp;
            my ($output,$input) = split /:/;
    
            $output =~ s/^\s*//;
            $output =~ s/\s*$//;
            $input  =~ s/^\s*//;
            $input  =~ s/\s*$//;
            
            $figRules{$output} = $input;
        }  
        
        close ($fh_cache);
    }
    
    # now we write all the dependencies to the dependency file
    my $fh_dep;
    open ($fh_dep, '>', $depfile) or die ("Failed to open $depfile $!\n");
    
    print $fh_dep "$outdir/$outjob.$outext : \\\n";
    foreach my $file (@files)
    {
        print $fh_dep "   $file \\\n";
    }
    
    print $fh_dep "\n\n";
    
    # now we write all the rules for building figures
    open ($fh_cache, '>', $depcache) or die ("Failed to open $depcache $!\n");
    foreach my $output (keys %figRules)
    {
        my $input = $figRules{$output};
        
        print $fh_dep "$output : $input\n";
        print $fh_dep "\t\@echo \"Generating figure \$@\" | \$(COLOR) green \n";
        print $fh_dep "\t\@\${CONVERT} \$< \$@\n\n";
        print $fh_cache "$output : $input\n";
    }
    
    close($fh_dep);
    close($fh_cache);
    
    $this->{'recurse'} = $missingFound;
}



sub recurse_if_necessary
{
    my $this    = shift;
    
    my $srcdir = $this->{'src'}->{'dir'};
    my $outdir = $this->{'out'}->{'dir'};
    my $outjob = $this->{'out'}->{'job'};
    my $outext = $this->{'out'}->{'ext'};
    my $fig    = $this->{'figext'};
    
    if($this->{'recurse'})
    {
        print_n 0, "Recurse flag is set, recursing";
        system( "make $outdir/$outjob.$outext ");
    }
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