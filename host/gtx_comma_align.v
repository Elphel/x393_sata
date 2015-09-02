/*******************************************************************************
 * Module: gtx_comma_align
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: comma aligner implementation
 *
 * Copyright (c) 2015 Elphel, Inc.
 * gtx_comma_align.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * gtx_comma_align.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
module gtx_comma_align(
    input   wire            rst,
    input   wire            clk,
    input   wire    [19:0]  indata,
    output  wire    [19:0]  outdata,
    // outdata contains comma
    output  wire            comma,
    // pulse, indicating that stream was once again adjusted to a comma
    // if asserted after link was down - OK
    // if asserted during a work - most likely indicates an error in a stream
    output  wire            realign
    // asserted when input stream looks like comma, but it is not
    // later on after 10/8 it would get something link NOTINTHETABLE error anyways
//    output  wire            error
);
// only comma character = K28.5, has 5 '1's or 5 '0's in a row. 
// after we met it, call it a comma group, we could compare other symbols
/*
// create a window
reg     [19:0]  indata_r;
wire    [23:0]  window;
always @ (posedge clk)
    indata_r <= indata;
assign  window = {indata_r[17:0], indata[19:14]};

// search for a comma group - parallel 24-bit window into 20 5-bit words
// transposed -> 5 x 20-bit words
wire    [19:0] lane0;
wire    [19:0] lane1;
wire    [19:0] lane2;
wire    [19:0] lane3;
wire    [19:0] lane4;
assign  lane0 = window[19:0];
assign  lane1 = window[20:1];
assign  lane2 = window[21:2];
assign  lane3 = window[22:3];
assign  lane4 = window[23:4];
// calcute at what position in a window comma group is detected, 
// so the position in actual {indata_r, indata} would be +2 from the left side
wire    [19:0] comma_pos;
assign  comma_pos = lane0 & lane1 & lane2 & lane3 & lane4;
*/

// seach for a comma
// TODO make it less expensive
reg     [19:0] indata_r;
wire    [38:0] window;
always @ (posedge clk)
    indata_r <= indata;
assign  window = {indata_r, indata};

// there is only 1 matched subwindow due to 20-bit comma's non-repetative pattern
wire    [19:0]  subwindow [19:0];
wire    [19:0]  comma_match;
reg     [19:0]  aligned_data;
reg     [19:0]  comma_match_prev;
wire            comma_detected;

genvar ii;
generate
    for (ii = 0; ii < 20; ii = ii + 1)
    begin: look_for_comma
        assign  subwindow[ii]   = window[ii + 19:ii];
        assign  comma_match[ii] = subwindow[ii] == 20'b01010101010011111010;
    end
endgenerate

assign  comma_detected = |comma_match;

// save the shift count
always @ (posedge clk)
    comma_match_prev <= rst ? 20'h0 : comma_detected ? comma_match : comma_match_prev;
// shift
wire    [38:0] shifted_window;
assign  shifted_window = comma_detected ? {window >> (comma_match - 1)} : {window >> (comma_match_prev - 1)};
always @ (posedge clk)
//    aligned_data <= comma_detected ? {window >> (comma_match - 1)}[19:0] : {window >> (comma_match_prev - 1)}[19:0];
    aligned_data <= shifted_window[19:0];

// form outputs
assign  comma   = comma_detected;
assign  realign = comma_detected & |(comma_match_prev ^ comma_match);
assign  outdata = aligned_data;

endmodule
