#!/usr/bin/env python

from __future__ import print_function
from __future__ import division

'''
/**
# Copyright (C) 2017, Elphel.inc.
# Description: switch between internal and external SSDs
# Comments:
#     reset_device (3x times max) 
#       does not matter if error or not - reload driver - wait for 10 seconds + 10
#           if error - reload (repeat up to 5x)
#
# Solved problem:
#     when using overlays deleting existing in the lower layer dirs can cause error (hopefully it gets fixed someday):
#       example: 
#           * /mnt/sda1 exists in lower layer: /tmp/rootfs.ro/tmp
#           * upper layer is mounted to /
#       # rmdir /mnt/sda1
#       # mkdir /mnt/sda1
#       mkdir: cannot create directory '/mnt/sda1': Operation not supported
#
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
# along with this program.  If not, see <http:#www.gnu.org/licenses/>.

@author:     Oleg K Dzhimiev
@copyright:  2017 Elphel, Inc.
@license:    GPLv3.0+
@contact:    oleg@elphel.com
@deffield    updated: unknown
'''

__author__ = "Elphel"
__copyright__ = "Copyright 2017, Elphel, Inc."
__license__ = "GPL"
__version__ = "3.0+"
__maintainer__ = "Oleg K Dzhimiev"
__email__ = "oleg@elphel.com"
__status__ = "Development"

import x393sata
import x393_mem

import subprocess
import sys
import time
import os
import re

from time import sleep

LOGFILE = "/var/log/x393sata_eyesis4pi.log"
STATEFILE = "/var/state/ssd"

# constants
RESET_LIMIT = 3
DRIVER_RELOAD_LIMIT = 5
DRIVER_WAIT_TIME = 10
DRIVER_UNLOAD_TRIES = 30

#global
DEVICE_CONNECTED = False

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
    print (colorize("[%8.2f] %s: "%(t, sys.argv[0].split('/')[-1].split('.')[0]),'GREEN',0)+msg)


def shout(cmd):
  #subprocess.call prints to console
  subprocess.call(cmd,shell=True)


def connection_errors():
  
  global DEVICE_CONNECTED
  
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
        if data!=0:
          DEVICE_CONNECTED = True
        first_line = False
    if fld_value or not skip0:
        log_msg("%8x : %s (%s)"%(fld_value, fld['name'], fld['description'] ))
        # the device is there but fails to establish a correct link
        if fld['name']=="DIAG.B" or fld['name']=="DIAG.S" or fld['name']=="ERR.E":
          result = False
        
  return result


def reset_device():
  
  global DEVICE_CONNECTED
  
  result = False
  
  sleep(0.5)
  
  for i in range(RESET_LIMIT):
    if not connection_errors():        
      log_msg("connection error ("+str(i)+"), resetting device",4)
      sata.reset_ie()
      sata.reset_device()
      sleep(0.5)
    else:
      if i!=0: 
        log_msg("resetting device: success")
      result = True
    
    if i==0:
      DEVICE_CONNECTED = False
    
    if result:
      break
  
  # load driver in any case
  load_driver()
  return result

def load_ahci_elphel_driver():
  
  shout("modprobe ahci_elphel &")
  shout("sleep 2")
  shout("echo 1 > /sys/devices/soc0/amba@0/80000000.elphel-ahci/load_module")
  log_msg("AHCI driver loaded")
  

def unload_ahci_elphel_driver():
  
  for i in range(DRIVER_UNLOAD_TRIES):
    unmount_partitions()
    try:
      output = subprocess.check_output(["rmmod","ahci_elphel"],stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:
      output = [x.strip() for x in e.output.split(":")]
      if output[-1]=="Resource temporarily unavailable":
        log_msg("Tried to unload driver "+str(i)+": "+output[-1])
        if i==(DRIVER_UNLOAD_TRIES-1):
          log_msg("AHCI driver unloading timeout")
        sleep(2)
      else:
        log_msg("AHCI driver is not loaded")
        break
    else:
      log_msg("AHCI driver unloaded")
      break

def unmount_partitions():
  
  with open("/proc/mounts") as f:
    content = f.readlines()
  
  content = [x.strip() for x in content]
  content = [x.split(" ")[0] for x in content]
  
  for mounted_device in content:
    m = re.search(r"sd[a-z][0-9]",mounted_device)
    if m:
      mountpoint = "/mnt/"+m.group(0)
      partname = "/dev/"+m.group(0)
      log_msg("Unmounting "+partname)
      shout("umount "+mountpoint)

def load_driver():

  for i in range(DRIVER_RELOAD_LIMIT):
    log_msg("Loading SATA driver ("+str(i)+")")
    result = reload_driver()
    if result:
      break
    
  if not result:
    log_msg("SATA failed, SSD was not detected: reconnect SSD",2)
    shout("echo 0 > "+STATEFILE)
  else:
    if not DEVICE_CONNECTED:
      log_msg("SSD was not detected, ahci_elphel driver is loaded",4)
    else:
      log_msg("SATA ok, SSD detected after "+str(i)+" tries")
      #automount()
    shout("echo 1 > "+STATEFILE)
  

#def automount():
  #output = subprocess.check_output("blkid")
  #output = output.split("\n")
  
  #for line in output:
    #pars = line.split(" ")
    #m = re.search(r"sd[a-z][0-9]",pars[0])
    #if m:
      #pname = m.group(0)
      #m = re.search(r"TYPE=\"ext",pars[2])
      #if m:
        #mount_partition(pname)

#def mount_partition(dirname):
  #mountpoint = "/mnt/"+dirname
  #partname = "/dev/"+dirname
  
  #if not os.path.exists(mountpoint):
    #shout("mkdir "+mountpoint)
    #shout("mount "+partname+" "+mountpoint)

def check_device():
  with open("/proc/partitions") as f:
    content = f.readlines()
  
  content = [x.strip() for x in content]
  content = [x.split(" ")[-1] for x in content]
  
  result = False
  
  for device in content:
    m = re.search(r"sd[a-z]",device)
    if m:
      result = True
      break
  
  return result

def reload_driver():

  unload_ahci_elphel_driver()
  # check once
  sata.reset_ie()
  sata.reset_device()
  sleep(0.5)
  connection_errors()
  
  load_ahci_elphel_driver()
  
  if DEVICE_CONNECTED:
    sleep(DRIVER_WAIT_TIME)
    result = check_device()
    
    # one more try
    if not result:
      log_msg(colorize("SSD was not detected: waiting for another "+str(DRIVER_WAIT_TIME)+" seconds",'YELLOW',True))
      sleep(DRIVER_WAIT_TIME)  
      result = check_device()
  else:
    result = True
  
  return result

def unmount_unload_disconnect():
  unload_ahci_elphel_driver()
  sata.vsc3304.disconnect_all()  

mem = x393_mem.X393Mem(0,0,1)
sata = x393sata.x393sata() # 1,0,"10389B")

if len(sys.argv) > 1:
  cmd = sys.argv[1]
else:
  cmd = "donothing"


if   cmd == "set_zynq_ssd":
  unmount_unload_disconnect()
  sata.set_zynq_ssd()
  reset_device()
elif cmd == "set_zynq_esata":
  unmount_unload_disconnect()
  sata.set_zynq_esata()
  reset_device()
elif cmd == "set_zynq_ssata":
  unmount_unload_disconnect()
  sata.set_zynq_ssata()
  reset_device()
elif cmd == "set_esata_ssd":
  unmount_unload_disconnect()
  sata.set_esata_ssd()
  reset_device()
else:
  print("Usage:")
  print("    * camera <-> internal SSD  :            x393sata_eyesis4pi_control.py set_zynq_ssd")
  print("    * camera <-> external disk :            x393sata_eyesis4pi_control.py set_zynq_esata")
  print("    * camera <-> external disk (crossover): x393sata_eyesis4pi_control.py set_zynq_ssata")
  print("    * PC <-> internal SSD)     :            x393sata_eyesis4pi_control.py set_esata_ssd")
