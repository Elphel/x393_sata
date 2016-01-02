/*******************************************************************************
 * Module: ahci_dma_rd_fifo
 * Date:2016-01-01  
 * Author: andrey     
 * Description: cross clocks,  word-realign, 64->32
 * Convertion from x64 QWORD-aligned AXI data @hclk to
 * 32-bit word-aligned data at mclk
 *
 * Copyright (c) 2016 Elphel, Inc .
 * ahci_dma_rd_fifo.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  ahci_dma_rd_fifo.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  ahci_dma_rd_fifo#(
    parameter WCNT_BITS    = 21,
    parameter ADDRESS_BITS = 3
)(
    input                 mrst,
    input                 hrst,
    input                 mclk,
    input                 hclk,
    // hclk domain
    input [WCNT_BITS-1:0] wcnt,  // decrementing word counter, 0- based (0 need 1, 1 - need 2, ...) valid @ start
    input           [1:0] woffs, // 2 LSBs of the initial word address - valid @ start
    input                 start, // start transfer
    input          [63:0] din,
    input                 din_av,
    input                 din_av_many,
    input                 last_prd, // last prd, flush partial dword if there were odd number of words transferred. valid @ start
    // Or maybe use "last_prd"?
    output                din_re,
    output reg            done,        // this PRD data sent to cross-clock FIFO (may result in only half-dword sent out),
                                       // OK to fetch another PRD (if it was not the last) 
    output                done_flush,  // finished last PRD (indicated by last_prd @ start), data left module
    // mclk domain
    output         [31:0] dout,
    output                dout_vld,
    input                 dout_re
);
    localparam ADDRESS_NUM = (1<<ADDRESS_BITS); // 8 for ADDRESS_BITS==3
    reg   [ADDRESS_BITS : 0] waddr; // 1 extra bit       
    reg   [ADDRESS_BITS+1:0] raddr; // 1 extra bit       
    reg              [63:16] din_prev; // only 48 bits are needed
    reg      [WCNT_BITS-3:0] qwcntr;
//    reg                      some_offs;
    reg                      extra_in;
    reg                      busy;
//    reg                      din_last_w = din_re && (qwcntr==0);
    wire               [2:0] end_offs = wcnt[1:0] + woffs;
    
    reg               [63:0] fifo_ram  [0: ADDRESS_NUM - 1];
    reg                [3:0] vld_ram   [0: ADDRESS_NUM - 1];
    reg                [1:0] flush_ram [0: ADDRESS_NUM - 1];
    reg [(1<<ADDRESS_BITS)-1:0] fifo_full;  // set in write clock domain
    reg [(1<<ADDRESS_BITS)-1:0] fifo_nempty;// set in read clock domain
    wire                     fifo_wr;
    wire                     fifo_rd;
    reg                      hrst_mclk;
    wire [(1<<ADDRESS_BITS)-1:0] fifo_full2 =       {fifo_full[0],fifo_full[ADDRESS_NUM-1:1]};
//    wire [(1<<ADDRESS_BITS)-1:0] fifo_nempty_half = {fifo_nempty[(ADDRESS_NUM>>1)-1:0],fifo_full[ADDRESS_NUM-1: ADDRESS_NUM>>1]};
    reg                      fifo_dav;  // @mclk
    reg                      fifo_dav2; // @mclk
    reg                      fifo_half_hclk; // Half Fifo is empty, OK to write
    reg                [1:0] woffs_r;
    
    wire              [63:0] fifo_di= woffs_r[1]?(woffs_r[0] ? {din[47:0],din_prev[63:48]} : {din[31:0],din_prev[63:32]}):
                                                 (woffs_r[0] ? {din[15:0],din_prev[63:16]} : din[63:0]);
    wire               [3:0] fifo_di_vld;                                             
    wire               [1:0] fifo_di_flush;  // Assign
    wire              [63:0] fifo_do =       fifo_ram [raddr[ADDRESS_BITS:1]];
    wire               [3:0] fifo_do_vld =   vld_ram  [raddr[ADDRESS_BITS:1]];
    wire               [1:0] fifo_do_flush = flush_ram[raddr[ADDRESS_BITS:1]];
    reg                      din_av_safe_r;
    reg                      en_fifo_wr;
    reg                [3:0] last_mask;
    reg                      flush_r;
    wire                     done_flush_mclk;
    
    
    assign din_re =  busy && fifo_half_hclk && din_av_safe_r;
    assign fifo_wr = en_fifo_wr && fifo_half_hclk && (din_av_safe_r || !busy);
    assign fifo_di_vld =    (busy && (!extra_in || (qwcntr != 0)))? 4'hf : last_mask ;
    assign fifo_di_flush = ((busy && (!extra_in || (qwcntr != 0))) || !flush_r)? 2'h0 : {|last_mask[3:2], ~(|last_mask[3:2])} ;
    
    
    always @ (posedge hclk) begin
        if      (hrst)                      busy <= 0;
        else if (start)                     busy <= 1;
        else if (din_re && (qwcntr == 0))   busy <= 0;
        
        done <= busy && din_re && (qwcntr == 0);
        
        if      (hrst)                      en_fifo_wr <= 0;
        else if (start)                     en_fifo_wr <= (wcnt[1:0] == 0);
        else if (din_re || fifo_wr)         en_fifo_wr <= busy && ((qwcntr != 0) || extra_in);
        
        if       (start) qwcntr <= wcnt[WCNT_BITS-1:2];
        else if (din_re) qwcntr <= qwcntr - 1;
        
        if (start) extra_in <= end_offs[2];

        if (start) woffs_r <= woffs;
        
        if      (hrst)    fifo_full <= 0;
        else if (fifo_wr) fifo_full <= {fifo_full[ADDRESS_NUM-2:0],waddr[ADDRESS_BITS]};

        if      (hrst)    waddr <= 0;
        else if (fifo_wr) waddr <= waddr+1;
        
        fifo_half_hclk <= fifo_nempty [waddr[ADDRESS_BITS-1:0]] ^ waddr[ADDRESS_BITS];
        
        if (din_re) din_prev[63:16] <= din[63:16];
        
        if (fifo_wr) fifo_ram[waddr[ADDRESS_BITS-1:0]] <= fifo_di;
        if (fifo_wr) vld_ram [waddr[ADDRESS_BITS-1:0]] <= fifo_di_vld;
        if (fifo_wr) flush_ram[waddr[ADDRESS_BITS-1:0]] <= fifo_di_flush;
        
        if (hrst) din_av_safe_r <= 0;
        else      din_av_safe_r <= din_av && (din_av_many || !din_re);
        
        if (start) last_mask <= {&wcnt, wcnt[1], |wcnt, 1'b1}; 
        
        if (start) flush_r <= last_prd;
        
    end
    
    always @ (posedge hclk) begin
        hrst_mclk <= hrst;

        if    (hrst_mclk)             raddr <= 0;
        else if (fifo_rd)             raddr <= raddr + 1; 

        if      (hrst_mclk)           fifo_nempty <= {{(ADDRESS_NUM>>1){1'b0}},{(ADDRESS_NUM>>1){1'b1}}};// 8'b00001111
        else if (fifo_rd && raddr[0]) fifo_nempty <= {fifo_nempty[ADDRESS_NUM-2:0],raddr[ADDRESS_BITS+1] ^ raddr[ADDRESS_BITS]};
        
        fifo_dav <=  fifo_full [raddr[ADDRESS_BITS:1]] ^ raddr[ADDRESS_BITS+1];
        fifo_dav2 <= fifo_full2[raddr[ADDRESS_BITS:1]];
    end
    
    ahci_dma_rd_stuff ahci_dma_rd_stuff_i (
        .rst      (mrst),                                       // input
        .clk      (mclk),                                       // input
        .din_av   (fifo_dav),                                   // input
        .din_avm  (fifo_dav2),                                  // input
        .flush    (raddr[0]?fifo_do_flush[1]:fifo_do_flush[0]), // input
        .din      (raddr[0]?fifo_do[63:32]:  fifo_do[31:0]),    // input[31:0] 
        .dm       (raddr[0]?fifo_do_vld[3:2]:fifo_do_vld[1:0]), // input[1:0] 
        .din_re   (fifo_rd),                                    // output
        .flushed  (done_flush_mclk),                            // output reg: flush (end of last PRD is finished - data left module)
        .dout     (dout),                                       // output[31:0] reg 
        .dout_vld (dout_vld),                                   // output
        .dout_re  (dout_re)                                     // input
    );

    pulse_cross_clock #(
        .EXTRA_DLY(0)
    ) done_flush_i (
        .rst       (mrst),            // input
        .src_clk   (mclk),            // input
        .dst_clk   (hclk),            // input
        .in_pulse  (done_flush_mclk), // input
        .out_pulse (done_flush),      // output
        .busy()                       // output
    );
    
endmodule
