package Texmake::BuilderRegistry;

use strict;

use Fcntl;
use Proc::Killfam;  #apt-get libproc-processtable-perl
use File::Path qw(make_path);
use File::Basename qw(fileparse);
use Switch;

use Texmake::Printer qw(print_w print_f print_n print_e);
use Texmake::PrintIncrementer;


our $builtInBuilders = 
    [
        {
            'package'   =>  'Imagemagick', 
            'srcTypes'  => [ qw[.png .jpg .eps .pdf] ],
            'outTypes'  => [ qw[.png .jpg .eps .pdf] ], 
        },
        {
            'package'   =>  'Imagemagick', 
            'srcTypes'  => [ qw[.svg ] ],
            'outTypes'  => [ qw[.png ] ], 
        },
        {
            'package'   =>  'Pdflatex', 
            'srcTypes'  => [ qw[.tex] ], 
            'outTypes'  => [ qw[.pdf] ], 
        },
        {
            'package'   => 'Latexml',
            'srcTypes'  => [ qw[.tex] ],
            'outTypes'  => [ qw[.html .xhtml] ],  
        },
        {
            'package'   => 'Svg2eps', 
            'srcTypes'  => [ qw[.svg] ], 
            'outTypes'  => [ qw[.eps] ],
        },
        {
            'package'   => 'Svg2pdf', 
            'srcTypes'  => [ qw[.svg] ], 
            'outTypes'  => [ qw[.pdf] ],
        }
    ];

our $srcStore = {};
our $outStore = {};
our $buildMap = {};


sub registerBuilder
{
    my $builder     = shift;
    my $srcTypes    = shift;
    my $outTypes    = shift;
    
    foreach my $src( @$srcTypes )
    {
        $srcStore->{$src} = 1;
        unless( exists $buildMap->{$src} )
        {
            $buildMap->{$src} = {};
        }
        
        foreach my $out( @$outTypes )
        {
            $outStore->{$out} = 1;
            if( exists $buildMap->{$src}->{$out} )
            {
                my $oldBuilder = $buildMap->{$src}->{$out};
                print_w "Overriding $oldBuilder with $builder as builder from"
                        ."$src to $out";  
            }
            else
            {
                print_n 0, "Registering $builder as builder from $src to $out";
            }
            $buildMap->{$src}->{$out} = $builder;
        }
    }
}


sub findBuilder
{
    my $srcfile = shift;
    my $outfile = shift;
    
    my ($srcBase,$srcDir,$srcSuffix) = fileparse($srcfile, keys %$srcStore);
    my ($outBase,$outDir,$outSuffix) = fileparse($outfile, keys %$outStore);
    
    if(exists $buildMap->{$srcSuffix} &&
        exists $buildMap->{$srcSuffix}->{$outSuffix})
    {
        return $buildMap->{$srcSuffix}->{$outSuffix};
    }
    
    else
    {
        return undef;
    }
}


sub init
{
    print_n 0, "Initializing builder registry:\n----------------------";
    
    foreach my $builder (@$builtInBuilders )
    {
        registerBuilder('Texmake::Tools::'.$builder->{'package'},
            $builder->{'srcTypes'},
            $builder->{'outTypes'});
    }
    
    print_e " ";
}



