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
            {                           ACT: 'CLEAR_BSY_SET_DRQ'},  # clear_bsy_set_drq
            {                           ACT: 'SET_STS_7F'},         # set_sts_7f
            {                           ACT: 'SET_UPDATE_SIG'},     # set_update_sig
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
            
            {LBL:'P:RegFisUpdate',      ACT: 'GET_RFIS'},       #get_rfis
            {                           ACT: 'UPDATE_SIG'},     # update_sig
#            {IF: 'PCMD_FRE',            GOTO:'P:RegFisPostToMem'}, # pcmd_fre hardware always copies signature FIS to 'memory' if expected
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
            {LBL:'P:FetchCmd',          ACT: 'FETCH_CMD'},        # fetch_cmd (other actions included in ahci_fis_transmit)
            #ahci_fis_transmit already processes ch_p. ATAPI data is always preloaded, prd - if ch_p
            {IF: 'CTBAA_CTBAP',         GOTO:'CFIS:PrefetchACMD'},#1. ch_a && ch_p # Note ch_p may be ignored or transition may be ignored
            {IF: 'CTBAP',               GOTO:'CFIS:PrefetchPRD'}, #2. ch_p         # Note ch_p may be ignored or transition may be ignored
            {                           GOTO:'P:Idle'},          #3. PxTFD.STS.BSY must be set before issuing a command (or now if predicted)
            
            {LBL:'P:StartComm',         ACT: 'SET_STS_7F'},         # frcv_set_sts_7f
            {                           ACT: 'SET_UPDATE_SIG'},     #  #frcv_set_update_sig
            {                           ACT: 'XMIT_COMRESET'},      # Now does it on reset. See if it is possible to transmit COMRESET w/o reset
            {IF: 'PXSSTS_DET_EQ_1',     GOTO:'P:StartComm'},
            {                           GOTO:'P:NotRunning'},
#P:PowerOn, P;PwerOff,P:PhyListening - not implemented
#FB:* - Not implemented
#PM:* - Not implemented
            {LBL:'PM:Aggr',             ACT: 'NOP'},             # Just as a placeholder
            {                           GOTO:'P:Idle'},          #1
            

            {LBL:'NDR:Entry',           ACT: 'NOP'},
            {IF: 'FIS_ERR',             GOTO:'ERR:Non-fatal'},   # 1. fis_err
            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},       # 2. fis_ferr
            {                           GOTO:'NDR:Accept'},      # 4.

            {LBL:'NDR:IgnoreNR',        ACT: 'FIS_IOGNORE'},     # get_ignore This one is not in docs, just to empty FIS FIFO
            {                           GOTO:'P:NotRunning'},    # (was directly from NDR:Accept.4

            {LBL:'NDR:IgnoreIdle',      ACT: 'FIS_IOGNORE'},     # get_ignore This one is not in docs, just to empty FIS FIFO
            {                           GOTO:'P:Idle'},          # (was directly from NDR:Accept.4
            
            {LBL:'NDR:Accept',          ACT: 'R_OK'},            # send_R_OK to device
            {IF:'NB_ND_D2HR_PIO',       GOTO:'NDR:IgnoreIdle'},  # 2 :((FIS == FIS_D2HR) || (FIS == FIS_PIO)) && !PxTBD.STS.BSY & !PxTBD.STS.DRQ
            {IF:'NST_D2HR',             GOTO:'P:RegFisUpdate'},  # 3 :!ST && (FIS == FIS_D2HR) TODO: does it mean either BSY or DRQ are 1?
            {IF:'NPCMD_FRE',            GOTO:'NDR:IgnoreNR' },   # 4 !pcmd_fre (docs: goto P:NotRunning, but we need to clear FIFO)
            {IF:'D2HR',                 GOTO:'RegFIS:Entry' },   # 5 FIS == FIS_D2HR
            {IF:'SDB',                  GOTO:'SDB:Entry' },      # 7 (# 6 skipped)
            {IF:'DMA_ACT',              GOTO:'DX:Entry' },       # 8 FIS == FIS_DMA_ACT
            {IF:'DMA_SETUP',            GOTO:'DmaSet:Entry' },   # 9 FIS == FIS_DMA_SETUP
            {IF:'BIST_ACT_FE',          GOTO:'BIST:FarEndLoopback'},#10 FIS == FIS_BIST_ACT && |bist_bits TODO:get_ignore to read in FIS
            {IF:'BIST_ACT',             GOTO:'BIST:TestOngoing'},# 11 FIS == FIS_BIST_ACT && |bist_bits TODO:get_ignore to read in FIS
            {IF:'PIO_SETUP',            GOTO:'PIO:Entry' },      # 12 FIS == FIS_PIO_SETUP
            {                           GOTO:'UFIS:Entry' },     # 13 Unknown FIS (else)
#5.3.6. Command Transfer State            
            {LBL:'CFIS:SyncEscape',     ACT: 'SEND_SYNC_ESC'},   # syncesc_send, should wait (for syncesc_send_done)
            {                           ACT: 'SET_UPDATE_SIG'},  # set_update_sig
            {                           GOTO:'CFIS:Xmit' },      # 1
            
            {LBL:'CFIS:Xmit',           ACT: 'SET_BSY'},            # set_bsy
            {                           ACT: 'CFIS_XMIT'},          # cfis_xmit
            {IF: 'X_RDY_COLLISION',     GOTO:'P:Idle'},             # 2. x_rdy_collision_pend
            {IF: 'SYNCESC_RECV',        GOTO:'ERR:SyncEscapeRecv'}, # 4. syncesc_recv
            {IF: 'FIS_OK',              GOTO:'CFIS:SUCCESS'},       # 5. fis_ok
            {                           GOTO:'ERR:Non-fatal'},      # 6
            
            {LBL:'CFIS:Success',        ACT: 'CLEAR_CMD_TO_ISSUE'}, # clearCmdToIssue
            {IF: 'CTBA_B',              GOTO:'BIST:TestOngoing'}, # 1. ch_b
            {IF: 'CTBA_C',              GOTO:'CFIS:ClearCI'},     # 2. ch_c
            {IF: 'CTBAA_CTBAP',         GOTO:'CFIS:PrefetchACMD'},# 3. ch_a && ch_p # Note ch_p may be ignored or transition may be ignored
            {IF: 'CTBAP',               GOTO:'CFIS:PrefetchPRD'}, # 4. ch_p         # Note ch_p may be ignored or transition may be ignored
            {                           GOTO:'P:Idle'},           # 6.
            
            {LBL:'CFIS:CLearCI',        ACT: 'PSCI0'},            # pxci0_clear, reset both (pIssueSlot:=32) and PxCI[0]
            {                           ACT: 'CLEAR_BSY_DRQ'},    # clear_bsy_drq
            {                           GOTO:'PM:Aggr' },         # 1
            
            # As ahci_fis_transmit processes ch_p, GOTO:'CFIS:Prefetch*' can be shortcut to GOTO:'P:Idle'
            {LBL:'CFIS:PrefetchACMD',   ACT: 'NOP'},              # Nothing to do as it is already in memory, fetched together with command
            {IF: 'CTBAP',               GOTO:'CFIS:PrefetchPRD'}, # 1. ch_p Note ch_p may be ignored or transition may be ignored
            {                           GOTO:'P:Idle'},           # 3.
            
            {LBL:'CFIS:PrefetchPRD',    ACT: 'NOP'},              # ahci_fis_transmit processes ch_p, no more actions needed
            {                           GOTO:'P:Idle'},           # 1.

            {LBL:'CFIS:PrefetchData',   ACT: 'NOP'},              # ahci_fis_transmit-> ahci_dma prefetches data if possible 
            {                           GOTO:'P:Idle'},           # 1.
#5.3.7 ATAPI Command Transfer States
            {LBL:'ATAPI:Entry',         ACT: 'ATAPI_XMIT'},       # atapi_xmit, '0->pXferAtapi[pPmpCur]' is done ahci_fis_transmit.
            {IF: 'TX_ERR',              GOTO:'ERR:Fatal'},        # 1. dx_err[1] (reset by new command)
            {                           GOTO:'PIO:Update'},       # 2.
#5.3.8 D2H Register FIS Receive States
            {LBL:'RegFIS:Entry',        ACT: 'GET_RFIS'},         # get_rfis
            {IF: 'TFD_STS_ERR',         GOTO:'ERR:FatalTaskfile'},# 1. tfd_sts[0]
            {IF: 'NB_ND',               GOTO:'RegFIS:ClearCI'},   # 2. PxTFD.STS.BSY =’0’ and PxTFD.STS.DRQ =’0’
            {                           GOTO:'RegFIS:UpdateSig'}, # 3.
            
            {LBL:'RegFIS:ClearCI',      ACT: 'UPDATE_PRDBC'},     # update_prdbc
            {                           ACT: 'PSCI0'},            # pxci0_clear, reset both (pIssueSlot:=32) and PxCI[0]
            {IF: 'FIS_I',               GOTO:'RegFIS:SetIntr'},   # 2. fis_i
            {                           GOTO:'RegFIS:UpdateSig'}, # 3.

            {LBL:'RegFIS:SetIntr',      ACT: 'SIRQ_DHR'},         # sirq_DHR
            {                           GOTO:'RegFIS:UpdateSig'}, # 2. (PxIE/IRQ is handled)
#RegFIS:SetIS, RegFIS:GenIntr are handled by hardware, skipping
            {LBL:'RegFIS:UpdateSig',    ACT: 'UPDATE_SIG'},       # update_sig will only update if pUpdateSig
            {                           GOTO:'PM:Aggr' },         # 1
#RegFIS:SetSig skipped, done in RegFIS:UpdateSig
#5.3.9 PIO Setup Receive States
            {LBL:'PIO:Entry',           ACT: 'GET_PSFIS'},        # get_psfis, includes all steps 1..9
            {IF: 'TFD_STS_ERR',         GOTO:'ERR:FatalTaskfile'},# 1. tfd_sts[0]
            {IF: 'NPD_NCA',             GOTO:'DX:Entry'},         # 2. pio_d = 0 && ch_a == 0
            {IF: 'NPD',                 GOTO:'ATAPI:Entry'},      # 3. pio_d = 0 , "ch_a == 1" is not needed
            {                           GOTO:'P:Idle' },          # 4
            
            
            
            
            
            
            
            
            
            ]

"""
    output reg                    pio_i,         // value of "I" field in received PIO Setup FIS
    output reg                    pio_d,         // value of "D" field in received PIO Setup FIS
    output                  [7:0] pio_es,        // value of PIO E_Status

sirq_DHR
fis_i
 update_prdbc,  // update PRDBC in registers
    output                  [7:0] tfd_sts,       // Current PxTFD status field (updated after regFIS and SDB - certain fields)
                                                 // tfd_sts[7] - BSY, tfd_sts[4] - DRQ, tfd_sts[0] - ERR

            {LBL:'P:RegFisUpdate',      ACT: 'GET_SIG'},     # update_sig


    input                  [ 1:0] dx_err,       // bit 0 - syncesc_recv, 1 - xmit_err  (valid @ xmit_err and later, reset by new command)

            {IF: 'CTBAA_CTBAP',         ACT:'CFIS:PrefetchACMD'},#1. ch_a && ch_p # Note ch_p may be ignored or transition may be ignored
            {IF: 'CTBAP',               ACT:'CFIS:PrefetchPRD'}, #2. ch_p         # Note ch_p may be ignored or transition may be ignored


    input                         ch_c,        // Clear busy upon R_OK for this FIS
    input                         ch_b,        // Built-in self test command
    input                         ch_r,        // reset - may need to send SYNC escape before this command
    input                         ch_p,        // prefetchable - only used with non-zero PRDTL or ATAPI bit set
    input                         ch_w,        // Write: system memory -> device
    input                         ch_a,        // ATAPI: 1 means device should send PIO setup FIS for ATAPI command
    input                   [4:0] ch_cfl,      // length of the command FIS in DW, 0 means none. 0 and 1 - illegal,

fis_ok
syncesc_recv
x_rdy_collision_pend
    input                         cfis_xmit,    // transmit command (wait for dma_ct_busy == 0)

    input              syncesc_send_done, // "SYNC escape until the interface is quiescent..."

set_update_sig
bist_bits (use get_ignore to read in BIST FIS)
get_ignore
    output                        send_R_OK,    // Should it be originated in this layer SM?
    output                        send_R_ERR,

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