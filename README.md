# x393_sata
SATA controller for x393 camera
Board: Zynq 7z30
FPGA: Kintex-7

# Install VDT plugin - see instructions on https://github.com/Elphel/vdt-plugin

# Clone

git clone https://github.com/Elphel/x393_sata

# Working on remote PC

1. sudo apt-get install ssh-askpass  
2. ssh-copy-id user@ip  
 
# Simulation
* Xilinx unisims license prevents it from re-distribution, so you need to get these files from 
* VDT has a tool (Vivado Tools -> Vivado utilities -> Copy Xilinx Vivado primitives library to the local project) that does this
* Refresh project (Select it and press F5 key), the files will be re-scanned   

# Synthesis
* Add constraints file through Synthesis parameters
* Bitstream Tool parameters - check *Force(overwrite)*
 
