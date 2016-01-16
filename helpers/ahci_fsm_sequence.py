#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import print_function
from __future__ import division
# Copyright (C) 2016, Elphel.inc.
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
__copyright__ = "Copyright 2016, Elphel, Inc."
__license__ = "GPL"
__version__ = "3.0+"
__maintainer__ = "Andrey Filippov"
__email__ = "andrey@elphel.com"
__status__ = "Development"
import sys
LBL= "Label"
ACT="Action"
IF="If"
GOTO= "Goto"
ADR = "Address"
NOP = "NOP"
sequence = [{LBL:'POR',      ADR: 0x0,  ACT: NOP},
            {                           GOTO:'H:Init'},
            {LBL:'HBA_RST',  ADR: 0x2,  ACT: NOP},
            {                           GOTO:'H:Init'},
            
            {LBL:'PORT_RST', ADR: 0x4,  ACT: NOP},
            {                           GOTO:'H:Init'},
            
            {LBL:'COMINIT',  ADR: 0x6, ACT: NOP},
            {                           GOTO:'P:Cominit'},

            {LBL:'ST_CLEARED',ADR: 0x6, ACT: NOP}, # TODO: make sure this jump is not from P:Init
            {                           GOTO:'P:StartBitCleared'},
            

            {LBL:'H:Init',              ACT: NOP},
            {                           GOTO:'H:WaitForAhciEnable'},

            {LBL:'H:WaitForAhciEnable', ACT: NOP},
            {                           GOTO:'H:Idle'}, # GHC.AE is always on 

            {LBL:'H:Idle',              ACT: NOP},
            {                           GOTO:'P:Init'}, #All required actions for H* are done in hardware, just go to port initialization

            {LBL:'P:Init',              ACT: 'PFSM'},               # pfsm_started HBA init done, port FSM started 
            {                           ACT: 'PSCI0'},              # pxci0_clear, reset both (pIssueSlot:=32) and PxCI[0]
            {                           ACT: 'CLEAR_BSY_SET_DRQ'},  # frcv_clear_bsy_set_drq
            {                           ACT: 'SET_STS_7F'},         # frcv_set_sts_7f
            {                           ACT: 'SET_UPDATE_SIG'},     #  #frcv_set_update_sig
            {                           ACT: 'XMIT_COMRESET'},      # Now does it on reset. See if it is possible to transmit COMRESET w/o reset
            {                           GOTO:'P:NotRunning'},

            {LBL:'P:NotRunning',        ACT: 'NOP'},  # 'PSCI0'}, # pxci0_clear, - should not be here as it updates soft registers?
            {IF:'SCTL_DET_CHANGED_TO_4',GOTO:'P:Offline'},   #4
            {IF:'SCTL_DET_CHANGED_TO_1',GOTO:'P:StartComm'}, #5
# Transition 8.  PxCMD.FRE written to ‘1’ from a ‘0’ and previously processed Register FIS is in receive FIFO and PxSERR.DIAG.X = ‘0’
# can not be implemented - it is too late, FIS is already gone. So as we do not move FIS receive area, there is no sense to disable FIS,
# and for the signature we'll always assume FRE is on
            {IF:'ST_NB_ND',             GOTO:'P:Idle'},      #12 : PxCMD.ST & !PxTBD.STS.BSY & !PxTBD.STS.DRQ
            {IF:'FR_D2HR',              GOTO:'NDR:Entry'},   #13 fis_first_vld & fis_type == 0x34 (D2H Register)
            {                           GOTO:'P:NotRunning'},#14
            
            {LBL:'P:Cominit',           ACT: 'NOP'}, # got here asynchronously from COMINIT label
            {                           ACT: 'SET_STS_80'},     # frcv_set_sts_80 (Not clear 0xff or 0x80 should be here?)
            {                           ACT: 'PXSSTS_DET_1'},   # ssts_det_dnp,      // device detected, but phy communication not established
            {                           ACT: 'PXSERR_DIAG_X'},  # sirq_PC,  // RO:  Port Connect Change Status (pulse to set)
#            {IF:'PXIE_PCE',             GOTO:'P:CominitSetIS'}, # Not needed, interrupt
            {                           GOTO:'P:NotRunning'},
            
            {LBL:'P:RegFisUpdate',      ACT: 'NOP'},         #  
            {                           ACT: 'GET_SIG'},     # get_sig
#            {IF: 'pcmd_fre',            GOTO:'P:RegFisPostToMem'}, # pcmd_fre hardware always copies signature FIS to 'memory' if expected
            {                           GOTO:'P:NotRunning'},

            {LBL:'P:RegFisPostToMem',   ACT: 'NOP'},         # Probably not needed, handled at lower level  
            {                           GOTO:'P:NotRunning'},
            
            {LBL:'P:Offline',           ACT: 'SET_OFFLINE'}, # set_offline
            {                           GOTO:'P:NotRunning'},
            
            {LBL:'P:StartBitCleared',   ACT: 'PXCI0_CLEAR'},     # pxci0_clear
            {                           ACT: 'DMA_ABORT'},       # dma_cmd_abort (should eventually clear PxCMD.CR)?
            {                           ACT: 'PCMD_CR_CLEAR'},   # pcmd_cr_reset
            {                           ACT: 'XFER_CNTR_CLEAR'}, # clear_xfer_cntr
            
            {LBL:'P:Idle',              ACT: 'PCMD_CR_SET'},     # pcmd_cr_set
            {IF: 'PXSSTS_DET_NE_3',     GOTO:'P:NotRunning' },   # 1. ssts_det!=3, // device detected, phy communication not established
            {IF: 'PXCI0_NOT_CMDTOISSUE',GOTO:'P:FetchCmd' },     # 2. pxci0 && !pCmdToIssue was pIssueSlot==32, -> p:SelectCmd
            {IF: 'PCTI_CTBAR_XCZ',      GOTO:'CFIS:SyncEscape'}, # 3. pCmdToIssue && ch_r && xfer_cntr_zero
            {IF: 'FIS_DATA',            GOTO:'DR:Entry'},        # 4. fis_first_vld && (fis_type == 'h46)
            {IF: 'FIS',                 GOTO:'NDR:Entry'},       # 5. fis_first_vld # already assumed && ((fis_type != 'h46)
            {IF: 'PCTI_XCZ',            GOTO:'CFIS:Xmit'},       # 6. pCmdToIssue && xfer_cntr_zero
            {                           GOTO:'P:Idle'},          #10. (#7-#9 PM, not implemented)
#P:SelectCmd not implemented, using single slot            
            {LBL:'P:FetchCmd',          ACT:'FETCH_CMD'},        # fetch_cmd (other actions included in ahci_fis_transmit)
            {IF: 'CTBAA_CTBAP',         ACT:'CFIS:PrefetchACMD'},#1. ch_a && ch_p # Note ch_p may be ignored or transition may be ignored
            {IF: 'CTBAP',               ACT:'CFIS:PrefetchPRD'}, #2. ch_p         # Note ch_p may be ignored or transition may be ignored
                                                                 # PxTFD.STS.BSY must be set before issuing a command (or now if predicted)
            {LBL:'P:StartComm',         ACT: 'SET_STS_7F'},         # frcv_set_sts_7f
            {                           ACT: 'SET_UPDATE_SIG'},     #  #frcv_set_update_sig
            {                           ACT: 'XMIT_COMRESET'},      # Now does it on reset. See if it is possible to transmit COMRESET w/o reset
            {IF: 'PXSSTS_DET_EQ_1',     GOTO:'P:StartComm'},
            {                           GOTO:'P:NotRunning'},
#P:PowerOn, P;PwerOff,P:PhyListening - not implemented
#FB:* - Not implemented
#PM:* - Not implemented
            {LBL:'NDR:Entry',           ACT: 'NOP'},
            {IF: 'FIS_ERR',             GOTO:'ERR:Non-fatal'},   # 1. fis_ok
            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},       # 2. fis_ferr
            {                           GOTO:'NDR:Accept'},      # 3.
            
            ]

"""
    input                         fis_ok,        // FIS done,  checksum OK reset by starting a new get FIS
    input                         fis_err,       // FIS done, checksum ERROR reset by starting a new get FIS
    input                         fis_ferr,      // FIS done, fatal error - FIS too long

    input                         fetch_cmd,   // Enter p:FetchCmd, fetch command header (from the register memory, prefetch command FIS)
                                               // wait for either fetch_cmd_busy == 0 or pCmdToIssue ==1 after fetch_cmd

    input                         fis_first_vld, // fis_first contains valid FIS header, reset by 'get_*'
    input                   [7:0] fis_type,      // FIS type (low byte in the first FIS DWORD), valid with  'fis_first_vld'

pcmd_cr_set,    // command list run set
clear_xfer_cntr
pcmd_cr_reset
frcv_clear_xfer_cntr
dma_cmd_abort
    input                         fis_first_vld, // fis_first contains valid FIS header, reset by 'get_*'
    input                   [7:0] fis_type,      // FIS type (low byte in the first FIS DWORD), valid with  'fis_first_vld'

serr_diag_X ==0 , fis_first_vld, 
 (pIssueSlot==32) is the same as (pxci0 == 0), use pxci0_clear (pIssueSlot:=32)
    localparam LABEL_POR =      11'h0;
    localparam LABEL_HBA_RST =  11'h10;
    localparam LABEL_PORT_RST = 11'h20;

"""