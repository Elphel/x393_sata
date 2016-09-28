VERILOGDIR=   $(DESTDIR)/usr/local/verilog
INSTALLDIR=   $(DESTDIR)/usr/local/bin
SCRIPTPATH=   py393sata
 
OWN = -o root -g root

INSTMODE   = 0755
DOCMODE    = 0644

PYTHON_EXE = $(SCRIPTPATH)/*.py
FPGA_BITFILES =   x393_sata.bit

all:
	@echo "make all in x393sata"
install:
	@echo "make install in x393sata"
	$(INSTALL) $(OWN) -d $(VERILOGDIR)
	$(INSTALL) $(OWN) -d $(INSTALLDIR)

	$(INSTALL) $(OWN) -m $(INSTMODE) $(PYTHON_EXE)                          $(INSTALLDIR)
	$(INSTALL) $(OWN) -m $(DOCMODE)  $(FPGA_BITFILES)                       $(VERILOGDIR)
clean:
	@echo "make clean in x393sata"
	