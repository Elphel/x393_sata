/*******************************************************************************
 * Module: link
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: sata link layer implementation
 *
 * Copyright (c) 2015 Elphel, Inc.
 * link.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * link.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`include "scrambler.v"
`include "crc.v"
module link #(
    // 4 = dword. 4-bytes aligned data transfers TODO 2 = word - easy, 8 = qword - difficult
    parameter DATA_BYTE_WIDTH = 4
)
(
    // TODO insert watchdogs
    input   wire    rst,
    input   wire    clk,

    // data inputs from transport layer
    // input data stream (if any data during OOB setting => ignored)
    input   wire    [DATA_BYTE_WIDTH*8 - 1:0] data_in,
    // in case of strange data aligments and size (1st mentioned @ doc, p.310, odd number of words case)
    // Actually, only last data bundle shall be masked, others are always valid.
    // Mask could be encoded into 3 bits instead of 4 for qword, but encoding+decoding aren't worth the bit
    // TODO, for now not supported, all mask bits are assumed to be set
    input   wire    [DATA_BYTE_WIDTH/2 - 1:0] data_mask_in,
    // buffer read strobe
    output  wire    data_strobe_out,
    // transaction's last data budle pulse
    input   wire    data_last_in,
    // read data is valid (if 0 while last pulse wasn't received => need to hold the line)
    input   wire    data_val_in,

    // data outputs to transport layer
    // read data, same as related inputs
    output  wire    [DATA_BYTE_WIDTH*8 - 1:0] data_out,
    // same thing - all 1s for now. TODO
    output  wire    [DATA_BYTE_WIDTH/2 - 1:0] data_mask_out,
    // count every data bundle read by transport layer, even if busy flag is set
    // let the transport layer handle oveflows by himself
    output  wire    data_val_out,
    // transport layer tells if its inner buffer is almost full
    input   wire    data_busy_in,
    output  wire    data_last_out,

    // request for a new frame transition
    input   wire    frame_req,
    // a little bit of overkill with the cound of response signals, think of throwing out 1 of them
    // LL tells back if it cant handle the request for now
    output  wire    frame_busy,
    // LL tells if the request is transmitting
    output  wire    frame_ack,
    // or if it was cancelled because of simultanious incoming transmission
    output  wire    frame_rej,
    // TL tell if the outcoming transaction is done and how it was done
    output  wire    frame_done_good,
    output  wire    frame_done_bad,

    // if started an incoming transaction
    output  wire    incom_start,
    // if incoming transition was completed
    output  wire    incom_done,
    // if incoming transition had errors
    output  wire    incom_invalidate,
    // transport layer responds on a completion of a FIS
    input   wire    incom_ack_good,
    input   wire    incom_ack_bad,

    // oob sequence is reinitiated and link now is not established or rxelecidle
    input   wire    link_reset,
    // TL demands to brutally cancel current transaction
    input   wire    sync_escape_req,
    // acknowlegement of a successful reception
    output  wire    sync_escape_ack,
    // TL demands to stop current recieving session
    input   wire    incom_stop_req,

    // inputs from phy
    // phy is ready - link is established
    input   wire    phy_ready,

    // data-primitives stream from phy
    input   wire    [DATA_BYTE_WIDTH*8 - 1:0] phy_data_in,
    input   wire    [DATA_BYTE_WIDTH   - 1:0] phy_isk_in, // charisk
    input   wire    [DATA_BYTE_WIDTH   - 1:0] phy_err_in, // disperr | notintable
    // to phy
    output  wire    [DATA_BYTE_WIDTH*8 - 1:0] phy_data_out,
    output  wire    [DATA_BYTE_WIDTH   - 1:0] phy_isk_out // charisk


);
// latching data-primitives stream from phy
reg     [DATA_BYTE_WIDTH*8 - 1:0] phy_data_in_r;
reg     [DATA_BYTE_WIDTH   - 1:0] phy_isk_in_r; // charisk
reg     [DATA_BYTE_WIDTH   - 1:0] phy_err_in_r; // disperr | notintable
always @ (posedge clk)
begin
    phy_data_in_r   <= phy_data_in;
    phy_isk_in_r    <= phy_isk_in;
    phy_err_in_r    <= phy_err_in;
end

wire    frame_done;
// scrambled data
wire    [DATA_BYTE_WIDTH*8 - 1:0]   scrambler_out;
wire    dec_err; // doc, p.311 
// while receiving session shows crc check status
wire    crc_good;
wire    crc_bad;
// current crc
wire    [31:0] crc_dword; 

// send primitives variety count, including CRC and DATA as primitives
localparam  PRIM_NUM = 15;
wire    [PRIM_NUM - 1:0] rcvd_dword; // shows current processing primitive (or just data dword)
wire                     dword_val;
// list of bits of rcvd_dword
localparam  CODE_DATA   = 0;
localparam  CODE_CRC    = 1;
localparam  CODE_SYNCP  = 2;
localparam  CODE_ALIGNP = 3;
localparam  CODE_XRDYP  = 4;
localparam  CODE_SOFP   = 5;
localparam  CODE_HOLDAP = 6;
localparam  CODE_HOLDP  = 7;
localparam  CODE_EOFP   = 8;
localparam  CODE_WTRMP  = 9;
localparam  CODE_RRDYP  = 10;
localparam  CODE_IPP    = 11;
localparam  CODE_DMATP  = 12;
localparam  CODE_OKP    = 13;
localparam  CODE_ERRP   = 14;

reg                      data_txing; // if there are still some data to transmit and the transaction wasn't cancelled
always @ (posedge clk)
    data_txing <= rst | (data_last_in & data_strobe_out | dword_val & rcvd_dword[CODE_DMATP]) ? 1'b0 : frame_req ? 1'b1 : data_txing;

// fsm
// states and transitions are taken from the doc, "Link Layer State Machine" chapter
// power mode states are not implemented. TODO insert them as an additional branch of fsm

// !!!IMPORTANT!!! If add/remove any states, dont forget to change this parameter value
localparam STATES_COUNT = 23;
// idle state
wire    state_idle;
reg     state_sync_esc;     // SyncEscape
reg     state_nocommerr;    // NoComErr
reg     state_nocomm;       // NoComm
reg     state_align;        // SendAlign
reg     state_reset;        // RESET
// tranmitter branch
reg     state_send_rdy;     // SendChkRdy
reg     state_send_sof;     // SendSOF
reg     state_send_data;    // SendData
reg     state_send_rhold;   // RcvrHold - hold initiated by current data reciever
reg     state_send_shold;   // SendHold - hold initiated by current data sender
reg     state_send_crc;     // SendCVC
reg     state_send_eof;     // SendEOF
reg     state_wait;         // Wait
// receiver branch
reg     state_rcvr_wait;    // RcvWaitFifo
reg     state_rcvr_rdy;     // RcvChkRdy
reg     state_rcvr_data;    // RcvData
reg     state_rcvr_rhold;   // Hold     - hold initiated by current data reciever
reg     state_rcvr_shold;   // RcvHold  - hold initiated by current data sender
reg     state_rcvr_eof;     // RcvEOF
reg     state_rcvr_goodcrc; // GoodCRC
reg     state_rcvr_goodend; // GoodEnd
reg     state_rcvr_badend;  // BadEnd

wire    set_sync_esc;
wire    set_nocommerr;
wire    set_nocomm;
wire    set_align;
wire    set_reset;
wire    set_send_rdy;
wire    set_send_sof;
wire    set_send_data;
wire    set_send_rhold;
wire    set_send_shold;
wire    set_send_crc;
wire    set_send_eof;
wire    set_wait;
wire    set_rcvr_wait;
wire    set_rcvr_rdy;
wire    set_rcvr_data;
wire    set_rcvr_rhold;
wire    set_rcvr_shold;
wire    set_rcvr_eof;
wire    set_rcvr_goodcrc;
wire    set_rcvr_goodend;
wire    set_rcvr_badend;
                            
wire    clr_sync_esc;
wire    clr_nocommerr;
wire    clr_nocomm;
wire    clr_align;
wire    clr_reset;
wire    clr_send_rdy;
wire    clr_send_sof;
wire    clr_send_data;
wire    clr_send_rhold;
wire    clr_send_shold;
wire    clr_send_crc;
wire    clr_send_eof;
wire    clr_wait;
wire    clr_rcvr_wait;
wire    clr_rcvr_rdy;
wire    clr_rcvr_data;
wire    clr_rcvr_rhold;
wire    clr_rcvr_shold;
wire    clr_rcvr_eof;
wire    clr_rcvr_goodcrc;
wire    clr_rcvr_goodend;
wire    clr_rcvr_badend;

assign state_idle = ~state_sync_esc
                  & ~state_nocommerr
                  & ~state_nocomm
                  & ~state_align
                  & ~state_reset
                  & ~state_send_rdy
                  & ~state_send_sof
                  & ~state_send_data
                  & ~state_send_rhold
                  & ~state_send_shold
                  & ~state_send_crc
                  & ~state_send_eof
                  & ~state_wait
                  & ~state_rcvr_wait
                  & ~state_rcvr_rdy
                  & ~state_rcvr_data
                  & ~state_rcvr_rhold
                  & ~state_rcvr_shold
                  & ~state_rcvr_eof
                  & ~state_rcvr_goodcrc
                  & ~state_rcvr_goodend
                  & ~state_rcvr_badend;


// got an escaping primitive = request to cancel the transmission
wire    alignes_pair;   // pauses every state go give a chance to insert 2 align primitives on a line at least every 256 dwords due to spec
wire    alignes_pair_0; // time for 1st align primitive
wire    alignes_pair_1; // time for 2nd align primitive
reg     [8:0] alignes_timer;

assign  alignes_pair_0 = alignes_timer == 9'd252;
assign  alignes_pair_1 = alignes_timer == 9'd253;
assign  alignes_pair   = alignes_pair_0 | alignes_pair_1;
always @ (posedge clk)
    alignes_timer <= rst | alignes_pair_1 | state_reset ? 9'h0 : alignes_timer + 1'b1;


wire    got_escape;
assign  got_escape = dword_val & rcvd_dword[CODE_SYNCP];

// escaping is done
assign  sync_escape_ack = state_sync_esc;


// Whole transitions table, literally from doc pages 311-328
assign  set_sync_esc        = sync_escape_req;
assign  set_nocommerr       = ~phy_ready & ~state_nocomm & ~state_reset;
assign  set_nocomm          = state_nocommerr;
assign  set_align           = state_reset       & ~link_reset;
assign  set_reset           = link_reset;
assign  set_send_rdy        = state_idle        & frame_req;
assign  set_send_sof        = state_send_rdy    & phy_ready  &                                dword_val &  rcvd_dword[CODE_RRDYP];
assign  set_send_data       = state_send_sof    & phy_ready 
                            | state_send_rhold  & data_txing & ~dec_err &                     dword_val & ~rcvd_dword[CODE_HOLDP] & ~rcvd_dword[CODE_SYNCP] & ~rcvd_dword[CODE_DMATP]
                            | state_send_shold  & data_txing &  data_val_in &                 dword_val & ~rcvd_dword[CODE_HOLDP] & ~rcvd_dword[CODE_SYNCP];
assign  set_send_rhold      = state_send_data   & data_txing &  data_val_in & ~data_last_in & dword_val &  rcvd_dword[CODE_HOLDP]
                            | state_send_shold  & data_txing &  data_val_in &                 dword_val &  rcvd_dword[CODE_HOLDP];
assign  set_send_shold      = state_send_data   & data_txing & ~data_val_in &                 dword_val & ~rcvd_dword[CODE_SYNCP];
assign  set_send_crc        = state_send_data   & data_txing &  data_val_in &  data_last_in & dword_val & ~rcvd_dword[CODE_SYNCP] 
                            | state_send_data   &                                             dword_val &  rcvd_dword[CODE_DMATP];
assign  set_send_eof        = state_send_crc    & phy_ready &                                 dword_val & ~rcvd_dword[CODE_SYNCP];
assign  set_wait            = state_send_eof    & phy_ready &                                 dword_val & ~rcvd_dword[CODE_SYNCP];
// receiver's branch
assign  set_rcvr_wait       = state_idle        & dword_val &  rcvd_dword[CODE_XRDYP]
                            | state_send_rdy    & dword_val &  rcvd_dword[CODE_XRDYP];
assign  set_rcvr_rdy        = state_rcvr_wait   & dword_val &  rcvd_dword[CODE_XRDYP]  & ~data_busy_in;
assign  set_rcvr_data       = state_rcvr_rdy    & dword_val &  rcvd_dword[CODE_SOFP]
                            | state_rcvr_rhold  & dword_val & ~rcvd_dword[CODE_HOLDP] & ~rcvd_dword[CODE_EOFP] & ~rcvd_dword[CODE_SYNCP] & ~data_busy_in
                            | state_rcvr_shold  & dword_val & ~rcvd_dword[CODE_HOLDP] & ~rcvd_dword[CODE_EOFP] & ~rcvd_dword[CODE_SYNCP];
assign  set_rcvr_rhold      = state_rcvr_data   & dword_val &  rcvd_dword[CODE_DATA]  &  data_busy_in;
assign  set_rcvr_shold      = state_rcvr_data   & dword_val &  rcvd_dword[CODE_HOLDP]
                            | state_rcvr_rhold  & dword_val &  rcvd_dword[CODE_HOLDP] & ~data_busy_in;
assign  set_rcvr_eof        = state_rcvr_data   & dword_val &  rcvd_dword[CODE_EOFP]
                            | state_rcvr_rhold  & dword_val &  rcvd_dword[CODE_EOFP]
                            | state_rcvr_shold  & dword_val &  rcvd_dword[CODE_EOFP];
assign  set_rcvr_goodcrc    = state_rcvr_eof    & crc_good;
assign  set_rcvr_goodend    = state_rcvr_goodcrc& incom_ack_good;
assign  set_rcvr_badend     = state_rcvr_data   & dword_val &  rcvd_dword[CODE_WTRMP]
                            | state_rcvr_eof    & crc_bad
                            | state_rcvr_goodcrc& incom_ack_bad;

assign  clr_sync_esc        = set_nocommerr | set_reset                | dword_val & (rcvd_dword[CODE_RRDYP] | rcvd_dword[CODE_SYNCP]);
assign  clr_nocommerr       =                 set_reset                | set_nocomm;
assign  clr_nocomm          =                 set_reset                | set_align;
assign  clr_align           = set_nocommerr | set_reset                | phy_ready;
assign  clr_reset           =                                           ~link_reset;
assign  clr_send_rdy        = set_nocommerr | set_reset | set_sync_esc | set_send_sof | set_rcvr_wait;
assign  clr_send_sof        = set_nocommerr | set_reset | set_sync_esc | set_send_data | got_escape;
assign  clr_send_data       = set_nocommerr | set_reset | set_sync_esc | set_send_rhold | set_send_shold | set_send_crc | got_escape;
assign  clr_send_rhold      = set_nocommerr | set_reset | set_sync_esc | set_send_data | set_send_crc | got_escape;
assign  clr_send_shold      = set_nocommerr | set_reset | set_sync_esc | set_send_data | set_send_rhold | set_send_crc | got_escape;
assign  clr_send_crc        = set_nocommerr | set_reset | set_sync_esc | set_send_eof | got_escape;
assign  clr_send_eof        = set_nocommerr | set_reset | set_sync_esc | set_wait | got_escape;
assign  clr_wait            = set_nocommerr | set_reset | set_sync_esc | frame_done | got_escape; 
assign  clr_rcvr_wait       = set_nocommerr | set_reset | set_sync_esc | set_rcvr_rdy | dword_val & ~rcvd_dword[CODE_XRDYP];
assign  clr_rcvr_rdy        = set_nocommerr | set_reset | set_sync_esc | set_rcvr_data | dword_val & ~rcvd_dword[CODE_XRDYP] & ~rcvd_dword[CODE_SOFP];
assign  clr_rcvr_data       = set_nocommerr | set_reset | set_sync_esc | set_rcvr_rhold | set_rcvr_shold | set_rcvr_eof | set_rcvr_badend | got_escape;
assign  clr_rcvr_rhold      = set_nocommerr | set_reset | set_sync_esc | set_rcvr_data | set_rcvr_eof | set_rcvr_shold | got_escape;
assign  clr_rcvr_shold      = set_nocommerr | set_reset | set_sync_esc | set_rcvr_data | set_rcvr_eof | got_escape;
assign  clr_rcvr_eof        = set_nocommerr | set_reset | set_sync_esc | set_rcvr_goodcrc | set_rcvr_badend;
assign  clr_rcvr_goodcrc    = set_nocommerr | set_reset | set_sync_esc | set_rcvr_goodend | set_rcvr_badend | got_escape;
assign  clr_rcvr_goodend    = set_nocommerr | set_reset | set_sync_esc | got_escape;
assign  clr_rcvr_badend     = set_nocommerr | set_reset | set_sync_esc | got_escape;

// the only truely asynchronous transaction between states is -> state_ reset. It shall not be delayed by sending alignes
// Luckily, while in that state, the line is off, so we dont need to care about merging alignes and state-bounded primitives
// Others transitions are straightforward
always @ (posedge clk)
begin
    state_sync_esc      <= (state_sync_esc     | set_sync_esc     & ~alignes_pair) & ~clr_sync_esc     & ~rst;
    state_nocommerr     <= (state_nocommerr    | set_nocommerr    & ~alignes_pair) & ~clr_nocommerr    & ~rst;
    state_nocomm        <= (state_nocomm       | set_nocomm       & ~alignes_pair) & ~clr_nocomm       & ~rst;
    state_align         <= (state_align        | set_align        & ~alignes_pair) & ~clr_align        & ~rst;
    state_reset         <= (state_reset        | set_reset                       ) & ~clr_reset        & ~rst;
    state_send_rdy      <= (state_send_rdy     | set_send_rdy     & ~alignes_pair) & ~clr_send_rdy     & ~rst;
    state_send_sof      <= (state_send_sof     | set_send_sof     & ~alignes_pair) & ~clr_send_sof     & ~rst;
    state_send_data     <= (state_send_data    | set_send_data    & ~alignes_pair) & ~clr_send_data    & ~rst;
    state_send_rhold    <= (state_send_rhold   | set_send_rhold   & ~alignes_pair) & ~clr_send_rhold   & ~rst;
    state_send_shold    <= (state_send_shold   | set_send_shold   & ~alignes_pair) & ~clr_send_shold   & ~rst;
    state_send_crc      <= (state_send_crc     | set_send_crc     & ~alignes_pair) & ~clr_send_crc     & ~rst;
    state_send_eof      <= (state_send_eof     | set_send_eof     & ~alignes_pair) & ~clr_send_eof     & ~rst;
    state_wait          <= (state_wait         | set_wait         & ~alignes_pair) & ~clr_wait         & ~rst;
    state_rcvr_wait     <= (state_rcvr_wait    | set_rcvr_wait    & ~alignes_pair) & ~clr_rcvr_wait    & ~rst;
    state_rcvr_rdy      <= (state_rcvr_rdy     | set_rcvr_rdy     & ~alignes_pair) & ~clr_rcvr_rdy     & ~rst;
    state_rcvr_data     <= (state_rcvr_data    | set_rcvr_data    & ~alignes_pair) & ~clr_rcvr_data    & ~rst;
    state_rcvr_rhold    <= (state_rcvr_rhold   | set_rcvr_rhold   & ~alignes_pair) & ~clr_rcvr_rhold   & ~rst;
    state_rcvr_shold    <= (state_rcvr_shold   | set_rcvr_shold   & ~alignes_pair) & ~clr_rcvr_shold   & ~rst;
    state_rcvr_eof      <= (state_rcvr_eof     | set_rcvr_eof     & ~alignes_pair) & ~clr_rcvr_eof     & ~rst;
    state_rcvr_goodcrc  <= (state_rcvr_goodcrc | set_rcvr_goodcrc & ~alignes_pair) & ~clr_rcvr_goodcrc & ~rst;
    state_rcvr_goodend  <= (state_rcvr_goodend | set_rcvr_goodend & ~alignes_pair) & ~clr_rcvr_goodend & ~rst;
    state_rcvr_badend   <= (state_rcvr_badend  | set_rcvr_badend  & ~alignes_pair) & ~clr_rcvr_badend  & ~rst;
end

// flag if incoming request to terminate current transaction came from TL
reg     incom_stop_f;
always @ (posedge clk)
    incom_stop_f <= rst | incom_done | ~frame_busy ? 1'b0 : incom_stop_req ? 1'b1 : incom_stop_f;

// form data to phy
reg     [DATA_BYTE_WIDTH*8 - 1:0] to_phy_data;
reg     [DATA_BYTE_WIDTH   - 1:0] to_phy_isk;
// TODO implement CONTP
localparam [15:0] PRIM_SYNCP_HI     = {3'd5, 5'd21, 3'd5, 5'd21};
localparam [15:0] PRIM_SYNCP_LO     = {3'd4, 5'd21, 3'd3, 5'd28};
localparam [15:0] PRIM_ALIGNP_HI	= {3'd3, 5'd27, 3'd2, 5'd10};
localparam [15:0] PRIM_ALIGNP_LO	= {3'd2, 5'd10, 3'd5, 5'd28};
localparam [15:0] PRIM_XRDYP_HI		= {3'd2, 5'd23, 3'd2, 5'd23};
localparam [15:0] PRIM_XRDYP_LO		= {3'd5, 5'd21, 3'd3, 5'd28};
localparam [15:0] PRIM_SOFP_HI		= {3'd1, 5'd23, 3'd1, 5'd23};
localparam [15:0] PRIM_SOFP_LO		= {3'd5, 5'd21, 3'd3, 5'd28};
localparam [15:0] PRIM_HOLDAP_HI	= {3'd4, 5'd21, 3'd4, 5'd21};
localparam [15:0] PRIM_HOLDAP_LO	= {3'd5, 5'd10, 3'd3, 5'd28};
localparam [15:0] PRIM_HOLDP_HI		= {3'd6, 5'd21, 3'd6, 5'd21};
localparam [15:0] PRIM_HOLDP_LO		= {3'd5, 5'd10, 3'd3, 5'd28};
localparam [15:0] PRIM_EOFP_HI		= {3'd6, 5'd21, 3'd6, 5'd21};
localparam [15:0] PRIM_EOFP_LO		= {3'd5, 5'd21, 3'd3, 5'd28};
localparam [15:0] PRIM_WTRMP_HI		= {3'd2, 5'd24, 3'd2, 5'd24};
localparam [15:0] PRIM_WTRMP_LO		= {3'd5, 5'd21, 3'd3, 5'd28};
localparam [15:0] PRIM_RRDYP_HI		= {3'd2, 5'd10, 3'd2, 5'd10};
localparam [15:0] PRIM_RRDYP_LO		= {3'd4, 5'd21, 3'd3, 5'd28};
localparam [15:0] PRIM_IPP_HI		= {3'd2, 5'd21, 3'd2, 5'd21};
localparam [15:0] PRIM_IPP_LO		= {3'd5, 5'd21, 3'd3, 5'd28};
localparam [15:0] PRIM_DMATP_HI		= {3'd1, 5'd22, 3'd1, 5'd22};
localparam [15:0] PRIM_DMATP_LO		= {3'd5, 5'd21, 3'd3, 5'd28};
localparam [15:0] PRIM_OKP_HI		= {3'd1, 5'd21, 3'd1, 5'd21};
localparam [15:0] PRIM_OKP_LO		= {3'd5, 5'd21, 3'd3, 5'd28};
localparam [15:0] PRIM_ERRP_HI		= {3'd2, 5'd22, 3'd2, 5'd22};
localparam [15:0] PRIM_ERRP_LO		= {3'd5, 5'd21, 3'd3, 5'd28};


wire    [DATA_BYTE_WIDTH*8 - 1:0] prim_data [PRIM_NUM - 1:0];

// fill all possible output primitives to choose from them after
generate
if (DATA_BYTE_WIDTH == 2)
begin
    reg     prim_word; // word counter in a primitive TODO logic
    assign  prim_data[CODE_SYNCP] [15:0]    =  prim_word ? PRIM_SYNCP_HI    : PRIM_SYNCP_LO;
    assign  prim_data[CODE_ALIGNP][15:0]    =  prim_word ? PRIM_ALIGNP_HI   : PRIM_ALIGNP_LO;
    assign  prim_data[CODE_XRDYP] [15:0]    =  prim_word ? PRIM_XRDYP_HI    : PRIM_XRDYP_LO;
    assign  prim_data[CODE_SOFP]  [15:0]    =  prim_word ? PRIM_SOFP_HI     : PRIM_SOFP_LO;
    assign  prim_data[CODE_DATA]  [15:0]    =  scrambler_out[15:0];
    assign  prim_data[CODE_HOLDAP][15:0]    =  prim_word ? PRIM_HOLDAP_HI   : PRIM_HOLDAP_LO;
    assign  prim_data[CODE_HOLDP] [15:0]    =  prim_word ? PRIM_HOLDP_HI    : PRIM_HOLDP_LO;
    assign  prim_data[CODE_CRC]   [15:0]    =  scrambler_out[15:0];
    assign  prim_data[CODE_EOFP]  [15:0]    =  prim_word ? PRIM_EOFP_HI     : PRIM_EOFP_LO;
    assign  prim_data[CODE_WTRMP] [15:0]    =  prim_word ? PRIM_WTRMP_HI    : PRIM_WTRMP_LO;
    assign  prim_data[CODE_RRDYP] [15:0]    =  prim_word ? PRIM_RRDYP_HI    : PRIM_RRDYP_LO;
    assign  prim_data[CODE_IPP]   [15:0]    =  prim_word ? PRIM_IPP_HI      : PRIM_IPP_LO;
    assign  prim_data[CODE_DMATP] [15:0]    =  prim_word ? PRIM_DMATP_HI    : PRIM_DMATP_LO;
    assign  prim_data[CODE_OKP]   [15:0]    =  prim_word ? PRIM_OKP_HI      : PRIM_OKP_LO;
    assign  prim_data[CODE_ERRP]  [15:0]    =  prim_word ? PRIM_ERRP_HI     : PRIM_ERRP_LO;
    always @ (posedge clk)
    begin
        $display("%m: unsupported data width");
        $finish;
    end
end
else
if (DATA_BYTE_WIDTH == 4)
begin
    assign  prim_data[CODE_SYNCP]     = {PRIM_SYNCP_HI    , PRIM_SYNCP_LO};
    assign  prim_data[CODE_ALIGNP]    = {PRIM_ALIGNP_HI   , PRIM_ALIGNP_LO};
    assign  prim_data[CODE_XRDYP]     = {PRIM_XRDYP_HI    , PRIM_XRDYP_LO};
    assign  prim_data[CODE_SOFP]      = {PRIM_SOFP_HI     , PRIM_SOFP_LO};
    assign  prim_data[CODE_DATA]      = scrambler_out;
    assign  prim_data[CODE_HOLDAP]    = {PRIM_HOLDAP_HI   , PRIM_HOLDAP_LO};
    assign  prim_data[CODE_HOLDP]     = {PRIM_HOLDP_HI    , PRIM_HOLDP_LO};
    assign  prim_data[CODE_CRC]       = scrambler_out;
    assign  prim_data[CODE_EOFP]      = {PRIM_EOFP_HI     , PRIM_EOFP_LO};
    assign  prim_data[CODE_WTRMP]     = {PRIM_WTRMP_HI    , PRIM_WTRMP_LO};
    assign  prim_data[CODE_RRDYP]     = {PRIM_RRDYP_HI    , PRIM_RRDYP_LO};
    assign  prim_data[CODE_IPP]       = {PRIM_IPP_HI      , PRIM_IPP_LO};
    assign  prim_data[CODE_DMATP]     = {PRIM_DMATP_HI    , PRIM_DMATP_LO};
    assign  prim_data[CODE_OKP]       = {PRIM_OKP_HI      , PRIM_OKP_LO};
    assign  prim_data[CODE_ERRP]      = {PRIM_ERRP_HI     , PRIM_ERRP_LO};
end
else
begin
    always @ (posedge clk)
    begin
        $display("%m: unsupported data width");
        $finish;
    end
end
endgenerate

// select which primitive shall be sent 
wire    [PRIM_NUM - 1:0]    select_prim;
assign  select_prim[CODE_SYNCP]     = ~alignes_pair & (state_idle | state_sync_esc | state_rcvr_wait | state_reset);
assign  select_prim[CODE_ALIGNP]    =  alignes_pair | (state_nocomm | state_nocommerr | state_align);
assign  select_prim[CODE_XRDYP]     = ~alignes_pair & (state_send_rdy);
assign  select_prim[CODE_SOFP]      = ~alignes_pair & (state_send_sof);
assign  select_prim[CODE_DATA]      = ~alignes_pair & (state_send_data & ~set_send_shold); // if there's no data availible for a transmission, fsm still = state_send_data. Need to explicitly count this case.
assign  select_prim[CODE_HOLDAP]    = ~alignes_pair & (state_send_rhold | state_rcvr_shold & ~incom_stop_f);
assign  select_prim[CODE_HOLDP]     = ~alignes_pair & (state_send_shold | state_rcvr_rhold | state_send_data & set_send_shold); // the case mentioned 2 lines upper
assign  select_prim[CODE_CRC]       = ~alignes_pair & (state_send_crc);
assign  select_prim[CODE_EOFP]      = ~alignes_pair & (state_send_eof);
assign  select_prim[CODE_WTRMP]     = ~alignes_pair & (state_wait);
assign  select_prim[CODE_RRDYP]     = ~alignes_pair & (state_rcvr_rdy);
assign  select_prim[CODE_IPP]       = ~alignes_pair & (state_rcvr_data & ~incom_stop_f | state_rcvr_eof | state_rcvr_goodcrc);
assign  select_prim[CODE_DMATP]     = ~alignes_pair & (state_rcvr_data &  incom_stop_f | state_rcvr_shold & incom_stop_f);
assign  select_prim[CODE_OKP]       = ~alignes_pair & (state_rcvr_goodend);
assign  select_prim[CODE_ERRP]      = ~alignes_pair & (state_rcvr_badend);

// primitive selector MUX 
always @ (posedge clk)
    to_phy_data <=  rst ? {DATA_BYTE_WIDTH*8{1'b0}}: 
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_SYNCP]}}  & prim_data[CODE_SYNCP]  |
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_ALIGNP]}} & prim_data[CODE_ALIGNP] |
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_RRDYP]}}  & prim_data[CODE_RRDYP]  |
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_SOFP]}}   & prim_data[CODE_SOFP]   |
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_HOLDAP]}} & prim_data[CODE_HOLDAP] |
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_HOLDP]}}  & prim_data[CODE_HOLDP]  |
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_EOFP]}}   & prim_data[CODE_EOFP]   |
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_WTRMP]}}  & prim_data[CODE_WTRMP]  |
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_XRDYP]}}  & prim_data[CODE_XRDYP]  |
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_IPP]}}    & prim_data[CODE_IPP]    |
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_DMATP]}}  & prim_data[CODE_DMATP]  |
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_OKP]}}    & prim_data[CODE_OKP]    |
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_ERRP]}}   & prim_data[CODE_ERRP]   |
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_CRC]}}    & prim_data[CODE_CRC]    |
                    {DATA_BYTE_WIDTH*8{select_prim[CODE_DATA]}}   & prim_data[CODE_DATA];

always @ (posedge clk)
    to_phy_isk <= rst | ~select_prim[CODE_DATA] & ~select_prim[CODE_CRC] ? {{(DATA_BYTE_WIDTH - 1){1'b0}}, 1'b1} : {DATA_BYTE_WIDTH{1'b0}} ;

// incoming data is data
wire    inc_is_data;
assign  inc_is_data = dword_val & rcvd_dword[CODE_DATA] & (state_rcvr_data | state_rcvr_rhold);
/*
 * Scrambler can work both as a scrambler and a descramler, because data stream could be
 * one direction at a time
 */
scrambler scrambler(
    .rst        (select_prim[CODE_SOFP] | dword_val & rcvd_dword[CODE_SOFP]),
    .clk        (clk),
    .val_in     (select_prim[CODE_DATA] | inc_is_data),
    .data_in    (crc_dword & {DATA_BYTE_WIDTH*8{select_prim[CODE_CRC]}} | 
                 data_in & {DATA_BYTE_WIDTH*8{select_prim[CODE_DATA]}} | 
                 phy_data_in_r & {DATA_BYTE_WIDTH*8{inc_is_data}}),
    .data_out   (scrambler_out)
);

/*
 * Same as for scrambler, crc computation for both directions
 */
crc crc(
    .clk        (clk),
    .rst        (select_prim[CODE_SOFP] | dword_val & rcvd_dword[CODE_SOFP]),
    .val_in     (select_prim[CODE_DATA] | inc_is_data),
    .data_in    (data_in & {DATA_BYTE_WIDTH*8{select_prim[CODE_DATA]}} | scrambler_out & {DATA_BYTE_WIDTH*8{inc_is_data}}),
    .crc_out    (crc_dword)
);

// the output of crc module shall be 0 if 1 tick later reciever got a crc checksum and no errors occured
assign  crc_good = ~|crc_dword & state_rcvr_eof;
assign  crc_bad  =  |crc_dword & state_rcvr_eof;

// to TL data outputs assigment
// delay outputs so the last data would be marked
reg [31:0]  data_out_r;
reg         data_val_out_r;
reg [31:0]  data_out_rr;
reg         data_val_out_rr;
// if current == EOF => _r == CRC and _rr == last data piece
always @ (posedge clk)
begin
    data_out_r      <= scrambler_out;
    data_out_rr     <= data_out_r;
    data_val_out_r  <= inc_is_data;
    data_val_out_rr <= data_val_out_r & ~set_rcvr_eof; // means that @ previous clock cycle the delivered data was crc
end
assign  data_out        = data_out_rr;
assign  data_mask_out   = 2'b11;//{DATA_BYTE_WIDTH/2{1'b1}};
assign  data_val_out    = data_val_out_rr;
assign  data_last_out   = set_rcvr_eof;



// from TL data
// gives a strobe everytime data is present and we're at a corresponding state.
assign  data_strobe_out = select_prim[CODE_DATA];

// assign phy data outputs
assign  phy_data_out = to_phy_data;
assign  phy_isk_out  = to_phy_isk;

assign  frame_busy  = ~state_idle;
assign  frame_ack   = state_send_sof;
assign  frame_rej   = set_rcvr_wait & state_send_rdy & ~alignes_pair;

// incoming fises detected
assign  incom_start = set_rcvr_wait & ~alignes_pair;
// ... and processed
assign  incom_done  = set_rcvr_goodcrc & ~alignes_pair;
// or the FIS had errors
assign  incom_invalidate = state_rcvr_eof & crc_bad & ~alignes_pair | state_rcvr_data   & dword_val &  rcvd_dword[CODE_WTRMP] 
                         | (state_rcvr_wait | state_rcvr_rdy | state_rcvr_data | state_rcvr_rhold | state_rcvr_shold | state_rcvr_eof | state_rcvr_goodcrc) & got_escape;

// shows that incoming primitive or data is ready to be processed // TODO somehow move alignes_pair into dword_val
assign  dword_val = |rcvd_dword & phy_ready & ~rcvd_dword[CODE_ALIGNP];
// determine imcoming primitive type
assign  rcvd_dword[CODE_DATA]	= ~|phy_isk_in_r;
assign  rcvd_dword[CODE_CRC]	= 1'b0;
assign  rcvd_dword[CODE_SYNCP]	= phy_isk_in_r[0] == 1'b1 & ~|phy_isk_in_r[DATA_BYTE_WIDTH-1:1] & prim_data[CODE_SYNCP ] == phy_data_in_r;
assign  rcvd_dword[CODE_ALIGNP]	= phy_isk_in_r[0] == 1'b1 & ~|phy_isk_in_r[DATA_BYTE_WIDTH-1:1] & prim_data[CODE_ALIGNP] == phy_data_in_r;
assign  rcvd_dword[CODE_XRDYP]	= phy_isk_in_r[0] == 1'b1 & ~|phy_isk_in_r[DATA_BYTE_WIDTH-1:1] & prim_data[CODE_XRDYP ] == phy_data_in_r;
assign  rcvd_dword[CODE_SOFP]	= phy_isk_in_r[0] == 1'b1 & ~|phy_isk_in_r[DATA_BYTE_WIDTH-1:1] & prim_data[CODE_SOFP  ] == phy_data_in_r;
assign  rcvd_dword[CODE_HOLDAP]	= phy_isk_in_r[0] == 1'b1 & ~|phy_isk_in_r[DATA_BYTE_WIDTH-1:1] & prim_data[CODE_HOLDAP] == phy_data_in_r;
assign  rcvd_dword[CODE_HOLDP]	= phy_isk_in_r[0] == 1'b1 & ~|phy_isk_in_r[DATA_BYTE_WIDTH-1:1] & prim_data[CODE_HOLDP ] == phy_data_in_r;
assign  rcvd_dword[CODE_EOFP]	= phy_isk_in_r[0] == 1'b1 & ~|phy_isk_in_r[DATA_BYTE_WIDTH-1:1] & prim_data[CODE_EOFP  ] == phy_data_in_r;
assign  rcvd_dword[CODE_WTRMP]	= phy_isk_in_r[0] == 1'b1 & ~|phy_isk_in_r[DATA_BYTE_WIDTH-1:1] & prim_data[CODE_WTRMP ] == phy_data_in_r;
assign  rcvd_dword[CODE_RRDYP]	= phy_isk_in_r[0] == 1'b1 & ~|phy_isk_in_r[DATA_BYTE_WIDTH-1:1] & prim_data[CODE_RRDYP ] == phy_data_in_r;
assign  rcvd_dword[CODE_IPP]	= phy_isk_in_r[0] == 1'b1 & ~|phy_isk_in_r[DATA_BYTE_WIDTH-1:1] & prim_data[CODE_IPP   ] == phy_data_in_r;
assign  rcvd_dword[CODE_DMATP]	= phy_isk_in_r[0] == 1'b1 & ~|phy_isk_in_r[DATA_BYTE_WIDTH-1:1] & prim_data[CODE_DMATP ] == phy_data_in_r;
assign  rcvd_dword[CODE_OKP]	= phy_isk_in_r[0] == 1'b1 & ~|phy_isk_in_r[DATA_BYTE_WIDTH-1:1] & prim_data[CODE_OKP   ] == phy_data_in_r;
assign  rcvd_dword[CODE_ERRP]	= phy_isk_in_r[0] == 1'b1 & ~|phy_isk_in_r[DATA_BYTE_WIDTH-1:1] & prim_data[CODE_ERRP  ] == phy_data_in_r;

// phy level errors handling TODO
assign  dec_err = |phy_err_in_r;

// form a response to transport layer
assign  frame_done      = frame_done_good | frame_done_bad;
assign  frame_done_good = state_wait & dword_val & rcvd_dword[CODE_OKP];
assign  frame_done_bad  = state_wait & dword_val & rcvd_dword[CODE_ERRP];

`ifdef CHECKERS_ENABLED
// incoming primitives
always @ (posedge clk)
    if (~|rcvd_dword & phy_ready)
    begin
        $display("%m: invalid primitive recieved : %h, conrol : %h, err : %h", phy_data_in_r, phy_isk_in_r, phy_err_in_r);
        $finish;
    end
// States checker
reg  [STATES_COUNT - 1:0] sim_states_concat;
always @ (posedge clk)
    if (~rst)
    if (( 32'h0
       + state_idle
       + state_sync_esc
       + state_nocommerr
       + state_nocomm
       + state_align
       + state_reset
       + state_send_rdy
       + state_send_sof
       + state_send_data
       + state_send_rhold
       + state_send_shold
       + state_send_crc
       + state_send_eof
       + state_wait
       + state_rcvr_wait
       + state_rcvr_rdy
       + state_rcvr_data
       + state_rcvr_rhold
       + state_rcvr_shold
       + state_rcvr_eof
       + state_rcvr_goodcrc
       + state_rcvr_goodend
       + state_rcvr_badend
       ) != 1)
    begin
        sim_states_concat = {
                           state_idle
                         , state_sync_esc
                         , state_nocommerr
                         , state_nocomm
                         , state_align
                         , state_reset
                         , state_send_rdy
                         , state_send_sof
                         , state_send_data
                         , state_send_rhold
                         , state_send_shold
                         , state_send_crc
                         , state_send_eof
                         , state_wait
                         , state_rcvr_wait
                         , state_rcvr_rdy
                         , state_rcvr_data
                         , state_rcvr_rhold
                         , state_rcvr_shold
                         , state_rcvr_eof
                         , state_rcvr_goodcrc
                         , state_rcvr_goodend
                         , state_rcvr_badend
                         };
        $display("%m: invalid states: %b", sim_states_concat);
        $finish;
    end
`endif

`ifdef SIMULATION
always @ (posedge clk)
begin
    if (data_val_out) begin
        $display("[Host] LINK: From device - received data = %h", data_out);
    end

//    if (inc_is_data) begin
//        $display("[Host] LINK: From device - received raw data = %h", phy_data_in);
//    end
end
    
`endif

`ifdef LA
    
`endif


endmodule
