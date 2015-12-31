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
import sys
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
fD = "fieldDescription"
fC = "fieldContent"
fT = "fieldType"
RW =  "RW"
RO=   "RO"
RWC = "RWC"
RW1 = "RW1"
# All unspecified ranges/fields default to fT:RO, fC:0 (readonly, reset value = 0)
VID = 0xfffe # What to use for non-PCI "vendorID"?
DID = 0x0001
SSVID = 0xfffe
SSID =  0x0001
IPIN = 0x01 # TODO: Put a real number for "Interrupt pin"
ILINE = 0x00 # Interrupt line - software is supposed to fill it - maybe here we need to put some predefined value?
HBA_OFFS = 0x0
#HBA_PORT0 = 0x100 Not needed, always HBA_OFFS + 0x100
PCIHEAD = 0x180
PMCAP =   0x1C0
ABAR =  0x80000000 + HBA_OFFS
P0CLB = 0x0  # Port 0 CLB address - define here?
P0FB = 0x0  # Port 0 received FIS address - define here?

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
            [{fN:"RID",               fT:RO,  fC:1, fD:"HBA Revision ID"}]},
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
             {fN:"SSVID", fS:0,  fE:15, fT:RO, fC:SVID, fD:"SubSystem Vendor ID"}]},
         {rN:"EROM", rS:0x30, rE:0x33,                  rD:"Extension ROM (optional)", rC:
            [{fN:"RBA",                fT:RO,  fC:0,    fD:"ROM Base Address"}]},
         {rN:"CAP", rS:0x34,                            rD:"Capabilities Pointer", rC:
            [{fN:"CAP",                fT:RO,  fC:(PMCAP-PCIHEAD), fD:"Capabilities pointer"}]},
          #0x35-0x3b are reserved
         {rN:"INTR", rS:0x3c, rE:0x3d,                  rD:"Interrupt Information", rC:
            [{fN:"IPIN",  fS: 8, fE:15, fT:RO, fC:IPIN, fD:"Interrupt pin"},
             {fN:"ILINE", fS: 0, fE: 7, fT:RW, fC:ILINE,fD:"Interrupt Line"}]},
         {rN:"MGNT", rS:0x3e,                           rD:"Minimal Grant (optional)", rC:
            [{fN:"MGNT",                fT:R0,  fC:0,   fD:"Minimal Grant"}]},
         {rN:"MLAT", rS:0x3f,                           rD:"Maximal Latency (optional)", rC:
            [{fN:"MLAT",                fT:R0,  fC:0,   fD:"Maximal Latency"}]}
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
             {fN:"ISS",   fS:20, fe:23, fT:RO, fC:2, fD:"Interface Maximal speed: 2 - Gen2, 3 - Gen3"},
             {            fS:19,        fT:RO, fC:0, fD:"Reserved"},
             {fN:"SAM",   fS:18,        fT:RO, fC:1, fD:"AHCI only (0 - legacy too)"},
             {fN:"SPM",   fS:17,        fT:RO, fC:0, fD:"Supports Port Multiplier - no"},
             {fN:"FBSS",  fS:16,        fT:RO, fC:0, fD:"Supports FIS-based switching of the Port Multiplier - no"},
             {fN:"PMD",   fS:15,        fT:RO, fC:0, fD:"PIO Multiple DRQ block - no"},
             {fN:"SSC",   fS:14,        fT:RO, fC:0, fD:"Slumber State Capable - no"},
             {fN:"PSC",   fS:13,        fT:RO, fC:0, fD:"Partial State Capable - no"},
             {fN:"NSC",   fS: 8, fe:12, fT:RO, fC:0, fD:"Number of Command Slots, 0-based (0 means 1?)"},
             {fN:"CCCS",  fS: 7,        fT:RO, fC:0, fD:"Command Completion Coalescing  - no"},
             {fN:"EMS",   fS: 6,        fT:RO, fC:0, fD:"Enclosure Management - no"},
             {fN:"SXS",   fS: 5,        fT:RO, fC:1, fD:"External SATA connector - yes"},
             {fN:"NP",    fS: 0, fe: 4, fT:RO, fC:0, fD:"Number of Ports, 0-based (0 means 1?)"}]}, 
        {rN:"GHC",  rS:0x4,  rE:0x07,                rD:"Global HBA Control", rC:
            [{fN:"AE",    fS:31,        fT:RO, fC:1, fD:"AHCI enable (0 - legacy)"},
             {            fS: 3, fe:30, fT:RO, fC:0, fD:"Reserved"},
             {fN:"MRSM",  fS: 2,        fT:RO, fC:0, fD:"MSI Revert to Single Message"},
             {fN:"IE",    fS: 1,        fT:RW, fC:0, fD:"Interrupt Enable (all ports)"},
             {fN:"HR",    fS: 0,        fT:RW1,fC:0, fD:"HBA reset (COMINIT, ...). Set by software, cleared by hardware, section 10.4.3"}]}, 
        {rN:"IS",  rS:0x08, rE:0x0b,                 rD:"Interrupt Status Register", rC:
            [{fN:"IPS",                 fT:RWC,fC:0, fD:"Interrupt Pending Status (per port)"}]}, 
        {rN:"PI",  rS:0x0c, rE:0x0f,                 rD:"Interrupt Status Register", rC:
            [{fN:"PI",                  fT:RO, fC:1, fD:"Ports Implemented"}]}, 
        {rN:"VS",  rS:0x10,  rE:0x13,                rD:"AHCI Verion", rC:
            [{fN:"MJR",   fS:16, fE:31, fT:RO, fC:0x0001, fD:"AHCI Major Verion 1."},
             {fN:"MNR",   fS: 0, fE:15, fT:RO, fC:0x0301, fD:"AHCI Minor Verion 3.1"}]}, 
        {rN:"CCC_CTL",   rS:0x14, rE:0x17,           rD:"Command Completion Coalescing Control", rC:
            [{                          fT:RO, fC:0, fD:"Not Implemented"}]}, 
        {rN:"CCC_PORTS", rS:0x18, rE:0x1b,           rD:"Command Completion Coalescing Ports", rC:
            [{                          fT:RO, fC:0, fD:"Not Implemented"}]}, 
        {rN:"EM_LOC",    rS:0x1c, rE:0x1f,           rD:"Enclosure Management Location", rC:
            [{                          fT:RO, fC:0, fD:"Not Implemented"}]}, 
        {rN:"EM_CTL",    rS:0x20, rE:0x23,           rD:"Enclosure Management Control", rC:
            [{                          fT:RO, fC:0, fD:"Not Implemented"}]}, 

        {rN:"CAP2", rS:0x24,  rE:0x27,                       rD:"HBA Capabilities Extended", rC:
            [{            fs: 6, fE:31, fT:RO, fC:0, fD:"Reserved"},
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
             {            fS: 0, fe: 9, fT:RO, fC:0, fD:"Reserved"}]}, 
        {rN:"PxCLBU", rS:0x04, rE:0x07,              rD:"Port x CLB address, upper 32 bits of 64", rC:
            [{                          fT:RO, fC:0, fD:"Not Implemented"}]}, 
        {rN:"PxFB",   rS:0x8,  rE:0x0b,              rD:"FIS Base Address", rC:
            [{fN:"CLB",   fS: 8, fE:31, fT:RW, fC:P0FB>> 8, fD:"Command List Base Address (1KB aligned)"},
             {            fS: 0, fe: 7, fT:RO, fC:0, fD:"Reserved"}]}, 
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
             {fN:"DMPS",  fS: 7,        fT:RO, fC:0, fD:"Device Mechanical Presence Status"}, #Indirect clear 
             {fN:"PCS",   fS: 6,        fT:RO, fC:0, fD:"Port Connect Change Status"}, #Indirect clear 
             {fN:"DPS",   fS: 5,        fT:RWC,fC:0, fD:"Descriptor Processed"}, 
             {fN:"UFS",   fS: 4,        fT:RO, fC:0, fD:"Unknown FIS"},  #Indirect clear
             {fN:"SDBS",  fS: 3,        fT:RWC,fC:0, fD:"Set Device Bits Interrupt - Set Device bits FIS with 'I' bit set"},
             {fN:"DSS",   fS: 2,        fT:RWC,fC:0, fD:"DMA Setup FIS Interrupt - DMA Setup FIS received with 'I' bit set"},
             {fN:"PSS",   fS: 1,        fT:RWC,fC:0, fD:"PIO Setup FIS Interrupt - PIO Setup FIS received with 'I' bit set"},
             {fN:"DHRS",  fS: 0,        fT:RWC,fC:0, fD:"D2H Register FIS Interrupt - D2H Register FIS received with 'I' bit set"}]}, 
     

       
       
       ]},  
     ]
"""
         {rN:"??", rS:0x06, rE:0x7, rD:"????", rC:
            []},

VID = 0xfffe # What to use for non-PCI "vendorID"?
DID = 0x0001
SSVID = 0xfffe
SSID =  0x0001
IPIN = 0x01 # TODO: Put a real number for "Interrupt pin"
ILINE = 0x00 # Interrupt line - software is supposed to fill it - maybe here we need to put some predefined value?
HBA_OFFS = 0x0
#HBA_PORT0 = 0x100 Not needed, always HBA_OFFS + 0x100
PCIHEAD = 0x180
PMCAP =   0x1C0
ABAR =  0x80000000 + HBA_OFFS
P0CLB = 0x0  # Port 0 CLB address - define here? 
"""