# format for rules is
# sourcefile : output_1 output_2 ...
#
# You can put outputs on separate lines if you end the previous line with a \
# For instance
#
# sourcefile: output_1  \
#               output_2 \
#               output_3 \
#
# you can tell texmake to recurse into subdirectories by using a line like
# +subdir1
# +subdir2
#

addTarget( 'texmake.pdf', 'texmake.tex' );
addTarget( 'texmake.xhtml', 'texmake.tex' );

addSubdirectory('a');