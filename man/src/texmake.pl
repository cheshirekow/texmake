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

addTarget( 'texmake.pdf', 'texmake_pdf.tex' );

addTarget( 
    {
        'outfile'   =>'texmake.xhtml', 
        'srcfile'   =>'texmake_html.tex', 
        'bibfiles'  =>['bib/references.bib',
                        'bib/references2.bib'],
        'options'   =>'--splitat=chapter --css=amsart'
    } );
    
addTarget( 
    {
        'outfile'   =>'texmake_monolithic.xhtml', 
        'srcfile'   =>'texmake_html.tex', 
        'bibfiles'  =>['bib/references.bib',
                        'bib/references2.bib'],
        'options'   =>'--css=amsart'
    } );

