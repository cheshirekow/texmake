package Texmake::Builder;

use strict;

use Fcntl;
use Proc::Killfam;  #apt-get libproc-processtable-perl
use File::Path qw(make_path);
use Switch;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;
use Texmake::LatexBuilder;
use Texmake::LatexmlBuilder;






# creates a new maker which holds the state of the current build process
sub new()
{
    # make self a reference to an anonymouse hash
    my $this = 
    {
        'cache'     => undef,
        'out'       => 
        {
            'file'  => undef,
            'dir'   => undef,
            'job'   => undef,
            'ext'   => undef
        },
        'src'       => 
        {
            'file'  => undef,
            'dir'   => undef,
            'job'   => undef,
            'ext'   => undef
        },
        'bibfiles'  => undef, 
        'figext'    => undef,
        'ltxcmd'    => undef
    };  
    
    # first, shift off the class name
    shift;

    # this method requires at least two parameters
    if( ($#_ +1) < 2 )
    {
        $this->{'out'}->{'file'}  = shift;
        $this->{'src'}->{'file'}  = shift;
        if(@_)
        {
            my @copy            = @_;
            $this->{'bibfiles'} = \@copy;
        }
    }
    else
    {
        print_f "Improper usage of $0 build ";
        print_e "usage: $0 build output.[dvi|pdf|xhtml] source.tex [bibfiles]";
        die;
    }

    bless($this);   # tell the reference it is a reference to a 
                    # Texmake::Builder object
    return $this;
}




sub go()
{
    my $this = shift;
    $this->check_for_cachefile();
    $this->parse_jobs();
    $this->check_output_directory();
    $this->dispatch();
}




sub check_for_cachefile()
{
    my $this = shift;
    
    # next, check to see if we've already built a cache file, and if so, add all
    # the variables from it
    unless( -e "./texmake.cache" )
    {
        print_f "No cachefile found, cannot run builder";
        die;
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
    
    # copy a reference to the cache hash to the object
    $this->{cache} = \%cache;  
}



sub parse_jobs
{
    my $this = shift;
    
    my $srcfile = $this->{'src'}->{'file'};
    my $outfile = $this->{'out'}->{'file'};
    
    my $srcdir;
    my $srcjob;
    my $srcext;
    
    my $outdir;
    my $outjob;
    my $outext;
    
    # strip the directory part from the source file path
    if($srcfile =~ /^(.+)\/([^\/]+)$/)
    {
        $srcdir    = $1;
        $srcfile   = $2;
    }
    else
    {
        $srcdir    = ".";
    }
    
    # strip the extension from the source file
    if($srcfile =~ /(.+)\.([^\.]+)/)
    {
        $srcjob    = $1;
        $srcext    = $2;
        
        print_n <<END;
srcdir:     $srcdir
srcfile:    $srcfile
srcjob:     $srcjob
srcext:     $srcext
END
        
        print_w "sourcefile $srcfile is not a .tex file" 
            unless ($srcext=~/^tex$/i);
    }
    else
    {
        print_f "Cannot split $srcfile into job and extension";
        die;
    }
    
    
    $this->{'src'}->{'dir'} = $srcdir;
    $this->{'src'}->{'job'} = $srcjob;
    $this->{'src'}->{'ext'} = $srcext;
    
    
    # strip the directory part from the output file path
    if($outfile =~ /^(.+)\/([^\/]+)$/)
    {
        $outdir    = $1;
        $outfile   = $2;
    }
    else
    {
        $outdir    = ".";
    }
    
    # strip the extension from the output file
    if($outfile =~ /(.+)\.([^\.]+)/)
    {
        $outjob    = $1;
        $outext    = $2;
        
        print <<END;
outdir:     $outdir
outfile:    $outfile
outjob:     $outjob
outext:     $outext
END
        
    }
    else
    {
        print_f "Cannot split $outfile into job and extension";
        die;
    }
    
    $this->{'out'}->{'dir'} = $outdir;
    $this->{'out'}->{'job'} = $outjob;
    $this->{'out'}->{'ext'} = $outext;
}





sub check_output_directory
{
    my $this    = shift;
    my $outdir  = $this->{'out'}->{'dir'};
     
     
    # check to make sure the output directory exists
    unless( -e $outdir )
    {
        print_n "$outdir does not exist attempting to make it";
        unless ( make_path($outdir) )
        {
            print_f "Failed to make $outdir $!";
            die;
        }
    }
}




sub create_rootfile()
{
    # create the root file for this document build
    my $this    = shift;
    my $cmd     = shift;
    my $srcfile = $this->{'src'}->{'file'};
    my $outdir  = $this->{'out'}->{'dir'};
    my $outjob  = $this->{'out'}->{'job'};
    my $outext  = $this->{'out'}->{'ext'};
    my $rootfile= "$outdir/$outjob\_$outext.tex";
    
    my $fh;
    unless ( open ($fh, '>', "$rootfile") )
    {
        print_f "Cannot open $rootfile for write $!";
        die;
    }
    
    print $fh <<END;
    \\newif\\ifpdfoutput
    \\newif\\ifxhtmloutput
    \\newif\\ifdvioutput
    
    $cmd
    
    \\listfiles
    
    \\input{$srcfile}
END
    
    close $fh;
    
    print_n "Created rootfile in $rootfile";
}






sub dispatch
{
    my $this = shift;

    # based on what file format we're building, determine what the graphics file
    
    my ($fig,$cmd);
    my $builder;
 
    switch($this->{'out'}->{'ext'})
    {
        case "pdf" { next }
        case "dvi"
        {
            $builder = Texmake::LatexBuilder->new($this);
        }
        
        case "html" { next }
        case "xhtml"
        {
            $builder = Texmake::LatexmlBuilder->new($this);
        }

        else
        {
            print_f
            die "unknown output extension $_";
        }            
    }   
    
    $builder->go();
}



1;