VERILOGDIR=   $(DESTDIR)/usr/local/verilog
INSTALLDIR=   $(DESTDIR)/usr/local/bin
WWW_PAGES =   $(DESTDIR)/www/pages
SCRIPTPATH=   py393sata
 
OWN = -o root -g root

INSTMODE   = 0755
DOCMODE    = 0644

PYTHON_EXE = $(SCRIPTPATH)/*.py
PHP_EXE    = $(SCRIPTPATH)/*.php
FPGA_BITFILES =   x393_sata.bit

all:
	@echo "make all in x393sata"
install:
	@echo "make install in x393sata"
	$(INSTALL) $(OWN) -d $(VERILOGDIR)
	$(INSTALL) $(OWN) -d $(INSTALLDIR)
	$(INSTALL) $(OWN) -d $(WWW_PAGES)

	$(INSTALL) $(OWN) -m $(INSTMODE) $(PYTHON_EXE)                          $(INSTALLDIR)
	$(INSTALL) $(OWN) -m $(DOCMODE)  $(FPGA_BITFILES)                       $(VERILOGDIR)
	$(INSTALL) $(OWN) -m $(INSTMODE) $(PHP_EXE)                             $(WWW_PAGES)
clean:
	@echo "make clean in x393sata"
	