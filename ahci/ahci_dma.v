/*******************************************************************************
 * Module: ahci_dma
 * Date:2016-01-01  
 * Author: Andrey Filippov     
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
 *
 * Additional permission under GNU GPL version 3 section 7:
 * If you modify this Program, or any covered work, by linking or combining it
 * with independent modules provided by the FPGA vendor only (this permission
 * does not extend to any 3-rd party modules, "soft cores" or macros) under
 * different license terms solely for the purpose of generating binary "bitstream"
 * files and/or simulating the code, the copyright holders of this Program give
 * you the right to distribute the covered work without those independent modules
 * as long as the source code for them is available from the FPGA vendor free of
 * charge, and there is no dependence on any encrypted modules for simulating of
 * the combined code. This permission applies to you if the distributed code
 * contains all the components and scripts required to completely simulate it
 * with at least one of the Free Software programs.
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
    input                         dev_wr,       // write to device (valid at start)
    input                         cmd_start,     // start processing command table, reset prdbc
    input                         prd_start,     // at or after cmd_start - enable reading PRD/data (if any)
    input                         cmd_abort,     // try to abort a command TODO: Implement

// Optional control of the AXI cache mode, default will be set to 4'h3, 4'h3 at mrst
    input                  [3:0]  axi_wr_cache_mode, 
    input                  [3:0]  axi_rd_cache_mode,
    input                         set_axi_wr_cache_mode,
    input                         set_axi_rd_cache_mode,
    
    // Some data from the command table will be used internally, data will be available on the general
    // sys_out[31:0] port and should be consumed
    output reg                    ct_busy,      // cleared after 0x20 DWORDs are read out
    // reading out command table data
    input                  [ 4:0] ct_addr,     // DWORD address
    input                  [ 1:0] ct_re,       // [0] - re, [1]-regen  
    output reg             [31:0] ct_data,     // 
    
    // After the first 0x80 bytes of the Command Table are read out, this module will read/process PRDs,
    // not forwarding them to the output 
    output                        prd_done,     // @mclk prd done (regardless of the interrupt) - data transfer of one PRD is finished (any direction)
    input                         prd_irq_clear, // reset pending prd_irq
    output reg                    prd_irq_pend,  // prd interrupt pending. This is just a condition for irq - actual will be generated after FIS OK
    output reg                    cmd_busy,     // all commands
    output                        cmd_done,     // @ mclk
    
    // Data System memory -> HBA interface @ mclk
    output                 [31:0] sys_out,      // 32-bit data from the system memory to HBA (dma data)
    output                        sys_dav,      // at least one dword is ready to be read
//    output                        sys_dav_many, // several DWORDs are in the FIFO (TODO: decide how many)
    input                         sys_re,       // sys_out data read, advance internal FIFO
    // Data HBA -> System memory  interface @ mclk
    input                  [31:0] sys_in,       // HBA -> system memory
    output                        sys_nfull,    // internal FIFO has room for more data (will decide - how big reserved space to keep)
    input                         sys_we,    
    
    output                        extra_din,    // all DRDs are transferred to memory, but FIFO has some data. Valid when transfer is stopped
    
    // axi_hp signals write channel
    // write address
    output  [31:0] afi_awaddr,
    output         afi_awvalid,
    input          afi_awready, // @SuppressThisWarning VEditor unused - used FIF0 level
    output  [ 5:0] afi_awid,
    output  [ 1:0] afi_awlock,
    output reg [ 3:0] afi_awcache,
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
    input          afi_bvalid,   // @SuppressThisWarning VEditor unused
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
    output            afi_arvalid,
    input             afi_arready,  // @SuppressThisWarning VEditor unused - used FIF0 level
    output  [ 5:0] afi_arid,
    output  [ 1:0] afi_arlock,
    output reg [ 3:0] afi_arcache,
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


// Read command table
//    localparam AFI_FIFO_LAT = 2; // >=2
   localparam SAFE_RD_BITS =   3; //2; // 3;

    reg     [31:0] ct_data_ram [0:31];
    reg      [3:0] int_data_addr;    // internal (ct,prd) data address
    reg     [31:7] ctba_r;
    reg     [15:0] prdtl_mclk;
    wire           cmd_start_hclk;
    reg            prd_start_r;
    wire           prd_start_hclk;
    reg            prd_start_hclk_r; // to make sure it is with/after prd_start_hclk if in mclk they are in the same cycle
    wire           cmd_abort_hclk; // TODO: Implement as graceful as possible command abort
    reg            prd_enabled;
    reg      [1:0] ct_over_prd_enabled; // prd read and data r/w enabled, command table fetch done
    
    reg     [31:4] ct_maddr; // granularity matches PRDT entry - 4xDWORD, 2xQWORD
    wire           ct_done;
    wire           first_prd_fetch; // CT read done, prd enabled
    reg     [31:0] afi_addr; // common for afi_araddr and afi_awaddr
    wire           axi_set_raddr_ready = !(|afi_racount[2:1]) && (!axi_set_raddr_r || !afi_racount[0]); // What is the size of ra fifo - just 4? Latency?
//    wire           axi_set_raddr_ready = !(|afi_racount) && !axi_set_raddr_r); // Most pessimistic
    wire           axi_set_waddr_ready = !afi_wacount[5] && !afi_wacount[4]; // What is the size of wa fifo - just 32? Using just half - safe
    wire           axi_set_raddr_w;
    wire           axi_set_waddr_w;
    wire           axi_set_addr_data_w;
    
    reg            axi_set_raddr_r; // [0] - actual write address to fifo
    reg            axi_set_waddr_r; // [0] - actual write address to fifo
    reg            is_ct_addr;    // current address is ct address
    reg            is_prd_addr;   // current address is prd address
    reg            is_data_addr;  // current address is data address (r or w)
    
    reg     [31:1] data_addr; // 2 lower addresses will be used in in/out fifo modules
    reg      [3:0] data_len; //
    reg            data_irq; // interrupt at the end of this PRD
    reg     [21:1] wcount;  // Word count
    reg            wcount_set; 
    reg     [22:1] qwcount; // only [21:3] are used ([22] - carry from subtraction )
    
    reg     [21:3] qw_datawr_left;
    reg     [ 3:0] qw_datawr_burst;
    reg            qw_datawr_last; 
    
    wire           data_afi_re;
    
    reg     [15:0] prds_left;
    reg            last_prd;
    
    reg     [1:0]  afi_rd_ctl; // read non-data (CT or PRD)
    reg     [1:0]  ct_busy_r;
    reg            prd_rd_busy; // reading PRD
    
    reg            dev_wr_mclk;
    reg            dev_wr_hclk;
    reg            prd_wr;    // write PRD data to memory
    reg            prd_rd;    // read  PRD data from memory
    wire     [3:0] afi_wstb4;

    wire           done_dev_wr; // finished PRD mem -> device
    wire           done_dev_rd; // finished PRD device -> mem
    wire           prd_done_hclk = done_dev_wr || done_dev_rd;
    wire           done_flush;  // done flushing last partial dword
    wire           cmd_done_hclk;
    wire           ct_done_mclk;
    reg      [3:0] afi_alen;
    wire           afi_wcount_many = !afi_wcount[7] && !(&afi_wcount[6:4]);
    
    reg            data_next_burst;
    
//    wire           raddr_prd_rq = (|prds_left) && (ct_done || prd_done);
    wire           raddr_prd_rq = (|prds_left) && (first_prd_fetch || prd_done_hclk);
    
    reg            raddr_prd_pend;
            
    wire           raddr_ct_rq = cmd_start_hclk;
    reg            raddr_ct_pend;

/*
    wire           addr_data_rq = (wcount_set || data_next_burst);
     
    wire           waddr_data_rq =  !dev_wr_hclk && addr_data_rq;
    wire           raddr_data_rq =   dev_wr_hclk && addr_data_rq;

*/     
    wire           addr_data_rq_w = (wcount_set || data_next_burst);
    reg            addr_data_rq_r;
     
    wire           waddr_data_rq =  !dev_wr_hclk && addr_data_rq_r;
    wire           raddr_data_rq =   dev_wr_hclk && addr_data_rq_r;

    reg            waddr_data_pend;
    reg            raddr_data_pend;
    // count different types of AXI ID separately - just for debugging
    reg      [3:0] ct_id;
    reg      [3:0] prd_id;
    reg      [3:0] dev_wr_id;
    reg      [3:0] dev_rd_id;
    reg      [5:0] afi_id; // common for 3 channels
    
    wire           fifo_nempty_mclk;
    reg            en_extra_din_r;
    reg     [31:0] ct_data_reg;
    
      
//    assign prd_done = done_dev_wr || done_dev_rd;
    assign cmd_done_hclk = ((ct_busy_r==2'b10) && (prdtl_mclk == 0)) || ((done_flush || done_dev_rd) && last_prd);
    assign ct_done = (ct_busy_r == 2'b10);
    assign first_prd_fetch = ct_over_prd_enabled == 2'b01;
    assign axi_set_raddr_w = axi_set_raddr_ready && (raddr_ct_pend || raddr_prd_pend || raddr_data_pend);    
/// assign axi_set_waddr_w = axi_set_raddr_ready && raddr_data_pend;    
    assign axi_set_waddr_w = axi_set_waddr_ready && waddr_data_pend;    
    assign axi_set_addr_data_w = (axi_set_raddr_ready && raddr_data_pend) || (axi_set_waddr_ready && waddr_data_pend);
    
    
    assign afi_awaddr = afi_addr;
    assign afi_araddr = afi_addr;
    assign afi_arlen  = afi_alen;
    assign afi_awlen  = afi_alen;
    assign afi_arvalid = axi_set_raddr_r;
    assign afi_awvalid = axi_set_waddr_r;
    assign afi_rready = afi_rd_ctl[0] || data_afi_re;
    assign afi_wstrb = {{2{afi_wstb4[3]}},{2{afi_wstb4[2]}},{2{afi_wstb4[1]}},{2{afi_wstb4[0]}}};
    assign afi_wlast = qw_datawr_last;

    assign afi_awid = afi_id;
    assign afi_wid =  afi_id;
    assign afi_arid = afi_id;

// Unused or static output signals
    assign afi_bready = 1'b1;
    assign afi_awlock =        2'h0;
//    assign afi_awcache =       4'h3;
    assign afi_awprot =        3'h0;
    assign afi_awsize =        2'h3;
    assign afi_awburst =       2'h1;
    assign afi_awqos =         4'h0;
    assign afi_wrissuecap1en = 1'b0;

    assign afi_arlock =        2'h0;
//    assign afi_arcache =       4'h3;
    assign afi_arprot =        3'h0;
    assign afi_arsize =        2'h3;
    assign afi_arburst =       2'h1;
    assign afi_arqos =         4'h0;
    assign afi_rdissuecap1en = 1'b0;
    assign extra_din = en_extra_din_r && fifo_nempty_mclk;
//    reg             [31:0] ct_data_reg;
    always @ (posedge mclk) begin
        if (ct_re[0]) ct_data_reg <=  ct_data_ram[ct_addr];
        if (ct_re[1]) ct_data <=      ct_data_reg;
        
        if (ctba_ld) ctba_r <=        ctba[31:7];
        
        if (cmd_start) prdtl_mclk <=  prdtl;
        
        if (cmd_start) dev_wr_mclk <= dev_wr;
        
        if      (mrst)      cmd_busy <= 0;
        else if (cmd_start) cmd_busy <= 1; 
        else if (cmd_done)  cmd_busy <= 0;

        if      (mrst)         ct_busy <= 0;
        else if (cmd_start)    ct_busy <= 1; 
        else if (ct_done_mclk) ct_busy <= 0;
        
        if      (mrst)                  afi_arcache <= 4'h3;
        else if (set_axi_rd_cache_mode) afi_arcache <= axi_rd_cache_mode;

        if      (mrst)                  afi_awcache <= 4'h3;
        else if (set_axi_wr_cache_mode) afi_awcache <= axi_wr_cache_mode;
        
        prd_start_r <= prd_start;
        
        if (mrst || prd_irq_clear ||cmd_start || cmd_abort) prd_irq_pend <= 0; 
        else if (data_irq && prd_done)                      prd_irq_pend <= 1;
        
        if (mrst || cmd_start || cmd_abort) en_extra_din_r <= 0; 
        else if (cmd_done)                  en_extra_din_r <= 1;
        

    end
       
//        afi_rd_ctl <= { afi_rd_ctl[0],(ct_busy_r[0] || prd_rd_busy) && ((|afi_rcount[7:SAFE_RD_BITS]) || (afi_rvalid && !(|afi_rd_ctl)))};
    wire debug_01 = ct_busy_r[0] || prd_rd_busy ;      
    wire debug_02 =|afi_rcount[7:SAFE_RD_BITS];
    wire debug_03 = (afi_rvalid && !(|afi_rd_ctl));
    
    wire [21:1] wcount_plus_data_addr = wcount[21:1] + data_addr[2:1];
    
    always @ (posedge hclk) begin
        addr_data_rq_r <= addr_data_rq_w;
        
        prd_start_hclk_r <= prd_start_hclk;
        
        if      (hrst || cmd_abort_hclk) prd_enabled <= 0;
        else if (prd_start_hclk_r)       prd_enabled <= 1; // presedence over  cmd_start_hclk
        else if (cmd_start_hclk)         prd_enabled <= 0;
    
    
        if (cmd_start_hclk)  ct_maddr[31:4] <= {ctba_r[31:7],3'b0};
        else if (ct_done)    ct_maddr[31:4] <= ct_maddr[31:4] + 8; // 16;
        else if (wcount_set) ct_maddr[31:4] <= ct_maddr[31:4] + 1;
        
        // overall sequencing makes sure that there will be no new requests until older served
        // additionally they are mutuially exclusive - only one may be pending at a time
        if      (hrst)                raddr_ct_pend <= 0;
        else if (raddr_ct_rq)         raddr_ct_pend <= 1;
        else if (axi_set_raddr_ready) raddr_ct_pend <= 0;
        
        if      (hrst)                raddr_prd_pend <= 0;
        else if (raddr_prd_rq)        raddr_prd_pend <= 1;
        else if (axi_set_raddr_ready) raddr_prd_pend <= 0;
        
        if      (hrst)                raddr_data_pend <= 0;
        else if (raddr_data_rq)       raddr_data_pend <= 1;
        else if (axi_set_raddr_ready) raddr_data_pend <= 0;
        
        if      (hrst)                waddr_data_pend <= 0;
        else if (waddr_data_rq)       waddr_data_pend <= 1;
        else if (axi_set_waddr_ready) waddr_data_pend <= 0;
        
        if (hrst)                                           {is_ct_addr, is_prd_addr, is_data_addr} <= 0;
        else if (raddr_ct_rq || raddr_prd_rq || wcount_set) {is_ct_addr, is_prd_addr, is_data_addr} <= {raddr_ct_rq, raddr_prd_rq, wcount_set};
        
        if (axi_set_raddr_w || axi_set_waddr_w) begin
            if (raddr_data_pend || waddr_data_pend)  afi_addr <= {data_addr[31:3], 3'b0};
            else                                     afi_addr <= {ct_maddr[31:4],  4'b0};

            if (raddr_data_pend || waddr_data_pend)  afi_alen <= data_len;
            else if (raddr_ct_pend)                  afi_alen <= 4'hf; // 16 QWORDS (128 bytes)
            else                                     afi_alen <= 4'h1; // 2 QWORDS
            
            if (raddr_data_pend || waddr_data_pend)  afi_id <= raddr_data_pend ? {2'h2, dev_rd_id} : {2'h3, dev_wr_id};
            else                                     afi_id <= raddr_ct_pend   ? {2'h0, ct_id} :     {2'h1, prd_id};
        end    
        
        
        if (hrst) axi_set_raddr_r <= 0;
        else      axi_set_raddr_r <= axi_set_raddr_w;

        if (hrst) axi_set_waddr_r <= 0;
        else      axi_set_waddr_r <= axi_set_waddr_w;
        
///     if (addr_data_rq)   data_len <= ((|qwcount[21:7]) || (&qwcount[6:3]))? 4'hf: qwcount[6:3];       // early calculate
        if (addr_data_rq_r) data_len <= ((|qwcount[21:7]) || (&qwcount[6:3]))? 4'hf: qwcount[6:3];       // early calculate

///     if      (wcount_set)          qwcount[21:1] <= wcount[21:1] + data_addr[2:1]; //minus 1
///     else if (axi_set_addr_data_w) qwcount[21:7] <= qwcount[21:7] - 1; // may get negative

        if      (wcount_set)          qwcount[22:1] <= {1'b0,wcount_plus_data_addr[21:1]}; // wcount[21:1] + data_addr[2:1]; //minus 1
        else if (axi_set_addr_data_w) qwcount[22:7] <= qwcount[22:7] - 1; // may get negative
        
//wcount_plus_data_addr        
        
///     data_next_burst <= axi_set_addr_data_w && ((|qwcount[21:7]) || (&qwcount[6:3])); // same time as afi_awvalid || afi_arvalid
///        data_next_burst <= !qwcount[22] && axi_set_addr_data_w && ((|qwcount[21:7]) || (&qwcount[6:3])); // same time as afi_awvalid || afi_arvalid
        data_next_burst <= !qwcount[22] && axi_set_addr_data_w && (|qwcount[21:7]); // same time as afi_awvalid || afi_arvalid

// Get PRD data
        // store data address from PRD, increment when needed
        if (afi_rd_ctl[0] && is_prd_addr && (!int_data_addr[0])) data_addr[31:1] <= afi_rdata[31:1];
        if (axi_set_addr_data_w) data_addr[31:7] <= data_addr[31:7] + 1;

        if (afi_rd_ctl[0] && is_prd_addr && (int_data_addr[0])) data_irq <=     afi_rdata[63];

        if (afi_rd_ctl[0] && is_prd_addr && (int_data_addr[0])) wcount[21:1] <= afi_rdata[53:33];

        wcount_set <= afi_rd_ctl[0] && is_prd_addr && (int_data_addr[0]);

        if      (cmd_start_hclk)  prds_left  <= prdtl_mclk;
        else if (raddr_prd_rq)    prds_left  <= prds_left  - 1;

        if      (raddr_prd_rq)    last_prd  <= prds_left[15:1] == 0;
        
        // Set/increment address to store (internally) CT and PRD data 
        if      (axi_set_raddr_r)                int_data_addr <= 0;
        else if (afi_rd_ctl[0] && !is_data_addr) int_data_addr <= int_data_addr + 1;
        
        if (afi_rd_ctl[0] && is_ct_addr) {ct_data_ram[{int_data_addr,1'b1}],ct_data_ram[{int_data_addr,1'b0}]} <= afi_rdata; // make sure it is synthesized correctly
        
        // generate busy for command table (CT) read
        if      (hrst)                                            ct_busy_r[0] <= 0;
        else if (cmd_start_hclk)                                  ct_busy_r[0] <= 1;
        else if (afi_rd_ctl[0] && is_ct_addr && (&int_data_addr)) ct_busy_r[0] <= 0;
        ct_busy_r[1] <= ct_busy_r[0]; // delayed version to detect end of command
        
        if (hrst || ct_busy_r[0])                   ct_over_prd_enabled[0] <= 0;
        else if (prd_enabled)                       ct_over_prd_enabled[0] <= 1;
        ct_over_prd_enabled[1] <= ct_over_prd_enabled[0];  // detecting 0->1 transition
        
        // generate busy for PRD table entry read
        if      (hrst)                                prd_rd_busy <= 0;
//        else if (prd_rd_busy) prd_rd_busy <= 1;
        else if (raddr_prd_rq && axi_set_raddr_ready) prd_rd_busy <= 1;
        else if (wcount_set)                          prd_rd_busy <= 0;
        
        if (cmd_start_hclk) dev_wr_hclk <= dev_wr_mclk; // 1: memory -> device, 0: device -> memory
        
        prd_wr <= wcount_set && !dev_wr_hclk;
        prd_rd <= wcount_set &&  dev_wr_hclk;
        
        afi_rd_ctl <= { afi_rd_ctl[0],(ct_busy_r[0] || prd_rd_busy) && ((|afi_rcount[7:SAFE_RD_BITS]) || (afi_rvalid && !(|afi_rd_ctl)))};
        
        // calculate afi_wlast - it is (qw_datawr_burst == 0), just use register qw_datawr_last
        
        if      (prd_wr)     qw_datawr_last <= qwcount[21:3] == 0;
///     else if (afi_wvalid) qw_datawr_last <= qw_datawr_burst == 1;        
        else if (afi_wvalid) qw_datawr_last <= (qw_datawr_burst == 1) || (qw_datawr_last && (qw_datawr_left[21:3] == 16)); // last case - n*16 + 1 (last burst single)       
        
        if      (prd_wr)                                                      qw_datawr_burst <= (|qwcount[21:7])? 4'hf: qwcount[6:3];
///     else if (afi_wvalid && qw_datawr_last && (qw_datawr_left[21:7] == 0)) qw_datawr_burst <= qw_datawr_left[6:3]; // if not last roll over to 'hf
///     else if (afi_wvalid &&                   (qw_datawr_left[21:7] == 0)) qw_datawr_burst <= qw_datawr_left[6:3]; // if not last roll over to 'hf
        else if (afi_wvalid && qw_datawr_last && (qw_datawr_left[21:7] == 1)) qw_datawr_burst <= qw_datawr_left[6:3]; // if not last roll over to 'hf
        else if (afi_wvalid)                                                  qw_datawr_burst <= qw_datawr_burst - 1;
        
        if      (prd_wr)                       qw_datawr_left[21:3] <= qwcount[21:3];
        else if (afi_wvalid && qw_datawr_last) qw_datawr_left[21:7] <= qw_datawr_left[21:7] - 1; // can go negative - OK?
        
        // Count AXI IDs
        if      (hrst)             ct_id <= 0;
        else if (ct_busy_r==2'b10) ct_id <= ct_id + 1;

        if      (hrst)             prd_id <= 0;
        else if (wcount_set)       prd_id <= prd_id + 1;

        if      (hrst)             dev_wr_id <= 0;
        else if (done_dev_wr)      dev_wr_id <= dev_wr_id + 1;

        if      (hrst)             dev_rd_id <= 0;
        else if (done_dev_rd)      dev_rd_id <= dev_rd_id + 1;
        
        
    end
    
    ahci_dma_rd_fifo #( // memory to device
        .WCNT_BITS    (21),
        .ADDRESS_BITS (3)
    ) ahci_dma_rd_fifo_i (
        .mrst         (mrst),                        // input
        .hrst         (hrst),                        // input
        .mclk         (mclk),                        // input
        .hclk         (hclk),                        // input
        .wcnt         (wcount[21:1]),                // input[20:0] 
        .woffs        (data_addr[2:1]),              // input[1:0] 
        .start        (prd_rd),                      // input
        .din          (afi_rdata),                   // input[63:0] 
        .din_av       (afi_rvalid),                  // input
        .din_av_many  (|afi_rcount[7:SAFE_RD_BITS]), // input
        .last_prd     (last_prd),                    // input
        .din_re       (data_afi_re),                 // output
        .done         (done_dev_wr),                 // output reg // @ hclk
        .done_flush   (done_flush),                  // output     // @ hclk
        .dout         (sys_out),                     // output[31:0] 
        .dout_vld     (sys_dav),                     // output
        .dout_re      (sys_re)                       // input
    );
    
    ahci_dma_wr_fifo #( // device to memory
        .WCNT_BITS    (21),
        .ADDRESS_BITS (3)
    ) ahci_dma_wr_fifo_i (
        .mrst         (mrst),           // input
        .hrst         (hrst),           // input
        .mclk         (mclk),           // input
        .hclk         (hclk),           // input
        .wcnt         (wcount[21:1]),   // input[20:0] 
        .woffs        (data_addr[2:1]), // input[1:0] 
        .init         (cmd_start_hclk), // input
        .start        (prd_wr),         // input
        .dout         (afi_wdata),      // output[63:0] reg 
//        .dout_av      (), // input
        .dout_av_many (afi_wcount_many),// input
        .last_prd     (last_prd),       // input
        .dout_we      (afi_wvalid),     // output
        .dout_wstb    (afi_wstb4),      // output[3:0] reg 
        .done         (done_dev_rd),    // output reg 
        .busy         (), // output
        .fifo_nempty_mclk  (fifo_nempty_mclk), // output reg 
        .din          (sys_in),         // input[31:0] 
        .din_rdy      (sys_nfull),      // output
        .din_avail    (sys_we)          // input
    );
    
    
    // mclk -> hclk cross-clock synchronization
    pulse_cross_clock #(
        .EXTRA_DLY(0)
    ) cmd_start_hclk_i (
        .rst       (mrst),            // input
        .src_clk   (mclk),            // input
        .dst_clk   (hclk),            // input
        .in_pulse  (cmd_start),       // input
        .out_pulse (cmd_start_hclk),    // output
        .busy()                       // output
    );
    pulse_cross_clock #(
        .EXTRA_DLY(0)
    ) cmd_abort_hclk_i (
        .rst       (mrst),            // input
        .src_clk   (mclk),            // input
        .dst_clk   (hclk),            // input
        .in_pulse  (cmd_abort),       // input
        .out_pulse (cmd_abort_hclk),    // output
        .busy()                       // output
    );
    pulse_cross_clock #(
        .EXTRA_DLY(0)
    ) prd_start_hclk_i (
        .rst       (mrst),            // input
        .src_clk   (mclk),            // input
        .dst_clk   (hclk),            // input
        .in_pulse  (prd_start_r),     // input
        .out_pulse (prd_start_hclk),  // output
        .busy()                       // output
    );


    
    // hclk -> mclk;
    pulse_cross_clock #(
        .EXTRA_DLY(0)
    ) cmd_done_i (
        .rst       (hrst),            // input
        .src_clk   (hclk),            // input
        .dst_clk   (mclk),            // input
        .in_pulse  (cmd_done_hclk),   // input
        .out_pulse (cmd_done),        // output
        .busy()                       // output
    );

    pulse_cross_clock #(
        .EXTRA_DLY(0)
    ) ct_done_mclk_i (
        .rst       (hrst),            // input
        .src_clk   (hclk),            // input
        .dst_clk   (mclk),            // input
        .in_pulse  (ct_done),         // input
        .out_pulse (ct_done_mclk),    // output
        .busy()                       // output
    );

    pulse_cross_clock #(
        .EXTRA_DLY(0)
    ) prd_done_mclk_i (
        .rst       (hrst),            // input
        .src_clk   (hclk),            // input
        .dst_clk   (mclk),            // input
        .in_pulse  (prd_done_hclk),   // input
        .out_pulse (prd_done),        // output
        .busy()                       // output
    );




endmodule

