##  @class
#   @brief  a node which uses pdflatex to compile a .tex document
package Texmake::Tools::Latexml;

use strict;

use Switch;
use File::stat;
use File::Copy;
use File::Basename qw(dirname);
use Time::localtime;
use Cwd qw(getcwd);

use Texmake ':all';
use Texmake::Printer ':all';
use Texmake::PrintIncrementer;

use Texmake::Node;
use Texmake::Tools::Source;
use Texmake::Tools::Symlink;
use Texmake::Tools::Bibtex;
use Texmake::Tools::TexRootMaker;
use Texmake::Tools::Latexml::Html::Node;
use Texmake::Tools::Latexml::Xhtml::Node;
use Texmake::Tools::Latexml::Xml::Node;

sub getSourceTypes
{
    my @srcTypes = qw(tex);
    return \@srcTypes;
}

sub getOutputTypes
{
    my @outTypes = qw(html xhtml);
    return \@outTypes;
}



##  @method void createTree($target)
#   @brief  performs the actual initialization, creating the build directory,
#           generating the rootfile, generating the dependency graph
#   @param[in]  init    reference to the Texmake::Initializer who is calling us
sub createTree
{
    my $class   = shift;
    my $target  = shift;
    my $output  = $target->{'outdir'} . '/' . $target->{'outfile'};
    my $outdir  = "$output.texmake";
    
    my $ext     = "xhtml";
    if( $target->{'outfile'} =~ /\.html$/ )
    {
        $ext    = "html";
    }
    
    my $buildout= "$outdir/root.$ext";
    my $srcdir  = $target->{'srcdir'};
    my $params  = {
        'outdir' => $outdir,
        'srcdir' => $target->{'srcdir'},
        'inputs' => $target->{'inputs'},
        'header' => $target->{'header'},
        'footer' => $target->{'fooder'}
        };
    
    # if the user passed us a string, then we assume it is the file name of the
    # source to include, otherwise we assume it's a hash of inputs, header,
    # and footer
    if( exists $target->{'srcfile'} )
    {
        print_n 0, "Using sourcefile " . $target->{'srcfile'} . " for latexml inputs";
        my @inputs = ( $target->{'srcfile'} );
        $params->{'inputs'} = \@inputs;
    }
     
    my $pkg         = "Texmake::Tools::";
    my $xmlNode     = ($pkg.'Latexml::Xml::Node')->new($outdir,$srcdir);
    my $postNode;
    my $rootfileNode= ($pkg.'TexRootMaker::Node')->new($params);
    
    if($ext eq "html")
        {$postNode  =  ($pkg.'Latexml::Html::Node')->new($output,$srcdir);}
    else
        {$postNode  =  ($pkg.'Latexml::Xhtml::Node')->new($output,$srcdir);}
    


    # note:
    # we don't need to explicitly add the source file since the scanner will
    # pick that up during the first build
    $postNode->dependsOn($xmlNode);
    $xmlNode->dependsOn($rootfileNode);
    
    return $postNode;
}










1;