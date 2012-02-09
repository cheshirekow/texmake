#!/bin/bash
export PATH=$PWD/../../Texmake/bin:$PATH
export PERL5LIB=$PWD/../../Texmake/lib

texmake init ../src
texmake make

