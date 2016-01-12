/*******************************************************************************
 * Module: ahci_fsm
 * Date:2016-01-10  
 * Author: andrey     
 * Description: AHCI host+port0 state machine
 *
 * Copyright (c) 2016 Elphel, Inc .
 * ahci_fsm.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  ahci_fsm.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  ahci_fsm #(
//    parameter PREFETCH_ALWAYS =   0,
    parameter READ_REG_LATENCY =  2, // 0 if  reg_rdata is available with reg_re/reg_addr, 2 with re/regen
//    parameter READ_CT_LATENCY =   1, // 0 if  ct_rdata is available with reg_re/reg_addr, 2 with re/regen
    parameter ADDRESS_BITS =     10 // number of memory address bits - now fixed. Low half - RO/RW/RWC,RW1 (2-cycle write), 2-nd just RW (single-cycle)
)(
    input                         hba_rst, // @posedge mclk
    input                         mclk, // for command/status
    // notification from axi_ahci_regs that software has written data to register
    input      [ADDRESS_BITS-1:0] soft_write_addr,  // register address written by software
    input                  [31:0] soft_write_data,  // register data written (after applying wstb and type (RO, RW, RWC, RW1)
    input                         soft_write_en,     // write enable for data write
//    input                         soft_arst,        // reset SATA PHY not relying on SATA clock
   // R/W access to AXI/AHCI registers, shared with ahci_fis_receive and ahci_fis_transmit modules
    output     [ADDRESS_BITS-1:0] regs_addr,
    output                        regs_we,
//   output                 [3:0] regs_wstb, Needed?
    output                  [1:0] regs_re, // [0] - re, [1] - regen
    output                 [31:0] regs_din,
    input                  [31:0] regs_dout,
    
    // direct communication with transposrt, link and phy layers
    input                         phy_ready,     // goes up after comreset,cominit, align, ...
    output                        syncesc_send,  // Send sync escape
    
    // Other signals....
    
    // inputs from the DMA engine
    input                         dma_prd_done, // output (finished next prd)
    input                         dma_prd_irq, // output (finished next prd and prd irq is enabled)
    input                         dma_cmd_busy, // output reg (DMA engine is processing PRDs)
    input                         dma_cmd_done, // output (last PRD is over)
    
    // Communication with ahci_fis_receive (some are unused
    input                         fis_first_vld, // fis_first contains valid FIS header, reset by 'get_*'
    input                   [7:0] fis_type,      // FIS type (low byte in the first FIS DWORD), valid with  'fis_first_vld'
    // Receiving FIS
    output                        get_sig,        // update signature
    output                        get_dsfis,
    output                        get_psfis,
    output                        get_rfis,
    output                        get_sdbfis,
    output                        get_ufis,
    output                        get_data_fis,
    output                        get_ignore,    // ignore whatever FIS (use for DMA activate too?)
    input                         get_fis_busy,  // busy processing FIS 
    input                         get_fis_done,  // done processing FIS (see fis_ok, fis_err, fis_ferr)
    input                         fis_ok,        // FIS done,  checksum OK reset by starting a new get FIS
    input                         fis_err,       // FIS done, checksum ERROR reset by starting a new get FIS
    input                         fis_ferr,      // FIS done, fatal error - FIS too long
    // next commands use register address/data/we for 1 clock cycle - after next to command (commnd - t0, we - t2)
    output                        update_err_sts,// update PxTFD.STS and PxTFD.ERR from the last received regs d2h
    output                        update_prdbc,  // update PRDBC in registers
    output                        clear_bsy_drq, // clear PxTFD.STS.BSY and PxTFD.STS.DRQ, update
    output                        set_bsy,       // set PxTFD.STS.BSY, update
    output                        set_sts_7f,    // set PxTFD.STS = 0x7f, update
    output                        set_sts_80,    // set PxTFD.STS = 0x80 (may be combined with set_sts_7f), update
    output                        decr_dwc,      // decrement DMA Xfer counter // need pulse to 'update_prdbc' to write to registers
    output                 [11:0] decr_DXC_dw,   // decrement value (in DWORDs)
    input                   [7:0] tfd_sts,       // Current PxTFD status field (updated after regFIS and SDB - certain fields)
                                                 // tfd_sts[7] - BSY, tfd_sts[4] - DRQ, tfd_sts[0] - ERR
    input                   [7:0] tfd_err,       // Current PxTFD error field (updated after regFIS and SDB)
    input                         fis_i,         // value of "I" field in received regsD2H or SDB FIS
    input                         sdb_n,         // value of "N" field in received SDB FIS 
    input                         dma_a,         // value of "A" field in received DMA Setup FIS 
    input                         dma_d,         // value of "D" field in received DMA Setup FIS
    input                         pio_i,         // value of "I" field in received PIO Setup FIS
    input                         pio_d,         // value of "D" field in received PIO Setup FIS
    input                   [7:0] pio_es,        // value of PIO E_Status
    // Using even word count (will be rounded up), partial DWORD (last) will be handled by PRD length if needed
    input                  [31:2] xfer_cntr,     // transfer counter in words for both DMA (31 bit) and PIO (lower 15 bits), updated after decr_dwc
    input                         xfer_cntr_zero,// valid next cycle                   
    
    // Communication with ahci_fis_transmit
    // Command pulses to execute states
    output                        fetch_cmd,   // Enter p:FetchCmd, fetch command header (from the register memory, prefetch command FIS)
                                               // wait for either fetch_cmd_busy == 0 or pCmdToIssue ==1 after fetch_cmd
    output                        cfis_xmit,    // transmit command (wait for dma_ct_busy == 0)
    output                        dx_transmit,  // send FIS header DWORD, (just 0x46), then forward DMA data
                                                // transmit until error, 2048DWords or pDmaXferCnt 
    output                        atapi_xmit,   // tarsmit ATAPI command FIS
    input                         done,
    input                         busy,

    output                        clearCmdToIssue, // From CFIS:SUCCESS 
    input                         pCmdToIssue, // AHCI port variable
//    output                        dmaCntrZero, // DMA counter is zero - would be a duplicate to the one in receive module and dwords_sent output
//    input                         syncesc_recv, // These two inputs interrupt transmit
//    input                         xmit_err,     // 
    input                  [ 1:0] dx_err,       // bit 0 - syncesc_recv, 1 - xmit_err  (valid @ xmit_err and later, reset by new command)
    
    input                  [15:0] ch_prdtl,    // Physical region descriptor table length (in entries, 0 is 0)
    input                         ch_c,        // Clear busy upon R_OK for this FIS
    input                         ch_b,        // Built-in self test command
    input                         ch_r,        // reset - may need to send SYNC escape before this command
    input                         ch_p,        // prefetchable - only used with non-zero PRDTL or ATAPI bit set
    input                         ch_w,        // Write: system memory -> device
    input                         ch_a,        // ATAPI: 1 means device should send PIO setup FIS for ATAPI command
    input                   [4:0] ch_cfl,      // length of the command FIS in DW, 0 means none. 0 and 1 - illegal,
                                               // maximal is 16 (0x10)
    input                  [11:0] dwords_sent // number of DWORDs transmitted (up to 2048)                                 

);
`include "includes/ahci_localparams.vh" // @SuppressThisWarning VEditor : Unused localparams

/*
Notes:
 Implement sync esc request/ackn in TL (available in LL)
*/
endmodule

