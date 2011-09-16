package Texmake::Tools::Bibtex;
require Texmake::Tools::Bibtex::Node;

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

sub getSourceTypes
{
    return ();
}

sub getOutputTypes
{
    return qw(bbl);
}





1;