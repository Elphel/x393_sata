TOPLEVEL := sata_host
TOPLEVEL_LANG ?= verilog

PWD=$(shell pwd)
COCOTB=~/sata/git/x393_sata/coco

ifeq ($(OS),Msys)
WPWD=$(shell sh -c 'pwd -W')
PYTHONPATH := $(WPWD);$(PYTHONPATH)
else
WPWD=$(shell pwd)
PYTHONPATH := $(WPWD):$(PYTHONPATH)
endif
export PYTHONPATH

VERILOG_SOURCES = $(WPWD)/../sata_host.v $(WPWD)/../x393/glbl.v $(WPWD)/../GTXE2_CHANNEL.v
COMPILE_ARGS = -I$(WPWD)/../ -I$(WPWD)/../x393/ -I$(WPWD)/../x393/axi/ -I$(WPWD)/../host/ -y$(WPWD)/../x393/unisims -y$(WPWD)/../x393/util_modules/ -y$(WPWD)/../x393/wrap -y$(WPWD)/../x393/memctrl -D CHECKERS_ENABLED -D SIMULATION
GPI_IMPL := vpi

export TOPLEVEL_LANG

MODULE ?= test_host

include $(COCOTB)/makefiles/Makefile.inc
include $(COCOTB)/makefiles/Makefile.sim
