#!/usr/bin/env python

from __future__ import print_function
from __future__ import division
import x393sata
import x393_mem
import sys
import time

LOGFILE = "/var/log/x393sata_control.log"

def colorize(string, color, bold):
    color=color.upper()
    attr = []
    if color == 'RED':
        attr.append('31')
    elif color == 'GREEN':    
        attr.append('32')
    elif color == 'YELLOW':    
        attr.append('33')
    elif color == 'BLUE':    
        attr.append('34')
    elif color == 'MAGENTA':    
        attr.append('35')
    elif color == 'CYAN':    
        attr.append('36')
    elif color == 'GRAY':    
        attr.append('37')
    else:
        pass
        # red
    if bold:
        attr.append('1')
    return '\x1b[%sm%s\x1b[0m' % (';'.join(attr), string)
  
def log_msg(msg, mode=0):
    bold = False
    color = ""
    if mode == 2: #bold red - error
        color = "RED"
        bold = True
    elif mode == 3: # just bold
        bold = True
    elif mode == 4: # just bold
        bold = True
        color = "YELLOW" #warning
            
    with open ('/proc/uptime') as f: 
        t=float(f.read().split()[0])
    with open(LOGFILE,'a') as msg_file:
        print("[%8.2f]  %s"%(t,msg),file=msg_file)
    if bold or color:
        msg = colorize(msg,color,bold)    
    print (colorize("[%8.2f] %s: "%(t, sys.argv[0].split('/')[-1].split('.')[0]),'CYAN',0)+msg)

def connection_errors():
  result = True
  skip0 = True
  MAXI1_ADDR = 0x80000000
  group_range = "HBA_PORT__PxSERR"
  cached_addr = None
  cached_data = None
  first_line = True
  
  range_defines = sata.register_defines[group_range]
  
  for fld in range_defines:  
    byte_addr = 4 * fld['dword_address'] + MAXI1_ADDR
    if byte_addr != cached_addr:
        cached_addr = byte_addr
        cached_data = mem.read_mem(cached_addr)
    data = cached_data
    fld_value = (data >> fld['start_bit']) & ((1 << fld['num_bits']) - 1)
    if first_line:
        first_line = False
    if fld_value or not skip0:
        # the device is there but fails to establish a correct link
        if fld['name']=="DIAG.B" or fld['name']=="DIAG.S":
          result = False
  return result

def reset_device():
  result = False
  for i in range(reset_limit):
    if not connection_errors():
      log_msg("connection error ("+str(i)+"), resetting device",4)
      sata.reset_device()
      sata.reset_ie()
    else:
      if i!=0: 
        log_msg("resetting device: success")
      result = True
      break
    time.sleep(1)
  return result

mem = x393_mem.X393Mem(0,0,1)
sata = x393sata.x393sata() # 1,0,"10389B")

if len(sys.argv) > 1:
  cmd = sys.argv[1]
else:
  cmd = "donothing"

reset_limit = 10

if   cmd == "set_zynq_ssd":
  sata.vsc3304.disconnect_all()
  sata.set_zynq_ssd()
  reset_device()
elif cmd == "set_zynq_esata":
  sata.vsc3304.disconnect_all()  
  sata.set_zynq_esata()
  reset_device()
elif cmd == "set_zynq_ssata":
  sata.vsc3304.disconnect_all()
  sata.set_zynq_ssata()
  reset_device()
elif cmd == "set_esata_ssd":
  sata.vsc3304.disconnect_all()
  sata.set_esata_ssd()
  reset_device()
else:
  print("Usage:")
  print("    * camera <-> internal SSD  :            x393sata_control.py set_zynq_ssd")
  print("    * camera <-> external disk :            x393sata_control.py set_zynq_esata")
  print("    * camera <-> external disk (crossover): x393sata_control.py set_zynq_ssata")
  print("    * PC <-> internal SSD)     :            x393sata_control.py set_esata_ssd")
