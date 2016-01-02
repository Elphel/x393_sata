/*******************************************************************************
 * Module: ahci_dma_rd_stuff
 * Date:2016-01-01  
 * Author: andrey     
 * Description: Stuff DWORD data with missing words into continuous 32-bit data
 *
 * Copyright (c) 2016 Elphel, Inc .
 * ahci_dma_rd_stuff.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  ahci_dma_rd_stuff.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  ahci_dma_rd_stuff(
    input             rst,      // sync reset
    input             clk,      // single clock
    input             din_av,   // input data available
    input             din_avm,  // >1 word of data available
    input             flush,    // output partial dword if available (should be ? cycles after last _re/ with data?)
    input      [31:0] din,      // 32-bit input dfata
    input       [1:0] dm,       // data mask showing which (if any) words in input dword are valid 
    output            din_re,   // read input data
    output reg [31:0] dout,     // output 32-bit data
    output            dout_vld, // output data valid
    input             dout_re   // consumer reads output data (should be anded with dout_vld)
);
    reg  [15:0] hr; // holds 16-bit data from previous din_re if not consumed
    reg         hr_full;
    reg         dout_vld_r;
    reg         flushing;
    wire        din_av_safe = din_av && (din_avm || !din_re);
    wire  [1:0] dav_in = {2{din_av_safe}} & dm;
    wire        two_words_avail = &dav_in || (|dav_in && hr_full);
    assign din_re = (din_av_safe && !(|dm)) || ((!dout_vld_r || dout_re) && (two_words_avail)) ; // flush
    assign dout_vld = dout_vld_r;
    always @ (posedge clk) begin
        if ((!dout_vld_r || dout_re) && (two_words_avail || flushing) ) begin
            if (hr_full)               dout[15: 0] <= hr;
            else                       dout[15: 0] <= din[15: 0];
            
            if (hr_full && dav_in[0])  dout[31:16] <= din[15: 0];
            else                       dout[31:16] <= din[31:16];
        end

        // todo add reset/flush
        if (!dout_vld_r || dout_re)
            // 2 but not 3 sources available
            if (flushing || ((two_words_avail) && ! (&dav_in && hr_full))) hr_full <= 0;
        else if (dav_in[0] ^ dav_in[1]) hr_full <= 1;

        if ((!dout_vld_r || dout_re) && (&dav_in && hr_full)) hr <= din[31:16];
        else if ((dav_in[0] ^ dav_in[1]) && !hr_full)         hr <= dav_in[0]? din[15:0] : din[31:16];

        if      (rst)                                                                    dout_vld_r <= 0;
        else if ((!dout_vld_r || dout_re) && (two_words_avail || (flushing && hr_full))) dout_vld_r <= 1;
        else if (dout_re)                                                                dout_vld_r <= 0;
        
        if      (rst)                                               flushing <= 0;
        else if (flush)                                             flushing <= 1;
        else if ((!dout_vld_r || dout_re) && !(&dav_in && hr_full)) flushing <= 0; 

        
    end
    


endmodule

