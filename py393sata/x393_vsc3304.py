from __future__ import print_function
from __future__ import division

'''
# Copyright (C) 2016, Elphel.inc.
# Control for the VSC3304 in 393 camera,
# NOTE: different connections in 10389 rev 0 and revs A/B
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
#from time import sleep
#import shutil
VSC_DIR_OLD="/sys/devices/amba.0/e0004000.ps7-i2c/i2c-0/0-0001"
VSC_DIR_NEW="/sys/devices/soc0/amba@0/e0004000.ps7-i2c/i2c-0/0-0001"
# 10389 rev "0"
VSC_DIR = None
class x393_vsc3304(object):
    DRY_MODE= True # True
    DEBUG_MODE=1
    x393_mem=None
    PCB_CONNECTIONS = {
        "10389": {
            "INVERTED_PORTS": ("D","E","G","H"),
            "ESATA_A":        "C",
            "ESATA_B":        "D",
            "SSD_A":          "E",
            "SSD_B":          "F",
            "ZYNQ_A":         "G",
            "ZYNQ_B":         "H"},
        "10389B": {
            "INVERTED_PORTS": ("A","E","G","H"),
            "ESATA_A":        "A",
            "ESATA_B":        "C",
            "SSD_A":          "E",
            "SSD_B":          "F",
            "ZYNQ_A":         "G",
            "ZYNQ_B":         "H"},
     }
    PORT_NUM = {"A":{"OUT": 8,"IN":12}, # I/O port numbers for each port name
                "B":{"OUT": 9,"IN":13},
                "C":{"OUT":10,"IN":14},
                "D":{"OUT":11,"IN":15},
                "E":{"OUT":12,"IN": 8},
                "F":{"OUT":13,"IN": 9},
                "G":{"OUT":14,"IN":10},
                "H":{"OUT":15,"IN":11}}

    VSC3304_CONNECTIONS = {
        "IDLE"       : [],
        "ESATA<->SSD": [{"FROM": "SSD_B",   "TO": "ESATA_B"},
                        {"FROM": "ESATA_A", "TO": "SSD_A"}],
                           
        "ZYNQ<->SSD":  [{"FROM": "ZYNQ_A",  "TO": "SSD_A" },
                        {"FROM": "SSD_B",   "TO": "ZYNQ_B"}],

        "ZYNQ<->ESATA":[{"FROM": "ZYNQ_A",  "TO": "ESATA_A" },
                        {"FROM": "ESATA_B", "TO": "ZYNQ_B"}],
                           
        "DEBUG_SSD":   [{"FROM": "ZYNQ_A",  "TO": "SSD_A" },
                        {"FROM": "SSD_B",   "TO": "ZYNQ_B"},
                        
                        {"FROM": "ZYNQ_A",  "TO": "ESATA_A"}, # Copy to external connector for the oscilloscope
                        {"FROM": "SSD_B",   "TO": "ESATA_B"}, # Copy to external connector for the oscilloscope
                        ],
                           }

    PCB_REV = "10389"
    current_mode = "ESATA<->SSD"
    def __init__(self, debug_mode=1,dry_mode=False, pcb_rev = "10389"):
        global VSC_DIR
        self.DEBUG_MODE=debug_mode
        if not dry_mode:
            if not os.path.exists("/dev/xdevcfg"):
                dry_mode=True
                print("Program is forced to run in SIMULATED mode as '/dev/xdevcfg' does not exist (not a camera)")
            else:
                if os.path.exists(VSC_DIR_OLD):
                    if self.DEBUG_MODE:
                        print ('x393_vsc3304: Running on OLD system')
                    VSC_DIR = VSC_DIR_OLD
                elif os.path.exists(VSC_DIR_NEW):    
                    if self.DEBUG_MODE:
                        print ('x393_vsc3304: Running on NEW system')
                    VSC_DIR = VSC_DIR_NEW
                else:
                    print ("Does not seem to be a known system - both %s (old) and %s (new) are not found"%(VSC_DIR_OLD, VSC_DIR_NEW))
                    return
                    
                    
        self.DRY_MODE=dry_mode
        self.x393_mem=X393Mem(debug_mode,dry_mode, 1)
        if not pcb_rev in self.PCB_CONNECTIONS:
            print ("Unknown PCB/rev: %s (defined: %s), using %s"%(pcb_rev, str(self.PCB_CONNECTIONS.keys()),self.PCB_REV))
        else:    
            self.PCB_REV = pcb_rev
            
    def echo(self, what, where):
        if self.DRY_MODE:
            print ("'%s' -> '%s'"%(str(what), VSC_DIR+"/"+where))
        else:
            if self.DEBUG_MODE:
                print ("'%s' -> '%s'"%(str(what), VSC_DIR+"/"+where))
            with open (VSC_DIR+"/"+where,"w") as f:
                print (str(what),file=f)
    def read_vals(self, path):
        with open(VSC_DIR+"/"+path, 'r') as f:
            line = f.readline().replace('\n', '')
        rslt = []
        for s in line.split():
            rslt.append(int(s))    
        return rslt
            
    def out_port (self, port_name):
        return "port_%02d"%(self.PORT_NUM[port_name]["OUT"])

    def in_port (self, port_name):
        return "port_%02d"%(self.PORT_NUM[port_name]["IN"])

    def in_port_number (self, port_name):
        return self.PORT_NUM[port_name]["IN"]

    def port_name(self, diff_pair):
        return self.PCB_CONNECTIONS[self.PCB_REV][diff_pair]

    def inverted_ports(self):
        return self.port_name('INVERTED_PORTS')

    def reinit(self): #Issue soft reset and re-initialize VSC3304 registers to idle mode
        self.echo("1","control/soft_reset")
        for port_letter in  self.inverted_ports():
            self.echo("1", "input_state_invert/"+self.in_port(port_letter))
            self.echo("10","output_mode/"+self.out_port(port_letter))
        self.echo("1", "forward_OOB/all")
        self.current_mode = "IDLE"

    def connect(self, mode):
        # Disconnect all existing connections
        self.echo("1", "input_state_off/all")
        self.echo("16","connections/all")
        defconn= "IDLE"
        try:
            conns = self.VSC3304_CONNECTIONS[mode]
        except:
            print("Invalid connections: %s (defined are: %s), using %s"%(mode, str(self.VSC3304_CONNECTIONS.keys()), defconn))
            mode =  defconn
            conns = self.VSC3304_CONNECTIONS[mode]
        if self.DEBUG_MODE:
            print(str(conns))
        #activate inputs
        for conn in conns:
            self.echo("0", "input_state_off/"+self.in_port(self.port_name (conn["FROM"])))
        #set crosspoint connections
        for conn in conns:
            self.echo(self.in_port_number(self.port_name (conn["FROM"])),
                     "connections/"+self.out_port(self.port_name (conn["TO"])))
        self.current_mode = mode    

    def disconnect_all(self):
        self.connect("IDLE")
        
    def connect_esata_ssd(self):
        self.connect("ESATA<->SSD")

    def connect_zynq_ssd(self):
        self.connect("ZYNQ<->SSD")

    def connect_zynq_esata(self):
        self.connect("ZYNQ<->ESATA")
        
    def connect_debug(self):
        self.connect("DEBUG_SSD")
        
    def connection_status(self):
        print("VSC3304 state: %s"%(self.current_mode))
        conns = self.VSC3304_CONNECTIONS[self.current_mode]
        for conn in conns:
            in_port = self.in_port(self.port_name (conn["FROM"]))
            loss = self.read_vals("status/"+in_port)[0]
            print ("%s -> %s : %s"%(conn["FROM"],conn["TO"], ('ACTIVE','LOST')[loss]))

