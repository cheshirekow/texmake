#!/usr/bin/perl

if($#ARGV < 1)
{
	print "usage: makedep <root.tex> <intendedoutput>\n";
	die;
}

my $rootfile = $ARGV[0];
my $output   = $ARGV[1];

$output =~ /(.+)\.([^.]+)$/;
my $base= $1;
my $ext = $2;

my $fig;
if($ext eq "pdf")
{
    $fig = "pdf";
}
elsif($ext eq "xhtml" || $ext eq "html")
{
    $fig = "png";
}
elsif($ext eq "dvi")
{
    $fig = "eps";
}
else
{
	print "unknown output extension $ext\n";
	die;
}

open DEPEND, "texdepend -format=1 $rootfile |";

my @files;

while(<DEPEND>)
{
    next if(/^#/);
    chomp;
    s/\.eps$/\.$fig/;
    push(@files, $_);
}

close DEPEND;

open OUTFILE, ">$output.d";

print OUTFILE "$output: $rootfile $output.d \\\n";

foreach $file (@files)
{
	print OUTFILE "    $file \\\n";
}

print OUTFILE "\n\n";
print OUTFILE "$output.d: $rootfile \\\n";

foreach $file (@files)
{
    print OUTFILE "    $file \\\n";
}

print OUTFILE "\n\n";
close OUTFILE;
