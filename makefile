PROJECT     :=  gpu_rrtstar

# The following definitions are the specifics of this project
PDF_OUTPUT  :=  $(PROJECT).pdf
HTML_OUTPUT :=  $(PROJECT).xhtml

PDF_MAIN	:=  $(PROJECT)_pdf.tex
HTML_MAIN   :=  $(PROJECT)_html.tex

COMMON_TEX 	:=	$(PROJECT).tex \
                preamble_common.tex 
				
PDF_TEX		:=  $(COMMON_TEX) \
                $(PROJECT)_pdf.tex \
                preamble_pdf.tex
				
HTML_TEX    :=  $(COMMON_TEX) \
                $(PROJECT)_html.tex \
                preamble_html.tex 
                
BIB         :=  

CLEAN_EXT   :=  aux txt log css cache bbl blg lof lot out toc xml html xhtml pdf

# these variables are the dependencies for the outputs
PDF_SRC     := $(PDF_TEX) $(BIB)
HTML_SRC    := $(HTML_TEX) $(BIB)

CLEAN_CMD   := $(addprefix *.,$(CLEAN_EXT))

# the 'all' target will make both the pdf and html outputs
all: pdf html

# the 'pdf' target will make the pdf output
pdf: $(PDF_OUTPUT)

# the 'html' target will make the html output
html: $(HTML_OUTPUT)

# the pdf output depends on the pdf tex files
# we use a shell script to optionally run pdflatex multiple times until the
# output does not suggest that we rerun latex
$(PDF_OUTPUT): $(PDF_TEX) makefile
	@echo "Running pdflatex on $(PDF_MAIN)"
	@pdflatex $(basename $(PDF_MAIN)) > $(basename $(PDF_MAIN))_0.log
	@echo "Running bibtex"
	@-bibtex   $(basename $(PDF_MAIN)) > bibtex_pdf.log 
	@echo "Checking for rerun suggestion"
	@for ITER in 1 2 3 4; do \
		STABELIZED=`cat $(basename $(PDF_MAIN)).log | grep "Rerun"`; \
		if [ -z "$$STABELIZED" ]; then \
			echo "Document stabelized after $$ITER iterations"; \
			break; \
		fi; \
		echo "Document not stabelized, rerunning pdflatex"; \
		pdflatex $(basename $(PDF_MAIN)) > $(basename $(PDF_MAIN))_$$ITER.log; \
	done
	@echo "Copying pdf to target file"
	@cp $(basename $(PDF_MAIN)).pdf $(PDF_OUTPUT)
	
# the html output depends on the html tex files
# we have to process all of the bibliography files separately into xml files, 
# and then include them all in the call to the postprocessor
$(HTML_OUTPUT): $(HTML_TEX) makefile
	@echo "Running latexml on $(HTML_MAIN)"
	@latexml $(HTML_MAIN) --dest=$(basename $(HTML_OUTPUT)).xml > $(basename $(HTML_MAIN)).log 2>&1
	@BIBSTRING=""; \
	for BIBFILE in $(BIB); do \
		echo "Running latexml on $$BIBFILE"; \
		XMLFILE=`basename "$$BIBFILE" .bib`.xml; \
		LOGFILE=`basename "$$BIBFILE" .bib`_html.log; \
	    latexml $$BIBFILE --dest=$$XMLFILE > $$LOGFILE 2>&1; \
	    BIBSTRING="$$BIBSTRING --bibliography=$$XMLFILE"; \
	done; \
	echo $$BIBSTRING > bibstring.txt
	@echo "postprocessing with `cat bibstring.txt`"
	@latexmlpost $(basename $(HTML_OUTPUT)).xml `cat bibstring.txt` --dest=$(HTML_OUTPUT) --css=navbar-left.css
#	@latexmlpost --splitat chapter $(basename $(HTML_OUTPUT)).xml `cat bibstring.txt` --dest=$(HTML_OUTPUT) --css=navbar-left.css
#	@echo "postprocessing for monolithic page"
#	@latexmlpost $(basename $(HTML_OUTPUT)).xml `cat bibstring.txt` --dest=$(basename $(HTML_OUTPUT))_monolithic.xhtml --css=navbar-left.css
	
# the 2>/dev/null redirects stderr to the null device so that we don't get error
# messages in the console when rm has nothing to remove
clean:
	@-rm -v $(CLEAN_CMD) 

