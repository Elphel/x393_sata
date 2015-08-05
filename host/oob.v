/*******************************************************************************
 * Module: oob
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: sata oob unit implementation
 *
 * Copyright (c) 2015 Elphel, Inc.
 * oob.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * oob.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
/*
 * For now both device and host shall be set up to SATA2 speeds.
 * Need to think how to change speed grades on fly (either to broaden 
 * data iface width or to change RXRATE/TXRATE)
 */
// All references to doc = to SerialATA_Revision_2_6_Gold.pdf
module oob #(
    parameter DATA_BYTE_WIDTH = 4,
    parameter CLK_SPEED_GRADE = 2, // 1 - 75 Mhz, 2 - 150Mhz, 4 - 300Mhz
)
(
    // sata clk = usrclk2
    input   wire    clk,
    // reset oob
    input   wire    rst,
    // gtx is ready = all resets are done TODO move it to control oobstart/status control block
    input   wire    gtx_ready,
    // oob responces
    input   wire    rxcominitdet_in,
    input   wire    rxcomwakedet_in,
    input   wire    rxelecidle_in,
    // oob issues
    output  wire    txcominit,
    output  wire    txcomwake,
    output  wire    txelecidle,

    // input data stream (if any data during OOB setting => ignored)
    input   wire    [DATA_BYTE_WIDTH*8 - 1:0] txdata_in,
    input   wire    [DATA_BYTE_WIDTH - 1:0]   txcharisk_in,
    // output data stream to gtx
    output  wire    [DATA_BYTE_WIDTH*8 - 1:0] txdata_out,
    output  wire    [DATA_BYTE_WIDTH - 1:0]   txcharisk_out,
    // input data from gtx
    input   wire    [DATA_BYTE_WIDTH*8 - 1:0] rxdata_in,
    input   wire    [DATA_BYTE_WIDTH - 1:0]   rxcharisk_in,
    // bypassed data from gtx
    output  wire    [DATA_BYTE_WIDTH*8 - 1:0] rxdata_out,
    output  wire    [DATA_BYTE_WIDTH - 1:0]   rxcharisk_out,

    // oob sequence needs to be issued
    input   wire    oob_start,
    // connection established, all further data is valid
    output  wire    oob_done,

    // doc p265, link is established after 3back-to-back non-ALIGNp
    output  wire    link_up,

    // the device itself sends cominit
    output  wire    cominit_req,
    // allow to respond to cominit
    input   wire    cominit_allow,

    // status information to handle by a control block if any exists
    // incompatible host-device speed grades (host cannot lock to alignp)
    output  wire    oob_incompatible,
    // timeout in an unexpected place
    output  wire    oob_error,
    // noone responds to our cominits
    output  wire    oob_silence

`ifdef OOB_MULTISPEED
    //TODO
    // !!Implement it later on, ref to gen.adjustment fsm in the notebook!!

    // speed grade control
    ,
    // current speed grade, dynamic instead of static parameter
    input   wire    [2:0]   speed_grade,
    // clock to be adjusted to best speed
    input   wire    adj_clk,
    // ask for slower protocol clock
    output  wire    speed_down_req,
    input   wire    speed_down_ack,
    // reset speedgrade to the fastest one
    output  wire    speed_rst_req,
    input   wire    speed_rst_ack
`endif OOB_MULTISPEED
);

// 873.8 us error timer
// = 2621400 SATA2 serial ticks (period = 0.000333 us)
// = 131070 ticks @ 150Mhz
// = 65535  ticks @ 75Mhz 
localparam  [19:0]  CLK_TO_TIMER_CONTRIB = CLK_SPEED_GRADE == 1 ? 20'h4 :
                                           CLK_SPEED_GRADE == 2 ? 20'h2 :
                                           CLK_SPEED_GRADE == 4 ? 20'h1 : 20'h1;
localparam  [19:0]  TIMER_LIMIT = 19'd262140;
reg     [19:0]  timer;
wire            timer_clr;
wire            timer_fin;

// latching inputs from gtx
reg     rxcominitdet;
reg     rxcomwakedet;
reg     rxelecidle;
reg     [DATA_BYTE_WIDTH*8 - 1:0] rxdata;
reg     [DATA_BYTE_WIDTH - 1:0]   rxcharisk;

// primitives detection
wire    detected_alignp;
wire    detected_synp;

// fsm, doc p265,266
wire    state_idle;
reg     state_wait_cominit;
reg     state_wait_comwake;
reg     state_wait_align;
reg     state_wait_synp;
reg     state_wait_linkup;
reg     state_error;

wire    set_wait_cominit;
wire    set_wait_comwake;
wire    set_wait_align;
wire    set_wait_synp;
wire    set_wait_linkup;
wire    set_error;
wire    clr_wait_cominit;
wire    clr_wait_comwake;
wire    clr_wait_align;
wire    clr_wait_synp;
wire    clr_wait_linkup;
wire    clr_error;

assign  state_idle = ~state_wait_cominit & ~state_wait_comwake & ~state_wait_align & ~state_wait_synp & ~state_wait_linkup & ~state_error;
always @ (posedge clk)
begin
    state_wait_cominit  <= (state_wait_cominit | set_wait_cominit) & ~clr_wait_cominit & ~rst;
    state_wait_comwake  <= (state_wait_comwake | set_wait_comwake) & ~clr_wait_comwake & ~rst;
    state_wait_align    <= (state_wait_align   | set_wait_align  ) & ~clr_wait_align   & ~rst;
    state_wait_synp     <= (state_wait_synp    | set_wait_synp   ) & ~clr_wait_synp    & ~rst;
    state_wait_linkup   <= (state_wait_linkup  | set_wait_linkup ) & ~clr_wait_linkup  & ~rst;
    state_error         <= (state_error        | set_error       ) & ~clr_error        & ~rst;
end

assign  set_wait_cominit = state_idle & oob_start & ~cominit_req;
assign  set_wait_comwake = state_idle & cominit_req & cominit_allow | state_wait_cominit & rxcominitdet;
assign  set_wait_align   = state_wait_comwake & rxcomwakedet;
assign  set_wait_synp    = state_wait_align & detected_alignp;
assign  set_wait_linkup  = state_wait_synp & detected_synp;
assign  set_error        = timer_fin & (state_wait_cominit | state_wait_comwake | state_wait_align | state_wait_synp/* | state_wait_linkup*/);
assign  clr_wait_cominit = set_wait_comwake | set_error;
assign  clr_wait_comwake = set_wait_align | set_error;
assign  clr_wait_align   = set_wait_synp | set_error;
assign  clr_wait_synp    = set_wait_linkup | set_error;
assign  clr_wait_linkup  = state_linkup; //TODO not so important, but still have to trace 3 back-to-back non alignp primitives
assign  clr_error        = state_error;

// waiting timeout timer
assign  timer_fin = timer == TIMER_LIMIT;
assign  timer_clr = set_error | state_idle;
always @ (posedge clk)
    timer <= rst ? 20'h0 : timer + CLK_TO_TIMER_CONTRIB;

// something is wrong with speed grades if the host cannot lock to device's alignp stream
assign  oob_incompatible = state_wait_align & set_error;

// oob sequence is done, everything is okay
assign  oob_done = set_wait_linkup;

// noone responds to cominits
assign  oob_silince = set_error & state_wait_cominit;

// other timeouts
assign  oob_error = set_error & ~oob_silence & ~oob_incompatible;

// set gtx controls
reg     txelecidle_r;
always @ (posedge clk)
    txelecidle_r <= rst ? 1'b0 : clr_wait_cominit ? 1'b0 : set_wait_cominit ? 1'b1 : txelecidle_r;

assign  txcominit  = set_wait_cominit;
assign  txcomwake  = set_wait_comwake;
assign  txelecidle = set_wait_cominit | txelecidle_r;

// indicate if link up condition was made
assign  link_up = clr_wait_linkup;

// indicate that device is requesting for oob
reg     cominit_req_r;
wire    cominit_req_set;

assign  cominit_req_set = state_idle & rxcominitdet;
always @ (posedge clk)
    cominit_req_r <= (cominit_req_r | cominit_req_set) & ~(cominit_allow & cominit_req) & ~rst;
assign  cominit_req = cominit_req_set | cominit_req_r;

// detect which primitives sends the device after comwake was done
generate 
    if (DATA_BYTE_WIDTH == 16)
    begin
        reg detected_alignp_f;
        always @ (posedge clk)
            detected_alignp_f <= rst | ~state_wait_align ? 1'b0 : 
                                 ~|(rxdata ^ {8'b01001010, 8'b10111100}) & ~|(rxchaisk ^ 2'b01); // {D10.2, K28.5}
        assign detected_alignp = detected_aligp_f & ~|(rxdata ^ {8'b01111011, 8'b01001010}) & ~|(rxchaisk ^ 2'b00); // {D27.3, D10.2}
        
        reg detected_syncp_f;
        always @ (posedge clk)
            detected_syncp_f <= rst | ~state_wait_sync ? 1'b0 : 
                                ~|(rxdata ^ {8'b10010101, 8'b01111100}) & ~|(rxchaisk ^ 2'b01); // {D21.4, K28.3}
        assign detected_syncp = detected_syncp_f & ~|(rxdata ^ {8'b10110101, 8'b10110101}) & ~|(rxchaisk ^ 2'b00); // {D21.5, D21.5}
    end
    else
    if (DATA_BYTE_WIDTH == 32)
    begin
        assign detected_alignp = detected_aligp_f & ~|(rxdata ^ {8'b01111011, 8'b01001010, 8'b01001010, 8'b10111100}) & ~|(rxchaisk ^ 4'h1); // {D27.3, D10.2, D10.2, K28.5}
        assign detected_syncp  = detected_syncp_f & ~|(rxdata ^ {8'b10110101, 8'b10110101, 8'b10010101, 8'b01111100}) & ~|(rxchaisk ^ 4'h1); // {D21.5, D21.5, D21.4, K28.3}
    end
    else
    if (DATA_BYTE_WIDTH == 64)
    begin
        assign detected_alignp = detected_aligp_f & ~|(rxdata ^ {2{8'b01111011, 8'b01001010, 8'b01001010, 8'b10111100}}) & ~|(rxchaisk ^ 8'h11); // {D27.3, D10.2, D10.2, K28.5}
        assign detected_syncp  = detected_syncp_f & ~|(rxdata ^ {2{8'b10110101, 8'b10110101, 8'b10010101, 8'b01111100}}) & ~|(rxchaisk ^ 8'h11); // {D21.5, D21.5, D21.4, K28.3}
    end
    else
        $display("%m oob module works only with 16/32/64 gtx input data width");
endgenerate

// buf inputs from gtx
always @ (posedge clk)
begin
    rxcominitdet <= rxcominitdet_in;
    rxcomwakedet <= rxcomwakedet_in;
    rxelecidle   <= rxelecidle_in;
    rxdata       <= rxdata_in;
    rxcharisk    <= rxcharisk_in;
end

// set data outputs to upper levels
assign  rxdata_out    = rxdata;
assign  rxcharisk_out = rxcharisk;

// as depicted @ doc, p264, figure 163, have to insert D10.2 and align primitives after
// getting comwake from device
reg     [DATA_BYTE_WIDTH*8 - 1:0] txdata;
reg     [DATA_BYTE_WIDTH - 1:0]   txcharisk;
wire    [DATA_BYTE_WIDTH*8 - 1:0] txdata_d102;
wire    [DATA_BYTE_WIDTH - 1:0]   txcharisk_d102;
wire    [DATA_BYTE_WIDTH*8 - 1:0] txdata_align;
wire    [DATA_BYTE_WIDTH - 1:0]   txcharisk_align;

always @ (posedge clk)
begin
    txdata      <= state_wait_align ? txdata_d102 :
                   state_wait_sync  ? txdata_align : txdata_in;
    txchaisk    <= state_wait_align ? txcharisk_d102 :
                   state_wait_sync  ? txcharisk_align : txcharisk_in;
end

// Continious D10.2 primitive
assign  txcharisk_d102  = {DATA_BYTE_WIDTH{1'b0}};
assign  txdata_d102     = {DATA_BYTE_WIDTH{8'b01001010}};

// Align primitive: K28.5 + D10.2 + D10.2 + D27.3
generate 
    if (DATA_BYTE_WIDTH == 16)
    begin
        reg align_odd;
        always @ (posedge clk)
            align_odd <= rst | ~state_wait_sync ? 1'b0 : ~align_odd;
        
        assign txcharisk_align  = align_odd ? 2'b01 : 2'b00;
        assign txdata_align     = align_odd ? {8'b01001010, 8'b10111100} : // {D10.2, K28.5}
                                              {8'b01111011, 8'b01001010); // {D27.3, D10.2}
    end
    else
    if (DATA_BYTE_WIDTH == 32)
    begin
        assign txcharisk_align  = 4'h1;
        assign txdata_align     = {8'b01111011, 8'b01001010, 8'b01001010, 8'b10111100}; // {D27.3, D10.2, D10.2, K28.5}
    end
    else
    if (DATA_BYTE_WIDTH == 64)
    begin
        assign txcharisk_align  = 8'h11;
        assign txdata_align     = {2{8'b01111011, 8'b01001010, 8'b01001010, 8'b10111100}}; // 2x{D27.3, D10.2, D10.2, K28.5}
    end
    else
        $display("%m oob module works only with 16/32/64 gtx input data width");
endgenerate

// set data outputs to gtx
assign  txdata_out    = txdata;
assign  txcharisk_out = txcharisk;

endmodule
