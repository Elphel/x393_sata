/*******************************************************************************
 * Module: sipo_to_xclk_measure
 * Date:2016-02-09  
 * Author: andrey     
 * Description: Measuring phase of the SIPO data output relative to (global) xclk
 * This module allow select all/some of the input data lines and see if the data
 * sampled at negedge of the xclk differs from sampled at the previous or next
 * posedge on any of the selected bits. Mismatch with previous posedge means that
 * data comes while xclk == 0 (input data too late), mismatch with next posedge
 * means that data changes while xclk == 1 (too early). 
 * Input selection for low 16 bits is written at address DRP_MASK_ADDR (0), next
 * 16 bits - at DRP_MASK_ADDR + 1.
 * Measurement starts by writing duration to DRP_TIMER_ADDR (8).
 * Results (number of mismatches) are available as 15-bit numbers at
 * DRP_EARLY_ADDR (9) and DRP_LATE_ADDR (10), MSB indicates that measurement is
 * still in progress (wait it clears, small latency for 0 -> 1 should not be
 * a problem).
 *
 * Copyright (c) 2016 Elphel, Inc .
 * sipo_to_xclk_measure.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  sipo_to_xclk_measure.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  sipo_to_xclk_measure#(
    parameter DATA_WIDTH = 20, // Number of data bits to measure
    parameter DRP_ABITS = 8,
    parameter DRP_MASK_ADDR =   0,
    parameter DRP_MASK_BITS =   3,
    parameter DRP_TIMER_ADDR =  8, // write timer value (how long to count early/late)
    parameter DRP_EARLY_ADDR =  9, // write timer value (how long to count early/late)
    parameter DRP_LATE_ADDR =  10, // write timer value (how long to count early/late)
    parameter DRP_OTHERCTRL_ADDR = 11
)(
    input                   xclk,
    input                   drp_rst, // for other_control
    input  [DATA_WIDTH-1:0] sipo_di,
    output [DATA_WIDTH-1:0] sipo_do, // input data registered @ posedge xclk (to be used by other modules)
    
    input                   drp_clk,
    input                   drp_en, // @aclk strobes drp_ad
    input                   drp_we,
    input   [DRP_ABITS-1:0] drp_addr,       
    input            [15:0] drp_di,
    output reg              drp_rdy,
    output reg       [15:0] drp_do,
    output reg       [15:0] other_control // set/reset some control bits not related to this module
);
    localparam MASK_WORDS = (DATA_WIDTH + 15) >> 4;
    reg          [DATA_WIDTH-1:0] sipo_p;   // input data registered @ posedge xclk
    reg          [DATA_WIDTH-1:0] sipo_n;   // input data registered @ negedge xclk
    reg          [DATA_WIDTH-1:0] sipo_pp;  // input data registered twice @ posedge xclk
    reg          [DATA_WIDTH-1:0] sipo_np;  // input data registered @ negedge xclk, then @ posedge xclk
    reg [(16 * MASK_WORDS) - 1:0] dmask;    // bits to consider (or)
    reg                           input_early_r; // SIPO data is intended to be registered @ posedge xclk
    reg                           input_late_r;
    
    reg                    [15:0] timer_cntr;
    reg                    [14:0] early_cntr;
    reg                    [14:0] late_cntr;
    wire                          timer_start;
    reg                           timer_run;
    
    reg           [DRP_ABITS-1:0] drp_addr_r;
    reg                           drp_wr_r;
    reg                    [ 1:0] drp_rd_r;
    reg                    [15:0] drp_di_r;
    reg                           drp_mask_wr;
    reg                           drp_timer_wr;
    reg                           drp_read_early;
    reg                           drp_read_late;
    reg                           drp_other_ctrl;
    reg                           drp_read_other_ctrl;
    
    localparam DRP_MASK_MASK = (1 << DRP_MASK_BITS) -1;
    assign sipo_do = sipo_p;
    
    
    always @ (negedge xclk) sipo_n <= sipo_di; // only data registered @negedge
    
    always @ (posedge xclk) begin
        sipo_p <= sipo_di;
        sipo_np <= sipo_n;
        sipo_pp <= sipo_p;
        input_early_r <= |(dmask[DATA_WIDTH-1:0] & (sipo_np ^ sipo_pp));
        input_late_r <=  |(dmask[DATA_WIDTH-1:0] & (sipo_np ^ sipo_p));
        
        if      (timer_start) timer_cntr <= drp_di_r;
        else if (timer_run)   timer_cntr <= timer_cntr  - 1;
        
        if      (timer_start)          timer_run <= 1;
        else if (!(|timer_cntr[15:1])) timer_run <= 0;

        if      (timer_start)                early_cntr <= 0;
        else if (timer_run && input_early_r) early_cntr <= early_cntr + 1;

        if      (timer_start)                late_cntr <= 0;
        else if (timer_run && input_late_r)  late_cntr <= late_cntr + 1;
        
    end
    
    // DRP interface
    always @ (posedge drp_clk) begin
        drp_addr_r <=           drp_addr;
        drp_wr_r <=             drp_we && drp_en;
        drp_rd_r <=             {drp_rd_r[0],~drp_we & drp_en};
        drp_di_r <=             drp_di;
        drp_mask_wr <=          drp_wr_r && ((drp_addr_r & ~DRP_MASK_MASK) == DRP_MASK_ADDR);
        drp_timer_wr <=         drp_wr_r && (drp_addr_r == DRP_TIMER_ADDR);
        drp_read_early <=       drp_rd_r[0] && (drp_addr_r == DRP_EARLY_ADDR);
        drp_read_late <=        drp_rd_r[0] && (drp_addr_r == DRP_LATE_ADDR);
        drp_other_ctrl <=       drp_wr_r && (drp_addr_r == DRP_OTHERCTRL_ADDR);
        drp_read_other_ctrl <=  drp_rd_r[0] && (drp_addr_r == DRP_OTHERCTRL_ADDR);       
        drp_rdy <=              drp_wr_r || drp_rd_r[1];
        drp_do <=               ({16{drp_read_early}} & {timer_run,early_cntr}) |
                                ({16{drp_read_late}} & {timer_run,late_cntr}) |
                                ({16{drp_read_other_ctrl}} & {other_control}) ;
        
        if      (drp_rst)        other_control <= 0;
        else if (drp_other_ctrl) other_control <= drp_di_r;
        
    end
    // 0..7 - data mask
    genvar i1;
    generate
        for (i1 = 0; i1 < MASK_WORDS; i1 = i1 + 1) begin: gen_drp_mask
            always @ (posedge drp_clk) 
                if (drp_mask_wr && ((drp_addr_r & DRP_MASK_MASK) ==i1)) dmask[16*i1 +: 16] <= drp_di_r;
        end
    endgenerate

    pulse_cross_clock #(
        .EXTRA_DLY(0)
    ) timer_set_i (
        .rst       (drp_mask_wr),     // input
        .src_clk   (drp_clk),         // input
        .dst_clk   (xclk),            // input
        .in_pulse  (drp_timer_wr),    // input
        .out_pulse (timer_start),     // output
        .busy()                       // output
    );
    


endmodule

