#!/usr/bin/perl


my @hashes;
my @authors;
my @dates;
my @messages;

my $authlength = 0;
my $datelength = 0;

open INFILE, "lasthash";
$lasthash = <INFILE>;
close INFILE;

#git log -n 10 --pretty=format:'%h & %an & %ad & %s \\ \hline' > git.tex

open GITLOG, "git log -n 10 --pretty=format:%h |";
while(<GITLOG>)
{
	chomp;
	push(@hashes,$_);
}
close GITLOG;

open GITLOG, "git log -n 10 --pretty=format:%an |";
while(<GITLOG>)
{
    chomp;
    push(@authors,$_);
    if( length($_) > $authlength )
    {
        $authlength = length($_);
    }
}
close GITLOG;

open GITLOG, "git log -n 10 --pretty=format:%ad |";
while(<GITLOG>)
{
    chomp;
    push(@dates,$_);
    if( length($_) > $datelength )
    {
        $datelength = length($_);
    }
}
close GITLOG;

open GITLOG, "git log -n 10 --pretty=format:%s |";
while(<GITLOG>)
{
    chomp;
    push(@messages,$_);
}
close GITLOG;

if( $hashes[0] eq $lasthash )
{
	print "git.tex does not need updating\n";
	exit;
}


open OUTFILE, ">git.tex";
print OUTFILE "\\lstset{breaklines=true}\n";
print OUTFILE "\\begin{lstlisting}\n";

for( $i=0; $i <= $#hashes; $i++)
{
    my $hash   = $hashes[$i];
    my $author = $authors[$i];
    my $date   = $dates[$i];
    my $message= $messages[$i];
    
    while( length($author) < $authlength )
    {
    	$author .= " ";
    }
    
    while( length($date) < $datelength )
    {
    	$date .= " ";
    }
    
   	print OUTFILE "$hash  $author  $date  $message\n";
}

print OUTFILE "\\end{lstlisting}\n";
close OUTFILE;

open OUTFILE, ">lasthash";
print OUTFILE $hashes[0];
close OUTFILE;