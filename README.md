# x393_sata
SATA controller for x393 camera
Board: Zynq 7z30
FPGA: Kintex-7
# Current step:
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
