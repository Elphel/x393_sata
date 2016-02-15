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
import os
import datetime
LBL= "Label"
ACT="Action"
IF="If"
GOTO= "Goto"
ADDR = "Address"
NOP = "NOP"
actions_cnk =    (11,2)  # 2 hot of 8
conditions_cnk = (8,3)   # 3 hot of 11
#action_decoder_verilog_path=None
action_decoder_verilog_path= '../generated/action_decoder.v'
action_decoder_module_name=  'action_decoder'
condition_mux_verilog_path=  '../generated/condition_mux.v'
condition_mux_module_name=   'condition_mux'
condition_mux_fanout =       8 
code_rom_path=  '../includes/ahxi_fsm_code.vh'
#Set actions, conditions to empty string to rebuild list. Then edit order and put here
actions = ['NOP',
    # CTRL_STAT
    'PXSERR_DIAG_X', 'SIRQ_DHR', 'SIRQ_DP', 'SIRQ_DS', 'SIRQ_IF', 'SIRQ_INF', 'SIRQ_PS', 'SIRQ_SDB', 'SIRQ_TFE', 'SIRQ_UF',
    'PFSM_STARTED', 'PCMD_CR_CLEAR', 'PCMD_CR_SET', 'PXCI0_CLEAR', 'PXSSTS_DET_1', 'SSTS_DET_OFFLINE', 'SCTL_DET_CLEAR',
    # FIS RECEIVE
    'SET_UPDATE_SIG', 'UPDATE_SIG', 'UPDATE_ERR_STS', 'UPDATE_PIO', 'UPDATE_PRDBC', 'CLEAR_BSY_DRQ',
    'CLEAR_BSY_SET_DRQ', 'SET_BSY', 'SET_STS_7F', 'SET_STS_80', 'XFER_CNTR_CLEAR', 'DECR_DWCR', 'DECR_DWCW', 'FIS_FIRST_FLUSH',
    # FIS_TRANSMIT
    'CLEAR_CMD_TO_ISSUE',
    # DMA
    'DMA_ABORT*', 'DMA_PRD_IRQ_CLEAR',
    # SATA TRANSPORT/LINK/PHY
    'XMIT_COMRESET', 'SEND_SYNC_ESC*', 'SET_OFFLINE', 'R_OK', 'R_ERR',
    # FIS TRANSMIT/WAIT DONE
    'FETCH_CMD*', 'ATAPI_XMIT*', 'CFIS_XMIT*', 'DX_XMIT*',
    #FIS RECEIVE/WAIT DONE
    'GET_DATA_FIS*', 'GET_DSFIS*', 'GET_IGNORE*', 'GET_PSFIS*', 'GET_RFIS*', 'GET_SDBFIS*', 'GET_UFIS*']

conditions = [
    #COMPOSITE
    'ST_NB_ND', 'PXCI0_NOT_CMDTOISSUE', 'PCTI_CTBAR_XCZ', 'PCTI_XCZ', 'NST_D2HR', 'NPD_NCA', 'CHW_DMAA',
    # CTRL_STAT
    'SCTL_DET_CHANGED_TO_4', 'SCTL_DET_CHANGED_TO_1', 'PXSSTS_DET_NE_3', 'PXSSTS_DET_EQ_1', 'NPCMD_FRE',
    # FIS RECEIVE
    'FIS_OK', 'FIS_ERR', 'FIS_FERR', 'FIS_EXTRA', 'FIS_FIRST_INVALID', 'FR_D2HR', 'FIS_DATA', 'FIS_ANY',
    'NB_ND_D2HR_PIO', 'D2HR', 'SDB', 'DMA_ACT', 'DMA_SETUP', 'BIST_ACT_FE', 'BIST_ACT', 'PIO_SETUP',
    'NB_ND', 'TFD_STS_ERR', 'FIS_I', 'PIO_I', 'NPD', 'PIOX', 'XFER0', 'PIOX_XFER0',
    # FIS_TRANSMIT
    'CTBAA_CTBAP', 'CTBAP', 'CTBA_B', 'CTBA_C', 'TX_ERR', 'SYNCESC_ERR',
    # DMA
    'DMA_PRD_IRQ_PEND',
    # SATA TRANSPORT/LINK/PHY
    'X_RDY_COLLISION'] # TODO: set/reset

#actions = []
#conditions = []

sequence = [{LBL:'POR',      ADDR: 0x0, ACT: NOP},
            {                           GOTO:'H:Init'},
            {LBL:'HBA_RST',  ADDR: 0x2, ACT: NOP},
            {                           GOTO:'H:Init'},
            
            {LBL:'PORT_RST', ADDR: 0x4, ACT: NOP},
            {                           GOTO:'H:Init'},
            
            {LBL:'COMINIT',  ADDR: 0x6, ACT: NOP},
            {                           GOTO:'P:Cominit'},

            {LBL:'ST_CLEARED',ADDR: 0x8,ACT: NOP}, # TODO: make sure this jump is not from P:Init
            {                           GOTO:'P:StartBitCleared'},
            

            {LBL:'H:Init',              ACT: NOP},
            {                           GOTO:'H:WaitForAhciEnable'},

            {LBL:'H:WaitForAhciEnable', ACT: NOP},
            {                           GOTO:'H:Idle'}, # GHC.AE is always on 

            {LBL:'H:Idle',              ACT: NOP},
            {                           GOTO:'P:Init'}, #All required actions for H* are done in hardware, just go to port initialization

            {LBL:'P:Init',              ACT: 'PFSM_STARTED'},        # pfsm_started HBA init done, port FSM started 
            {                           ACT: 'PXCI0_CLEAR'},         # pxci0_clear, reset both (pIssueSlot:=32) and PxCI[0]
            {                           ACT: 'CLEAR_BSY_SET_DRQ'},   # clear_bsy_set_drq
            {                           ACT: 'SET_STS_7F'},          # set_sts_7f
            {                           ACT: 'SET_UPDATE_SIG'},      # set_update_sig
            {                           ACT: 'XMIT_COMRESET'},       # comreset_send (not yet implemented) Now does it on reset. See if it is possible to transmit COMRESET w/o reset
            {                           GOTO:'P:NotRunning'},

            {LBL:'P:NotRunningGarbage', ACT: 'FIS_FIRST_FLUSH'},     # fis_first_flush (FIFO output has data, but not FIS head
            #TODO - add to some error? Now silently skips
            {                           GOTO:'P:NotRunning'},

            {LBL:'P:NotRunning',        ACT: 'NOP'},                 # 'PXCI0_CLEAR'},    # pxci0_clear, - should not be here as it updates soft registers?
            {IF: 'FIS_FIRST_INVALID',   GOTO:'P:NotRunningGarbage'}, 
            {IF:'SCTL_DET_CHANGED_TO_4',GOTO:'P:Offline'},           #4
            {IF:'SCTL_DET_CHANGED_TO_1',GOTO:'P:StartComm'},         #5
# Transition 8.  PxCMD.FRE written to ‘1’ from a ‘0’ and previously processed Register FIS is in receive FIFO and PxSERR.DIAG.X = ‘0’
# can not be implemented - it is too late, FIS is already gone. So as we do not move FIS receive area, there is no sense to disable FIS,
# and for the signature we'll always assume FRE is on
            {IF:'ST_NB_ND',             GOTO:'P:Idle'},              #12 : PxCMD.ST & !PxTFD.STS.BSY & !PxTFD.STS.DRQ
            {IF:'FR_D2HR',              GOTO:'NDR:Entry'},           #13 fis_first_vld & fis_type == 0x34 (D2H Register)
            {                           GOTO:'P:NotRunning'},        #14
            
            {LBL:'P:Cominit',           ACT: 'NOP'}, # got here asynchronously from COMINIT label
            {                           ACT: 'SET_STS_80'},          # set_sts_80 (Not clear 0xff or 0x80 should be here?)
            {                           ACT: 'PXSSTS_DET_1'},        # ssts_det_dnp,      // device detected, but phy communication not established
            {                           ACT: 'PXSERR_DIAG_X'},       # sirq_PC,  // RO:  Port Connect Change Status (pulse to set)
#            {IF:'PXIE_PCE',             GOTO:'P:CominitSetIS'},     # Not needed, interrupt
            {                           GOTO:'P:NotRunning'},
            
            {LBL:'P:RegFisUpdate',      ACT: 'GET_RFIS*'},           # get_rfis
            {IF: 'FIS_ERR',             GOTO:'ERR:Non-Fatal'},       # 1. fis_err
            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},           # 2. fis_ferr
            {                           GOTO:'P:RegFisAccept'},

            {LBL:'P:RegFisAccept',      ACT: 'R_OK'},                # send R_OK
            {                           ACT: 'UPDATE_SIG'},          # update_sig
            {                           ACT: 'UPDATE_ERR_STS'},      # update_err_sts
            {IF: 'FIS_I',               GOTO:'P:RegFisSetIS'},       # ** Not it docs - setting DHRS interrupt if "i" bit was set in D2HR FIS
            {                           GOTO:'P:NotRunning'},
# Not in documentation - do we need to issue DWRS interrupt if "i" bit is set? Adding such state
            {LBL:'P:RegFisSetIS',       ACT: 'SIRQ_DHR'},            # sirq_DHR
            {                           GOTO:'P:NotRunning'},
            
#            {IF: 'PCMD_FRE',            GOTO:'P:RegFisPostToMem'},  # pxcmd_fre hardware always copies signature FIS to 'memory' if expected

#            {LBL:'P:RegFisPostToMem',   ACT: 'NOP'},                # Probably not needed, handled at lower level  
#            {                           GOTO:'P:NotRunning'},
            
            {LBL:'P:Offline',           ACT: 'SET_OFFLINE'},         # set_offline
            {                           ACT: 'SCTL_DET_CLEAR'},      # sctl_det_reset
            {                           GOTO:'P:NotRunning'},
            
            {LBL:'P:StartBitCleared',   ACT: 'PXCI0_CLEAR'},         # pxci0_clear
            {                           ACT: 'DMA_ABORT*'},          # dma_cmd_abort (should eventually clear PxCMD.CR)?
            {                           ACT: 'PCMD_CR_CLEAR'},       # pcmd_cr_reset
            {                           ACT: 'XFER_CNTR_CLEAR'},     # clear_xfer_cntr
            
            {LBL:'P:IdleGarbage',       ACT: 'FIS_FIRST_FLUSH'},     # fis_first_flush (FIFO output has data, but not FIS head
            #TODO - add to some error? Now silently skips
            {                           GOTO:'P:Idle'},
            
            {LBL:'P:Idle',              ACT: 'PCMD_CR_SET'},         # pcmd_cr_set
            {IF: 'PXSSTS_DET_NE_3',     GOTO:'P:NotRunning' },       # 1. ssts_det!=3, // device detected, phy communication not established
            {IF: 'PXCI0_NOT_CMDTOISSUE',GOTO:'P:FetchCmd' },         # 2. pxci0 && !pCmdToIssue was pIssueSlot==32, -> p:SelectCmd
            {IF: 'PCTI_CTBAR_XCZ',      GOTO:'CFIS:SyncEscape'},     # 3. pCmdToIssue && ch_r && xfer_cntr_zero
            {IF: 'FIS_FIRST_INVALID',   GOTO:'P:IdleGarbage'}, 
            {IF: 'FIS_DATA',            GOTO:'DR:Entry'},            # 4. fis_first_vld && (fis_type == 'h46)
            {IF: 'FIS_ANY',             GOTO:'NDR:Entry'},           # 5. fis_first_vld  # already assumed && ((fis_type != 'h46)
            {IF: 'PCTI_XCZ',            GOTO:'CFIS:Xmit'},           # 6. pCmdToIssue && xfer_cntr_zero
            {                           GOTO:'P:Idle'},              #10. (#7-#9 PM, not implemented)
#P:SelectCmd not implemented, using single slot            
            {LBL:'P:FetchCmd',          ACT: 'FETCH_CMD*'},          # fetch_cmd (other actions included in ahci_fis_transmit)
            #ahci_fis_transmit already processes ch_p. ATAPI data is always preloaded, prd - if ch_p
            {IF: 'CTBAA_CTBAP',         GOTO:'CFIS:PrefetchACMD'},   # 1. ch_a && ch_p # Note ch_p may be ignored or transition may be ignored
            {IF: 'CTBAP',               GOTO:'CFIS:PrefetchPRD'},    # 2. ch_p         # Note ch_p may be ignored or transition may be ignored
            {                           GOTO:'P:Idle'},              # 3. PxTFD.STS.BSY must be set before issuing a command (or now if predicted)
            
            {LBL:'P:StartComm',         ACT: 'SET_STS_7F'},          # frcv_set_sts_7f
            {                           ACT: 'SET_UPDATE_SIG'},      #  #frcv_set_update_sig
            {                           ACT: 'XMIT_COMRESET'},       # Now does it on reset. See if it is possible to transmit COMRESET w/o reset
            {                           ACT: 'SCTL_DET_CLEAR'},      # sctl_det_reset
            {IF: 'PXSSTS_DET_EQ_1',     GOTO:'P:StartComm'},
            {                           GOTO:'P:NotRunning'},
#New states, because FIS needs to be read in befor R_OK
            {LBL:'P:OkIdle',            ACT: 'R_OK'},                # send_R_OK to device
            {                           GOTO:'P:Idle'},              # (was directly from NDR:Accept.4

            {LBL:'P:OkNotRunning',      ACT: 'R_OK'},                # send_R_OK to device
            {                           GOTO:'P:NotRunning'},        # (was directly from NDR:Accept.4

#P:PowerOn, P;PwerOff,P:PhyListening - not implemented
#FB:* - Not implemented
#PM:* - Not implemented
            {LBL:'PM:Aggr',             ACT: 'NOP'},                 # Just as a placeholder
            {                           GOTO:'P:Idle'},              #1
            

            {LBL:'NDR:Entry',           ACT: 'NOP'},
#            {IF: 'FIS_ERR',             GOTO:'ERR:Non-Fatal'},      # 1. fis_err
#            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},          # 2. fis_ferr
            {                           GOTO:'NDR:Accept'},          # 4.

            {LBL:'NDR:IgnoreNR',        ACT: 'GET_IGNORE*'},          # get_ignore This one is not in docs, just to empty FIS FIFO
            {IF: 'FIS_ERR',             GOTO:'ERR:Non-Fatal'},       # 1. fis_err
            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},           # 2. fis_ferr
            {                           GOTO:'P:OkIdle'},            #

            {LBL:'NDR:IgnoreIdle',      ACT: 'GET_IGNORE*'},          # get_ignore This one is not in docs, just to empty FIS FIFO
            {IF: 'FIS_ERR',             GOTO:'ERR:Non-Fatal'},       # 1. fis_err
            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},           # 2. fis_ferr
            {                           GOTO:'P:OkNotRunning'},      #
            
            
            {LBL:'NDR:Accept',          ACT: 'NOP'}, # ********      # send R_OK after reading in FIS: ACT: 'R_OK'}, # send_R_OK to device
            {IF:'NB_ND_D2HR_PIO',       GOTO:'NDR:IgnoreIdle'},      # 2 :((FIS == FIS_D2HR) || (FIS == FIS_PIO)) && !PxTFD.STS.BSY & !PxTFD.STS.DRQ
            {IF:'NST_D2HR',             GOTO:'P:RegFisUpdate'},      # 3 :!ST && (FIS == FIS_D2HR) TODO: does it mean either BSY or DRQ are 1?
            {IF:'NPCMD_FRE',            GOTO:'NDR:IgnoreNR' },       # 4 !pxcmd_fre (docs: goto P:NotRunning, but we need to clear FIFO)
            {IF:'D2HR',                 GOTO:'RegFIS:Entry' },       # 5 FIS == FIS_D2HR
            {IF:'SDB',                  GOTO:'SDB:Entry' },          # 7 (# 6 skipped)
            {IF:'DMA_ACT',              GOTO:'DX:EntryIgnore' },     # 8 FIS == FIS_DMA_ACT
            {IF:'DMA_SETUP',            GOTO:'DmaSet:Entry' },       # 9 FIS == FIS_DMA_SETUP
            {IF:'BIST_ACT_FE',          GOTO:'BIST:FarEndLoopback'}, # 10 FIS == FIS_BIST_ACT && |bist_bits
            {IF:'BIST_ACT',             GOTO:'BIST:TestOngoing'},    # 11 FIS == FIS_BIST_ACT # && !(|bist_bits)
            {IF:'PIO_SETUP',            GOTO:'PIO:Entry' },          # 12 FIS == FIS_PIO_SETUP
            {                           GOTO:'UFIS:Entry' },         # 13 Unknown FIS (else)
#5.3.6. Command Transfer State            
            {LBL:'CFIS:SyncEscape',     ACT: 'SEND_SYNC_ESC*'},      # syncesc_send, should wait (for syncesc_send_done)
            {                           ACT: 'SET_UPDATE_SIG'},      # set_update_sig
            {                           GOTO:'CFIS:Xmit' },          # 1
            
            {LBL:'CFIS:Xmit',           ACT: 'SET_BSY'},             # set_bsy
            {                           ACT: 'CFIS_XMIT*'},          # cfis_xmit
            {IF: 'X_RDY_COLLISION',     GOTO:'P:Idle'},              # 2. x_rdy_collision_pend
            {IF: 'SYNCESC_ERR',         GOTO:'ERR:SyncEscapeRecv'},  # 4. dx_err[0] (reset by new command)
            
#            {IF: 'FIS_OK',              GOTO:'CFIS:Success'},       # 5. fis_ok - wrong, it was for received FISes
#            {                           GOTO:'ERR:Non-Fatal'},      # 6
            {IF: 'TX_ERR',              GOTO:'ERR:Non-Fatal'},       # dx_err[1] - R_ERR received - non-fatal, retransmit
            {                           GOTO:'CFIS:Success'},        # No errors, R_OK received            
            
                        
            {LBL:'CFIS:Success',        ACT: 'CLEAR_CMD_TO_ISSUE'},  # clearCmdToIssue
            {IF: 'CTBA_B',              GOTO:'BIST:TestOngoing'},    # 1. ch_b
            {IF: 'CTBA_C',              GOTO:'CFIS:ClearCI'},        # 2. ch_c
            {IF: 'CTBAA_CTBAP',         GOTO:'CFIS:PrefetchACMD'},   # 3. ch_a && ch_p # Note ch_p may be ignored or transition may be ignored
            {IF: 'CTBAP',               GOTO:'CFIS:PrefetchPRD'},    # 4. ch_p         # Note ch_p may be ignored or transition may be ignored
            {                           GOTO:'P:Idle'},              # 6.
            
            {LBL:'CFIS:ClearCI',        ACT: 'PXCI0_CLEAR'},         # pxci0_clear, reset both (pIssueSlot:=32) and PxCI[0]
            {                           ACT: 'CLEAR_BSY_DRQ'},       # clear_bsy_drq
            {                           GOTO:'PM:Aggr' },            # 1
            
            # As ahci_fis_transmit processes ch_p, GOTO:'CFIS:Prefetch*' can be shortcut to GOTO:'P:Idle'
            {LBL:'CFIS:PrefetchACMD',   ACT: 'NOP'},                 # Nothing to do as it is already in memory, fetched together with command
            {IF: 'CTBAP',               GOTO:'CFIS:PrefetchPRD'},    # 1. ch_p Note ch_p may be ignored or transition may be ignored
            {                           GOTO:'P:Idle'},              # 3.
            
            {LBL:'CFIS:PrefetchPRD',    ACT: 'NOP'},                 # ahci_fis_transmit processes ch_p, no more actions needed
            {                           GOTO:'P:Idle'},              # 1.

#            {LBL:'CFIS:PrefetchData',   ACT: 'NOP'},                # ahci_fis_transmit-> ahci_dma prefetches data if possible 
#            {                           GOTO:'P:Idle'},             # 1.
#5.3.7 ATAPI Command Transfer States
            {LBL:'ATAPI:Entry',         ACT: 'ATAPI_XMIT*'},         # atapi_xmit, '0->pXferAtapi[pPmpCur]' is done ahci_fis_transmit.
            {IF: 'TX_ERR',              GOTO:'ERR:Fatal'},           # 1. dx_err[1] (reset by new command)
            {                           GOTO:'PIO:Update'},          # 2.
#5.3.8 D2H Register FIS Receive States
            {LBL:'RegFIS:Entry',        ACT: 'GET_RFIS*'},           # get_rfis
            {IF: 'FIS_ERR',             GOTO:'ERR:Non-Fatal'},       # 1. fis_err
            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},           # 2. fis_ferr
            {                           GOTO:'RegFIS:Accept'},       #
            
            {LBL:'RegFIS:Accept',       ACT: 'R_OK'},                # send R_OK
            {                           ACT: 'UPDATE_ERR_STS'},      # update_err_sts
            {IF: 'TFD_STS_ERR',         GOTO:'ERR:FatalTaskfile'},   # 1. tfd_sts[0]
            {IF: 'NB_ND',               GOTO:'RegFIS:ClearCI'},      # 2. PxTFD.STS.BSY =’0’ and PxTFD.STS.DRQ =’0’
            {                           GOTO:'RegFIS:UpdateSig'},    # 3.
            
            {LBL:'RegFIS:ClearCI',      ACT: 'UPDATE_PRDBC'},        # update_prdbc
            {                           ACT: 'PXCI0_CLEAR'},         # pxci0_clear, reset both (pIssueSlot:=32) and PxCI[0]
            {IF: 'FIS_I',               GOTO:'RegFIS:SetIntr'},      # 2. fis_i
            {                           GOTO:'RegFIS:UpdateSig'},    # 3.

            {LBL:'RegFIS:SetIntr',      ACT: 'SIRQ_DHR'},            # sirq_DHR
            {                           GOTO:'RegFIS:UpdateSig'},    # 2. (PxIE/IRQ is handled)
#RegFIS:SetIS, RegFIS:GenIntr are handled by hardware, skipping
            {LBL:'RegFIS:UpdateSig',    ACT: 'UPDATE_SIG'},          # update_sig will only update if pUpdateSig
            {                           GOTO:'PM:Aggr' },            # 1
#RegFIS:SetSig skipped, done in RegFIS:UpdateSig
#5.3.9 PIO Setup Receive States
            {LBL:'PIO:Entry',           ACT: 'GET_PSFIS*'},          # get_psfis, includes all steps 1..9
            {IF: 'FIS_ERR',             GOTO:'ERR:Non-Fatal'},       # 1. fis_err
            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},           # 2. fis_ferr
            {                           GOTO:'PIO:Accept' },
            
            {LBL:'PIO:Accept',          ACT: 'R_OK'},                # get_psfis, includes all steps 1..9
            {IF: 'TFD_STS_ERR',         GOTO:'ERR:FatalTaskfile'},   # 1. tfd_sts[0]
            {IF: 'NPD_NCA',             GOTO:'DX:Entry'},            # 2. pio_d = 0 && ch_a == 0
            {IF: 'NPD',                 GOTO:'ATAPI:Entry'},         # 3. pio_d = 0 , "ch_a == 1" is not needed
            {                           GOTO:'P:Idle' },             # 5.
            
            {LBL:'PIO:Update',          ACT: 'UPDATE_PIO'},          # update_pio -  update PxTFD.STS and PxTFD.ERR from pio_*
            {IF: 'TFD_STS_ERR',         GOTO:'ERR:FatalTaskfile'},   # 1. tfd_sts[0]
            {IF: 'NB_ND',               GOTO:'PIO:ClearCI'},         # 2. PxTFD.STS.BSY =’0’ and PxTFD.STS.DRQ =’0’
            {IF: 'PIO_I',               GOTO:'PIO:SetIntr'},         # 3. pio_i
            {                           GOTO:'P:Idle' },             # 5.
            
            {LBL:'PIO:ClearCI',         ACT: 'UPDATE_PRDBC'},        # update_prdbc
            {                           ACT: 'PXCI0_CLEAR'},         # pxci0_clear, reset both (pIssueSlot:=32) and PxCI[0]
            {IF: 'PIO_I',               GOTO:'PIO:SetIntr'},         # 2. pio_i
            {                           GOTO:'PM:Aggr' },            # 3.
#PIO:Ccc - not implemented
            {LBL:'PIO:SetIntr',         ACT: 'SIRQ_PS'},             # sirq_PS
            {                           GOTO:'PM:Aggr'},             # 1. (PxIE/IRQ is handled)
#PIO:SetIS, PIO:GenIntr are handled by hardware, skipping
#5.3.10 Data Transmit States
            {LBL:'DX:EntryIgnore',      ACT: 'GET_IGNORE*'},          # Read/Ignore FIS in FIFO (not in docs)
            {IF: 'FIS_ERR',             GOTO:'ERR:Non-Fatal'},       # 1. fis_err
            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},           # 2. fis_ferr
            {                           GOTO:'DX:Accept'},           #
            
            {LBL:'DX:Accept',           ACT: 'R_OK'},                # send R_OK
            {                           GOTO:'DX:Entry'},            #

            {LBL:'DX:Entry',            ACT: 'DMA_PRD_IRQ_CLEAR'},   # dma_prd_irq_clear (FIS should be accepted/confirmed)
            {IF: 'PIOX_XFER0',          GOTO:'PIO:Update'},          # 1. pPioXfer && xfer_cntr_zero
            {IF: 'XFER0',               GOTO:'P:Idle'},              # 3. xfer_cntr_zero # && !pPioXfer (implied) 
            {                           GOTO:'DX:Transmit'},         # 4.

            {LBL:'DX:Transmit',         ACT: 'DX_XMIT*'},            # dx_transmit
            {IF: 'SYNCESC_ERR',         GOTO:'ERR:SyncEscapeRecv'},  # 1. dx_err[0] (reset by new command)
            {IF: 'TX_ERR',              GOTO:'ERR:Fatal'},           # 1. dx_err[1] (reset by new command)
            {                           GOTO:'DX:UpdateByteCount'},  # 3. (#2 - skipped PxFBS.EN==1)
            
            {LBL:'DX:UpdateByteCount',  ACT: 'DECR_DWCW'},           # decr_dwc - decrement remaining DWORDS count, increment transferred
            {                           ACT: 'UPDATE_PRDBC'},        # update_prdbc
            {IF: 'DMA_PRD_IRQ_PEND',    GOTO:'DX:PrdSetIntr'},       # 1. dma_prd_irq_pend
            {IF: 'PIOX',                GOTO:'PIO:Update'},          # 2. pPioXfer
            {                           GOTO:'P:Idle'},              # 4. 
            
            {LBL:'DX:PrdSetIntr',       ACT: 'SIRQ_DP'},             # sirq_DP (if any PRD for this FIS requested PRD interrupt)
            {                           ACT: 'DMA_PRD_IRQ_CLEAR'},   # dma_prd_irq_clear
#DX:PrdSetIS, DX:PrdGenIntr skipped as they are handled at lower level            
            {IF: 'PIOX',                GOTO:'PIO:Update'},          # 2. pPioXfer (#1 ->DX:PrdSetIS is handled by hardware)
            {                           GOTO:'P:Idle'},              # 4. 
# 5.3.11 Data Receive States
            {LBL:'DR:Entry',            ACT: 'DMA_PRD_IRQ_CLEAR'},   # dma_prd_irq_clear
            {                           GOTO:'DR:Receive'},
            
            {LBL:'DR:Receive',          ACT: 'GET_DATA_FIS*'},       # get_data_fis
            {IF: 'FIS_ERR',             GOTO:'ERR:Fatal'},           # 3. fis_err - checking for errors first to give some time for fis_extra
                                                                     # to reveal itself from the ahci_dma module (ahci_fis_receive does not need it)
            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},           # 3a.  fis_ferr 
            {IF: 'FIS_EXTRA',           GOTO:'ERR:Non-Fatal'},       # 1.  fis_extra 
            {                           GOTO:'DR:UpdateByteCount'},  # 2. fis_ok implied
            
            {LBL:'DR:UpdateByteCount',  ACT: 'R_OK'},                # send_R_OK to device
            {                           ACT: 'DECR_DWCR'},  # decr_dwc - decrement remaining DWORDS count, increment transferred
            {                           ACT: 'UPDATE_PRDBC'},        # update_prdbc
            {IF: 'DMA_PRD_IRQ_PEND',    GOTO:'DX:PrdSetIntr'},       # 1. dma_prd_irq_pend
            {IF: 'PIOX',                GOTO:'PIO:Update'},          # 2. pPioXfer (#1 ->DX:PrdSetIS is handled by hardware)
            {                           GOTO:'P:Idle'},              # 4. 
            
# 5.3.12 DMA Setup Receive States
            {LBL:'DmaSet:Entry',        ACT: 'GET_DSFIS*'},          # get_dsfis
            {IF: 'FIS_ERR',             GOTO:'ERR:Non-Fatal'},       # 1. fis_err
            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},           # 2. fis_ferr
            {                           GOTO:'DmaSet:Accept'},       # 

            {LBL:'DmaSet:Accept',       ACT: 'R_OK'},                # send R_OK
            {IF: 'FIS_I',               GOTO:'DmaSet:SetIntr'},      # 1. fis_i
            {                           GOTO:'DmaSet:AutoActivate'}, # 2. 
            
            {LBL:'DmaSet:SetIntr',      ACT: 'SIRQ_DS'},             # sirq_DS DMA Setup FIS received with 'I' bit set
            {                           GOTO:'DmaSet:AutoActivate'}, # 2.  (interrupt is handled by hardware)
#DmaSet:SetIS, DmaSet:GenIntr skipped as they are handled at lower level            
            {LBL:'DmaSet:AutoActivate', ACT: 'NOP'},                 # 
            {IF: 'CHW_DMAA',            GOTO:'DmaSet:SetIntr'},      # 1. ch_w && dma_a
            {                           GOTO:'P:Idle' },             # 3.
#5.3.13 Set Device Bits States
            {LBL:'SDB:Entry',           ACT: 'GET_SDBFIS*'},         # get_sdbfis Is in only for Native CC ?
            {IF: 'FIS_ERR',             GOTO:'ERR:Non-Fatal'},       # 1. fis_err
            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},           # 2. fis_ferr
            {                           GOTO:'SDB:Accept' },         # 3.
            
            {LBL:'SDB:Accept',          ACT: 'R_OK'},                # get_sdbfis Is in only for Native CC ?
            {                           ACT: 'UPDATE_ERR_STS'},      # update_err_sts
            {IF: 'TFD_STS_ERR',         GOTO:'ERR:FatalTaskfile'},   # 1. tfd_sts[0]
            {IF: 'FIS_I',               GOTO:'SDB:SetIntr'},         # 3. fis_i
            {                           GOTO:'PM:Aggr' },            # 4.
            
            {LBL:'SDB:SetIntr',         ACT: 'SIRQ_SDB'},            # sirq_SDB 
            {                           GOTO:'PM:Aggr' },            # 5.
#5.3.14 Unknown FIS Receive States
            {LBL:'UFIS:Entry',          ACT: 'GET_UFIS*'},           # get_ufis
            {IF: 'FIS_ERR',             GOTO:'ERR:Non-Fatal'},       # 1. fis_err
            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},           # 2. fis_ferr
            {                           GOTO:'UFIS:Accept' },        # 
            
            {LBL:'UFIS:Accept',         ACT: 'R_OK'},                # get_ufis
            {                           ACT: 'SIRQ_UF'},             # sirq_UF
            {                           GOTO:'P:Idle' },             # 1. (IRQ states are handled)
#UFIS:SetIS, UFIS:GenIntr are handled by hardware, skipping
            
#5.3.15 BIST States 
            {LBL:'BIST:FarEndLoopback', ACT: 'GET_IGNORE*'},         # get_ignore
            {IF: 'FIS_ERR',             GOTO:'ERR:Non-Fatal'},       # 1. fis_err
            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},           # 2. fis_ferr
            {                           GOTO:'BIST:FarEndLoopbackAccept'}, # 1. (IRQ states are handled)

            {LBL:'BIST:FarEndLoopbackAccept', ACT: 'R_OK'},          # send R_OK
            {                           ACT: 'SSTS_DET_OFFLINE'},    # ssts_det_offline
            {                           GOTO:'BIST:TestLoop'},       # 1.
            
            {LBL:'BIST:TestOngoing',    ACT: 'GET_IGNORE*'},         # get_ignore
            {IF: 'FIS_ERR',             GOTO:'ERR:Non-Fatal'},       # 1. fis_err
            {IF: 'FIS_FERR',            GOTO:'ERR:Fatal'},           # 2. fis_ferr
            {                           GOTO:'BIST:TestLoopAccept'}, # 

            {LBL:'BIST:TestLoopAccept', ACT: 'R_OK'},                #
            {                           GOTO:'BIST:TestLoop'},       # 
            
            {LBL:'BIST:TestLoop',       ACT: 'NOP'},                 #
            {                           GOTO:'BIST:TestLoop'},       # 
#5.3.16 Error States
            {LBL:'ERR:SyncEscapeRecv',  ACT: 'CLEAR_BSY_DRQ'},       # clear_bsy_drq
            {                           ACT: 'SIRQ_IF'},             # sirq_IF
            {                           GOTO:'ERR:WaitForClear'  },
            
            {LBL:'ERR:Fatal',           ACT: 'R_ERR'},               # Send R_ERR to device
            {                           ACT: 'SIRQ_IF'},             # sirq_IF
            {                           GOTO:'ERR:WaitForClear'  },
            
            {LBL:'ERR:FatalTaskfile',   ACT: 'SIRQ_TFE'},             # sirq_TFE
            {                           GOTO:'ERR:WaitForClear'  },
            
            {LBL:'ERR:WaitForClear',    ACT: 'NOP'},                 #
            {                           GOTO:'ERR:WaitForClear'  },  # Loop until PxCMD.ST is cleared by software
            
            {LBL:'ERR:Non-Fatal',       ACT: 'NOP'},                 # Do anything else here?
            {                           ACT: 'SIRQ_INF'},            # sirq_INF            
            {                           GOTO:'P:Idle'},              #
            ]
def get_cnk (start,end,level):
    result = []
    for i in range (start,end+1-level):
        if level == 1:
            result.append([i])
        else:
            l = get_cnk(i+1, end,level - 1)
            for r in l:
                result.append ([i]+r)
    return result            
def bin_cnk (n,k):
    bits = get_cnk (0, n, k)
    result = []
    for l in bits:
        d=0
        for b in l:
            d |= (1 << b)
        result.append(d)
    return result        

def condition_mux_verilog(conditions, condition_vals, module_name, fanout, file=None):
    header_template="""/*******************************************************************************
 * Module: %s
 * Date:%s  
 * Author: auto-generated file, see %s
 * Description: Select condition
 *******************************************************************************/

`timescale 1ns/1ps

module %s (
    input        clk,
    input        ce,  // enable recording all conditions
    input [%2d:0] sel,
    output       condition,"""
    v=max(condition_vals.values())
    num_inputs = 0;
    while v:
        num_inputs += 1
        v >>= 1
    maximal_length = max([len(n) for n in conditions])
    numregs = (len(conditions) + fanout) // fanout # one more bit for 'always' (sel == 0)
    header = header_template%(module_name, datetime.date.today().isoformat(), os.path.basename(__file__), module_name, num_inputs-1)
    print(header,file=file)
    for input_name in conditions[:len(conditions)-1]:
        print("    input        %s,"%(input_name),            file=file)
    print("    input        %s);\n"%(conditions[-1]),         file=file)
    print("    wire [%2d:0] masked;"%(len(conditions)),       file=file)
    print("    reg  [%2d:0] registered;"%(len(conditions) -1),file=file)
    if numregs > 1:
        print("    reg  [%2d:0] cond_r;\n"%(numregs-1),file=file)
    else:
        print("    reg          cond_r;\n",file=file)
    
    if numregs > 1:
        print("    assign condition = |cond_r;\n",file=file)
    else:
        print("    assign condition = cond_r;\n",file=file)

    for b in range (len(conditions)):
#       print("    assign masked[%2d] = %s %s"%(b, conditions[b] , " "*(maximal_length - len(conditions[b]))),end="",file=file)
        print("    assign masked[%2d] = registered[%2d] "%(b, b),end="",file=file)
        d = condition_vals[conditions[b]]
        
        for nb in range(num_inputs-1,-1,-1):
            if d & (1 << nb):
                print (" && sel[%2d]"%(nb), end="", file=file)
        print (";", file=file)
    print("    assign masked[%2d] = !(|sel); // always TRUE condition (sel ==0)"%(len(conditions)), file=file)
        
    print  ("\n    always @(posedge clk) begin", file=file)
    print    ("        if (ce) begin", file=file)
    for b in range (len(conditions)):
        print("            registered[%2d] <= %s;"%(b, conditions[b]),file=file)
    print    ("        end", file=file)        

    
    for nb in range (numregs):
        ll = nb * fanout
#        hl = min(ll + fanout, len(conditions)) -1
        hl = min(ll + fanout -1, len(conditions))
        if numregs > 1:
            print ("        cond_r[%2d] <= "%(nb), end="", file=file)
        else:
            print ("        cond_r <= ", end="", file=file)

        if hl > ll:
            print ("|masked[%2d:%2d];"%(hl,ll), file=file)
        else:
            print (" masked[%2d];"%(ll), file=file)
    print ("    end", file=file)
    print("endmodule",file=file)


def action_decoder_verilog(actions, action_vals, module_name, file=None):
    header_template="""/*******************************************************************************
 * Module: %s
 * Date:%s  
 * Author: auto-generated file, see %s
 * Description: Decode sequencer code to 1-hot actions
 *******************************************************************************/

`timescale 1ns/1ps

module %s (
    input        clk,
    input        enable,
    input [%2d:0] data,"""
    v=max(action_vals.values())
    num_inputs = 0;
    while v:
        num_inputs += 1
        v >>= 1
    names= []
    for a in actions[1:]:
        if a.endswith("*"):
            names.append(a[0:-1])
        else:
            names.append(a)
    maximal_length = max([len(n) for n in names])
                    
    header = header_template%(module_name, datetime.date.today().isoformat(), os.path.basename(__file__), module_name, num_inputs-1)
    print(header,file=file)
    for output_name in names[:len(names)-1]:
        print("    output reg   %s,"%(output_name),file=file)
    print("    output reg   %s);\n"%(names[-1]),file=file)
    print ("    always @(posedge clk) begin", file=file)
    for i, name in enumerate(names): # i is one less than action_vals index
        d = action_vals[actions[i+1]]
        print("        %s"%(name + " <= "+(" "*(maximal_length-len(name)))), end="", file=file)
        print ("enable", end="", file=file)
        for nb in range(num_inputs-1,-1,-1):
            if d & (1 << nb):
                print (" && data[%2d]"%(nb), end="", file=file)
        print (";", file=file)
    print ("    end", file=file)
    print("endmodule",file=file)
    
#def code_generator (sequence, actions, action_vals,conditions, condition_vals, labels):
def code_generator (sequence, action_vals, condition_vals, labels):
    wait_act =  0x10000
    last_act =  0x20000
    act_mask =  0x0ffff # actually 0x007ff (11 bits) is enough
    goto_mask = 0x003ff # 10-bit address
    cond_mask = 0xff # before <<
    cond_shift = 10 # 
    jump_mode = False;
    code=[]
    for a, l in enumerate (sequence):
        # checks
        if not jump_mode:
            if (IF in l) or (GOTO in l):
                raise Exception ("Unexpected line %d: %s - was expecting action, not GOTO"%(a,str(l)))
        else:
            if (LBL in l) or (ACT in l) or (ADDR in l):
                jump_mode = False # set ACT mode before processing, set GOTO mode - after processing
                if IF in sequence[a-1]: # first ACT after JUMP
                    raise Exception ("Last jump (%d: %s) should be unconditional GOTO"%(a-1,str(sequence[a-1])))
        d=0
        if not jump_mode:
            if ACT in l:
                act = action_vals[l[ACT]]
                if act != (act & act_mask):
                    raise Exception ("ACT = 0x%x does not fit into designated field (0x%x) in line %d:%s"%(act, act_mask, a,str(l)))
                d=act | (0,wait_act)[l[ACT].endswith('*')]
                if (GOTO in sequence[a+1]):
                    jump_mode = True
                    d |= last_act
        else: # jump mode
            goto = labels[l[GOTO]]
            if goto != (goto & goto_mask):
                raise Exception ("GOTO = 0x%x does not fit into designated field (0x%x) in line %d:%s"%(goto, goto_mask, a,str(l)))
            cond = 0
            if IF in l:
               cond = condition_vals[l[IF]]
            if cond != (cond & cond_mask):
                raise Exception ("IF = 0x%x does not fit into designated field (0x%x) in line %d:%s"%(cond, cond_mask, a,str(l)))
            d = goto | (cond << cond_shift)
        code.append(d)
    return code        

def create_with_parity (init_data,   # numeric data (may be less than full array
                        num_bits,    # number of bits in item, valid:  1,2,4,8,9,16,18,32,36,64,72
#                        start_bit,   # bit number to start filling from 
                        full_bram):  # true if ramb36, false - ramb18
    d = num_bits
    num_bits8 = 1;
    while d > 1:
        d >>= 1
        num_bits8 <<= 1
    bsize = (0x4000,0x8000)[full_bram]
    bdata = [0  for i in range(bsize)]
    sb = 0
    for item in init_data:
        for bt in range (num_bits8):
            bdata[sb+bt] = (item >> bt) & 1;
        sb += num_bits8
    data = []
    for i in range (len(bdata)//256):
        d = 0;
        for b in range(255, -1,-1):
            d = (d<<1) +  bdata[256*i+b]
        data.append(d)
    data_p = []
    num_bits_p = num_bits8 >> 3
    sb = 0
    print ("num_bits=",num_bits)
    print ("num_bits8=",num_bits8)
    print ("num_bits_p=",num_bits_p)
    if num_bits_p:    
        pbsize = bsize >> 3    
        pbdata = [0  for i in range(pbsize)]
        for item in init_data:
#            print ("item = 0x%x, p = 0x%x"%(item,item >> num_bits8))
            for bt in range (num_bits_p):
                pbdata[sb+bt] = (item >> (bt+num_bits8)) & 1;
#                print ("pbdata[%d] = 0x%x"%(sb+bt, pbdata[sb+bt]))
            sb += num_bits_p
        for i in range (len(pbdata)//256):
            d = 0;
            for b in range(255, -1,-1):
                d = (d<<1) +  pbdata[256*i+b]
            data_p.append(d)
#    print(bdata)  
#    print(data)  
#    print(pbdata)  
#    print(data_p)  
    return {'data':data,'data_p':data_p}


def print_params(data,out_file_name):
    with open(out_file_name,"w") as out_file:
        for i, v in enumerate(data['data']):
            if v:
                print (", .INIT_%02X (256'h%064X)"%(i,v), file=out_file)
    #    if (include_parity):
        for i, v in enumerate(data['data_p']):
            if v:
                print (", .INITP_%02X (256'h%064X)"%(i,v), file=out_file)
                        
                 
    
#print (sequence)
ln = 0
while ln < len(sequence):
    if ADDR in sequence[ln]:
        while ln < sequence[ln][ADDR]:
            sequence.insert(ln,{})
            ln += 1
        if sequence[ln][ADDR] < ln:
            print ("Can not place '%s' at line # %d, it is already %d"%(sequence[ln],sequence[ln][ADDR],ln))
    ln += 1

labels = {}
jumps = set()
for ln, line in enumerate(sequence):
    if LBL in line:
        label=line[LBL]
        if label in labels:
            print ("Duplicate label '%s': line #%d and line # %d"%(label, labels[label], ln))
        else:
            labels[label]=ln
    if GOTO in line:
        jumps.add(line[GOTO])

#Using lists, not sets to preserve order
sort_actions = False
sort_conditions = False
if not actions:
    sort_actions = True
    for ln, line in enumerate(sequence):
        if ACT in line:
            if not line[ACT] in actions:
                actions.append(line[ACT])
if not conditions:
    sort_conditions = True
    for ln, line in enumerate(sequence):
        if IF in line:
            if not line[IF] in conditions:
                conditions.append(line[IF])

print ("Checking for undefined labels:")
undef_jumps = []
for label in jumps:
    if not label in labels:
        undef_jumps.append(label)
if undef_jumps:
    print ("Undefined jumps:")
    for i,jump in enumerate(undef_jumps):
        print("%d: '%s'"%(i,jump))
else:
    print ("All jumps are to defined labels")
    
print ("Checking for unused labels:")
unused_labels = []
for label in labels:
    if not label in jumps:
        unused_labels.append(label)
if unused_labels:
    print ("Unused labels:")
    for i,label in enumerate(unused_labels):
        print("%d: '%s'"%(i,label))
else:
    print ("All labels are used")
wait_actions=[]
fast_actions=[]
for a in actions:
    if a.endswith("*"):
#        wait_actions.append(a[:len(a)-1])
        wait_actions.append(a)
    else:
        fast_actions.append(a)
if sort_actions:
    wait_actions.sort()        
    fast_actions.sort()
    if 'NOP' in fast_actions:
        nop = fast_actions.pop(fast_actions.index('NOP'))
        fast_actions = [nop]+fast_actions
    actions = fast_actions + wait_actions
if sort_conditions:
    conditions.sort()    
#Assign values to actions
action_vals={}
vals = bin_cnk (*actions_cnk)
indx = 0
for i, v in enumerate (actions):
    if v == 'NOP':
        action_vals[v]= 0
    else:    
        action_vals[v]= vals[indx]
        indx += 1
#Assign values to conditions
condition_vals={}
vals = bin_cnk (*conditions_cnk)
for i, v in enumerate (conditions):
    condition_vals[v]= vals[i]
    
print ("Number of lines :  %d"%(len(sequence)))
print ("Number of labels : %d"%(len(labels)))
print ("Number of actions : %d"%(len(actions)))
print ("Number of conditions : %d"%(len(conditions)))
#print ("\nActions:")
#for i,a in enumerate(actions):
#    print ("%02d: %s"%(i,a))
print ("\nActions that do not wait for done (%d):"%(len(fast_actions)))
for i,a in enumerate(fast_actions):
#    print ("%02d: %s"%(i,a))
    print ("%s"%(a))
print ("\nActions that wait for done (%d):"%(len(wait_actions)))
for i,a in enumerate(wait_actions):
#    print ("%02d: %s"%(i,a))
    print ("%s"%(a))


print ("\nConditions(%d):"%(len(conditions)))
for i,c in enumerate(conditions):
#    print ("%02d: %s"%(i,c))
    print ("%s"%(c))

#print ("action_vals=",   action_vals)    
#print ("condition_vals=",condition_vals)    

#for i, line in enumerate(sequence):
#    print ("%03x: %s"%(i,line))

if not action_decoder_verilog_path:
    action_decoder_verilog(actions, action_vals, action_decoder_module_name)
else:
    with open(os.path.abspath(os.path.join(os.path.dirname(__file__), action_decoder_verilog_path)),"w") as out_file:
        action_decoder_verilog(actions, action_vals, action_decoder_module_name, out_file)
    print ("AHCI FSM actions decoder is written to %s"%(os.path.abspath(os.path.join(os.path.dirname(__file__), action_decoder_verilog_path))))
    
if not condition_mux_verilog_path:
    condition_mux_verilog(conditions, condition_vals, condition_mux_module_name, condition_mux_fanout)
else:
    with open(os.path.abspath(os.path.join(os.path.dirname(__file__), condition_mux_verilog_path)),"w") as out_file:
        condition_mux_verilog(conditions, condition_vals,condition_mux_module_name, condition_mux_fanout, out_file)
    print ("AHCI FSM conditions multiplexer is written to %s"%(os.path.abspath(os.path.join(os.path.dirname(__file__), condition_mux_verilog_path))))

code = code_generator (sequence, action_vals, condition_vals, labels)

#print_params(create_with_parity(code, 18, 0, False),os.path.abspath(os.path.join(os.path.dirname(__file__), code_rom_path)))
print_params(create_with_parity(code, 18, False),os.path.abspath(os.path.join(os.path.dirname(__file__), code_rom_path)))
print ("AHCI FSM code data is written to %s"%(os.path.abspath(os.path.join(os.path.dirname(__file__), code_rom_path))))


#longest_label = max([len(labels[l]) for l in labels.keys()])
longest_label = max([len(l) for l in labels])
longest_act =   max([len(act) for act in actions])
longest_cond =  max([len(cond) for cond in conditions])
format_act = "%%%ds do %%s%%s"%(longest_label+1) 
format_cond = "%%%ds %%%ds goto %%s"%(longest_label+1, longest_cond+3)
#print ("format_act=", format_act) 
#print ("format_cond=",format_cond) 
print ("\n code:")
for a,c in enumerate(code):
    l = sequence[a]
    if LBL in l:
        print()
    print ("%03x: %05x #"%(a,c),end = "")
    if (ACT in l) or (LBL in l):
        try:
            lbl = l[LBL]+":"
        except:
            lbl = ""
        try:
            act = l[ACT]
        except:
            act = "NOP"
        wait = ""
        if act.endswith('*'):
            wait = ", WAIT DONE"
            act = act[0:-1]
        print(format_act%(lbl,act,wait))    
    else:
        try:
            cond = "if "+l[IF]
        except:
            cond = "always"
        cond += ' '*(longest_cond+3-len(cond))    
        print(format_cond%("",cond,l[GOTO]))    
#    print ("%03x: %05x # %s"%(a,c,str(sequence[a])))

#condition_mux_verilog(conditions, condition_vals, 'condition_mux',100, file=None)
            