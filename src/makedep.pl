#!/usr/bin/perl

if($#ARGV < 1)
{
	print "usage: makedep <root.tex> <intendedoutput>\n";
	die;
}

my @texmf = (".", "/usr/share/texmf", "/usr/share/texmf-texlive", "~/texmf/");

my $rootfile = $ARGV[0];
my $output   = $ARGV[1];

$output =~ /(.+)\.([^.]+)$/;
my $base= $1;
my $ext = $2;

my $fig;
my $cmd;
if($ext eq "pdf")
{
    $fig = "pdf";
    $cmd = "\\pdfoutputtrue";
}
elsif($ext eq "xhtml" || $ext eq "html")
{
    $fig = "png";
    $cmd = "\\xhtmloutputtrue";
}
elsif($ext eq "dvi")
{
    $fig = "eps";
    $cmd = "\\dvioutputtrue";
}
else
{
	print "unknown output extension $ext\n";
	die;
}


open DEPEND, "latex -draftmode -interaction nonstopmode \"\\listfiles \\input{conditionals.tex} $cmd \\input{$rootfile}\" |";

my @packages;
my @images;
my @includes;
my @bibs;

my @foundpackages;

my $filelist=0;

while(<DEPEND>)
{
    if($filelist)
    {
        if(/^\s*\*+\s*$/)
        {
        	$filelist=0;
        	next;
        }
        elsif(/^\s*(\S+)\s*/)
        {
            $file = $1;
            if($file=~/\.tex$/)
            {
            	push(@includes,$file);
            }
            elsif($file=~/\.bib$/)
            {
            	push(@bibs,$file);
            }
            elsif($file=~/(.+)\.pdf$/ || $file=~/(.+)\.eps$/ || $file=~/(.+)\.png$/ )
            {
            	push(@images,"$1.$fig");
            }
            elsif($file=~/\.out/)
            {
            	next;
            }
            else
            {
            	push(@packages,$file);
            }
            
            next;
        }
    }
    else
    {
    	if(/^! LaTeX Error: File `([^']+)' not found.$/)
        {
            chomp;
            push(@images,"$1.$fig");
            next;        
        }
        elsif(/^\s*\*File List\*\s*$/)
        {
            $filelist=1;
            next;
        }
    }
}

close DEPEND;



foreach my $file (@packages)
{
    my $found=0;	
	foreach my $dir (@texmf)
	{
		open FIND, "find $dir -iname \"$file\" |";
		while(<FIND>)
		{
			chomp;
			push(@foundpackages,$_);
			$found=1;
			last;
		}
		close FIND;
		last if($found);
	}
}


my @files;
push(@files,@foundpackages);
push(@files,@includes);
push(@files,@images);
push(@files,@bibs);

open OUTFILE, ">$output.d";

print OUTFILE "$output: $rootfile $output.d \\\n";

foreach $file (@files)
{
	if($file=~/^\//)
    {
        print OUTFILE "    $file \\\n";
    }
    else
    {
        print OUTFILE "    \$(SOURCE_DIR)/$file \\\n";
    }
}

print OUTFILE "\n\n";
print OUTFILE "$output.d: $rootfile \\\n";

foreach $file (@includes)
{
	if($file=~/^\//)
	{
		print OUTFILE "    $file \\\n";
	}
	else
	{
        print OUTFILE "    \$(SOURCE_DIR)/$file \\\n";
	}
}

print OUTFILE "\n\n";
close OUTFILE;
