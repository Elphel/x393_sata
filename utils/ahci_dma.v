/*******************************************************************************
 * Module: ahci_dma
 * Date:2016-01-01  
 * Author: andrey     
 * Description: DMA R/W over 64-AXI channel for AHCI implementation
 *
 * Copyright (c) 2016 Elphel, Inc .
 * ahci_dma.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  ahci_dma.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  ahci_dma (
//    input         rst,
    input                         mrst, // @posedge mclk - sync reset
    input                         hrst, // @posedge hclk - sync reset
    
    input                         mclk, // for command/status
    input                         hclk,   // global clock to run axi_hp @ 150MHz
    // Control interface  (@mclk)
    input                  [31:7] ctba,         // command table base address
    input                         ctba_ld,      // load command table base address
    input                  [15:0] prdtl,        // number of entries in PRD table (valid at cmd_start)
    input                         cmd_start,     // start processing command table, reset prdbc
    // Some data from the command table will be used internally, data will be available on the general
    // sys_out[31:0] port and should be consumed
    output                        ct_busy,      // cleared after 0x20 DWORDs are read out
    // After the first 0x80 bytes of the Command Table are read out, this module will read/process PRDs,
    // not forwarding them to the output 
    output                        prd_done,     // prd done (regardless of the interrupt)
    output                        prd_irq,      // prd interrupt, if enabled
    output                        cmd_busy,     // all command 
    output                        cmd_done,
    
    // Data System memory -> HBA interface @ mclk
    output                 [31:0] sys_out,      // 32-bit data from the system memory to HBA - command table, dma data
    output                        sys_dav,      // at least one dword is ready to be read
    output                        sys_dav_many, // several DWORDs are in the FIFO (TODO: decide how many)
    input                         sys_re,       // sys_out data read, advance internal FIFO
    // Data HBA -> System memory  interface @ mclk
    output                 [31:0] sys_out,      // 32-bit data from the system memory to HBA - command table, dma data
    output                        sys_nfull,    // internal FIFO has room for more data (will decide - how big reserved space to keep)
    input                         sys_we,    
    
    // axi_hp signals write channel
    // write address
    output  [31:0] afi_awaddr,
    output         afi_awvalid,
    input          afi_awready, // @SuppressThisWarning VEditor unused - used FIF0 level
    output  [ 5:0] afi_awid,
    output  [ 1:0] afi_awlock,
    output  [ 3:0] afi_awcache,
    output  [ 2:0] afi_awprot,
    output  [ 3:0] afi_awlen,
    output  [ 1:0] afi_awsize,
    output  [ 1:0] afi_awburst,
    output  [ 3:0] afi_awqos,
    // write data
    output  [63:0] afi_wdata,
    output         afi_wvalid,
    input          afi_wready,  // @SuppressThisWarning VEditor unused - used FIF0 level
    output  [ 5:0] afi_wid,
    output         afi_wlast,
    output  [ 7:0] afi_wstrb,
    // write response
    input          afi_bvalid,
    output         afi_bready,
    input   [ 5:0] afi_bid,      // @SuppressThisWarning VEditor unused
    input   [ 1:0] afi_bresp,    // @SuppressThisWarning VEditor unused
    // PL extra (non-AXI) signals
    input   [ 7:0] afi_wcount,
    input   [ 5:0] afi_wacount,
    output         afi_wrissuecap1en,
    // AXI_HP signals - read channel
    // read address
    output  [31:0] afi_araddr,
    output         afi_arvalid,
    input          afi_arready,  // @SuppressThisWarning VEditor unused - used FIF0 level
    output  [ 5:0] afi_arid,
    output  [ 1:0] afi_arlock,
    output  [ 3:0] afi_arcache,
    output  [ 2:0] afi_arprot,
    output  [ 3:0] afi_arlen,
    output  [ 1:0] afi_arsize,
    output  [ 1:0] afi_arburst,
    output  [ 3:0] afi_arqos,
    // read data
    input   [63:0] afi_rdata,
    input          afi_rvalid,
    output         afi_rready,
    input   [ 5:0] afi_rid,     // @SuppressThisWarning VEditor unused
    input          afi_rlast,   // @SuppressThisWarning VEditor unused
    input   [ 1:0] afi_rresp,   // @SuppressThisWarning VEditor unused
    // PL extra (non-AXI) signals
    input   [ 7:0] afi_rcount,
    input   [ 2:0] afi_racount,
    output         afi_rdissuecap1en
);


endmodule

