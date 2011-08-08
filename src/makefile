SVG2PDF := /home/josh/Codes/c/svg2pdf/gitclone/svg2pdf
SVG2EPS := /home/josh/Codes/c/svg2pdf/gitclone/svg2eps
MAKEDEP := ../makedep.pl
MAKEGIT := ../makegit.pl

gpu_rrtstar.pdf.d   : root.tex
gpu_rrtstar.xhtml.d : root.tex
index.xhtml.d       : root.tex
gpu_rrtstar.dvi.d   : root.tex

SOURCE_DIR := ./
include gpu_rrtstar.pdf.d
include gpu_rrtstar.xhtml.d
include gpu_rrtstar.dvi.d


#note use TEXINPUTS=".:../../src:" to prepend the current directory and the source
#directory to the search path for \input and \include directives

CLEAN_EXT   :=  aux txt log cache bbl blg lof lot out toc xml html xhtml pdf d dvi png gz
CLEAN_IMG   :=  png pdf eps

# these variables are the dependencies for the outputs
PDF_SRC     := $(PDF_TEX) $(BIB)
HTML_SRC    := $(HTML_TEX) $(BIB)

CLEAN_CMD   := $(addprefix *.,$(CLEAN_EXT)) \
               $(addprefix fig/*.,$(CLEAN_IMG)) \
               $(addprefix fig/blocks*.,$(CLEAN_IMG))

# the 'all' target will make both the pdf and html outputs
all: $(addprefix gpu_rrtstar, .dvi .pdf .xhtml)

	
	


%.d : 
	$(MAKEDEP) $< $*

%.eps : %.svg
	$(SVG2EPS) $< $@
	
%.png : %.svg
	convert $< $@
	
%.pdf : %.svg
	$(SVG2PDF) $< $@
	
git.tex: 
	$(MAKEGIT)

%.pdf : %.pdf.d
	@echo "Bulding Root Document $*_pdf.tex"
	cat conditionals.tex > $*_pdf.tex
	echo "\pdfoutputtrue" >> $*_pdf.tex
	echo "" >> $*_pdf.tex
	cat $(word 2,$^) >> $*_pdf.tex
	@echo "Running pdflatex on $*_pdf.tex"
	@pdflatex -interaction=nonstopmode -jobname $* $*_pdf.tex > $*_pdf_0.log
	@BIBS=$(filter *.bib, $^); \
	if [ -n "$$BIBS" ]; then \
		echo "bib dependencies: $$BIBS"; \
	    echo "Running bibtex on $*_pdf.tex"; \
	    bibtex  $*_pdf.tex > $*_pdf_bibtex.log; \
    fi;
	@echo "Checking for rerun suggestion"
	@for ITER in 1 2 3 4; do \
		STABELIZED=`cat $*.log | grep "Rerun"`; \
		if [ -z "$$STABELIZED" ]; then \
			echo "Document stabelized after $$ITER iterations"; \
			break; \
		fi; \
		echo "Document not stabelized, rerunning pdflatex"; \
		pdflatex -interaction=nonstopmode -jobname $* $*_pdf.tex > $*_pdf_$$ITER.log; \
	done
	@echo "Finished"



%.dvi : %.dvi.d
	@echo "Bulding Root Document $*_dvi.tex"
	cat conditionals.tex > $*_dvi.tex
	echo "\dvioutputtrue" >> $*_dvi.tex
	echo "" >> $*_dvi.tex
	cat $(word 2,$^) >> $*_dvi.tex
	@echo "Running latex on $*_dvi.tex"
	@latex -interaction=nonstopmode -jobname $* $*_dvi.tex > $*_dvi_0.log
	@BIBS=$(filter *.bib, $^); \
	if [ -n "$$BIBS" ]; then \
		echo "bib dependencies: $$BIBS"; \
	    echo "Running bibtex on $*_dvi.tex"; \
	    bibtex  $*_dvi.tex > $*_dvi_bibtex.log; \
    fi; 
	@echo "Checking for rerun suggestion"
	@for ITER in 1 2 3 4; do \
		STABELIZED=`cat $*.log | grep "Rerun"`; \
		if [ -z "$$STABELIZED" ]; then \
			echo "Document stabelized after $$ITER iterations"; \
			break; \
		fi; \
		echo "Document not stabelized, rerunning latex"; \
		latex -interaction=nonstopmode -jobname $* $*_dvi.tex > $*_dvi_$$ITER.log; \
	done
	@echo "Finished"
	


%.xhtml: %.xhtml.d
	@echo "Bulding Root Document $*_xhtml.tex"
	cat conditionals.tex > $*_xhtml.tex
	echo "\xhtmloutputtrue" >> $*_xhtml.tex
	echo "" >> $*_xhtml.tex
	cat $(word 2,$^) >> $*_xhtml.tex
	@echo "Running latexml on $*_xhtml.tex"
	@latexml $*_xhtml.tex --dest=$*.xml > $*.xml.log 2>&1
	@BIBSTRING=""; \
	BIB="$(filter *.bib, $^)"; \
	for BIBFILE in $$BIB; do \
		echo "Running latexml on $$BIBFILE"; \
		XMLFILE=`basename "$$BIBFILE" .bib`.xml; \
		LOGFILE=`basename "$$BIBFILE" .bib`.xml.log; \
	    latexml $$BIBFILE --dest=$$XMLFILE > $$LOGFILE 2>&1; \
	    BIBSTRING="$$BIBSTRING --bibliography=$$XMLFILE"; \
	done; \
	echo $$BIBSTRING > bibstring.txt
	@echo "postprocessing with `cat bibstring.txt`"
	@latexmlpost $*.xml `cat bibstring.txt` --dest=$@ --css=navbar-left.css

	
# the 2>/dev/null redirects stderr to the null device so that we don't get error
# messages in the console when rm has nothing to remove
clean:
	@-rm -vf $(CLEAN_CMD) 
    
