# x393_sata
SATA controller for x393 camera
Board: Zynq 7z30
FPGA: Kintex-7

# Clone

git clone https://github.com/Elphel/x393_sata **--recursive**

# Working on remote PC

1. sudo apt-get install ssh-askpass  
2. ssh-copy-id user@ip  

# Swtich between synthesis & simulation
See update below
Edit *.editor_defines*:
* simulation:
  `define SIMULATION 1
  `define CHECKERS_ENABLED 1
  `define OPEN_SOURCE_ONLY 1
  `define PRELOAD_BRAMS
* synthesis:
  //`define SIMULATION 1
  //`define CHECKERS_ENABLED 1
  //`define OPEN_SOURCE_ONLY 1
  `define PRELOAD_BRAMS

Refresh the project and update hierarchy (or rescan)

**Update:** Not needed anymore with updated VDT plugin - it now calculates closure per-tool and per-top file defines,
so *.editor_defines* is now just for the editor (which branches to parse). No refresh/rescan is required.
  
# Simulation
* Get unisims library - refresh project files otherwise nothing will work  

# Synthesis
* Add constraints file through Synthesis parameters
* Bitstream Tool parameters - check *Force(overwrite)*
  
# Current step in try2 branch:
Not yet tested in hardware, started AHCI implementation (currently coded registers and DMA engine, that processes command table/PRD list,
Transfers data between clock domains, re-aligns between WORD size granularity, HAB 32-bit data and 64-bit AFI accesses.
# Current step in main branch:
Testing basic functionallity of a host.  
Trying out pio access.  
Fullfilling device-side drivers and monitors via tasks.  
Tests are mostly manual, relied on a common sense and waveforms instpection. Still, complatible both with gtx-gpl and unisims/gtx
# Going to do afterwards:
Test dma functionallity of the host.  
Make cocotb testbench - gtx-gpl only - random payload high-level verification testing purposes.  
Create a base of regression tests, containing lower-level tests - both gtx-gpl and unisims/gtx.  
Improve an implementation of DMA control module.  
Finally decide what to do with a driver and modify application level (actally, write it from scrap) correspodning to driver's interfaces.  
