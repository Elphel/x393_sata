from __future__ import print_function
from __future__ import division

'''
# Copyright (C) 2015, Elphel.inc.
# Parsing Verilog parameters from the header files
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

@author:     Andrey Filippov
@copyright:  2015 Elphel, Inc.
@license:    GPLv3.0+
@contact:    andrey@elphel.coml
@deffield    updated: Updated
'''
__author__ = "Andrey Filippov"
__copyright__ = "Copyright 2015, Elphel, Inc."
__license__ = "GPL"
__version__ = "3.0+"
__maintainer__ = "Andrey Filippov"
__email__ = "andrey@elphel.com"
__status__ = "Development"

import os
from x393_mem import X393Mem
from x393_vsc3304 import x393_vsc3304
import create_ahci_registers as registers
from time import sleep
import shutil

PAGE_SIZE =           4096
#:/sys/devices/soc0/amba@0/e0004000.ps7-i2c/i2c-0
#Old System
SI5338_PATH_OLD =   '/sys/devices/amba.0/e0004000.ps7-i2c/i2c-0/0-0070'
MEM_PATH_OLD =      '/sys/devices/elphel393-mem.2/'
#new System
SI5338_PATH_NEW =   '/sys/devices/soc0/amba@0/e0004000.ps7-i2c/i2c-0/0-0070'
MEM_PATH_NEW =      '/sys/devices/soc0/elphel393-mem@0/'

DEFAULT_BITFILE="/usr/local/verilog/x393_sata.bit"
BUFFER_ADDRESS_NAME = 'buffer_address'
BUFFER_PAGES_NAME =   'buffer_pages'
BUFFER_FLUSH_NAME =   'buffer_flush'
FPGA_RST_CTRL= 0xf8000240
FPGA0_THR_CTRL=0xf8000178
FPGA_LOAD_BITSTREAM="/dev/xdevcfg"
INT_STS=       0xf800700c
MAXI1_ADDR = 0x80000000
DATASCOPE_ADDR = 0x1000 + MAXI1_ADDR
COMMAND_HEADER0_OFFS =    0x800 # offset of the command header 0 in MAXI1 space 
COMMAND_BUFFER_OFFSET =     0x0 # Just at the beginning of available memory
COMMAND_BUFFER_SIZE =     0x100 # 256 bytes - 128 before PRDT, 128+ - PRDTs (16 bytes each)
PRD_OFFSET =               0x80 # Start of the PRD table
FB_OFFS =                 0xc00 # Needs 0x100 bytes 
DRP_OFFS =                0xfec # Read/Write DRP data [31] - write/ready, [30:16] - address/0, [15:0] - data to/data from
DATAIN_BUFFER_OFFSET =  0x10000
DATAIN_BUFFER_SIZE =    0x10000
IDENTIFY_BUF =                0 # Identify receive buffer offset in  DATAIN_BUFFER, in bytes


DATAOUT_BUFFER_OFFSET = 0x20000
DATAOUT_BUFFER_SIZE =   0x10000
SI5338_PATH = None
MEM_PATH = None

BUFFER_ADDRESS =      None # in bytes
BUFFER_LEN =          None # in bytes
COMMAND_ADDRESS =     None # start of the command buffer (to be sent to device)
DATAIN_ADDRESS  =     None # start of the the 
DATAOUT_ADDRESS  =    None # start of the the 

#DRP addresses (non-GTX)
DRP_MASK_ADDR =      0x200 # ..0x207
DRP_TIMER_ADDR =     0x208 # write timer value (how long to count early/late)
DRP_EARLY_ADDR =     0x209 # write timer value (how long to count early/late)
DRP_LATE_ADDR =      0x20a # write timer value (how long to count early/late)
DRP_OTHERCTRL_ADDR = 0x20b # Now bit 0 - disable wait for phase align


#FIS types
FIS_H2DR = 0x27
FIS_D2HR = 0x34
FIS_DMAA = 0x39
FIS_DMAS = 0x41
FIS_DATA = 0x46
FIS_BIST = 0x58
FIS_PIOS = 0x5f
FIS_SDB =  0xa1
#ATA commands
ATA_IDFY =     0xec # Identify command
ATA_WDMA =     0xca # Write to device in DMA mode
ATA_WBUF_PIO = 0xe8 # Write 512 bytes to device buffer in PIO mode
ATA_WBUF_DMA = 0xeb # Write 512 bytes to device buffer in DMA mode
ATA_RDMA =     0xc8 # Read from device in DMA mode
ATA_RBUF_PIO = 0xe4 # Read  512 bytes from device buffer in PIO mode
ATA_RBUF_DMA = 0xe9 # Read  512 bytes from device buffer in DMA mode

class x393sata(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
    x393_mem=None
    vsc3304 = None
    register_defines=None
    def __init__(self, debug_mode=1,dry_mode=False, pcb_rev = "10389"):
        global BUFFER_ADDRESS, BUFFER_LEN, COMMAND_ADDRESS, DATAIN_ADDRESS, DATAOUT_ADDRESS, SI5338_PATH, MEM_PATH
        
        self.DEBUG_MODE=debug_mode
        if not dry_mode:
            if not os.path.exists("/dev/xdevcfg"):
                dry_mode=True
                print("Program is forced to run in SIMULATED mode as '/dev/xdevcfg' does not exist (not a camera)")
        self.DRY_MODE=dry_mode
        self.x393_mem=X393Mem(debug_mode,dry_mode, 1)
        self.vsc3304= x393_vsc3304(debug_mode, dry_mode, pcb_rev)
        self.register_defines = registers.process_data(False)['field_defines']
        if dry_mode:
            BUFFER_ADDRESS=0x27900000 # 0x38100000 on new
            BUFFER_LEN=    0x6400000
            print ("Running in simulated mode, using hard-coded addresses:")
        else:
            if os.path.exists(SI5338_PATH_OLD):
                print ('x393sata: Running on OLD system')
                SI5338_PATH = SI5338_PATH_OLD
                MEM_PATH =    MEM_PATH_OLD
            elif os.path.exists(SI5338_PATH_NEW):    
                print ('x393sata: Running on NEW system')
                SI5338_PATH = SI5338_PATH_NEW
                MEM_PATH =    MEM_PATH_NEW
            else:
                print ("Does not seem to be a known system - both %s (old) and %s (new) are not found"%(SI5338_PATH_OLD, SI5338_PATH_NEW))
                return
            try:
                with open(MEM_PATH+BUFFER_ADDRESS_NAME) as sysfile:
                    BUFFER_ADDRESS=int(sysfile.read(),0)
                with open(MEM_PATH+BUFFER_PAGES_NAME) as sysfile:
                    BUFFER_LEN=PAGE_SIZE*int(sysfile.read(),0)
            except:
                print("Failed to get reserved physical memory range")
                print('BUFFER_ADDRESS=',BUFFER_ADDRESS)    
                print('BUFFER_LEN=',BUFFER_LEN)    
                return
        COMMAND_ADDRESS = BUFFER_ADDRESS + COMMAND_BUFFER_OFFSET
        DATAIN_ADDRESS =  BUFFER_ADDRESS + DATAIN_BUFFER_OFFSET
        DATAOUT_ADDRESS = BUFFER_ADDRESS + DATAOUT_BUFFER_OFFSET
        print('BUFFER_ADDRESS=0x%x'%(BUFFER_ADDRESS))    
        print('BUFFER_LEN=0x%x'%(BUFFER_LEN))
        print('COMMAND_ADDRESS=0x%x'%(COMMAND_ADDRESS))
        print('DATAIN_ADDRESS=0x%x'%(DATAIN_ADDRESS))
        print('DATAOUT_ADDRESS=0x%x'%(DATAOUT_ADDRESS))
    def reset_get(self):
        """
        Get current reset state
        """
        return self.x393_mem.read_mem(FPGA_RST_CTRL)
    def reset_once(self):
        """
        Pulse reset ON, then OFF
        """
        self.reset((0,0xa))
    def reset(self,data):
        """
        Write data to FPGA_RST_CTRL register
        <data> currently data=1 - reset on, data=0 - reset on
               data can also be a list/tuple of integers, then it will be applied
               in sequence (0,0xe) will turn reset on, then off
        """
        if isinstance(data, (int,long)):
            self.x393_mem.write_mem(FPGA_RST_CTRL,data)
        else:
            for d in data:
                self.x393_mem.write_mem(FPGA_RST_CTRL,d)
                
    def flush_mem(self):                
        """
        Flush memory buffer
        """
        with open (MEM_PATH+BUFFER_FLUSH_NAME,"w") as f:
            print ("1",file=f)
        
                
    def bitstream(self,
                  bitfile=None,
                  quiet=1):
        """
        Turn FPGA clock OFF, reset ON, load bitfile, turn clock ON and reset OFF
        @param bitfile path to bitfile if provided, otherwise default bitfile will be used
        @param quiet Reduce output
        """
        if bitfile is None:
            bitfile=DEFAULT_BITFILE
        """            
        print ("Sensor ports power off")
        POWER393_PATH = '/sys/devices/elphel393-pwr.1'
        with open (POWER393_PATH + "/channels_dis","w") as f:
            print("vcc_sens01 vp33sens01 vcc_sens23 vp33sens23", file = f)
        """
        #Spread Spectrum off on channel 3
        print ("Spread Spectrum off on channel 3")
        with open (SI5338_PATH+"/spread_spectrum/ss3_values","w") as f:
            print ("0",file=f)
            
        print ("FPGA clock OFF")
        self.x393_mem.write_mem(FPGA0_THR_CTRL,1)
        print ("Reset ON")
        self.reset(0)
        print ("cat %s >%s"%(bitfile,FPGA_LOAD_BITSTREAM))
        if not self.DRY_MODE:
            l=0
            with open(bitfile, 'rb') as src, open(FPGA_LOAD_BITSTREAM, 'wb') as dst:
                buffer_size=1024*1024
                while True:
                    copy_buffer=src.read(buffer_size)
                    if not copy_buffer:
                        break
                    dst.write(copy_buffer)
                    l+=len(copy_buffer)
                    if quiet < 4 :
                        print("sent %d bytes to FPGA"%l)                            

            print("Loaded %d bytes to FPGA"%l)                            
#            call(("cat",bitfile,">"+FPGA_LOAD_BITSTREAM))
        if quiet < 4 :
            print("Wait for DONE")
        if not self.DRY_MODE:
            for _ in range(100):
                if (self.x393_mem.read_mem(INT_STS) & 4) != 0:
                    break
                sleep(0.1)
            else:
                print("Timeout waiting for DONE, [0x%x]=0x%x"%(INT_STS,self.x393_mem.read_mem(INT_STS)))
                return
        if quiet < 4 :
            print ("FPGA clock ON")
        self.x393_mem.write_mem(FPGA0_THR_CTRL,0)
        if quiet < 4 :
            print ("Reset OFF")
        self.reset(0xa)
#        self.x393_axi_tasks.init_state()
        self.set_zynq()
#        self.set_debug()
        print("Use 'set_zynq()', 'set_esata()' or 'set_debug() to switch SSD connection")
        
    def set_zynq(self):    
        self.vsc3304.connect_zynq_ssd()
        self.vsc3304.connection_status()

    def set_esata(self):    
        self.vsc3304.connect_esata_ssd()
        self.vsc3304.connection_status()
        
    def set_debug(self):    
        self.vsc3304.connect_debug()
        self.vsc3304.connection_status()

    def erate(self, dly = 1.0):
        c0 = self.x393_mem.read_mem(0x80000ff0)
        sleep(dly)
        c1 = self.x393_mem.read_mem(0x80000ff0)
        c00 = c0 & 0xffff
        c01 = (c0 >> 16) & 0xffff
        c10 = c1 & 0xffff
        c11 = (c1 >> 16) & 0xffff
        
        if c10 < c00:
            c10 += 1 << 16;
        if c11 < c01:
            c11 += 1 << 16;
        return ((c10 - c00)/dly, (c11 - c01)/dly)
    def dword_to_code(self,dword):
        def byte_to_code(b):
            return (b & 0x1f, (b >> 5) & 7)
        c = []
        for i in range(4):
            c.append (byte_to_code((dword >> (8*i)) & 0xff))
        return "D%d.%d D%d.%d D%d.%d K%d.%d "%(c[3][0],c[3][1],c[2][0],c[2][1],c[1][0],c[1][1],c[0][0],c[0][1])
    def reg_status(self, skip0 =True):
        important = ['HBA_PORT__PxIS',
                     'HBA_PORT__PxCMD',
                     'HBA_PORT__PxTFD',
                     'HBA_PORT__PxSIG',
                     'HBA_PORT__PxSSTS',
                     'HBA_PORT__PxSERR',
                     'HBA_PORT__PxCI'
                     ]
        self.parse_register(group_range = important,
                            skip0 =       skip0,
                            dword =       None)
        
    def reset_ie(self):
        """
        reset all interrupt and error bits
        """
        self.x393_mem.write_mem(self.get_reg_address('HBA_PORT__PxIS'),  0xffffffff)
        self.x393_mem.write_mem(self.get_reg_address('HBA_PORT__PxSERR'),0xffffffff)
        
    def reset_device(self):
        """
        reset device by initiating COMRESET sequence
        """
        self.x393_mem.write_mem(self.get_reg_address('HBA_PORT__PxSCTL'),  0x1)
        sleep(0.1)
        self.x393_mem.write_mem(self.get_reg_address('HBA_PORT__PxSCTL'),  0x0)
    
    def get_reg_address(self,group_range):
        """
        Get absoulte byte address for symbolic group/range name
        @param group_range - group name +'__'+ range name, i.e. 'HBA_PORT__PxIS'
        @return memory address or None
        """
        try:
            return 4 * self.register_defines[group_range][0]['dword_address'] + MAXI1_ADDR
        except:
            print ("failed to find address for %s"%(group_range))
            self.parse_register()
            return None
            
    def parse_register(self, group_range=None, skip0 =True, dword=None):
        """
        Read register and print field values
        @param group_name: group name +'__'+ range name, i.e. 'HBA_PORT__PxIS'
        @param skip0 - skip fields that are 0
        @param dword - provide register value instead of reading the hardware  
        """
        
        if isinstance(group_range,(tuple,list)):
            for gr in group_range:
                if (gr in self.register_defines) and len(self.register_defines[gr]):
                    self.parse_register(group_range = gr,
                                        skip0 =       skip0,
                                        dword =       dword)
            return        
        cached_addr=None
        cached_data=None
        
        try:
            range_defines = self.register_defines[group_range]
            _ = range_defines[0] # to treat empty as non-existing
        except:
            if group_range:
                print ("Group/range %s is undefined"%(group_range))
            print ("Valid group/range combinations:")
            descr={}    
            for k in  self.register_defines:
                try:
                    descr[k] = "%s / %s"%(self.register_defines[k][0]['group_decription'],self.register_defines[k][0]['range_decription'])
                except:
                    pass
            for k in sorted(descr.keys()):
                    print("%s: %s"%(k,descr[k]))
#            for k in  self.register_defines:
#                try:
#                    print("%s: %s / %s"%(k,self.register_defines[k][0]['group_decription'],self.register_defines[k][0]['range_decription']))
#               except:
#                    pass    
            return
        first_line = True
        for fld in range_defines:
            byte_addr = 4 * fld['dword_address'] + MAXI1_ADDR
            if dword is None:
                if byte_addr != cached_addr:
                    cached_addr = byte_addr
                    cached_data = self.x393_mem.read_mem(cached_addr)   
                data = cached_data
            else:
                data = dword
            fld_value = (data >> fld['start_bit']) & ((1 << fld['num_bits']) - 1)    
            if first_line:
                print("%s: 0x%08x [%08x]"%(group_range, data, byte_addr))
                first_line = False
            if fld_value or not skip0:
                print("%8x : %s (%s)"%(fld_value, fld['name'], fld['description'] ))
    
    #hex(mem.read_mem(0x80000ff0))
    def exp_gpio (self,
                  mode="in",
                  gpio_low=54,
                  gpio_high=None):
        """
        Export GPIO pins connected to PL (full range is 54..117)
        <mode>     GPIO mode: "in" or "out"
        <gpio_low> lowest GPIO to export     
        <gpio_hi>  Highest GPIO to export. Set to <gpio_low> if not provided     
        """
        if gpio_high is None:
            gpio_high=gpio_low
        print ("Exporting as \""+mode+"\":", end=""),    
        for gpio_n in range (gpio_low, gpio_high + 1):
            print (" %d"%gpio_n, end="")
        print() 
        if not self.DRY_MODE:
            for gpio in range (gpio_low, gpio_high + 1):
                try:
                    with open ("/sys/class/gpio/export","w") as f:
                        print (gpio,file=f)
                except:
                    print ("failed \"echo %d > /sys/class/gpio/export"%gpio)
                try:
                    with open ("/sys/class/gpio/gpio%d/direction"%gpio,"w") as f:
                        print (mode,file=f)
                except:
                    print ("failed \"echo %s > /sys/class/gpio/gpio%d/direction"%(mode,gpio))

    def mon_gpio (self,
                  gpio_low=54,
                  gpio_high=None):
        """
        Get state of the GPIO pins connected to PL (full range is 54..117)
        <gpio_low> lowest GPIO to export     
        <gpio_hi>  Highest GPIO to export. Set to <gpio_low> if not provided
        Returns data as list of 0,1 or None    
        """
        if gpio_high is None:
            gpio_high=gpio_low
        print ("gpio %d.%d: "%(gpio_high,gpio_low), end="")
        d=[]
        for gpio in range (gpio_high, gpio_low-1,-1):
            if gpio != gpio_high and ((gpio-gpio_low+1) % 4) == 0:
                print (".",end="")
            if not self.DRY_MODE:
                try:
                    with open ("/sys/class/gpio/gpio%d/value"%gpio,"r") as f:
                        b=int(f.read(1))
                        print ("%d"%b,end="")
                        d.append(b)
                except:
                    print ("X",end="")
                    d.append(None)
            else:
                print ("X",end="")
                d.append(None)
        print()
        return d
    

    def copy (self,
              src,
              dst):
        """
        Copy files in the file system
        @param src - source path
        @param dst - destination path/directory
        """
        shutil.copy2(src, dst)    
    
    def setup_pio_read_identify_command(self, do_not_start = False, prd_irqs = None):
        """
        @param do_not_start - do not actually launch the command by writing 1 to command_issue (CI) bit in PxCI register
        @param prd_irqs - None or a tuple/list with per-PRD interrupts
        """
        # clear system memory for the command
        for a in range(64):
            self.x393_mem.write_mem(COMMAND_ADDRESS + 4*a, 0)
        #Setup command table in system memory
        self.x393_mem.write_mem(COMMAND_ADDRESS + 0,
                                FIS_H2DR |         # FIS type - H2D register (0x27)
                               (0x80 << 8) |       # set C = 1
                               (ATA_IDFY << 16) |  # Command = 0xEC (IDFY)
                               ( 0 << 24))         # features = 0 ?
         # All other 4 DWORDs are 0 for this command
         # Set PRDT (single item) TODO: later check multiple small ones
        self.x393_mem.write_mem(COMMAND_ADDRESS + PRD_OFFSET + (0 << 2), DATAIN_ADDRESS + IDENTIFY_BUF)
        prdt_int = 0
        if prd_irqs:
            prdt_int = (0,1)[prd_irqs[0]] 
        self.x393_mem.write_mem(COMMAND_ADDRESS + PRD_OFFSET + (3 << 2), (prdt_int << 31) | 511) # 512 bytes in this PRDT)
        # Setup command header 
        self.x393_mem.write_mem(MAXI1_ADDR + COMMAND_HEADER0_OFFS + (0 << 2),
                                                     (5 <<  0) | # 'CFL' - number of DWORDs in this CFIS
                                                     (0 <<  5) | # 'A' Not ATAPI
                                                     (0 <<  6) | # 'W' Not write to device
                                                     (1 <<  7) | # 'P' Prefetchable = 1
                                                     (0 <<  8) | # 'R' Not a Reset
                                                     (0 <<  9) | # 'B' Not a BIST
                                                     (1 << 10) | # 'C' Do clear BSY/CI after transmitting this command
                                                     (1 << 16))  # 'PRDTL' - number of PRDT entries (just one)
        self.x393_mem.write_mem(MAXI1_ADDR + COMMAND_HEADER0_OFFS + (2 << 2),
                                                     (COMMAND_ADDRESS) & 0xffffffc0) # 'CTBA' - Command table base address
        # Write some junk to the higher addresses of the CFIS
        #Only was needed for debugging, removing
        """ 
        for i in range (10):
            self.x393_mem.write_mem(COMMAND_ADDRESS + 4*(i+1),
                                      (4 * i + 1) | 
                                     ((4 * i + 2) <<  8) | 
                                     ((4 * i + 3) << 16) | 
                                     ((4 * i + 4) << 24))

        """
        # Make it flush (dumb way - write each cache line (32 bytes) something?
        for i in range (4096):
            self.x393_mem.write_mem(COMMAND_ADDRESS + 32 * i, self.x393_mem.read_mem(COMMAND_ADDRESS + 32 * i))
            
#        print("Running flush_mem()")    
#        self.flush_mem() # Did not worked, caused error
#mem.write_mem(0x80000118,0x11)
        # Set PxCMD.ST bit (it may already be set)
        self.x393_mem.write_mem(self.get_reg_address('HBA_PORT__PxCMD'), 0x11) # .ST and .FRE bits (FRE is readonly 1 anyway)
        # Set Command Issued
        if do_not_start:
            print ('Run the following command to start the comand:')
            print("mem.write_mem(sata.get_reg_address('HBA_PORT__PxCI'), 1)")
        else:
            self.x393_mem.write_mem(self.get_reg_address('HBA_PORT__PxCI'), 1)
        print("Command table data:")    
        print("_=mem.mem_dump (0x%x, 0x10,4)"%(COMMAND_ADDRESS))
        self.x393_mem.mem_dump (COMMAND_ADDRESS, 0x20,4)        
        print("Datascope (debug) data:")    
        print("_=mem.mem_dump (0x%x, 0x20,4)"%(DATASCOPE_ADDR))
        self.x393_mem.mem_dump (DATASCOPE_ADDR, 0x20,4)
        print("Memory read data:")    
        print("_=mem.mem_dump (0x%x, 0x100, 2)"%(DATAIN_ADDRESS + IDENTIFY_BUF))
        self.x393_mem.mem_dump (DATAIN_ADDRESS + IDENTIFY_BUF, 0x100,2)        
        
    def dd_read_dma(self, skip, count = 1, do_not_start = False, prd_irqs = None): #TODO: Add multi-PRD testing
        """
        Read device to memory, use single PRD table
        @param skip - start block number
        @param count - number of blocks to read
        @param do_not_start - do not actually launch the command by writing 1 to command_issue (CI) bit in PxCI register
        @param prd_irqs - None or a tuple/list with per-PRD interrupts
        """
        if skip > (1 << 24):
            raise ValueError ("This program supports only 24-bit LBA") 
        if count > 256:
            raise ValueError ("This program supports only 8 bit count") 
        # clear system memory for the command
        for a in range(64):
            self.x393_mem.write_mem(COMMAND_ADDRESS + 4*a, 0)
        #Setup command table in system memory
        self.x393_mem.write_mem(COMMAND_ADDRESS +  0,
                                FIS_H2DR |         # FIS type - H2D register (0x27)
                               (0x80 << 8) |       # set C = 1
                               (ATA_RDMA << 16) |  # Command = 0xEC (IDFY)
                               ( 0 << 24))         # features = 0 ?
        self.x393_mem.write_mem(COMMAND_ADDRESS +  4, skip) # LBA 24 bits
        self.x393_mem.write_mem(COMMAND_ADDRESS + 12, count & 0xff) # count field (0 means 256 blocks)
        # Other DWORDs are reserved/0 for this command
        # Set PRDT (single item) TODO: later check multiple small ones
        self.x393_mem.write_mem(COMMAND_ADDRESS + PRD_OFFSET + (0 << 2), DATAIN_ADDRESS)
        prdt_int = 0
        if prd_irqs:
            prdt_int = (0,1)[prd_irqs[0]] 
        self.x393_mem.write_mem(COMMAND_ADDRESS + PRD_OFFSET + (3 << 2), (prdt_int << 31) | ((count * 512) -1)) # count * 512 bytes in this PRDT)
        # Setup command header 
        self.x393_mem.write_mem(MAXI1_ADDR + COMMAND_HEADER0_OFFS + (0 << 2),
                                                     (5 <<  0) | # 'CFL' - number of DWORDs in this CFIS
                                                     (0 <<  5) | # 'A' Not ATAPI
                                                     (0 <<  6) | # 'W' Not write to device
                                                     (1 <<  7) | # 'P' Prefetchable = 1
                                                     (0 <<  8) | # 'R' Not a Reset
                                                     (0 <<  9) | # 'B' Not a BIST
                                                     (1 << 10) | # 'C' Do clear BSY/CI after transmitting this command
                                                     (1 << 16))  # 'PRDTL' - number of PRDT entries (just one)
        self.x393_mem.write_mem(MAXI1_ADDR + COMMAND_HEADER0_OFFS + (2 << 2),
                                                     (COMMAND_ADDRESS) & 0xffffffc0) # 'CTBA' - Command table base address

        # Make it flush (dumb way - write each cache line (32 bytes) something?
        for i in range (4096):
            self.x393_mem.write_mem(COMMAND_ADDRESS + 32 * i, self.x393_mem.read_mem(COMMAND_ADDRESS + 32 * i))
            
#        print("Running flush_mem()")    
#        self.flush_mem() # Did not worked, caused error
#mem.write_mem(0x80000118,0x11)
        # Set PxCMD.ST bit (it may already be set)
        self.x393_mem.write_mem(self.get_reg_address('HBA_PORT__PxCMD'), 0x11) # .ST and .FRE bits (FRE is readonly 1 anyway)
        # Set Command Issued
        if do_not_start:
            print ('Run the following command to start the comand:')
            print("mem.write_mem(sata.get_reg_address('HBA_PORT__PxCI'), 1)")
        else:
            self.x393_mem.write_mem(self.get_reg_address('HBA_PORT__PxCI'), 1)
        print("Command table data:")    
        print("_=mem.mem_dump (0x%x, 0x10,4)"%(COMMAND_ADDRESS))
        self.x393_mem.mem_dump (COMMAND_ADDRESS, 0x20,4)        
        print("Datascope (debug) data:")    
        print("_=mem.mem_dump (0x%x, 0x20,4)"%(DATASCOPE_ADDR))
        self.x393_mem.mem_dump (DATASCOPE_ADDR, 0x20,4)
        print("Memory read data:")    
        print("_=mem.mem_dump (0x%x, 0x%x, 1)"%(DATAIN_ADDRESS, count * 0x200))
        self.x393_mem.mem_dump (DATAIN_ADDRESS, count * 0x200, 1)        

    def dd_write_dma(self, skip, count = 1, use_read_buffer = False, do_not_start = False, prd_irqs = None): #TODO: Add multi-PRD testing
        """
        Write device from memory, use single PRD table
        @param skip - start block number
        @param count - number of blocks to read
        @param use_read_buffer - write from the same memory as was used to receive data from device (False - use different memory range)
        @param do_not_start - do not actually launch the command by writing 1 to command_issue (CI) bit in PxCI register
        @param prd_irqs - None or a tuple/list with per-PRD interrupts
        """
        if skip > (1 << 24):
            raise ValueError ("This program supports only 24-bit LBA") 
        if count > 256:
            raise ValueError ("This program supports only 24-bit LBA")
        data_buf = (DATAOUT_ADDRESS, DATAIN_ADDRESS) [use_read_buffer]       
        # clear system memory for the command
        for a in range(64):
            self.x393_mem.write_mem(COMMAND_ADDRESS + 4*a, 0)
        #Setup command table in system memory
        self.x393_mem.write_mem(COMMAND_ADDRESS +  0,
                                FIS_H2DR |         # FIS type - H2D register (0x27)
                               (0x80 << 8) |       # set C = 1
                               (ATA_WDMA << 16) |  # Command = 0xEC (IDFY)
                               ( 0 << 24))         # features = 0 ?
        self.x393_mem.write_mem(COMMAND_ADDRESS +  4, skip) # LBA 24 bits
        self.x393_mem.write_mem(COMMAND_ADDRESS + 12, count & 0xff) # count field (0 means 256 blocks)
        # Other DWORDs are reserved/0 for this command
        # Set PRDT (single item) TODO: later check multiple small ones
        self.x393_mem.write_mem(COMMAND_ADDRESS + PRD_OFFSET + (0 << 2), data_buf)
        prdt_int = 0
        if prd_irqs:
            prdt_int = (0,1)[prd_irqs[0]] 
        self.x393_mem.write_mem(COMMAND_ADDRESS + PRD_OFFSET + (3 << 2), (prdt_int << 31) | ((count * 512) -1)) # count * 512 bytes in this PRDT)
        # Setup command header 
        self.x393_mem.write_mem(MAXI1_ADDR + COMMAND_HEADER0_OFFS + (0 << 2),
                                                     (5 <<  0) | # 'CFL' - number of DWORDs in this CFIS
                                                     (0 <<  5) | # 'A' Not ATAPI
                                                     (1 <<  6) | # 'W' Is write to device
                                                     (1 <<  7) | # 'P' Prefetchable = 1
                                                     (0 <<  8) | # 'R' Not a Reset
                                                     (0 <<  9) | # 'B' Not a BIST
                                                     (1 << 10) | # 'C' Do clear BSY/CI after transmitting this command
                                                     (1 << 16))  # 'PRDTL' - number of PRDT entries (just one)
        self.x393_mem.write_mem(MAXI1_ADDR + COMMAND_HEADER0_OFFS + (2 << 2),
                                                     (COMMAND_ADDRESS) & 0xffffffc0) # 'CTBA' - Command table base address

        # Make it flush (dumb way - write each cache line (32 bytes) something?
        for i in range (4096):
            self.x393_mem.write_mem(COMMAND_ADDRESS + 32 * i, self.x393_mem.read_mem(COMMAND_ADDRESS + 32 * i))
            
#        print("Running flush_mem()")    
#        self.flush_mem() # Did not worked, caused error
#mem.write_mem(0x80000118,0x11)
        # Set PxCMD.ST bit (it may already be set)
        self.x393_mem.write_mem(self.get_reg_address('HBA_PORT__PxCMD'), 0x11) # .ST and .FRE bits (FRE is readonly 1 anyway)
        # Set Command Issued
        if do_not_start:
            print ('Run the following command to start the comand:')
            print("mem.write_mem(sata.get_reg_address('HBA_PORT__PxCI'), 1)")
        else:
            self.x393_mem.write_mem(self.get_reg_address('HBA_PORT__PxCI'), 1)
        print("Command table data:")    
        print("_=mem.mem_dump (0x%x, 0x10,4)"%(COMMAND_ADDRESS))
        self.x393_mem.mem_dump (COMMAND_ADDRESS, 0x20,4)        
        print("Datascope (debug) data:")    
        print("_=mem.mem_dump (0x%x, 0x20,4)"%(DATASCOPE_ADDR))
        self.x393_mem.mem_dump (DATASCOPE_ADDR, 0x20,4)
        #print("Memory read data:")    
        #print("_=mem.mem_dump (0x%x, 0x%x, 1)"%(data_buf, count * 0x200))
        #self.x393_mem.mem_dump (data_buf, count * 0x200, 1)        

    def drp_write (self, addr, data):
        self.x393_mem.write_mem(MAXI1_ADDR + DRP_OFFS, (1 << 31) | ((addr & 0x7fff) << 16) | (data & 0xffff))
        #         while (self.x393_mem.read_mem(MAXI1_ADDR + DRP_OFFS)) & (1 << 31): # No need to wait from Python
        #                sleep(0.001)

    def drp_read (self, addr):
        self.x393_mem.write_mem(MAXI1_ADDR + DRP_OFFS, (0 << 31) | ((addr & 0x7fff) << 16))
        d = self.x393_mem.read_mem(MAXI1_ADDR + DRP_OFFS)
        while not d & (1 << 31) :
            d = self.x393_mem.read_mem(MAXI1_ADDR + DRP_OFFS)
        return int(d & 0xffff)
    def drp (self, addr, data=None):
        if data is None:
            return self.drp_read(addr)
        self.drp_write (addr, data)
    
    def read_sipo_meas(self, mask, duration):
        self.drp_write (DRP_MASK_ADDR,             mask & 0xffff)
        self.drp_write (DRP_MASK_ADDR + 1, (mask >> 16) & 0xffff)
        self.drp_write (DRP_TIMER_ADDR,            duration)
        early_count = self.drp_read(DRP_EARLY_ADDR)
        while (early_count & (1 << 15)):
            early_count = self.drp_read(DRP_EARLY_ADDR)
        late_count = self.drp_read(DRP_LATE_ADDR)
        print ("early_count = 0x%x, late_count = 0x%x, duration = 0x%x"%(early_count, late_count, duration))
        return (1.0 * early_count/duration, 1.0 * late_count/duration)
    
    def drp_cbit (self, bit, value=None):
        old_val = self.drp_read (DRP_OTHERCTRL_ADDR)
        if value is None:
            return (old_val >> bit ) & 1;
        mask = (1 << bit)
        if value:
            new_val = mask
        else:
            new_val = 0
        self.drp_write (DRP_OTHERCTRL_ADDR, ((old_val ^ new_val) & mask) ^ old_val)
        
    """
ATA_IDFY =     0xec # Identify command
ATA_WDMA =     0xca # Write to device in DMA mode
ATA_WBUF_PIO = 0xe8 # Write 512 bytes to device buffer in PIO mode
ATA_WBUF_DMA = 0xeb # Write 512 bytes to device buffer in DMA mode
ATA_RDMA =     0xc8 # Read from device in DMA mode
ATA_RBUF_PIO = 0xe4 # Read  512 bytes from device buffer in PIO mode
ATA_RBUF_DMA = 0xe9 # Read  512 bytes from device buffer in DMA mode

_=mem.mem_dump(0xf800b000,10,4)

_=mem.mem_dump (0x80000ff0, 4,4)
sata.read_sipo_meas(0xfffff,0x7ffe)
    
    
mem.write_mem(0x80000118,0x11) # ST & FRE

Implement DRP read/write:
mem.write_mem(0x80000fec, 0x550000)
hex(mem.read_mem(0x80000fec))
'0x8000001fL'

sata.drp_write(0x20b,1) #disable wait for auto align
sata.reset_device()
_=mem.mem_dump (0x80000ff0, 4,4)
sata.reg_status(
sata.reset_ie(), sata.reg_status()
sata.read_sipo_meas(0xfffff,0x7ffe)

    drp_write ('h20b, 'h401); // bypass, clock align
sata.reg_status(),sata.reset_ie()
sata.read_sipo_meas(0xfffff,0x7ffe)
_=mem.mem_dump (0x80000ff0, 4,4)

hex(sata.drp_read(0x55))
    
cd /mnt/mmc/local/bin
python    
from __future__ import print_function
from __future__ import division
import x393sata
import x393_mem
mem = x393_mem.X393Mem(1,0,1)
sata = x393sata.x393sata()

sata.bitstream()
#sata.drp_write (0x20b,0x401) # bypass, clock align
sata.drp (0x20b,0x81) # bypass, clock align
#sata.drp (0x20b,0x400) # bypass, clock align
sata.drp (0x59,0x8) # Use RXREC
#sata.drp (0x59,0x48) 
sata.reg_status()
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status(),sata.reset_ie()

sata.dd_read_dma(0x5ff, 1)
_=mem.mem_dump (0x80000ff0, 4,4)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status(),sata.reset_ie()


for block in range (1,255):
    sata.dd_read_dma(block, 1)
    _=mem.mem_dump (0x80000ff0, 4,4)
    _=mem.mem_dump (0x80001000, 0x100,4)
    sata.reg_status(),sata.reset_ie()



mem.write_mem(0x80000118,0x10)

06b: 00104 #                CFIS:Xmit: do SET_BSY
06c: 30060 #                           do CFIS_XMIT, WAIT DONE
06d: 19039 #                           if X_RDY_COLLISION       goto P:Idle
06e: 150f8 #                           if SYNCESC_ERR           goto ERR:SyncEscapeRecv
06f: 0a471 #                           if FIS_OK                goto CFIS:Success
070: 00102 #                           always                   goto ERR:Non-Fatal








sata.setup_pio_read_identify_command()
_=mem.mem_dump (0x80000ff0, 4,4)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status(),sata.reset_ie()

sata.reset_ie(), sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4) 
sata.dd_read_dma(0x867,1)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)
_=mem.mem_dump (0x80001000, 0x100,4)

mem.write_mem(sata.get_reg_address('HBA_PORT__PxCI'), 1)
_=mem.mem_dump (0x80001000, 0x20,4)
_=mem.mem_dump (0x38110000, 0x100,4)


sata.reset_ie()
sata.dd_read_dma(0x867, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reset_ie()
sata.dd_read_dma(0x865, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reset_ie()
sata.dd_read_dma(0x860, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)


sata.reset_ie()
sata.dd_read_dma(0x01, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)


sata.reset_ie()
sata.dd_read_dma(0x100, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)


sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x81, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)


sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x321, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x331, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x341, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x441, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x421, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x481, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x4c1, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x4f1, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x4ff, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x500, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x400, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x401, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x601, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x600, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x5ff, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x601, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x600, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)

sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x602, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)


sata.reg_status()
sata.reset_ie()
sata.dd_read_dma(0x5f0, 1)
_=mem.mem_dump (0x80001000, 0x100,4)
sata.reg_status()
_=mem.mem_dump (0x80000ff0, 4,4)




mem.write_mem(0x80000118,0x10)


sata.vsc3304.connection_status()

sata.reg_status() 

mem.write_mem(0x8000012c,1)
hex(mem.read_mem(0x8000012c))
mem.write_mem(0x8000012c,0)   
hex(mem.read_mem(0x8000012c))
hex(mem.read_mem(0x80000130))
hex(mem.read_mem(0x80000ff0))

sata.reset_ie(), sata.reg_status()
hex(mem.read_mem(0x80000ff0))


mem.write_mem(0x80000118,0x11)
sata.setup_pio_read_identify_command()
#mem.write_mem(sata.get_reg_address('HBA_PORT__PxCI'), 1)
_=mem.mem_dump (0x80001000, 0x20,4)

mem.maxi_base()
hex(mem.read_mem(0x80000180))
_=mem.mem_dump (0x80000000, 0x200,1)
_=mem.mem_dump (0x80000000, 0x400,4)


sata.reset_ie(),sata.reset_device(), sata.reg_status(), hex(mem.read_mem(0x80000ff0)) 
sata.reset_ie(), sata.reg_status(), hex(mem.read_mem(0x80000ff0)) 
 
_=mem.mem_dump (0x80001000, 0x10,4)
 
_=mem.mem_dump (0x80001000, 0x20,4)
_=mem.mem_dump (0x27900000, 0x20,4) 



for i in range (1024):
    mem.write_mem(0x27900000 + 32*i, mem.read_mem(0x27900000 + 32*i))

0x6b 16d53
06b: 00104 #                CFIS:Xmit: do SET_BSY
06c: 30060 #                           do CFIS_XMIT, WAIT DONE ***** Got stuck here?
06d: 19039 #                           if X_RDY_COLLISION       goto P:Idle
06e: 150f8 #                           if SYNCESC_ERR           goto ERR:SyncEscapeRecv
06f: 0a471 #                           if FIS_OK                goto CFIS:Success
070: 00102 #                           always                   goto ERR:Non-Fatal


sata.reset_ie(),sata.reset_device(), sata.reg_status(), hex(mem.read_mem(0x80000ff0))
sata.reset_ie(), sata.reg_status(), hex(mem.read_mem(0x80000ff0))
mem.write_mem(0x80000118,0x11)
sata.reg_status()
mem.write_mem(sata.get_reg_address('HBA_PORT__PxCI'), 1)
_=mem.mem_dump (0x80001000, 0x20,4)

mem.write_mem(0x80000118,0x10)


idfy:
Command table data:
_=mem.mem_dump (0x38100000, 0x10,4)

0x38100000:00ec8027 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x38100040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
Datascope (debug) data:
_=mem.mem_dump (0x80001000, 0x20,4)

0x80001000:5e2e8027 1c1f0000 18000000 10010000 80020000 00000005 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80001040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 

DMA read:

0x38100000:00c88027 00000867 00000000 00000001 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x38100040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
Datascope (debug) data:
_=mem.mem_dump (0x80001000, 0x20,4)

0x80001000:5e2f0000 1c100000 18010000 10020000 80030000 00000005 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80001040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 




>>> sata.setup_pio_read_identify_command()

>>> sata.reg_status()
HBA_PORT__PxIS: 0x00400042 [80000110]
       1 : PRCS (PhyRdy changed Status)
       1 : PCS (Port Connect Change Status)
       1 : PSS (PIO Setup FIS Interrupt - PIO Setup FIS received with 'I' bit set)
HBA_PORT__PxCMD: 0x00048017 [80000118]
       1 : HPCP (Hot Plug Capable Port)
       1 : CR (Command List Running (section 5.3.2))
       1 : FRE (FIS Receive Enable (enable after FIS memory is set))
       1 : POD (Power On Device (RW with Cold Presence Detection))
       1 : SUD (Spin-Up Device (RW with Staggered Spin-Up Support))
       1 : ST (Start (HBA may process commands). See section 10.3.1)
HBA_PORT__PxTFD: 0x00000050 [80000120]
       5 : STS.64 (Latest Copy of Task File Status Register: command-specific bits 4..6 )
HBA_PORT__PxSIG: 0x00000101 [80000124]
     101 : SIG (Data in the first D2H Register FIS)
HBA_PORT__PxSSTS: 0x00000123 [80000128]
       1 : IPM (Interface Power Management)
       2 : SPD (Interface Speed)
       3 : DET (Device Detection (should be detected if COMINIT is received))
HBA_PORT__PxSERR: 0x040d0000 [80000130]
       1 : DIAG.X (Exchanged (set on COMINIT), reflected in PxIS.PCS)
       1 : DIAG.B (10B to 8B decode error)
       1 : DIAG.W (COMMWAKE signal was detected)
       1 : DIAG.N (PhyRdy changed. Reflected in PxIS.PRCS bit.)
HBA_PORT__PxCI: 0x00000000 [80000138]
>>> hex(mem.read_mem(0x80000ff0))
'0x3916f53'
>>> _=mem.mem_dump (0x38110000, 0x100,4)

0x38110000:3fff0040 0010c837 00000000 0000003f 00000000 33393133 34303535 33353030 20202020 20202020 00000000 58320000 32303331 53613020 69736e44 53446b20 
0x38110040:46313653 32384d31 20204720 20202020 20202020 20202020 20202020 80012020 2f004000 02004000 00070000 00103fff fc10003f 010100fb 0ee7c2b0 00070000 
0x38110080:00780003 00780078 40200078 00000000 00000000 001f0000 0084870e 0040014c 002801f0 7d09346b 34694123 4123bc09 0001207f 00800006 0000fffe 00000000 
0x381100c0:00000000 00000000 0ee7c2b0 00000000 00100000 00004000 b44a5001 2d633bf2 00000000 00000000 00000000 401c0000 0000401c 00000000 00000000 00000000 
0x38110100:00000021 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x38110140:00000000 00000000 00000000 00000000 0001000b 00000000 00000000 00000000 20202020 20202020 20202020 20202020 20202020 20202020 20202020 20202020 
0x38110180:20202020 20202020 20202020 20202020 20202020 20202020 20202020 00000000 40000000 00000000 00000000 00000000 00010000 00000000 00000000 0000103f 
0x381101c0:00000000 00000000 00000000 00000000 00000000 00800001 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 4da50000 
0x38110200:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x38110240:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x38110280:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x381102c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x38110300:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x38110340:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x38110380:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x381103c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 

0x38110000:3fff0040 0010c837 00000000 0000003f 00000000 33393133 34303535 33353030 20202020 20202020 00000000 58320000 32303331 53613020 69736e44 53446b20 
0x38110040:46313653 32384d31 20204720 20202020 20202020 20202020 20202020 80012020 2f004000 02004000 00070000 00103fff fc10003f 010100fb 0ee7c2b0 00070000 
0x38110080:00780003 00780078 40200078 00000000 00000000 001f0000 0084870e 0040014c 002801f0 7d09346b 34694123 4123bc09 0001407f 00fe0006 0000fffe 00000000 
0x381100c0:00000000 00000000 0ee7c2b0 00000000 00100000 00004000 b44a5001 2d633bf2 00000000 00000000 00000000 401c0000 0000401c 00000000 00000000 00000000 
0x38110100:00000021 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x38110140:00000000 00000000 00000000 00000000 0001000b 00000000 00000000 00000000 20202020 20202020 20202020 20202020 20202020 20202020 20202020 20202020 
0x38110180:20202020 20202020 20202020 20202020 20202020 20202020 20202020 00000000 40000000 00000000 00000000 00000000 00010000 00000000 00000000 0000103f 
0x381101c0:00000000 00000000 00000000 00000000 00000000 00800001 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 afa50000 

7.12.7.91 Word 255: Integrity word
If bits 7:0 of this word contain the Checksum Validity Indicator A5h, then bits 15:8 contain the data structure
checksum. The data structure checksum is the two's complement of the sum of all bytes in words 0..254 and the
byte consisting of bits 7:0 in word 255. Each byte shall be added with unsigned arithmetic, and overflow shall be
ignored. The sum of all 512 bytes is zero if the checksum is correct.



andrey@shuttle-andrey:~/git/x393_sata/debug$ sudo dd if=/dev/sdd skip=2151 count=2 | hexdump -C
00000000  92 bd c5 05 a3 7d 07 29  05 ad 05 40 ad 24 4a 3d  |.....}.)...@.$J=|
00000010  3e c0 d5 d6 b1 6a b4 dc  ae a0 00 b6 45 a5 44 28  |>....j......E.D(|
00000020  24 f5 95 9b a8 ff f4 4f  2f 1f c7 6a 0c f5 b0 9c  |$......O/..j....|
00000030  9b fa e1 f4 b1 27 ee 5a  8f fa cc 71 30 d3 55 75  |.....'.Z...q0.Uu|
00000040  61 3a 19 b1 d7 6d 36 88  7f 64 d1 3c ac 03 b5 ed  |a:...m6..d.<....|
00000050  97 42 d5 09 87 18 f5 12  4b 76 ab a0 d7 8d 20 b7  |.B......Kv.... .|
00000060  b7 d6 ca de b5 ec c7 7b  e0 20 2e 07 36 a7 66 76  |.......{. ..6.fv|
00000070  c7 dd 88 c4 ee 20 1a 48  7d 4a d3 be 7e d0 74 88  |..... .H}J..~.t.|
00000080  e1 49 4c 52 35 ba 5b 77  35 66 0a 78 5a 13 35 72  |.ILR5.[w5f.xZ.5r|
00000090  58 85 18 c8 2e e7 bb f1  e8 4f 92 aa 03 a6 6b fc  |X........O....k.|
000000a0  6f a3 21 70 aa 01 f4 8a  88 d1 a2 f7 4c 95 20 78  |o.!p........L. x|
000000b0  4f 5d d4 c0 f4 2b d9 15  ad 4b 6d e2 a5 8f b2 28  |O]...+...Km....(|
000000c0  ed 6b f7 ee 79 c9 e9 9a  a1 7c 79 8c c9 01 5f 3f  |.k..y....|y..._?|
000000d0  98 91 1f 47 3b 25 8d 3e  3c e0 c6 85 3f 23 06 ac  |...G;%.><...?#..|
000000e0  ef 28 e0 21 a4 8a 15 85  75 f9 8f 57 23 52 3d 9d  |.(.!....u..W#R=.|
000000f0  5e 32 58 e8 d7 45 11 4b  fa a7 f2 a9 0b 82 48 52  |^2X..E.K......HR|
00000100  88 d3 33 25 2e 07 23 21  a5 c6 3e a4 38 ab b6 07  |..3%..#!..>.8...|
00000110  dc 31 5f f6 0c ec 2c 04  22 d7 fc fd 8a 93 0e 8a  |.1_...,.".......|
00000120  4b b6 b7 c1 53 21 26 b8  3d 2a da 2f db 03 01 8f  |K...S!&.=*./....|
00000130  76 09 89 42 4a a8 fc f8  28 ec 22 a9 2a 0b 7c 1d  |v..BJ...(.".*.|.|
00000140  6b c9 50 02 e8 00 dd 56  0b 69 44 ed 68 8d e1 aa  |k.P....V.iD.h...|
00000150  9a e2 f7 c0 54 bc f9 99  7c 14 90 85 8b fe 63 10  |....T...|.....c.|
00000160  95 be a1 d2 39 2c 90 a5  6e f7 27 84 45 25 8e 44  |....9,..n.'.E%.D|
00000170  a9 63 ee 76 bf dd 52 32  23 82 36 43 56 a4 86 f0  |.c.v..R2#.6CV...|
00000180  cd 8c f9 b6 88 a3 fd ba  de de 4e cc d8 30 91 79  |..........N..0.y|
00000190  f6 a6 c2 7c dd 9d b4 24  ae 82 ad 36 27 b1 a8 cc  |...|...$...6'...|
000001a0  f4 47 d8 db 84 7c e3 d4  2e 89 1c bf 47 ca 8c 4c  |.G...|......G..L|
000001b0  d1 10 39 04 8b 26 94 ec  b7 dd 87 36 53 6d f8 d5  |..9..&.....6Sm..|
000001c0  5d 43 4a da a2 b9 c2 fd  d8 61 94 8b 4a 16 f3 03  |]CJ......a..J...|
000001d0  26 b6 43 36 ef ee aa dc  f6 e4 d3 3e 9c 0a b3 a8  |&.C6.......>....|
000001e0  6a 91 ef 9b 10 b4 06 03  41 38 96 59 dc c2 bb 0a  |j.......A8.Y....|
000001f0  6f 6c f0 3b ac 78 9d 01  fe 9a 95 20 bf d7 83 e0  |ol.;.x..... ....|
00000200  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
2+0 records in
2+0 records out






0x27900000:00ec8027 04030201 08070605 0c0b0a09 100f0e0d 14131211 18171615 1c1b1a19 201f1e1d 24232221 28272625 00000000 00000000 00000000 00000000 00000000 
0x27900040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 

0x80001000:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80001040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 

0x80001000:00000000 00000000 00000000 00ec8027 04030201 08070605 0c0b0a09 100f0e0d 14131211 18171615 1c1b1a19 201f1e1d 24232221 28272625 00000000 00000000 
0x80001040:00000000 00000000 00000000 00000000 00000014 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 

0x80001000:40000000 40100000 40200000 403c8027 40430201 40570605 406b0a09 407f0e0d 40831211 40971615 40ab1a19 40bf1e1d 40c32221 40d72625 00e00000 00f00000 
0x80001040:01000000 81100000 00000012 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 

0x80001000:40000000 40100000 40200000 403c8027 40430201 40570605 406b0a09 407f0e0d 40831211 40971615 40d32221 00e72625 00f00000 01000000 81100000 0000000f 
0x80001040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 




 
0x27900000:00ec8027 11111111 22222222 33333333 44444444 55555555 66666666 77777777 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x27900040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 

0x80001000:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 0000000e 00000000 
0x80001040:00000000 00000000 00000012 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 

0x80001000:00000000 00000000 00000000 00ec8027 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80001040:00000000 00000000 00000012 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 


 
0x80000000:00240020 80000000 00000000 00000001 00010301 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000080:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800000c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000100:80000800 00000000 80000c00 00000000 00000000 00000000 00240006 00000000 00000000 ffffffff 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000140:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000033 00000003 00000000 00000000 
0x80000180:0001fffe 00100000 01010001 00000000 00000000 00000000 00000000 00000000 00000000 80000000 00000000 0001fffe 00000000 00000040 00000000 00000100 
0x800001c0:40000001 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000200:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000240:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000280:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800002c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000300:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000340:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000380:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800003c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 

0x80000000:00240020 80000000 00000000 00000001 00010301 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000080:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800000c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000100:80000800 00000000 80000c00 00000000 00400040 00000000 00040006 00000000 00000080 ffffffff 00000123 00000000 040d0000 00000000 00000000 00000000 
0x80000140:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000033 00000003 00000000 00000000 
0x80000180:0001fffe 00100000 01010002 00000000 00000000 00000000 00000000 00000000 00000000 80000000 00000000 0001fffe 00000000 00000040 00000000 00000100 
0x800001c0:40000001 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000200:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000240:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000280:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800002c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000300:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000340:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000380:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800003c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 


0x80000000:00240020 80000000 00000000 00000001 00010301 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000080:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800000c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000100:80000800 00000000 80000c00 00000000 00400055 00000000 0004c006 00000000 00000080 ffffffff 00000123 00000000 060d0000 00000000 00000000 00000000 
0x80000140:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000033 00000003 00000000 00000000 
0x80000180:0001fffe 00100000 01010002 00000000 00000000 00000000 00000000 00000000 00000000 80000000 00000000 0001fffe 00000000 00000040 00000000 00000100 
0x800001c0:40000001 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000200:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000240:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000280:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800002c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000300:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000340:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000380:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800003c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 

0x80000000:00240020 80000000 00000000 00000001 00010301 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000080:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800000c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000100:80000800 00000000 80000c00 00000000 00400040 00000000 0004c006 00000000 00000080 00000000 00000123 00000000 040d0000 00000000 00000000 00000000 
0x80000140:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000033 00000003 00000000 00000000 
0x80000180:0001fffe 00100000 01010002 00000000 00000000 00000000 00000000 00000000 00000000 80000000 00000000 0001fffe 00000000 00000040 00000000 00000100 
0x800001c0:40000001 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000200:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000240:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000280:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800002c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000300:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000340:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000380:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800003c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 

0x80000000:00240020 80000000 00000000 00000001 00010301 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000080:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800000c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000100:80000800 00000000 80000c00 00000000 08400075 00000000 0004c006 00000000 00000080 ffffffff 00000123 00000000 060d0800 00000000 00000000 00000000 
0x80000140:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000033 00000003 00000000 00000000 
0x80000180:0001fffe 00100000 01010002 00000000 00000000 00000000 00000000 00000000 00000000 80000000 00000000 0001fffe 00000000 00000040 00000000 00000100 
0x800001c0:40000001 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000200:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000240:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000280:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800002c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000300:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000340:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000380:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800003c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 


0x80000000:00240020 80000000 00000000 00000001 00010301 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000080:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800000c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000100:80000800 00000000 80000c00 00000000 00400040 00000000 0004c006 00000000 00000080 00000000 00000123 00000000 040d0000 00000000 00000000 00000000 
0x80000140:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000033 00000003 00000000 00000000 
0x80000180:0001fffe 00100000 01010002 00000000 00000000 00000000 00000000 00000000 00000000 80000000 00000000 0001fffe 00000000 00000040 00000000 00000100 
0x800001c0:40000001 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000200:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000240:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000280:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800002c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000300:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000340:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000380:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800003c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 

0x80000000:00240020 80000000 00000000 00000001 00010301 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000040:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000080:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800000c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000100:80000800 00000000 80000c00 00000000 00400040 00000000 00040006 00000000 00000150 00000101 00000123 00000000 040d0000 00000000 00000000 00000000 
0x80000140:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000033 00000003 00000000 00000000 
0x80000180:0001fffe 00100000 01010002 00000000 00000000 00000000 00000000 00000000 00000000 80000000 00000000 0001fffe 00000000 00000040 00000000 00000100 
0x800001c0:40000001 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000200:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000240:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000280:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800002c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000300:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000340:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x80000380:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 
0x800003c0:00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 

mem.write_mem(0x8000012c,1)
hex(mem.read_mem(0x8000012c))
mem.write_mem(0x8000012c,0)   
hex(mem.read_mem(0x8000012c))
hex(mem.read_mem(0x80000130))
hex(mem.read_mem(0x80000ff0))

    
    """