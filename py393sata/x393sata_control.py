#!/usr/bin/env python

from __future__ import print_function
from __future__ import division
import x393sata
import x393_mem
import sys

mem = x393_mem.X393Mem(1,0,1)
sata = x393sata.x393sata() # 1,0,"10389B")

if len(sys.argv) > 1:
  cmd = sys.argv[1]
else:
  cmd = "donothing"

if   cmd == "set_zynq_ssd":
  sata.set_zynq_ssd()
elif cmd == "set_zynq_esata":
  sata.set_zynq_esata()
elif cmd == "set_zynq_ssata":
  sata.set_zynq_esata()
elif cmd == "set_esata_ssd":
  sata.set_esata_ssd()
else:
  print("Usage:")
  print("    * camera <-> internal SSD  : x393sata_control.py set_zynq_ssd")
  print("    * camera <-> external disk : x393sata_control.py set_zynq_esata")
  print("    * camera <-> external disk (crossover): x393sata_control.py set_zynq_ssata")
  print("    * PC <-> internal SSD)     : x393sata_control.py set_esata_ssd")