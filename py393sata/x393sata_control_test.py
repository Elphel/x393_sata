#!/usr/bin/env python

from __future__ import print_function
from __future__ import division
import x393sata
import x393_mem

import subprocess
import sys
import time
import os

from time import sleep

LOGFILE = "/var/log/x393sata_control_test.log"

# constants
RESET_LIMIT = 10
DRIVER_RELOAD_LIMIT = 5
DRIVER_WAIT_TIME = 10

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

def shout(cmd):
  #subprocess.call prints to console
  subprocess.call(cmd,shell=True)

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
        log_msg("%s: 0x%08x [%08x]"%(group_range, data, byte_addr))
        first_line = False
    if fld_value or not skip0:
        log_msg("%8x : %s (%s)"%(fld_value, fld['name'], fld['description'] ))
        # the device is there but fails to establish a correct link
        if fld['name']=="DIAG.B" or fld['name']=="DIAG.S" or fld['name']=="ERR.E":
          result = False
        
  return result

def connection_error():
  return connection_errors()

def reset_device():
  result = False
  
  for i in range(100):
    connection_error()
    sata.reset_ie()
    sata.reset_device()
      
  for i in range(RESET_LIMIT):
    if not connection_error():
      log_msg("connection error ("+str(i)+"), resetting device",4)
      sata.reset_ie()
      sata.reset_device()
    else:
      if i!=0: 
        log_msg("resetting device: success")
      result = True
      break
    sleep(0.5)

  #debug output
  #sata.reg_status()
  
  return result

def test1():
  for i in range(100):
    log_msg("TEST1 ("+str(i)+")",2)
    connection_error()
    sata.reset_ie()
    sata.reset_device()
    sleep(0.5)

def test2():
  connection_error()
  for i in range(100):
    log_msg("TEST2 ("+str(i)+")",2)
    sata.reset_ie()
    sleep(10)
    connection_error()
    print("above: 10 seconds after reset_ie")
    sata.reset_ie()
    connection_error()
    print("above: immediate after reset_ie")
    sata.reset_ie()
    sata.reset_device()
    connection_error()
    print("above: immediate after reset_device")
    #sata.drp (0x20b,0x221)
    #sata.drp (0x59,0x8)
    for j in range(10):
      print("sub: "+str(j))
      sata.reset_ie()
      sleep(1)
      connection_error()


def test3():
  connection_error()
  for i in range(100):
    log_msg("TEST3 ("+str(i)+")",2)
    sata.vsc3304.disconnect_all()
    sata.reset_ie()
    
    sleep(1)
    connection_error()
    
    sata.reset_device()
    
    sleep(1)
    connection_error()
    
    sata.set_zynq_esata()
    sata.drp (0x20b,0x221)
    sata.drp (0x59,0x8)
    
    sleep(1)
    connection_error()

def run_test4():
  if os.path.ismount("/mnt/sda1"):
    shout("umount /mnt/sda1")
  shout("rmmod ahci_elphel")
  
  sata.reset_ie()
  #sata.reset_device()
  sleep(0.1)
  connection_error()
  
  shout("modprobe ahci_elphel &")
  shout("sleep 2")
  shout("echo 1 > /sys/devices/soc0/amba@0/80000000.elphel-ahci/load_module")
  
  shout("sleep "+str(DRIVER_WAIT_TIME))
  
  if os.path.ismount("/mnt/sda1"):
    log_msg(colorize("PASS",'GREEN',True))
    result = True
  else:
    log_msg(colorize("FAIL",'RED',True))
    result = False
    
  return result

def test4():
  errcounter = 0
  for i in range(100):
    log_msg("TEST "+str(i)+", failed: "+str(errcounter),2)
    if not run_test4():
      errcounter = errcounter + 1

def disconnect_and_reset():
  sata.vsc3304.disconnect_all()

mem = x393_mem.X393Mem(0,0,1)
sata = x393sata.x393sata() # 1,0,"10389B")

if len(sys.argv) > 1:
  cmd = sys.argv[1]
else:
  cmd = "donothing"


if   cmd == "test1":
  disconnect_and_reset()
  sata.set_zynq_esata()
  test1()
elif cmd == "test2":
  disconnect_and_reset()
  sata.set_zynq_esata()
  test2()
elif cmd == "test3":
  test3()
elif cmd == "test4":
  test4()
else:
  print("Usage: -")
