/*******************************************************************************
 * Module: oob_ctrl
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: module to start oob sequences and to handle errors
 *
 * Copyright (c) 2015 Elphel, Inc.
 * oob_ctrl.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * oob_ctrl.v file is distributed in the hope that it will be useful,
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
//`include "oob.v"
module oob_ctrl #(
    parameter DATA_BYTE_WIDTH = 4,
    parameter CLK_SPEED_GRADE = 1 // 1 - 75 Mhz, 2 - 150Mhz, 4 - 300Mhz
)
(
    // sata clk = usrclk2
    input   wire    clk,
    // reset oob
    input   wire    rst,
    // gtx is ready = all resets are done
    input   wire    gtx_ready,
    output  wire  [11:0] debug,
    // oob responses
    input   wire    rxcominitdet_in,
    input   wire    rxcomwakedet_in,
    input   wire    rxelecidle_in,
    // oob issues
    output  wire    txcominit,
    output  wire    txcomwake,
    output  wire    txelecidle,
    // partial tx reset
    output  wire    txpcsreset_req,
    input   wire    recal_tx_done,
    // rx reset (after rxelecidle -> 0)
    output  wire    rxreset_req,
    input   wire    rxreset_ack,

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

    // obvious
    input   wire    rxbyteisaligned,

    // shows if channel is ready
    output  wire    phy_ready
);

// oob sequence needs to be issued
wire    oob_start;
// connection established, all further data is valid
wire    oob_done;

// doc p265, link is established after 3back-to-back non-ALIGNp
wire    link_up;
wire    link_down;

// the device itself sends cominit
wire    cominit_req;
// allow to respond to cominit
wire    cominit_allow;

// status information to handle by a control block if any exists
// incompatible host-device speed grades (host cannot lock to alignp)
wire    oob_incompatible; // TODO
// timeout in an unexpected place
wire    oob_error;
// noone responds to our cominits
wire    oob_silence;
// obvious
wire    oob_busy;

// 1 - link is up and running, 0 - probably not
reg     link_state;
// 1 - connection is being established OR already established, 0 - is not
reg     oob_state;

assign  phy_ready = link_state & gtx_ready & rxbyteisaligned;

always @ (posedge clk)
    link_state  <= (link_state | link_up) & ~link_down & ~rst; 

always @ (posedge clk)
    oob_state   <= (oob_state | oob_start | cominit_req & cominit_allow) & ~oob_error & ~oob_silence & ~(link_down & ~oob_busy & ~oob_start) & ~rst;

// decide when to issue oob: always when gtx is ready
assign  oob_start = gtx_ready & ~oob_state & ~oob_busy;

// set line to idle state before if we're waiting for a device to answer AND while oob sequence
wire    txelecidle_inner;
assign  txelecidle = /*~oob_state |*/ txelecidle_inner;

// let devices always begin oob sequence, if only it's not a glitch
assign  cominit_allow = cominit_req & link_state;

oob #(
    .DATA_BYTE_WIDTH    (DATA_BYTE_WIDTH),
    .CLK_SPEED_GRADE    (CLK_SPEED_GRADE)
)
oob
(
    .debug (debug),
// sata clk = usrclk2
    .clk                            (clk),
// reset oob
    .rst                            (rst),
// oob responses
    .rxcominitdet_in                (rxcominitdet_in),
    .rxcomwakedet_in                (rxcomwakedet_in),
    .rxelecidle_in                  (rxelecidle_in),
// oob issues
    .txcominit                      (txcominit),
    .txcomwake                      (txcomwake),
    .txelecidle                     (txelecidle_inner),

    .txpcsreset_req                 (txpcsreset_req),
    .recal_tx_done                  (recal_tx_done),

    .rxreset_req                    (rxreset_req),
    .rxreset_ack                    (rxreset_ack),

// input data stream (if any data during OOB setting => ignored)
    .txdata_in                      (txdata_in),
    .txcharisk_in                   (txcharisk_in),
// output data stream to gtx
    .txdata_out                     (txdata_out),
    .txcharisk_out                  (txcharisk_out),
// input data from gtx
    .rxdata_in                      (rxdata_in),
    .rxcharisk_in                   (rxcharisk_in),
// bypassed data from gtx
    .rxdata_out                     (rxdata_out),
    .rxcharisk_out                  (rxcharisk_out),

// oob sequence needs to be issued
    .oob_start                      (oob_start),
// connection established, all further data is valid
    .oob_done                       (oob_done),

// doc p265, link is established after 3back-to-back non-ALIGNp
    .link_up                        (link_up),
    .link_down                      (link_down),

// the device itself sends cominit
    .cominit_req                    (cominit_req),
// allow to respond to cominit
    .cominit_allow                  (cominit_allow),

// status information to handle by a control block if any exists
// incompatible host-device speed grades (host cannot lock to alignp)
    .oob_incompatible               (oob_incompatible),
// timeout in an unexpected place
    .oob_error                      (oob_error),
// noone responds to our cominits
    .oob_silence                    (oob_silence),
// oob can't handle new start request
    .oob_busy                       (oob_busy)
);


endmodule
