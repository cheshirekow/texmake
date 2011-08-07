gpu_rrtstar.pdf.d   : gpu_rrtstar_pdf.tex 
gpu_rrtstar.xhtml.d : gpu_rrtstar_html.tex
gpu_rrtstar.dvi.d   : gpu_rrtstar_pdf.tex

include gpu_rrtstar.pdf.d
include gpu_rrtstar.xhtml.d
include gpu_rrtstar.dvi.d



CLEAN_EXT   :=  aux txt log cache bbl blg lof lot out toc xml html xhtml pdf d

# these variables are the dependencies for the outputs
PDF_SRC     := $(PDF_TEX) $(BIB)
HTML_SRC    := $(HTML_TEX) $(BIB)

CLEAN_CMD   := $(addprefix *.,$(CLEAN_EXT))

# the 'all' target will make both the pdf and html outputs
all: $(addprefix gpu_rrtstar, .dvi .pdf .xhtml)

	
	


%.d : 
	./makedep.pl $< $*

%.eps : %.svg
	convert $< $@
	
%.png : %.svg
	convert $< $@
	
%.pdf : %.svg
	convert $< $@
	


%.pdf : %.pdf.d
	@echo "Running pdflatex on $(word 2,$^)"
	@pdflatex -interaction=nonstopmode $(basename $(word 2,$^)) > $@_0.log
	@BIBS=$(filter *.bib, $^); \
	if [ -n "$$BIBS" ]; then \
		echo "bib dependencies: $$BIBS"; \
	    echo "Running bibtex on $(basename $(word 2,$^))"; \
	    bibtex  $(basename $(word 2,$^)) > $@_bibtex.log; \
    fi;
	@echo "Checking for rerun suggestion"
	@for ITER in 1 2 3 4; do \
		STABELIZED=`cat $(basename $(word 2,$^)).log | grep "Rerun"`; \
		if [ -z "$$STABELIZED" ]; then \
			echo "Document stabelized after $$ITER iterations"; \
			break; \
		fi; \
		echo "Document not stabelized, rerunning pdflatex"; \
		pdflatex -interaction=nonstopmode $(basename $(word 2,$^)) > $@_$$ITER.log; \
	done
	@echo "Copying pdf to target file"
	@cp $(basename $(word 2,$^)).pdf $@



%.dvi : %.dvi.d
	@echo "Running latex on $(word 2,$^)"
	@latex -interaction=nonstopmode $(basename $(word 2,$^)) > $@_0.log
	@BIBS=$(filter *.bib, $^); \
	if [ -n "$$BIBS" ]; then \
		echo "bib dependencies: $$BIBS"; \
	    echo "Running bibtex on $(basename $(word 2,$^))"; \
	    bibtex  $(basename $(word 2,$^)) > $@_bibtex.log; \
    fi; 
	@echo "Checking for rerun suggestion"
	@for ITER in 1 2 3 4; do \
		STABELIZED=`cat $(basename $(word 2,$^)).log | grep "Rerun"`; \
		if [ -z "$$STABELIZED" ]; then \
			echo "Document stabelized after $$ITER iterations"; \
			break; \
		fi; \
		echo "Document not stabelized, rerunning pdflatex"; \
		latex -interaction=nonstopmode $(basename $(word 2,$^)) > $@_$$ITER.log; \
	done
	@echo "Copying pdf to target file"
	@cp $(basename $(word 2,$^)).dvi $@
	


%.xhtml: %.xhtml.d
	@echo "Running latexml on $(word 2,$^)"
	@latexml $(word 2,$^) --dest=$(basename $@).xml > $(basename $@).xml.log 2>&1
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
	@latexmlpost $(basename $@).xml `cat bibstring.txt` --dest=$@ --css=navbar-left.css

	
# the 2>/dev/null redirects stderr to the null device so that we don't get error
# messages in the console when rm has nothing to remove
clean:
	@-rm -v $(CLEAN_CMD) 

