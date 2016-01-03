/*******************************************************************************
 * Module: ahci_dma_wr_fifo
 * Date:2016-01-02  
 * Author: Andrey Filippov
 * Description: cross clocks,  word-realign, 32 -> 64 with byte write mask
 * Convertion from x32 DWORD data received from FIS-es @ mclk to QWORD-aligned
 * AXI data @hclk
 *
 * Copyright (c) 2016 Elphel, Inc .
 * ahci_dma_wr_fifo.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  ahci_dma_wr_fifo.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  ahci_dma_wr_fifo#(
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
    input                 init,  // initializes cross-clock 32->64 FIFO, disables FIFO read until confirmed back form mclk domain
    input                 start, // start transfer
    output reg     [63:0] dout, // allow only each 3-rd wr if not many
    input                 dout_av,      // at least one QWORD space avaiable in AXI FIFO
    input                 dout_av_many, // several QWORD space avaiable in AXI FIFO
    input                 last_prd, // last prd, flush partial dword if there were odd number of words transferred. valid @ start
    // Or maybe use "last_prd"?
    output                dout_we,
    output reg      [3:0] dout_wstb, // word write enable (apply to wstb,  2 wstb input bits for one dout_wstb bit)
    output reg            done,      // this PRD data sent AXI FIFO (Some partial QWORD data may be left in this module if
                                     // last_prd was not set
//    output                done_flush,  // finished last PRD (indicated by last_prd @ start), data left module

    // mclk domain
    output         [31:0] din,
    output                din_rdy, // can accept data from HBA (multiple dwords, so reasonable latency is OK)
    input                 din_avail
);
    localparam ADDRESS_NUM = (1<<ADDRESS_BITS); // 8 for ADDRESS_BITS==3
    reg                   [31:0] fifo0_ram  [0: ADDRESS_NUM - 1];
    reg                   [31:0] fifo1_ram  [0: ADDRESS_NUM - 1];
    wire                         init_mclk;
    wire                         init_confirm;
    reg                          en_fifo_rd;
    reg                          en_fifo_wr;
    wire                         flush_hclk; // TODO: Define (less than 4 left to receive)?
    wire                         flush_mclk;
    wire                         flush_conf;
    reg       [ADDRESS_BITS : 0] raddr; // 1 extra bit       
    reg       [ADDRESS_BITS+1:0] waddr; // 1 extra bit       
    reg                  [63:16] fifo_do_prev; // only 48 bits are needed
    reg  [(1<<ADDRESS_BITS)-1:0] fifo_full;  // set in write clock domain
    reg  [(1<<ADDRESS_BITS)-1:0] fifo_nempty;// set in read clock domain
    wire                         fifo_wr = (din_avail && din_rdy) || (waddr[0] && flush_mclk);
//    wire                         fifo_rd;
    wire [(1<<ADDRESS_BITS)-1:0] fifo_full2 = {fifo_full[0],fifo_full[ADDRESS_NUM-1:1]};
    reg                          hrst_mclk;
    reg                          fifo_dav;  // @hclk
    reg                          fifo_dav2; // @hclk
    reg                          fifo_half_mclk; // Half Fifo is empty, OK to write
    wire                  [63:0] fifo_do =       {fifo1_ram [raddr[ADDRESS_BITS:1]], fifo0_ram [raddr[ADDRESS_BITS:1]]};
    reg                    [1:0] dout_we_r;
    
    reg                    [1:0] wp;   // word pointer in the output (0..3)
    reg                    [1:0] fp;   // pointer in the  {fifo_do,fifo_do_prev} pointer (0 - fifo_do_prev[16], ..., 3 - fifo_do[0])
    reg                    [1:0] wl;   // words left: 0: 1 word, ..., 3: >=4 words
    // implementing 6 -> 23 unregistered ROM
    reg                    [1:0] mx0; //4:1
    reg                    [2:0] mx1; //5:1
    reg                    [2:0] mx2; //6:1
    reg                    [2:0] mx3; //7:1
    reg                    [3:0] pm; // re_dout_wstb;
    reg                          fifo_rd;
//    reg                    [1:0] nwp; // Needed? 0 for all but first
    reg                    [1:0] nfp; //  next {fifo_do,fifo_do_prev} pointer (0 - fifo_do_prev[16], ..., 3 - fifo_do[0])
    reg                    [2:0] swl;  // subtract from words_left;
    // TODO: make separate register bits for  wl == 0, wl > =4
    
    
    
    
    assign din_rdy = en_fifo_wr && fifo_half_mclk;
    assign dout_we = dout_we_r[1]; // dout_we_r[0] - write to dout, use dout_av && (!(|dout_we_r) || dout_av_many) to enable dout_we_r[0]<=
    always @ (posedge hclk) begin
        if      (hrst || init) en_fifo_rd <= 0;
        else if (init_confirm) en_fifo_rd <= 1;
        else if (flush_conf)   en_fifo_rd <= 0;

        if      (hrst || init)        fifo_nempty <= {{(ADDRESS_NUM>>1){1'b0}},{(ADDRESS_NUM>>1){1'b1}}};// 8'b00001111
        else if (fifo_rd && raddr[0]) fifo_nempty <= {fifo_nempty[ADDRESS_NUM-2:0],raddr[ADDRESS_BITS] ^ raddr[ADDRESS_BITS-1]};

        
        fifo_dav <=  !init && en_fifo_rd && (fifo_full [raddr[ADDRESS_BITS:1]] ^ raddr[ADDRESS_BITS]);
        fifo_dav2 <= !init && en_fifo_rd && (fifo_full2[raddr[ADDRESS_BITS:1]]);

        if (fifo_rd) fifo_do_prev[63:16] <= fifo_do[63:16];
    end
    

    // mclk domain
    always @ (posedge mclk) begin
        hrst_mclk <= hrst;

        if      (mrst || hrst_mclk) en_fifo_wr <= 0;
        else if (init_mclk)         en_fifo_wr <= 1;
        else if (flush_mclk)        en_fifo_wr <= 0;


        if (hrst_mclk || init_mclk)    waddr <= 0;
        else if (fifo_wr)              waddr <= waddr + 1; 
        
        if (hrst_mclk || init_mclk)    fifo_full <= 0;
        else if (fifo_wr) fifo_full <= {fifo_full[ADDRESS_NUM-2:0], waddr[ADDRESS_BITS+1]};
        
        fifo_half_mclk <= fifo_nempty [waddr[ADDRESS_BITS:1]] ^ waddr[ADDRESS_BITS+1];
        
        if (fifo_wr && !waddr[0]) fifo0_ram[waddr[ADDRESS_BITS:1]] <= din;
        if (fifo_wr &&  waddr[0]) fifo1_ram[waddr[ADDRESS_BITS:1]] <= din;
        
    end


    // hclk -> mclk cross-clock synchronization
    pulse_cross_clock #(
        .EXTRA_DLY(0)
    ) init_mclk_i (
        .rst       (hrst),            // input
        .src_clk   (hclk),            // input
        .dst_clk   (mclk),            // input
        .in_pulse  (init),            // input
        .out_pulse (init_mclk),       // output
        .busy()                       // output
    );

    pulse_cross_clock #(
        .EXTRA_DLY(0)
    ) flush_mclk_i (
        .rst       (hrst),            // input
        .src_clk   (hclk),            // input
        .dst_clk   (mclk),            // input
        .in_pulse  (flush_hclk),      // input
        .out_pulse (flush_mclk),      // output
        .busy()                       // output
    );

    // mclk -> hclk cross-clock synchronization
    pulse_cross_clock #(
        .EXTRA_DLY(0)
    ) init_confirm_i (
        .rst       (mrst),            // input
        .src_clk   (mclk),            // input
        .dst_clk   (hclk),            // input
        .in_pulse  (init_mclk),       // input
        .out_pulse (init_confirm),    // output
        .busy()                       // output
    );

    pulse_cross_clock #(
        .EXTRA_DLY(0)
    ) flush_conf_i (
        .rst       (mrst),            // input
        .src_clk   (mclk),            // input
        .dst_clk   (hclk),            // input
        .in_pulse  (flush_mclk),      // input
        .out_pulse (flush_conf),      // output
        .busy()                       // output
    );

    /*
    wl: 0: left 1 word, 1: left 2 words, 2: left 3 words, 3: left >=4 words
    wp (pointer in the output qword, only first in PRD can be non-zero) 0: word 0 of output QW, ...
    mx0 0: use fifo_do_prev[16], 1: fifo_do_prev[32], 2:fifo_do_prev[48], 3:fifo_do[0];
    mx1 0: use fifo_do_prev[16], 1: fifo_do_prev[32], 2:fifo_do_prev[48], 3:fifo_do[0], 4:fifo_do[16];
    mx2 0: use fifo_do_prev[16], 1: fifo_do_prev[32], 2:fifo_do_prev[48], 3:fifo_do[0], 4:fifo_do[16], 5:fifo_do[32];
    mx3 0: use fifo_do_prev[16], 1: fifo_do_prev[32], 2:fifo_do_prev[48], 3:fifo_do[0], 4:fifo_do[16], 5:fifo_do[32],  6:fifo_do[48];
    fp/nfp: 0 - pointer to fifo_do_prev[16], 1 : fifo_do_prev[32], 2: fifo_do_prev[48], 3: fifo_do[0]
    
    */
    always @* case ({wp, fp, wl})
        6'h00: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b0001; fifo_rd <= 0; nfp <= 1; swl <= 1; end
        6'h01: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b0011; fifo_rd <= 0; nfp <= 2; swl <= 2; end
        6'h02: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b0111; fifo_rd <= 0; nfp <= 3; swl <= 3; end
        6'h03: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b1111; fifo_rd <= 1; nfp <= 0; swl <= 4; end

        6'h04: begin mx0 <= 1; mx1 <= 2; mx2 <= 3; mx3  <= 4; pm <= 4'b0001; fifo_rd <= 0; nfp <= 2; swl <= 1; end
        6'h05: begin mx0 <= 1; mx1 <= 2; mx2 <= 3; mx3  <= 4; pm <= 4'b0011; fifo_rd <= 0; nfp <= 3; swl <= 2; end
        6'h06: begin mx0 <= 1; mx1 <= 2; mx2 <= 3; mx3  <= 4; pm <= 4'b0111; fifo_rd <= 1; nfp <= 0; swl <= 3; end
        6'h07: begin mx0 <= 1; mx1 <= 2; mx2 <= 3; mx3  <= 4; pm <= 4'b1111; fifo_rd <= 1; nfp <= 1; swl <= 4; end

        6'h08: begin mx0 <= 2; mx1 <= 3; mx2 <= 4; mx3  <= 5; pm <= 4'b0001; fifo_rd <= 0; nfp <= 3; swl <= 1; end
        6'h09: begin mx0 <= 2; mx1 <= 3; mx2 <= 4; mx3  <= 5; pm <= 4'b0011; fifo_rd <= 1; nfp <= 0; swl <= 2; end
        6'h0a: begin mx0 <= 2; mx1 <= 3; mx2 <= 4; mx3  <= 5; pm <= 4'b0111; fifo_rd <= 1; nfp <= 1; swl <= 3; end
        6'h0b: begin mx0 <= 2; mx1 <= 3; mx2 <= 4; mx3  <= 5; pm <= 4'b1111; fifo_rd <= 1; nfp <= 2; swl <= 4; end

        6'h0c: begin mx0 <= 3; mx1 <= 4; mx2 <= 5; mx3  <= 6; pm <= 4'b0001; fifo_rd <= 1; nfp <= 0; swl <= 1; end
        6'h0d: begin mx0 <= 3; mx1 <= 4; mx2 <= 5; mx3  <= 6; pm <= 4'b0011; fifo_rd <= 1; nfp <= 1; swl <= 2; end
        6'h0e: begin mx0 <= 3; mx1 <= 4; mx2 <= 5; mx3  <= 6; pm <= 4'b0111; fifo_rd <= 1; nfp <= 2; swl <= 3; end
        6'h0f: begin mx0 <= 3; mx1 <= 4; mx2 <= 5; mx3  <= 6; pm <= 4'b1111; fifo_rd <= 1; nfp <= 3; swl <= 4; end

        6'h10: begin mx0 <= 0; mx1 <= 0; mx2 <= 1; mx3  <= 2; pm <= 4'b0010; fifo_rd <= 0; nfp <= 1; swl <= 1; end
        6'h11: begin mx0 <= 0; mx1 <= 0; mx2 <= 1; mx3  <= 2; pm <= 4'b0110; fifo_rd <= 0; nfp <= 2; swl <= 2; end
        6'h12: begin mx0 <= 0; mx1 <= 0; mx2 <= 1; mx3  <= 2; pm <= 4'b1110; fifo_rd <= 0; nfp <= 3; swl <= 3; end
        6'h13: begin mx0 <= 0; mx1 <= 0; mx2 <= 1; mx3  <= 2; pm <= 4'b1110; fifo_rd <= 0; nfp <= 3; swl <= 3; end

        6'h14: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b0010; fifo_rd <= 0; nfp <= 2; swl <= 1; end
        6'h15: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b0110; fifo_rd <= 0; nfp <= 3; swl <= 2; end
        6'h16: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b1110; fifo_rd <= 1; nfp <= 0; swl <= 3; end
        6'h17: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b1110; fifo_rd <= 1; nfp <= 0; swl <= 3; end

        6'h18: begin mx0 <= 1; mx1 <= 2; mx2 <= 3; mx3  <= 4; pm <= 4'b0010; fifo_rd <= 0; nfp <= 3; swl <= 1; end
        6'h19: begin mx0 <= 1; mx1 <= 2; mx2 <= 3; mx3  <= 4; pm <= 4'b0110; fifo_rd <= 1; nfp <= 0; swl <= 2; end
        6'h1a: begin mx0 <= 1; mx1 <= 2; mx2 <= 3; mx3  <= 4; pm <= 4'b1110; fifo_rd <= 1; nfp <= 1; swl <= 3; end
        6'h1b: begin mx0 <= 1; mx1 <= 2; mx2 <= 3; mx3  <= 4; pm <= 4'b1110; fifo_rd <= 1; nfp <= 1; swl <= 3; end
        
        6'h1c: begin mx0 <= 2; mx1 <= 3; mx2 <= 4; mx3  <= 5; pm <= 4'b0010; fifo_rd <= 1; nfp <= 0; swl <= 1; end
        6'h1d: begin mx0 <= 2; mx1 <= 3; mx2 <= 4; mx3  <= 5; pm <= 4'b0110; fifo_rd <= 1; nfp <= 1; swl <= 2; end
        6'h1e: begin mx0 <= 2; mx1 <= 3; mx2 <= 4; mx3  <= 5; pm <= 4'b1110; fifo_rd <= 1; nfp <= 2; swl <= 3; end
        6'h1f: begin mx0 <= 2; mx1 <= 3; mx2 <= 4; mx3  <= 5; pm <= 4'b1110; fifo_rd <= 1; nfp <= 2; swl <= 3; end
        
        6'h20: begin mx0 <= 0; mx1 <= 0; mx2 <= 0; mx3  <= 1; pm <= 4'b0100; fifo_rd <= 0; nfp <= 1; swl <= 1; end
        6'h21: begin mx0 <= 0; mx1 <= 0; mx2 <= 0; mx3  <= 1; pm <= 4'b1100; fifo_rd <= 0; nfp <= 2; swl <= 2; end
        6'h22: begin mx0 <= 0; mx1 <= 0; mx2 <= 0; mx3  <= 1; pm <= 4'b1100; fifo_rd <= 0; nfp <= 2; swl <= 2; end
        6'h23: begin mx0 <= 0; mx1 <= 0; mx2 <= 0; mx3  <= 1; pm <= 4'b1100; fifo_rd <= 0; nfp <= 2; swl <= 2; end

        6'h24: begin mx0 <= 0; mx1 <= 0; mx2 <= 1; mx3  <= 2; pm <= 4'b0100; fifo_rd <= 0; nfp <= 2; swl <= 1; end
        6'h25: begin mx0 <= 0; mx1 <= 0; mx2 <= 1; mx3  <= 2; pm <= 4'b1100; fifo_rd <= 0; nfp <= 3; swl <= 2; end
        6'h26: begin mx0 <= 0; mx1 <= 0; mx2 <= 1; mx3  <= 2; pm <= 4'b1100; fifo_rd <= 0; nfp <= 3; swl <= 2; end
        6'h27: begin mx0 <= 0; mx1 <= 0; mx2 <= 1; mx3  <= 2; pm <= 4'b1100; fifo_rd <= 0; nfp <= 3; swl <= 2; end

        6'h28: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b0100; fifo_rd <= 0; nfp <= 3; swl <= 1; end
        6'h29: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b1100; fifo_rd <= 1; nfp <= 0; swl <= 2; end
        6'h2a: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b1100; fifo_rd <= 1; nfp <= 0; swl <= 2; end
        6'h2b: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b1100; fifo_rd <= 1; nfp <= 0; swl <= 2; end

        6'h2c: begin mx0 <= 1; mx1 <= 2; mx2 <= 3; mx3  <= 4; pm <= 4'b0100; fifo_rd <= 1; nfp <= 0; swl <= 1; end
        6'h2d: begin mx0 <= 1; mx1 <= 2; mx2 <= 3; mx3  <= 4; pm <= 4'b1100; fifo_rd <= 1; nfp <= 1; swl <= 2; end
        6'h2e: begin mx0 <= 1; mx1 <= 2; mx2 <= 3; mx3  <= 4; pm <= 4'b1100; fifo_rd <= 1; nfp <= 1; swl <= 2; end
        6'h2f: begin mx0 <= 1; mx1 <= 2; mx2 <= 3; mx3  <= 4; pm <= 4'b1100; fifo_rd <= 1; nfp <= 1; swl <= 2; end

        6'h30: begin mx0 <= 0; mx1 <= 0; mx2 <= 0; mx3  <= 0; pm <= 4'b1000; fifo_rd <= 0; nfp <= 1; swl <= 1; end
        6'h31: begin mx0 <= 0; mx1 <= 0; mx2 <= 0; mx3  <= 0; pm <= 4'b1000; fifo_rd <= 0; nfp <= 1; swl <= 1; end
        6'h32: begin mx0 <= 0; mx1 <= 0; mx2 <= 0; mx3  <= 0; pm <= 4'b1000; fifo_rd <= 0; nfp <= 1; swl <= 1; end
        6'h33: begin mx0 <= 0; mx1 <= 0; mx2 <= 0; mx3  <= 0; pm <= 4'b1000; fifo_rd <= 0; nfp <= 1; swl <= 1; end
        
        6'h34: begin mx0 <= 0; mx1 <= 0; mx2 <= 0; mx3  <= 1; pm <= 4'b1000; fifo_rd <= 0; nfp <= 2; swl <= 1; end
        6'h35: begin mx0 <= 0; mx1 <= 0; mx2 <= 0; mx3  <= 1; pm <= 4'b1000; fifo_rd <= 0; nfp <= 2; swl <= 1; end
        6'h36: begin mx0 <= 0; mx1 <= 0; mx2 <= 0; mx3  <= 1; pm <= 4'b1000; fifo_rd <= 0; nfp <= 2; swl <= 1; end
        6'h37: begin mx0 <= 0; mx1 <= 0; mx2 <= 0; mx3  <= 1; pm <= 4'b1000; fifo_rd <= 0; nfp <= 2; swl <= 1; end

        6'h38: begin mx0 <= 0; mx1 <= 0; mx2 <= 1; mx3  <= 2; pm <= 4'b1000; fifo_rd <= 0; nfp <= 3; swl <= 1; end
        6'h39: begin mx0 <= 0; mx1 <= 0; mx2 <= 1; mx3  <= 2; pm <= 4'b1000; fifo_rd <= 0; nfp <= 3; swl <= 1; end
        6'h3a: begin mx0 <= 0; mx1 <= 0; mx2 <= 1; mx3  <= 2; pm <= 4'b1000; fifo_rd <= 0; nfp <= 3; swl <= 1; end
        6'h3b: begin mx0 <= 0; mx1 <= 0; mx2 <= 1; mx3  <= 2; pm <= 4'b1000; fifo_rd <= 0; nfp <= 3; swl <= 1; end

        6'h3c: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b1000; fifo_rd <= 1; nfp <= 0; swl <= 1; end
        6'h3d: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b1000; fifo_rd <= 1; nfp <= 0; swl <= 1; end
        6'h3e: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b1000; fifo_rd <= 1; nfp <= 0; swl <= 1; end
        6'h3f: begin mx0 <= 0; mx1 <= 1; mx2 <= 2; mx3  <= 3; pm <= 4'b1000; fifo_rd <= 1; nfp <= 0; swl <= 1; end
    endcase

endmodule

