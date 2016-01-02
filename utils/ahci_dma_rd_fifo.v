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
    input                 flush, // last prd, flush partial dword if there were odd number of words transferred
    // Or maybe use "last_prd"?
    output                din_re,
    output                done,
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
    reg                      some_offs;
    reg                      extra_in;
    reg                      busy;
    reg                      din_last_w = din_re && (qwcntr==0);
    wire               [2:0] end_offs = wcnt[1:0] + woffs;
    
    reg               [63:0] fifo_ram [0: ADDRESS_NUM - 1];
    reg                [3:0] vld_ram  [0: ADDRESS_NUM - 1];
    reg [(1<<ADDRESS_BITS)-1:0] fifo_full;  // set in write clock domain
    reg [(1<<ADDRESS_BITS)-1:0] fifo_nempty;// set in read clock domain
    wire                     fifo_wr;
    wire                     fifo_rd;
    reg                      hrst_mclk;
    wire [(1<<ADDRESS_BITS)-1:0] fifo_full2 =       {fifo_full[0],fifo_full[ADDRESS_NUM-1:1]};
//    wire [(1<<ADDRESS_BITS)-1:0] fifo_nempty_half = {fifo_nempty[(ADDRESS_NUM>>1)-1:0],fifo_full[ADDRESS_NUM-1: ADDRESS_NUM>>1]};
    reg                      fifo_dav;  // @mclk
    reg                      fifo_dav2; // @mclk
    reg                      fifo_half_hclk;
    reg                [1:0] woffs_r;
    
    wire              [63:0] fifo_di= woffs_r[1]?(woffs_r[0] ? {din[47:0],din_prev[63:48]} : {din[31:0],din_prev[63:32]}):
                                                 (woffs_r[0] ? {din[15:0],din_prev[63:16]} : din[63:0]);
    wire               [3:0] fifo_di_vld; // Assign                                             
    
    always @ (posedge hclk) begin
        if      (hrst)  busy <= 0;
        else if (start) busy <= 1;
        else if (done)  busy <= 0;
        
        if       (start) qwcntr <= wcnt[WCNT_BITS-1:2];
        else if (din_re) qwcntr <= qwcntr - 1;
        
        if (start) some_offs <= wcnt[1:0] != 0;
        
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
    end
    
    always @ (posedge hclk) begin
        hrst_mclk <= hrst;

        if      (hrst_mclk)           fifo_nempty <= {{(ADDRESS_NUM>>1){1'b0}},{(ADDRESS_NUM>>1){1'b1}}};// 8'b00001111
        else if (fifo_rd && raddr[0]) fifo_nempty <= {fifo_nempty[ADDRESS_NUM-2:0],raddr[ADDRESS_BITS+1] ^ raddr[ADDRESS_BITS]};
        
        fifo_dav <=  fifo_full [raddr[ADDRESS_BITS:1]] ^ raddr[ADDRESS_BITS+1];
        fifo_dav2 <= fifo_full2[raddr[ADDRESS_BITS:1]];
    end
    
    ahci_dma_rd_stuff ahci_dma_rd_stuff_i (
        .rst      (mrst), // input
        .clk      (mclk), // input
        .din_av   (), // input
        .din_avm  (), // input
        .flush    (), // input
        .din      (), // input[31:0] 
        .dm       (), // input[1:0] 
        .din_re   (), // output
        .dout     (dout),     // output[31:0] reg 
        .dout_vld (dout_vld), // output
        .dout_re  (dout_re)   // input
    );
    
    


endmodule

