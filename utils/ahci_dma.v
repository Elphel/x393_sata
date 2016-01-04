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
    input                         dev_wr,       // write to device (valid at start)
    input                         cmd_start,     // start processing command table, reset prdbc
    input                         cmd_abort,     // try to abort a command
    // Some data from the command table will be used internally, data will be available on the general
    // sys_out[31:0] port and should be consumed
    output reg                    ct_busy,      // cleared after 0x20 DWORDs are read out
    // reading out command table data
    input                  [ 4:0] ct_addr,     // DWORD address
    input                         ct_re,       //  
    output reg             [31:0] ct_data,     // 
    
    // After the first 0x80 bytes of the Command Table are read out, this module will read/process PRDs,
    // not forwarding them to the output 
    output                        prd_done,     // prd done (regardless of the interrupt) - data transfer of one PRD is finished (any direction)
    
    output                        prd_irq,      // prd interrupt, if enabled
    output reg                    cmd_busy,     // all commands
    output                        cmd_done,
    
    // Data System memory -> HBA interface @ mclk
    output                 [31:0] sys_out,      // 32-bit data from the system memory to HBA (dma data)
    output                        sys_dav,      // at least one dword is ready to be read
//    output                        sys_dav_many, // several DWORDs are in the FIFO (TODO: decide how many)
    input                         sys_re,       // sys_out data read, advance internal FIFO
    // Data HBA -> System memory  interface @ mclk
    input                  [31:0] sys_in,       // HBA -> system memory
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
    output            afi_arvalid,
    input             afi_arready,  // @SuppressThisWarning VEditor unused - used FIF0 level
    output  [ 5:0] afi_arid,
    output  [ 1:0] afi_arlock,
    output  [ 3:0] afi_arcache,
    output  [ 2:0] afi_arprot,
    output reg  [ 3:0] afi_arlen,
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
    wire           cmd_abort_hclk;
    reg     [31:4] ct_maddr; // granularity matches PRDT entry - 4xDWORD, 2xQWORD
    wire           ct_done;
    reg     [31:0] afi_addr; // common for afi_araddr and afi_awaddr
    wire           axi_set_raddr_ready = !(|afi_racount[2:1]); // What is the size of ra fifo?
    wire           axi_set_raddr_w;
    wire           axi_set_waddr_w;
    wire           axi_set_raddr_ct_w;   // next will be setting address/len/... to read command table
    reg            axi_set_raddr_prd;  // next will be setting address/len/... to read PRD entry
    wire           axi_set_raddr_data_w; // next will be setting address/len/... to read DATA  
    reg            axi_set_raddr_r; // [0] - actual write address to fifo
    reg            axi_set_waddr_r; // [0] - actual write address to fifo
    reg            was_ct_addr; // AXI RD channel was set to read command table 
    reg            was_prd_addr;// AXI RD channel was set to read prd table
    
    reg     [31:1] data_addr; // 2 lower addresses will be used in in/out fifo modules
    reg      [3:0] data_len; //
    reg            data_irq; // interrupt at the end of this PRD
    reg     [21:1] wcount;  // Word count
    reg            wcount_set; 
    reg     [21:1] qwcount; // only [21:3] are used
    reg            next_data16; // next data r/w address incremented by 16 QWORDS
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
    wire           done_flush;  // done flushing last partial dword
    wire           cmd_done_hclk;
    wire           ct_done_mclk;
    
    assign afi_arvalid = axi_set_raddr_r;
    assign afi_awvalid = axi_set_waddr_r;
    assign axi_set_raddr_w = (axi_set_raddr_ct_w || axi_set_raddr_prd || axi_set_raddr_data_w) && axi_set_raddr_ready ;
    assign afi_rready = afi_rd_ctl[0] || data_afi_re;
//    assign ct_busy = ct_busy_r[0];
    
    assign         afi_wstrb = {{2{afi_wstb4[3]}},{2{afi_wstb4[2]}},{2{afi_wstb4[1]}},{2{afi_wstb4[0]}}};
    assign prd_done = done_dev_wr || done_dev_rd;
    assign prd_irq = data_irq && prd_done;
    assign cmd_done_hclk = ((ct_busy_r==2'b10) && (prdtl_mclk == 0)) || done_flush || done_dev_rd;
    assign ct_done = (ct_busy_r == 2'b10);
    assign afi_awaddr = afi_addr;
    assign afi_araddr = afi_addr;
    
    always @ (posedge mclk) begin
        if (ct_re) ct_data <=         ct_data_ram[ct_addr];
        if (ctba_ld) ctba_r <=        ctba[31:7];
        if (cmd_start) prdtl_mclk <=  prdtl;
        if (cmd_start) dev_wr_mclk <= dev_wr;
        
        if      (mrst)      cmd_busy <= 0;
        else if (cmd_start) cmd_busy <= 1; 
        else if (cmd_done)  cmd_busy <= 0;

        if      (mrst)         ct_busy <= 0;
        else if (cmd_start)    ct_busy <= 1; 
        else if (ct_done_mclk) ct_busy <= 0;

    end
       
        
        
    always @ (posedge hclk) begin
        if (cmd_start_hclk)  ct_maddr[31:4] <= {ctba_r[31:7],3'b0};
        else if (ct_done)    ct_maddr[31:4] <= ct_maddr[31:4] + 16;
        else if (wcount_set) ct_maddr[31:4] <= ct_maddr[31:4] + 1;
        
        if (hrst) axi_set_raddr_r <= 0;
        else      axi_set_raddr_r <= axi_set_raddr_w;

        if (hrst) axi_set_waddr_r <= 0;
        else      axi_set_waddr_r <= axi_set_waddr_w;
        
        if (axi_set_raddr_w) begin
            was_ct_addr <= axi_set_raddr_ct_w;
            was_prd_addr <= axi_set_raddr_prd;
        end

        if      (cmd_start_hclk)                  prds_left  <= prdtl_mclk;
        else if (axi_set_raddr_r && was_prd_addr) prds_left  <= prds_left  - 1;

        if (axi_set_raddr_r && was_prd_addr) last_prd  <= prds_left == 1;
        
        if (axi_set_raddr_w || axi_set_waddr_w) begin
//            if (was_ct_addr || was_prd_addr) afi_addr <= {ct_maddr[31:4],4'b0};
            if (axi_set_raddr_ct_w || axi_set_raddr_prd) afi_addr <= {ct_maddr[31:4],4'b0};
            else                                         afi_addr <= {data_addr[31:3],3'b0};
            
//            if      (was_ct_addr)            afi_arlen  <= 4'hf; // 16 QWORDS
//            else if (was_prd_addr)           afi_arlen  <= 4'h1; //  2 QWORDS
            if      (axi_set_raddr_ct_w)     afi_arlen  <= 4'hf; // 16 QWORDS
            else if (axi_set_raddr_prd)      afi_arlen  <= 4'h1; //  2 QWORDS
            else                             afi_arlen  <= data_len; // TBD - all but last are 4'hf
        end
        
        if      (axi_set_raddr_r)                                int_data_addr <= 0; //  && (was_ct_addr || was_prd_addr))
        else if (afi_rd_ctl[0] && (was_ct_addr || was_prd_addr)) int_data_addr <= int_data_addr + 1;
        
        if (afi_rd_ctl[0] && was_ct_addr) {ct_data_ram[{int_data_addr,1'b1}],ct_data_ram[{int_data_addr,1'b0}]} <= afi_rdata; // make sure it is synthesized correctly
        
        if      (hrst)                                             ct_busy_r[0] <= 0;
        else if (cmd_start_hclk)                                   ct_busy_r[0] <= 1;
        else if (afi_rd_ctl[0] && was_ct_addr && (&int_data_addr)) ct_busy_r[0] <= 0;
        ct_busy_r[1] <= ct_busy_r[0]; // delayed version to detect end of command
        
        if      (hrst)        prd_rd_busy <= 0;
        else if (prd_rd_busy) prd_rd_busy <= 1;
        else if (wcount_set)  prd_rd_busy <= 0;
        
        
        
        // start PRD read
        if (hrst) axi_set_raddr_prd <= 0;
        else      axi_set_raddr_prd <= ((|prds_left) && (ct_done || prd_done));
        
        // store data address from PRD
        if (afi_rd_ctl[0] && was_prd_addr && (!int_data_addr[0])) data_addr[31:1] <= afi_rdata[31:1];
        else if (next_data16)                              data_addr[31:7] <= data_addr[31:7] + 1; // add 64 bytes to address, keep low bits
        
        if (afi_rd_ctl[0] && was_prd_addr && (int_data_addr[0])) data_irq <=     afi_rdata[63];

        if (afi_rd_ctl[0] && was_prd_addr && (int_data_addr[0])) wcount[21:1] <= afi_rdata[37:17];

        wcount_set <= afi_rd_ctl[0] && was_prd_addr && (int_data_addr[0]);

        if (wcount_set) qwcount[21:1] <= wcount[21:1] + data_addr[2:1];
        
        if (cmd_start_hclk) dev_wr_hclk <= dev_wr_mclk; // 1: memory -> device, 0: device -> memory
        
        prd_wr <= wcount_set && !dev_wr_hclk;
        prd_rd <= wcount_set &&  dev_wr_hclk;
        
        afi_rd_ctl <= { afi_rd_ctl[0],(ct_busy_r[0] || prd_rd_busy) && ((|afi_rcount[7:SAFE_RD_BITS]) || (afi_rvalid && !(|afi_rd_ctl)))};
        
    end
    
   // TODO: Push addresses for Data read/data Write (different address FIFO depth), use IDs
   // - different for commands (increment for each next command) and data (increment for each PRD) - not really needed, just for debugging
   // Generate afi_wlast - each 16-th and the very last QWORD
   
    
    
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
        .done         (done_dev_wr),                 // output reg 
        .done_flush   (done_flush),                  // output
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
        .dout_av      (), // input
        .dout_av_many (), // input
        .last_prd     (last_prd),       // input
        .dout_we      (afi_wvalid),     // output
        .dout_wstb    (afi_wstb4),      // output[3:0] reg 
        .done         (done_dev_rd), // output reg 
        .busy         (), // output
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
    
    // hclk -> mclk;
    pulse_cross_clock #(
        .EXTRA_DLY(0)
    ) cmd_done_i (
        .rst       (hrst),            // input
        .src_clk   (hclk),            // input
        .dst_clk   (mclk),            // input
        .in_pulse  (cmd_done_hclk),            // input
        .out_pulse (cmd_done),       // output
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

endmodule

