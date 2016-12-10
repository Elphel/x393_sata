#!/usr/bin/env python
# encoding: utf-8
from __future__ import print_function
from __future__ import division

import os
import x393_mem
import time
import sys

def get_wp(mem):
    return ((mem.read_mem(0x80000ffc) >> 10) & 0xffc) + 0x80001000 

def get_len(p1,p0):
    return p1-p0

# Temporary
# because mm[start_offset:end_offset] might not work properly
# last 64 bytes get bad
def mem_write_to_file(mem,bf, start_addr, length):
    with open("/dev/mem", "r+b") as f:
        first_page = start_addr // mem.PAGE_SIZE
        last_page = (start_addr + length - 1) // mem.PAGE_SIZE
        for page_num in range(first_page, last_page+1):
            start_offset = 0
            if page_num == first_page:
                start_offset = start_addr - mem.PAGE_SIZE * page_num
            end_offset =  mem.PAGE_SIZE
            if page_num == last_page:
                end_offset = start_addr + length - mem.PAGE_SIZE * page_num
            page_addr = page_num * mem.PAGE_SIZE 
            mm = mem.wrap_mm(f, page_addr)
            
            for i in range(start_offset,end_offset,4):
                bf.write(mm[i:i+4])
                
debug_mode=0
dry_mode=0
filename = "/tmp/x393mem.log"

MAX_SIZE = 20000000
TIMEOUT = 10

BUF_SIZE = 4096
BUF_START = 0x80001000
BUF_END   = 0x80002000

mem=x393_mem.X393Mem(debug_mode,dry_mode, 1)

run = True
wp_old = BUF_START
time_old = time.time()

if os.path.isfile(filename):
    os.remove(filename)

#
#f = open(filename,"w+b")
#mem_write_to_file(mem, f, 0x80001000, 64)
#f.close()

#mem.mem_save(self, filename, start_addr, length)

#sys.exit()

while(run):
    
    if not os.path.isfile(filename):
        f = open(filename,"w+b")
        
    wp_new = get_wp(mem)
    if wp_new==wp_old:
        to = time.time()-time_old
        #print("Skipping, dt= "+str(to))
        if to>TIMEOUT:
            print("Timeout: "+str(to)+" s")
            f.close()
            break
    else:
        time_old = time.time()
        l = get_len(wp_new,wp_old)
        if (l<0):
            #write end
            l = BUF_END - wp_old
            mem_write_to_file(mem, f, wp_old, l)
            #write_start
            l = wp_new - BUF_START
            mem_write_to_file(mem, f, BUF_START, l)
        else:
            mem_write_to_file(mem, f, wp_old, l)
        #print("Going to write something of size ="+str(l))
        wp_old = wp_new
        
    if os.path.getsize(filename)>MAX_SIZE:
        print("Close, then rename")
        f.close()
        os.rename(filename,filename+".0")
    
    

#print(get_wp(mem))

# open file
#with open(filename, "w+b") as bf:
    

# get pointer and read mem
# write to file


#_mem_write_to_file (self, bf, start_addr, length)
