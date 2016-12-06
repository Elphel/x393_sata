#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import print_function
from __future__ import division
# Copyright (C) 2015, Elphel.inc.
# Helper module create AHCI registers type/default data
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
#  
__author__ = "Andrey Filippov"
__copyright__ = "Copyright 2015, Elphel, Inc."
__license__ = "GPL"
__version__ = "3.0+"
__maintainer__ = "Andrey Filippov"
__email__ = "andrey@elphel.com"
__status__ = "Development"
#import sys

# All unspecified ranges/fields default to fT:RO, fC:0 (readonly, reset value = 0)
#RID = 0x02   # Revision ID (use for bitstream version)
RID = 0x03   # Revision ID (use for bitstream version)
VID = 0xfffe # What to use for non-PCI "vendorID"?
DID = 0x0001
SSVID = 0xfffe
SSID =  0x0001
IPIN = 0x01 # TODO: Put a real number for "Interrupt pin"
ILINE = 0x00 # Interrupt line - software is supposed to fill it - maybe here we need to put some predefined value?
HBA_OFFS = 0x0 # All offsets are in bytes
CLB_OFFS = 0x800 # In the second half of the register space (0x800..0xbff - 1KB)
FB_OFFS =  0xc00 # Needs 0x100 bytes 
#HBA_PORT0 = 0x100 Not needed, always HBA_OFFS + 0x100
PCIHEAD = 0x180
PMCAP =   0x1C0
AXI_BASEADDR =     0x80000000

reg_defaults_path= "../includes/ahci_defaults.vh"
reg_types_path=    "../includes/ahci_types.vh"
localparams_path=  "../includes/ahci_localparams.vh"


gN = "groupName"
gS = "groupStart"
gE = "groupEnd"
gD = "groupDescription"
gC = "groupContent"
rN = "rangeName"  # byte/word/dword
rS = "rangeStart" # in bytes relative to the Group start
rE = "rangeEnd"   # in bytes relative to the Group start
rD = "rangeDescription"
rC = "rangeContent"
fN = "fieldName"
fL = "fieldOffsetLow" # if any of fL, fH is absent, it is assumed to be equal to the other, if both - to the full range
fH = "fieldOffsetHigh"
fS = "fieldSize"
fE = "fieldEnd"
fD = "fieldDescription"
fC = "fieldContent"
fT = "fieldType"
RW =  "RW"
RO=   "RO"
RWC = "RWC"
RW1 = "RW1"


ABAR =             AXI_BASEADDR + HBA_OFFS
# Second half of the 4KB register memory does not have RO/RW/RWC/RW1 capability (just RW), but has a single-cycle write access
#Keeping CLB and received FIS reduces number of required DMA transfer types - just reading PRDs and Read/Write DMA data
P0CLB =            AXI_BASEADDR + CLB_OFFS  # Port 0 CLB address - keep in HBA internal memory 
P0FB =             AXI_BASEADDR + FB_OFFS   # Port 0 received FIS address - keep in HBA internal memory

#reg_defaults = [0]*4096 # array of bytes, default value = 0
#bit_types    = [0]*2048 # array of words, default value = 0


src=[{gN:"PCI_Header", gS: PCIHEAD, gE:PCIHEAD+0x3f, gD:" PCI header emulation with no PCI",gC:
        [{rN:"ID",  rS:0x0,  rE:0x3,                rD:"Identifiers", rC:
            [{fN:"DID", fS:16,  fE:31, fT:RO, fC:DID, fD:"Device ID"},
             {fN:"VID", fS:0,   fE:15, fT:RO, fC:VID, fD:"Vendor ID"}]},
         {rN:"CMD", rS:0x04, rE:0x5,                rD:"Command Register", rC:
            [{fS:11, fE:15, fT:RO, fC:0}, # reserved
             {fN:"ID",  fS:10,        fT:RW,  fC:0, fD:"HBA Interrupt Disable"},
             {fN:"FBE", fS: 9,        fT:RO,  fC:0, fD:"Fast Back-to-Back Enable"},
             {fN:"SEE", fS: 8,        fT:RO,  fC:0, fD:"SERR Enable"},
             {fN:"WCC", fS: 7,        fT:RO,  fC:0, fD:"Reserved"},
             {fN:"PEE", fS: 6,        fT:RO,  fC:0, fD:"Parity Error Response Enable"},
             {fN:"VGA", fS: 5,        fT:RO,  fC:0, fD:"Reserved"},
             {fN:"MWIE",fS: 4,        fT:RO,  fC:0, fD:"Reserved"},
             {fN:"SCE", fS: 3,        fT:RO,  fC:0, fD:"Reserved"},
             {fN:"BME", fS: 2,        fT:RW,  fC:0, fD:"Bus Master Enable (0 - stops any DMA)"},
             {fN:"MSE", fS: 1,        fT:RW,  fC:0, fD:"Memory Space enable (here - always?)"},
             {fN:"IOSE",fS: 0,        fT:RO,  fC:0, fD:"Enable IO space access (only for legacy IDE)"}]},
         {rN:"STS", rS:0x06, rE:0x7,                rD:"Device Status", rC:
            [{fN:"DPE", fS:15,        fT:RWC, fC:0, fD:"Detected Parity Error"},
             {fN:"SSE", fS:14,        fT:RWC, fC:0, fD:"Signaled System Error (HBA SERR)"},
             {fN:"RMA", fS:13,        fT:RWC, fC:0, fD:"Received Master Abort"},
             {fN:"RTA", fS:12,        fT:RWC, fC:0, fD:"Received Target Abort"},
             {fN:"STA", fS:11,        fT:RWC, fC:0, fD:"Signaled Target Abort"},
             {fN:"DEVT",fS: 9, fE:10, fT:RO,  fC:0, fD:"PCI DEVSEL Timing"},
             {fN:"DPD", fS: 8,        fT:RWC, fC:0, fD:"Master Data Parity Error Detected"},
             {fN:"FBC", fS: 7,        fT:RO,  fC:0, fD:"Fast Back-To-Back Capable"},
             {          fS: 6,        fT:RO,  fC:0, fD:"Reserved"},
             {fN:"C66", fS: 5,        fT:RO,  fC:0, fD:"66 MHz Capable"},
             {fN:"CL",  fS: 4,        fT:RO,  fC:1, fD:"Capabilities List (PCI power management mandatory)"},
             {fN:"IS",  fS: 3,        fT:RO,  fC:0, fD:"Interrupt Status (1 - asserted)"},
             {          fS: 0, fE:2,  fT:RO,  fC:0, fD:"Reserved"}]},
         {rN:"RID", rS:0x08,                        rD:"HBA Revision ID", rC:
            [{fN:"RID",               fT:RO,  fC:RID, fD:"HBA Revision ID"}]},
         {rN:"CC",  rS:0x09, rE:0x0b,               rD:"Class Code", rC:
            [{fN:"BCC", fS:16, fE:23, fT:RO,  fC:1, fD:"Base Class Code: 1 - Mass Storage Device"},
             {fN:"SCC", fS: 8, fE:15, fT:RO,  fC:6, fD:"Sub Class Code: 0x06 - SATA Device"},
             {fN:"PI",  fS: 8, fE:15, fT:RO,  fC:1, fD:"Programming Interface: 1 - AHCI HBA major rev 1"}]},
         {rN:"CLS", rS:0x0c,                        rD:"Cache Line Size", rC:
            [{fN:"CLS",               fT:RW,  fC:0, fD:"Cache Line Size"}]},
         {rN:"MLT", rS:0x0d,                        rD:"Master Latency Timer", rC:
            [{fN:"MLT",               fT:RW,  fC:0, fD:"Master Latency Timer"}]},
         {rN:"HTYPE", rS:0x0d,                      rD:"Header Type", rC:
            [{fN:"MFDT",fS:7,         fT:RO,  fC:0, fD:"Multi-Function Device"},
             {fN:"HL",  fS: 0, fE:6,  fT:RO,  fC:0, fD:"Header Layout 0 - HBA uses a target device layout"}]},
          #Offsets 0x10..0x23 - other BARs (optional)
         {rN:"ABAR", rS:0x24, rE:0x27,              rD:"AHCI Base Address", rC:
            [{fN:"BA",  fS: 4, fE:31, fT:RO,  fC:(ABAR >> 4), fD:"AHCI Base Address high bits, normally RW, but here RO to get to MAXIGP1 space"},
             {fN:"PF",  fS: 3,        fT:RO,  fC:0, fD:"Prefetchable (this is not)"},
             {fN:"TP",  fS: 1, fE:2,  fT:RO,  fC:0, fD:"Type (0 - any 32-bit address, here it is hard-mapped"},
             {fN:"RTE", fS: 0,        fT:RO,  fC:0, fD:"Resource Type Indicator: 0 - memory address"}]},
          # 0x28.0x2b skipped         
         {rN:"SS", rS:0x2c, rE:0x2f,                    rD:"Sub System identifiers", rC:
            [{fN:"SSID",  fS:16, fE:31, fT:RO, fC:SSID, fD:"SubSystem ID"},
             {fN:"SSVID", fS:0,  fE:15, fT:RO, fC:SSVID,fD:"SubSystem Vendor ID"}]},
         {rN:"EROM", rS:0x30, rE:0x33,                  rD:"Extension ROM (optional)", rC:
            [{fN:"RBA",                fT:RO,  fC:0,    fD:"ROM Base Address"}]},
         {rN:"CAP", rS:0x34,                            rD:"Capabilities Pointer", rC:
            [{fN:"CAP",                fT:RO,  fC:(PMCAP-PCIHEAD), fD:"Capabilities pointer"}]},
          #0x35-0x3b are reserved
         {rN:"INTR", rS:0x3c, rE:0x3d,                  rD:"Interrupt Information", rC:
            [{fN:"IPIN",  fS: 8, fE:15, fT:RO, fC:IPIN, fD:"Interrupt pin"},
             {fN:"ILINE", fS: 0, fE: 7, fT:RW, fC:ILINE,fD:"Interrupt Line"}]},
         {rN:"MGNT", rS:0x3e,                           rD:"Minimal Grant (optional)", rC:
            [{fN:"MGNT",                fT:RO,  fC:0,   fD:"Minimal Grant"}]},
         {rN:"MLAT", rS:0x3f,                           rD:"Maximal Latency (optional)", rC:
            [{fN:"MLAT",                fT:RO,  fC:0,   fD:"Maximal Latency"}]}
       ]}, # End of "PCI_Header" group
     {gN:"PMCAP", gS: PMCAP, gE:PMCAP+0x7, gD:"Power Management Capability",gC:
        [{rN:"PID",  rS:0x0,  rE:0x1,                rD:"PCI Power Management Capability ID", rC:
            [{fN:"NEXT",  fS: 8, fE:15, fT:RO, fC:0, fD:"Next Capability pointer"},
             {fN:"CID",   fS: 0, fE: 7, fT:RO, fC:1, fD:"This is PCI Power Management Capability"}]},
         {rN:"PC",  rS:0x2,  rE:0x3,                 rD:"Power Management Capabilities", rC:
            [{fN:"PSUP",  fS:11, fE:15, fT:RO, fC:8, fD:"PME_SUPPORT bits:'b01000"},
             {fN:"D2S",   fS:10,        fT:RO, fC:0, fD:"D2 Support - no"},
             {fN:"D1S",   fS: 9,        fT:RO, fC:0, fD:"D1 Support - no"},
             {fN:"AUXC",  fS: 6, fE: 8, fT:RO, fC:0, fD:"Maximal D3cold current"},
             {fN:"DSI",   fS: 5,        fT:RO, fC:0, fD:"Device-specific initialization required"}, #Use it?
             {            fS: 4,        fT:RO, fC:0, fD:"Reserved"},
             {fN:"PMEC",  fS: 3,        fT:RO, fC:0, fD:"PCI clock required to generate PME"},
             {fN:"VS",    fS: 0, fE: 2, fT:RO, fC:0, fD:"Revision of Power Management Specification support version"}]},
         {rN:"PMCS",  rS:0x4,  rE:0x5,               rD:"Power Management Control and Status", rC:
            [{fN:"PMES",  fS:15,        fT:RWC,fC:0, fD:"PME Status, set by hardware when HBA generates PME"},
             {            fS: 9, fE:14, fT:RO, fC:0, fD:"Reserved: AHCI HBA Does not implement data register"},
             {fN:"PMEE",  fS: 8,        fT:RW, fC:0, fD:"PME Enable"},
             {            fS: 2, fE: 7, fT:RO, fC:0, fD:"Reserved"},
             {fN:"PS",    fS: 0, fE: 1, fT:RW, fC:0, fD:"Power State"}]},
         
       ]},
     {gN:"GHC", gS: HBA_OFFS, gE:HBA_OFFS + 0x2b, gD:"HBA Generic Host Control",gC:
       [{rN:"CAP",  rS:0x0,  rE:0x03,                rD:"HBA Capabilities", rC:
            [{fN:"S64A",  fS:31,        fT:RO, fC:0, fD:"Supports 64-bit Addressing - no"},
             {fN:"SNCQ",  fS:30,        fT:RO, fC:0, fD:"Supports Native Command Queuing - no"},
             {fN:"SSNTF", fS:29,        fT:RO, fC:0, fD:"Supports SNotification Register - no"},
             {fN:"SMPS",  fS:28,        fT:RO, fC:0, fD:"Supports Mechanical Presence Switch - no"},
             {fN:"SSS",   fS:27,        fT:RO, fC:0, fD:"Supports Staggered Spin-up - no"},
             {fN:"SALP",  fS:26,        fT:RO, fC:0, fD:"Supports Aggressive Link Power Management - no"},
             {fN:"SAL",   fS:25,        fT:RO, fC:0, fD:"Supports Activity LED - no"},
             {fN:"SCLO",  fS:24,        fT:RO, fC:0, fD:"Supports Command List Override - no (not capable of clearing BSY and DRQ bits, needs soft reset"},
             {fN:"ISS",   fS:20, fE:23, fT:RO, fC:2, fD:"Interface Maximal speed: 2 - Gen2, 3 - Gen3"},
             {            fS:19,        fT:RO, fC:0, fD:"Reserved"},
             {fN:"SAM",   fS:18,        fT:RO, fC:1, fD:"AHCI only (0 - legacy too)"},
             {fN:"SPM",   fS:17,        fT:RO, fC:0, fD:"Supports Port Multiplier - no"},
             {fN:"FBSS",  fS:16,        fT:RO, fC:0, fD:"Supports FIS-based switching of the Port Multiplier - no"},
             {fN:"PMD",   fS:15,        fT:RO, fC:0, fD:"PIO Multiple DRQ block - no"},
             {fN:"SSC",   fS:14,        fT:RO, fC:0, fD:"Slumber State Capable - no"},
             {fN:"PSC",   fS:13,        fT:RO, fC:0, fD:"Partial State Capable - no"},
             {fN:"NSC",   fS: 8, fE:12, fT:RO, fC:0, fD:"Number of Command Slots, 0-based (0 means 1?)"},
             {fN:"CCCS",  fS: 7,        fT:RO, fC:0, fD:"Command Completion Coalescing  - no"},
             {fN:"EMS",   fS: 6,        fT:RO, fC:0, fD:"Enclosure Management - no"},
             {fN:"SXS",   fS: 5,        fT:RO, fC:1, fD:"External SATA connector - yes"},
             {fN:"NP",    fS: 0, fE: 4, fT:RO, fC:0, fD:"Number of Ports, 0-based (0 means 1?)"}]}, 
        {rN:"GHC",  rS:0x4,  rE:0x07,                rD:"Global HBA Control", rC:
            [{fN:"AE",    fS:31,        fT:RO, fC:1, fD:"AHCI enable (0 - legacy)"},
             {            fS: 3, fE:30, fT:RO, fC:0, fD:"Reserved"},
             {fN:"MRSM",  fS: 2,        fT:RO, fC:0, fD:"MSI Revert to Single Message"},
             {fN:"IE",    fS: 1,        fT:RW, fC:0, fD:"Interrupt Enable (all ports)"},
             {fN:"HR",    fS: 0,        fT:RW1,fC:0, fD:"HBA reset (COMINIT, ...). Set by software, cleared by hardware, section 10.4.3"}]}, 
        {rN:"IS",  rS:0x08, rE:0x0b,                 rD:"Interrupt Status Register", rC:
            [{fN:"IPS",                 fT:RWC,fC:0, fD:"Interrupt Pending Status (per port)"}]}, 
        {rN:"PI",  rS:0x0c, rE:0x0f,                 rD:"Interrupt Status Register", rC:
            [{fN:"PI",                  fT:RO, fC:1, fD:"Ports Implemented"}]}, 
        {rN:"VS",  rS:0x10,  rE:0x13,                rD:"AHCI Version", rC:
            [{fN:"MJR",   fS:16, fE:31, fT:RO, fC:0x0001, fD:"AHCI Major Version 1."},
             {fN:"MNR",   fS: 0, fE:15, fT:RO, fC:0x0301, fD:"AHCI Minor Version 3.1"}]}, 
        {rN:"CCC_CTL",   rS:0x14, rE:0x17,           rD:"Command Completion Coalescing Control", rC:
            [{                          fT:RO, fC:0, fD:"Not Implemented"}]}, 
        {rN:"CCC_PORTS", rS:0x18, rE:0x1b,           rD:"Command Completion Coalescing Ports", rC:
            [{                          fT:RO, fC:0, fD:"Not Implemented"}]}, 
        {rN:"EM_LOC",    rS:0x1c, rE:0x1f,           rD:"Enclosure Management Location", rC:
            [{                          fT:RO, fC:0, fD:"Not Implemented"}]}, 
        {rN:"EM_CTL",    rS:0x20, rE:0x23,           rD:"Enclosure Management Control", rC:
            [{                          fT:RO, fC:0, fD:"Not Implemented"}]}, 

        {rN:"CAP2", rS:0x24,  rE:0x27,                       rD:"HBA Capabilities Extended", rC:
            [{            fS: 6, fE:31, fT:RO, fC:0, fD:"Reserved"},
             {fN:"DESO",  fS: 5,        fT:RO, fC:0, fD:"DevSleep Entrance from Slumber Only"},
             {fN:"SADM",  fS: 4,        fT:RO, fC:0, fD:"Supports Aggressive Device Sleep Management"},
             {fN:"SDS",   fS: 3,        fT:RO, fC:0, fD:"Supports Device Sleep"},
             {fN:"APST",  fS: 2,        fT:RO, fC:0, fD:"Automatic Partial to Slumber Transitions"},
             {fN:"NVMP",  fS: 1,        fT:RO, fC:0, fD:"NVMHCI Present (section 10.15)"},
             {fN:"BOH",   fS: 0,        fT:RO, fC:0, fD:"BIOS/OS Handoff - not supported"}]},
        {rN:"BOHC",  rS:0x28, rE:0x2b,            rD:"BIOS/OS COntrol and status", rC:
            [{                          fT:RO, fC:0, fD:"Not Implemented"}]}, 
       ]},  

     {gN:"HBA_PORT", gS: HBA_OFFS + 0x100, gE:HBA_OFFS + 0x17f, gD:"HBA Port registers",gC:
       [{rN:"PxCLB",  rS:0x0,  rE:0x03,                rD:"Port x Command List Base Address", rC:
            [{fN:"CLB",   fS:10, fE:31, fT:RW, fC:P0CLB>>10, fD:"Command List Base Address (1KB aligned)"},
             {            fS: 0, fE: 9, fT:RO, fC:0, fD:"Reserved"}]}, 
        {rN:"PxCLBU", rS:0x04, rE:0x07,              rD:"Port x CLB address, upper 32 bits of 64", rC:
            [{                          fT:RO, fC:0, fD:"Not Implemented"}]}, 
        {rN:"PxFB",   rS:0x8,  rE:0x0b,              rD:"FIS Base Address", rC:
            [{fN:"CLB",   fS: 8, fE:31, fT:RW, fC:P0FB>> 8, fD:"Command List Base Address (1KB aligned)"},
             {            fS: 0, fE: 7, fT:RO, fC:0, fD:"Reserved"}]}, 
        {rN:"PxFBU",  rS:0x0c, rE:0x0f,               rD:"FIS address, upper 32 bits of 64", rC:
            [{                          fT:RO, fC:0, fD:"Not Implemented"}]}, 
        {rN:"PxIS",   rS:0x10, rE:0x13,              rD:"Port x Interrupt Status", rC:
            [{fN:"CPDS",  fS:31,        fT:RWC,fC:0, fD:"Cold Port Detect Status"},
             {fN:"TFES",  fS:30,        fT:RWC,fC:0, fD:"Task File Error Status"},
             {fN:"HBFS",  fS:29,        fT:RWC,fC:0, fD:"Host Bus (PCI) Fatal error"},
             {fN:"HBDS",  fS:28,        fT:RWC,fC:0, fD:"ECC error R/W system memory"},
             {fN:"IFS",   fS:27,        fT:RWC,fC:0, fD:"Interface Fatal Error Status (sect. 6.1.2)"},
             {fN:"INFS",  fS:26,        fT:RWC,fC:0, fD:"Interface Non-Fatal Error Status (sect. 6.1.2)"},
             {            fS:25,        fT:RO, fC:0, fD:"Reserved"},
             {fN:"OFS",   fS:24,        fT:RWC,fC:0, fD:"Overflow Status"},
             {fN:"IPMS",  fS:23,        fT:RWC,fC:0, fD:"Incorrect Port Multiplier Status"},
             {fN:"PRCS",  fS:22,        fT:RO, fC:0, fD:"PhyRdy changed Status"},  #Indirect clear
             {            fS: 8, fE:21, fT:RO, fC:0, fD:"Reserved"},
             {fN:"DMPS",  fS: 7,        fT:RWC,fC:0, fD:"Device Mechanical Presence Status"}, #Indirect clear 
             {fN:"PCS",   fS: 6,        fT:RO, fC:0, fD:"Port Connect Change Status"}, #Indirect clear 
             {fN:"DPS",   fS: 5,        fT:RWC,fC:0, fD:"Descriptor Processed"}, 
             {fN:"UFS",   fS: 4,        fT:RO, fC:0, fD:"Unknown FIS"},  #Indirect clear
             {fN:"SDBS",  fS: 3,        fT:RWC,fC:0, fD:"Set Device Bits Interrupt - Set Device bits FIS with 'I' bit set"},
             {fN:"DSS",   fS: 2,        fT:RWC,fC:0, fD:"DMA Setup FIS Interrupt - DMA Setup FIS received with 'I' bit set"},
             {fN:"PSS",   fS: 1,        fT:RWC,fC:0, fD:"PIO Setup FIS Interrupt - PIO Setup FIS received with 'I' bit set"},
             {fN:"DHRS",  fS: 0,        fT:RWC,fC:0, fD:"D2H Register FIS Interrupt - D2H Register FIS received with 'I' bit set"}]}, 
        {rN:"PxIE",   rS:0x14, rE:0x17,              rD:"Port x Interrupt Enable", rC:
            [{fN:"CPDE",  fS:31,        fT:RW, fC:0, fD:"Cold Port Detect Enable"},
             {fN:"TFEE",  fS:30,        fT:RW, fC:0, fD:"Task File Error Enable"},
             {fN:"HBFE",  fS:29,        fT:RW, fC:0, fD:"Host Bus (PCI) Fatal Error Enable"},
             {fN:"HBDE",  fS:28,        fT:RW, fC:0, fD:"ECC Error R/W System Memory Enable"},
             {fN:"IFE",   fS:27,        fT:RW, fC:0, fD:"Interface Fatal Error Enable (sect. 6.1.2)"},
             {fN:"INFE",  fS:26,        fT:RW, fC:0, fD:"Interface Non-Fatal Error Enable (sect. 6.1.2)"},
             {            fS:25,        fT:RO, fC:0, fD:"Reserved"},
             {fN:"OFE",   fS:24,        fT:RW, fC:0, fD:"Overflow Enable"},
             {fN:"IPME",  fS:23,        fT:RW, fC:0, fD:"Incorrect Port Multiplier Enable"},
             {fN:"PRCE",  fS:22,        fT:RW, fC:0, fD:"PhyRdy changed Enable"},  #Indirect clear
             {            fS: 8, fE:21, fT:RO, fC:0, fD:"Reserved"},
             {fN:"DMPE",  fS: 7,        fT:RO, fC:0, fD:"Device Mechanical Presence Interrupt Enable"}, #Indirect clear 
             {fN:"PCE",   fS: 6,        fT:RW, fC:0, fD:"Port Connect Change Interrupt Enable"}, #Indirect clear 
             {fN:"DPE",   fS: 5,        fT:RW, fC:0, fD:"Descriptor Processed Interrupt Enable"}, 
             {fN:"UFE",   fS: 4,        fT:RW, fC:0, fD:"Unknown FIS"},  #Indirect clear
             {fN:"SDBE",  fS: 3,        fT:RW, fC:0, fD:"Device Bits Interrupt Enable"},
             {fN:"DSE",   fS: 2,        fT:RW, fC:0, fD:"DMA Setup FIS Interrupt Enable"},
             {fN:"PSE",   fS: 1,        fT:RW, fC:0, fD:"PIO Setup FIS Interrupt Enable"},
             {fN:"DHRE",  fS: 0,        fT:RW, fC:0, fD:"D2H Register FIS Interrupt Enable"}]}, 
            
        {rN:"PxCMD",   rS:0x18, rE:0x1b,              rD:"Port x Command and Status", rC:
            [{fN:"ICC",   fS:28, fE:31, fT:RW, fC:0, fD:"Interface Communication Control"},
                                                      # Only act if Link Layer in L_IDLE or L_NoCommPower states
                                                      # 0x8 - DevSleep
                                                      # 0x6 - Slumber
                                                      # 0x2 - Partial
                                                      # 0x1 - Active
                                                      # 0x0 - No-Op/Idle
                                                      # All other commands reserved
             {fN:"ASP",   fS:27,        fT:RO, fC:0, fD:"Aggressive Slumber/Partial - not implemented"},
             {fN:"ALPE",  fS:26,        fT:RO, fC:0, fD:"Aggressive Link Power Management Enable - not implemented"},
             {fN:"DLAE",  fS:25,        fT:RW, fC:0, fD:"Drive LED on ATAPI enable"},
             {fN:"ATAPI", fS:24,        fT:RW, fC:0, fD:"Device is ATAPI (for activity LED)"},
             {fN:"APSTE", fS:23,        fT:RW, fC:0, fD:"Automatic Partial to Slumber Transitions Enabled"},
             {fN:"FBSCP", fS:22,        fT:RO, fC:0, fD:"FIS-Based Switching Capable Port - not implemented"},
             {fN:"ESP",   fS:21,        fT:RO, fC:1, fD:"External SATA port"},
             {fN:"CPD",   fS:20,        fT:RO, fC:0, fD:"Cold Presence Detection"},
             {fN:"MPSP",  fS:19,        fT:RO, fC:0, fD:"Mechanical Presence Switch Attached to Port"},
             {fN:"HPCP",  fS:18,        fT:RO, fC:1, fD:"Hot Plug Capable Port"},
             {fN:"PMA",   fS:17,        fT:RW, fC:0, fD:"Port Multiplier Attached - not implemented (software should write this bit)"},
             {fN:"CPS",   fS:16,        fT:RO, fC:0, fD:"Cold Presence State"},
             {fN:"CR",    fS:15,        fT:RO, fC:0, fD:"Command List Running (section 5.3.2)"},
             {fN:"FR",    fS:14,        fT:RO, fC:0, fD:"FIS Receive Running (section 10.3.2)"},
             {fN:"MPSS",  fS:13,        fT:RO, fC:0, fD:"Mechanical Presence Switch State"},
             {fN:"CCS",   fS: 8, fE:12, fT:RO, fC:0, fD:"Current Command Slot (when PxCMD.ST 1-> ) should be reset to 0, when 0->1 - highest priority is 0"},
             {            fS: 5, fE: 7, fT:RO, fC:0, fD:"Reserved"},
             {fN:"FRE",   fS: 4,        fT:RW, fC:0, fD:"FIS Receive Enable (enable after FIS memory is set)"},
             {fN:"CLO",   fS: 3,        fT:RW1,fC:0, fD:"Command List Override"},
             {fN:"POD",   fS: 2,        fT:RO, fC:1, fD:"Power On Device (RW with Cold Presence Detection)"},
             {fN:"SUD",   fS: 1,        fT:RO, fC:1, fD:"Spin-Up Device (RW with Staggered Spin-Up Support)"},
             {fN:"ST",    fS: 0,        fT:RW, fC:0, fD:"Start (HBA may process commands). See section 10.3.1"}]}, 
        # 0x1c..0x1f - Reserved
        {rN:"PxTFD",  rS:0x20, rE:0x23,               rD:"Port x Task File Data (copy of error/status from device)", rC:
            [{            fS:16, fE:31, fT:RO, fC:0, fD:"Reserved"},
             {fN:"ERR",   fS: 8, fE:15, fT:RO, fC:0, fD:"Latest Copy of Task File Error Register"},
#             {fN:"STS",   fS: 0, fE: 7, fT:RO, fC:0, fD:"Latest Copy of Task File Status Register"},
#                                                      # bit  7 -    BSY
#                                                      # bits 6..4 - command-specific
#                                                      # bit  3 -    DRQ
#                                                      # bits 1..2 - command-specific
#                                                      # bit  0 -    ERR
             {fN:"STS.BSY",   fS: 7, fE: 7, fT:RO, fC:0, fD:"Latest Copy of Task File Status Register: BSY"},
             {fN:"STS.64",    fS: 4, fE: 6, fT:RO, fC:0, fD:"Latest Copy of Task File Status Register: command-specific bits 4..6 "},
             {fN:"STS.DRQ",   fS: 3, fE: 3, fT:RO, fC:0, fD:"Latest Copy of Task File Status Register: DRQ"},
             {fN:"STS.12",    fS: 1, fE: 2, fT:RO, fC:0, fD:"Latest Copy of Task File Status Register: command-specific bits 1..2 "},
             {fN:"STS.ERR",   fS: 0, fE: 0, fT:RO, fC:0, fD:"Latest Copy of Task File Status Register: ERR"}
             ]}, 
        {rN:"PxSIG",  rS:0x24, rE:0x27,               rD:"Port x Signature (first D2H data after reset)", rC:
            [{fN:"SIG",   fS: 0, fE:31, fT:RO, fC:0xffffffff, fD:"Data in the first D2H Register FIS"},
                                                      # bits 24..31 - LBA High Register
                                                      # bits 16..23 - LBA Mid Register
                                                      # bits  8..15 - LBA Low Register
                                                      # bits  0.. 7 - Sector Count Register
             ]}, 
        {rN:"PxSSTS",  rS:0x28, rE:0x2b,               rD:"Port x SATA Status (SCR0:SStatus)", rC:
            [{            fS:12, fE:31, fT:RO, fC:0, fD:"Reserved"},
             {fN:"IPM",   fS: 8, fE:11, fT:RO, fC:0, fD:"Interface Power Management"},
                                                      # 0 - Device not present or communication not established
                                                      # 1 - Interface in active state
                                                      # 2 - Partial power state
                                                      # 6 - Slumber
                                                      # 8 - DevSleep
             {fN:"SPD",   fS: 4, fE: 7, fT:RO, fC:0, fD:"Interface Speed"},
                                                      # 0 - Device not present or communication not established
                                                      # 1 - Gen 1 speed
                                                      # 2 - Gen 2 speed
                                                      # 3 - Gen 3 speed
             {fN:"DET",   fS: 0, fE: 3, fT:RO, fC:0, fD:"Device Detection (should be detected if COMINIT is received)"},
                                                      # 0 - no device detected and Phy communication not established
                                                      # 1 - device present and detected but Phy communication not established
                                                      # 3 - device present and detected and Phy communication established
                                                      # 4 - Phy in offline mode as a result of interface being disabled or
                                                      #     or running in a BIST loopback mode
             ]}, 

        {rN:"PxSCTL",  rS:0x2c, rE:0x2f,               rD:"Port x SATA Control (SCR2:SControl)", rC:
            [{            fS:20, fE:31, fT:RO, fC:0, fD:"Reserved"},
             {fN:"PMP",   fS:16, fE:19, fT:RO, fC:0, fD:"Port Multiplier Port - not used by AHCI"},
             {fN:"SPM",   fS:12, fE:15, fT:RO, fC:0, fD:"Select Power Management - not used by AHCI"},
             {fN:"IPM",   fS: 8, fE:11, fT:RW, fC:0, fD:"Interface Power Management Transitions Allowed"},
                                                      # 0 - no interface restrictions
                                                      # 1 - Transitions to Partial are disabled
                                                      # 2 - Transitions to Slumber are disabled
                                                      # 4 - Transitions to DevSleep are disabled
                                                      # Other bit-ORed values are possible
             {fN:"SPD",   fS: 4, fE: 7, fT:RW, fC:0, fD:"Interface Highest Speed"},
                                                      # 0 - No Speed Limit
                                                      # 1 - Gen 1 speed only
                                                      # 2 - Gen 2 speed or less
                                                      # 3 - Gen 3 speed or less
             {fN:"DET",   fS: 0, fE: 3, fT:RW, fC:0, fD:"Device Detection Initialization"},
                                                      # 0 - no device detection/initialization requested
                                                      # 1 - Perform interface initialization (same as hard reset)
                                                      # 4 - Disable SATA and put PHY in offline mode
             ]}, 
        {rN:"PxSERR",  rS:0x30, rE:0x34,               rD:"Port x SATA Error (SCR1:SError)", rC:
            [{            fS:27, fE:31, fT:RO, fC:0, fD:"Reserved"},
             {fN:"DIAG.X",fS:26,        fT:RWC,fC:0, fD:"Exchanged (set on COMINIT), reflected in PxIS.PCS"},
             {fN:"DIAG.F",fS:25,        fT:RWC,fC:0, fD:"Unknown FIS"},
             {fN:"DIAG.T",fS:24,        fT:RWC,fC:0, fD:"Transport state transition error"},
             {fN:"DIAG.S",fS:23,        fT:RWC,fC:0, fD:"Link sequence error"},
             {fN:"DIAG.H",fS:22,        fT:RWC,fC:0, fD:"Handshake Error (i.e. Device got CRC error)"},
             {fN:"DIAG.C",fS:21,        fT:RWC,fC:0, fD:"CRC error in Link layer"},
             {fN:"DIAG.D",fS:20,        fT:RWC,fC:0, fD:"Disparity Error - not used by AHCI"},
             {fN:"DIAG.B",fS:19,        fT:RWC,fC:0, fD:"10B to 8B decode error"},
             {fN:"DIAG.W",fS:18,        fT:RWC,fC:0, fD:"COMMWAKE signal was detected"},
             {fN:"DIAG.I",fS:17,        fT:RWC,fC:0, fD:"PHY Internal Error"},
             {fN:"DIAG.N",fS:16,        fT:RWC,fC:0, fD:"PhyRdy changed. Reflected in PxIS.PRCS bit."},
             {            fS:12, fE:15, fT:RO, fC:0, fD:"Reserved"},
             {fN:"ERR.E", fS:11,        fT:RWC,fC:0, fD:"Internal Error"},
             {fN:"ERR.P", fS:10,        fT:RWC,fC:0, fD:"Protocol Error - a violation of SATA protocol detected"},
             {fN:"ERR.C", fS: 9,        fT:RWC,fC:0, fD:"Persistent Communication or Data Integrity Error"},
             {fN:"ERR.T", fS: 8,        fT:RWC,fC:0, fD:"Transient Data Integrity Error (error not recovered by the interface)"},
             {            fS: 2, fE: 7, fT:RO, fC:0, fD:"Reserved"},
             {fN:"ERR.M", fS: 1,        fT:RWC,fC:0, fD:"Communication between the device and host was lost but re-established"},
             {fN:"ERR.I", fS: 0,        fT:RWC,fC:0, fD:"Recovered Data integrity Error"}
             ]}, 
        {rN:"PxSACT",  rS:0x34, rE:0x37,               rD:"Port x SATA Active (SCR3:SActive), only set when PxCMD.ST==1", rC:
            [{fN:"DS",                  fT:RW1,fC:0, fD:"Device Status: bit per Port, for TAG in native queued command"}
             ]}, 

        {rN:"PxCI",    rS:0x38, rE:0x3b,               rD:"Port x Command Issue", rC:
            [{fN:"CI",                  fT:RW1,fC:0, fD:"Command Issued: bit per Port, only set when PxCMD.ST==1, also cleared by PxCMD.ST: 1->0 by soft"}
             ]}, 
        {rN:"PxSNTF",  rS:0x3c, rE:0x3f,               rD:"Port x SATA Notification (SCR4:SNotification)", rC:
            [{            fS:16, fE:31, fT:RO, fC:0, fD:"Reserved"},
             {fN:"PMN",   fS: 0, fE:15, fT:RWC,fC:0, fD:"PM Notify (bit per PM port)"}
             ]}, 
        {rN:"PxFBS",   rS:0x40, rE:0x43,               rD:"Port x FIS-based switching control)", rC:
            [{            fS:20, fE:31, fT:RO, fC:0, fD:"Reserved"},
             {fN:"DWE",   fS:16, fE:19, fT:RO, fC:0, fD:"Device with Error"},
             {fN:"ADO",   fS:12, fE:15, fT:RO, fC:0, fD:"Active Device Optimization"},
             {fN:"DEV",   fS: 8, fE:11, fT:RW, fC:0, fD:"Device To Issue"},
             {            fS: 3, fE: 7, fT:RO, fC:0, fD:"Reserved"},
             {fN:"SDE",   fS: 2,        fT:RO, fC:0, fD:"Single Device Error"},
             {fN:"DEC",   fS: 1,        fT:RW1,fC:0, fD:"Device Error Clear"},
             {fN:"EN",    fS: 0,        fT:RW, fC:0, fD:"Enable"}
             ]}, 
        
        {rN:"PxDEVSLP",rS:0x44, rE:0x47,               rD:"Port x Device Sleep", rC:
            [{            fS:29, fE:31, fT:RO, fC:0, fD:"Reserved"},
             {fN:"DM",    fS:25, fE:28, fT:RO, fC:0, fD:"DITO Multiplier"},
             {fN:"DITO",  fS:15, fE:24, fT:RW, fC:0, fD:"Device Sleep Idle Timeout (section 8.5.1.1.1)"},
             {fN:"MDAT",  fS:10, fE:14, fT:RW, fC:0, fD:"Minimum Device Sleep Assertion Time"},
             {fN:"DETO",  fS: 2, fE: 9, fT:RW, fC:0, fD:"Device Sleep Exit Timeout"},
             {fN:"DSP",   fS: 1,        fT:RO, fC:0, fD:"Device Sleep Present"},
             {fN:"ADSE",  fS: 0,        fT:RO, fC:0, fD:"Aggressive Device Sleep Enable"}
             ]},
        # 0x48..0x6f - reserved
        {rN:"AFI_CACHE",  rS:0x70, rE:0x73,               rD:"Port x Vendor Specific, program AXI cache modes", rC:
            [{            fS: 8, fE:31, fT:RO, fC:0, fD:"Reserved"},
             {fN:"WR_CM", fS: 4, fE: 7, fT:RW, fC:3, fD:"SAXIHP write channel cache mode "},
             {fN:"RD_CM", fS: 0, fE: 3, fT:RW, fC:3, fD:"SAXIHP read channel cache mode "},
             ]},
        {rN:"PGM_AHCI_SM",rS:0x74, rE:0x77,          rD:"Port x Vendor Specific, AHCI state machine", rC:
            [{            fS:25, fE:31, fT:RO, fC:0, fD:"Reserved"},
             {fN:"AnD",   fS:24,        fT:RW, fC:0, fD:"Address/not data for programming AHCI state machine"},
             {            fS:18, fE:23, fT:RO, fC:0, fD:"Reserved"},             
             {fN:"PGM_AD",fS: 0, fE:17, fT:RW, fC:0, fD:"Program address/data for programming AHCI state machine"},
             ]},
        {rN:"PunchTime",  rS:0x78, rE:0x7b,          rD:"Record current time to the datascope", rC:
            [{            fS:3,  fE:31, fT:RO, fC:0, fD:"Reserved"},
             {fN:"TAG",   fS:0,  fE:2,  fT:RW, fC:0, fD:"3-bit tag to add to the recorded timestamp"},
             ]},
        {rN:"PxVS",    rS:0x7c, rE:0x7f,             rD:"Other Port x Vendor Specific", rC:
            [{                          fT:RW, fC:0, fD:"Vendor-specific data - 96 bits"}
             ]},
       
       ]},  
     ]
def create_no_parity (init_data, # numeric data
                      num_bits,    # number of bits in item
                      start_bit,   # bit number to start filling from 
                      full_bram):  # true if ramb36, false - ramb18
    bsize = (0x4000,0x8000)[full_bram]
    bdata = [0  for i in range(bsize)]
    for item in init_data:
        for bt in range (num_bits):
            bdata[start_bit+bt] = (item >> bt) & 1;
        start_bit += num_bits
    data = []
    for i in range (len(bdata)//256):
        d = 0;
        for b in range(255, -1,-1):
            d = (d<<1) +  bdata[256*i+b]
        data.append(d)
#    print(bdata)  
#    print(data)  
    return {'data':data,'data_p':[]}

def print_params(data,out_file_name):
    with open(out_file_name,"w") as out_file:
        for i, v in enumerate(data['data']):
            if v:
                print (", .INIT_%02X (256'h%064X)"%(i,v), file=out_file)
    #    if (include_parity):
        for i, v in enumerate(data['data_p']):
            if v:
                print (", .INITP_%02X (256'h%064X)"%(i,v), file=out_file)
def process_data(verbose = True):
    reg_defaults = [0]*4096 # array of bytes, default value = 0
    bit_types    = [0]*2048 # array of words, default value = 0
    localparams =  []
    field_defines = {} # To interpret register data in the hardware
    for group in src:
        groupName =  group[gN]
        groupStart = group[gS]
        groupEnd =   group[gE]
        if groupStart > groupEnd:
            groupEnd, groupStart = (groupStart, groupEnd)
        try:
            groupDescription= group[gD]
        except:
            groupDescription= ""
            
        if verbose:
            print ("Group %s (%s) 0x%x..0x%x:"%(groupName, groupDescription, groupStart, groupEnd))
        for dataRange in group[gC]:
            try:
                rangeName =  dataRange[rN]
            except:
                rangeName =  ""
            if (not rS in dataRange) and (not rE in dataRange):
                rangeStart = 0
                rangeEnd =   groupEnd - groupStart -1
            else:
                try:
                    rangeStart = dataRange[rS]
                except:
                    rangeStart = dataRange[rE]
                try:
                    rangeEnd = dataRange[rE]
                except:
                    rangeEnd = dataRange[rS]    
            if rangeStart > rangeEnd:
                rangeEnd, rangeStart = (rangeStart, rangeEnd)
                    
            try:
                rangeDescription= dataRange[rD]
            except:
                rangeDescription= ""
            if verbose:
                print ("    Range %s (%s) 0x%x..0x%x:"%(rangeName, rangeDescription, rangeStart, rangeEnd))
            
            grop_range_name = "%s__%s"%(groupName,rangeName)
            field_defines[grop_range_name]=[]
    
            for dataField in dataRange[rC]:
                try:
                    fieldName =  dataField[fN]
                except:
                    fieldName =  ""
                if (not fS in dataField) and (not fE in dataField):
                    fieldStart = 0
                    fieldEnd =   (rangeEnd - rangeStart) * 8 +7 # last bit in bytes
                else:
                    try:
                        fieldStart = dataField[fS]
                    except:
                        fieldStart = dataField[fE]
                    try:
                        fieldEnd = dataField[fE]
                    except:
                        fieldEnd = dataField[fS]    
                if fieldStart > fieldEnd:
                    fieldEnd, fieldStart = (fieldStart, fieldEnd)
                        
                try:
                    fieldDescription= dataField[fD]
                except:
                    fieldDescription= ""
                try:
                    fieldValue = dataField[fC]
                except:
                    fieldValue = 0
                
                if verbose:
                    print ("        Field %s %d..%d, value = 0x%x, type = %s (%s)"%(fieldName, fieldStart, fieldEnd, fieldValue, dataField[fT], fieldDescription))
                # Split field in bytes
                offs=groupStart+rangeStart
                fv = fieldValue << fieldStart
                
                if dataField[fT]   == RO:
                    t = 0
                elif dataField[fT] == RW:
                    t = 1
                elif dataField[fT] == RWC:
                    t = 2
                elif dataField[fT] == RW1:
                    t = 3
                else:
                    raise("ERROR: Invalid field type %s, only RO, RW, RWC and RX1 are valid"%(dataField[fT]))
                ft=0
                for i in range(fieldEnd - fieldStart +1):
                    ft = (ft << 2) | t
                ft <<= (2*fieldStart)    
                
                for b in range (fieldStart//8, fieldEnd//8 + 1):
                    if (b > 0):
                        bs=0
                    else:
                        bs = fieldStart % 8
                    if (b < fieldEnd//8):
                        be = 7
                    else:
                        be = fieldEnd%8
                    bm = 0;
                    for i in range (bs,be+1):
                        bm |= (1 << i) 
                    bv = (fv >> (8*b)) & 0xff
                    
                    bt = (ft >> (16*b)) & 0xffff
                    bm16 = 0;
                    for i in range (bs,be+1):
                        bm16 |= (3 << (2*i)) 
                    
    #                print ("fS = 0x%x, fE=0x%x, fS//8 = 0x%x, fE//8 + 1 = 0x%x,  b=%d, fieldValue=0x%x, bv=0x%x"%(fieldStart, fieldEnd, fieldStart//8,(fieldEnd//8) + 1,b, fieldValue, bv))
                    reg_defaults[offs+b] = ((reg_defaults[offs+b] ^ bv) & bm) ^ reg_defaults[offs+b]
                    if verbose:
                        print ("reg_defaults[0x%x] = 0x%x"%(offs+b,reg_defaults[offs+b]))
                    
                    #bit_types
                    if (offs+b) < len(bit_types):
                        bit_types[offs+b] = ((bit_types[offs+b] ^ bt) & bm16) ^ bit_types[offs+b]
                        if verbose:
                            print ("bit_types[0x%x] = 0x%x"%(offs+b,bit_types[offs+b]))
                fullName=("%s__%s__%s"%(groupName,rangeName,fieldName)).replace(".","__") # no dots in field names
                comment= "%s: %s"%(dataField[fT], fieldDescription)
                dwas = (offs*8 + fieldStart) // 32 # 32-bit address
                dwae = (offs*8 + fieldEnd)   // 32 # 32-bit address
                fe=fieldEnd
                if dwae > dwas:
                    if verbose:
                        print ("***** WARNING: Field %s spans several DWORDs, truncating to the first one"%(fullName))
                    fe = 32*dwas +31 - offs*8 # Later AND fieldValue with field mask
                fieldMask = ((1 << (fe - fieldStart + 1)) -1) << ((offs % 4) * 8 + fieldStart)
                fieldShiftedValue = fieldValue << ((offs % 4) * 8 + fieldStart)
                fieldShiftedValue &= fieldMask
                if fieldName: # Skip reserved fields
                    localparams.append("// %s"%(comment))
                    localparams.append("    localparam %s__ADDR = 'h%x;"%(fullName, dwas))
                    localparams.append("    localparam %s__MASK = 'h%x;"%(fullName, fieldMask))
                    localparams.append("    localparam %s__DFLT = 'h%x;"%(fullName, fieldShiftedValue))
                    field_defines[grop_range_name].append(
                            {'name':            fieldName,
                             'description':     fieldDescription,
                             'dword_address':   dwas,
                             'start_bit':       (offs % 4) * 8 + fieldStart,
                             'num_bits':        fe - fieldStart + 1
                             })
                    if len(field_defines[grop_range_name]) == 1:
                        field_defines[grop_range_name][0]['group_decription']=groupDescription
                        field_defines[grop_range_name][0]['range_decription']=rangeDescription
    localparams.append("")

    return {"reg_defaults":reg_defaults, "bit_types":bit_types,  "localparams":localparams,'field_defines':field_defines}


def save_verilog_files (data):
    
    localparams_txt="\n".join(data['localparams'])
    #print(localparams_txt)
    import os
    print_params(create_no_parity(data['reg_defaults'], 8, 0, True),os.path.abspath(os.path.join(os.path.dirname(__file__), reg_defaults_path)))
    print ("AHCI register defaults are written to        %s"%(os.path.abspath(os.path.join(os.path.dirname(__file__), reg_defaults_path))))
    print_params(create_no_parity(data['bit_types'],   16, 0, True),os.path.abspath(os.path.join(os.path.dirname(__file__), reg_types_path)))
    print ("AHCI register bit field types are written to %s"%(os.path.abspath(os.path.join(os.path.dirname(__file__), reg_types_path))))
    #print(localparams_txt)
    with open(os.path.abspath(os.path.join(os.path.dirname(__file__), localparams_path)),"w") as out_file:
        print(localparams_txt, file=out_file)
    print ("AHCI localparam definitions are written to %s"%(os.path.abspath(os.path.join(os.path.dirname(__file__), localparams_path))))

if __name__ == "__main__": 
    save_verilog_files(process_data())
