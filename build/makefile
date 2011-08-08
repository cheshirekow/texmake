SVG2PDF := /home/josh/Codes/c/svg2pdf/gitclone/svg2pdf
SVG2EPS := /home/josh/Codes/c/svg2pdf/gitclone/svg2eps
CONVERT := convert
MAKEDEP := ../makedep.pl
MAKEGIT := ../makegit.pl
SOURCE_DIR := ../src

# the 'all' target will make both the pdf and html outputs
all:    dvi/gpu_rrtstar.dvi \
        pdf/gpu_rrtstar.pdf \
        xhtml/index.xhtml

pdf/gpu_rrtstar.pdf.d \
xhtml/index.xhtml.d \
dvi/gpu_rrtstar.dvi.d : $(SOURCE_DIR)/root.tex

include dvi/gpu_rrtstar.dvi.d
include pdf/gpu_rrtstar.pdf.d
include xhtml/index.xhtml.d


	


%.d : 
	$(MAKEDEP) $< $*

dvi/%.eps : $(SOURCE_DIR)/%.svg
	$(SVG2EPS) $< $@
	
xhtml/%.png : $(SOURCE_DIR)/%.svg
	$(CONVERT) $< $@
	
pdf/%.pdf : $(SOURCE_DIR)/%.svg
	$(SVG2PDF) $< $@
	
git.tex: 
	$(MAKEGIT)

%.pdf : %.pdf.d
	@echo "Bulding Root Document $*_pdf.tex"
	cat $(SOURCE_DIR)/conditionals.tex > $*_pdf.tex
	echo "\pdfoutputtrue" >> $*_pdf.tex
	echo "" >> $*_pdf.tex
	cat $(word 2,$^) >> $*_pdf.tex
	@echo "Running pdflatex on $*_pdf.tex"
	@export TEXINPUTS=".:pdf/:$(SOURCE_DIR):"; \
        pdflatex -interaction=nonstopmode -jobname $* $*_pdf.tex > $*_pdf_0.log
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
		export TEXINPUTS=".:pdf/:$(SOURCE_DIR):"; \
		pdflatex -interaction=nonstopmode -jobname $* $*_pdf.tex > $*_pdf_$$ITER.log; \
	done
	@echo "Finished"



%.dvi : %.dvi.d
	@echo "Bulding Root Document $*_dvi.tex"
	cat $(SOURCE_DIR)/conditionals.tex > $*_dvi.tex
	echo "\dvioutputtrue" >> $*_dvi.tex
	echo "" >> $*_dvi.tex
	cat $(word 2,$^) >> $*_dvi.tex
	@echo "Running latex on $*_dvi.tex"
	@export TEXINPUTS=".:dvi/:$(SOURCE_DIR):"; \
        latex -interaction=nonstopmode -jobname $* $*_dvi.tex > $*_dvi_0.log
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
		export TEXINPUTS=".:dvi/:$(SOURCE_DIR):"; \
		latex -interaction=nonstopmode -jobname $* $*_dvi.tex > $*_dvi_$$ITER.log; \
	done
	@echo "Finished"
	


%.xhtml: %.xhtml.d
	@echo "Bulding Root Document $*_xhtml.tex"
	cat $(SOURCE_DIR)/conditionals.tex > $*_xhtml.tex
	echo "\xhtmloutputtrue" >> $*_xhtml.tex
	echo "" >> $*_xhtml.tex
	cat $(word 2,$^) >> $*_xhtml.tex
	@echo "Running latexml on $*_xhtml.tex"
	@latexml $*_xhtml.tex --path=xhtml/ --path=$(SOURCE_DIR) --dest=$*.xml > $*.xml.log 2>&1
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
clean: $(addprefix clean_,dvi pdf xhtml)
	cp xhtml/core.css ./
	-rm -vf $(addsuffix /*,dvi pdf xhtml)
	mv core.css xhtml/
	-rm -vf conditionals.* bibstring.txt 
    
