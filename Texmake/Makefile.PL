use 5.010001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

@exe_files  = ('bin/texmake');

WriteMakefile(
    NAME              => 'Texmake',
    VERSION_FROM      => 'lib/Texmake.pm', # finds $VERSION
    EXE_FILES         => \@exe_files, 
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Texmake.pm', # retrieve abstract from module
       AUTHOR         => 'Josh BIalkowski <jbialk@mit.edu>') : ()),
);
