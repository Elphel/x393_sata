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
module link #(
    // 2 = word, 4 = dword or 8 = qword
    parameter DATA_BYTE_WIDTH = 4
)
(
    input   wire    rst,
    input   wire    clk,

    // inputs from transport layer
    // request for a new frame transition
    input   wire    frame_req,
    // input data stream (if any data during OOB setting => ignored)
    input   wire    [DATA_BYTE_WIDTH*8 - 1:0] data_in,
    // in case of strange data aligments and size (1st mentioned @ doc, p.310, odd number of words case)
    // Actually, only last data bundle shall be masked, others are always valid.
    // Mask could be encoded into 3 bits instead of 4 for qword, but encoding+decoding aren't worth the bit
    input   wire    [DATA_BYTE_WIDTH/2 - 1:0] data_mask_in,
    // buffer read strobe
    output  wire    data_strobe_out,
    // transaction's last data budle pulse
    input   wire    data_last_in,
    // read data is valid (if 0 while last pulse wasn't received => need to hold the line)
    input   wire    data_val_in,

    // outputs to transport layer
    // tell if the transaction is done and how it was done
    output  wire    frame_done_good,
    output  wire    frame_done_bad,
    // read data, same as related inputs
    output  wire    [DATA_BYTE_WIDTH*8 - 1:0] data_out,
    output  wire    [DATA_BYTE_WIDTH/2 - 1:0] data_mask_out,
    // count every data bundle read by transport layer, even if busy flag is set
    // let the transport layer handle oveflows by himself
    output  wire    data_val_out,
    output  wire    data_last_out,
    // transport layer tells if its inner buffer is almost full
    input   wire    data_busy_in,


    // inputs from phy
    // phy is ready - link is established
    input   wire    phy_ready,

);
wire    dec_err; // doc, p.311 TODO
wire    [:0]    rcvd_dword; // shows current processing primitive (or just data dword) TODO


wire    data_txing; // if there are still some data to transmit and the transaction wasn't cancelled
always @ (posedge clk)
    data_txing <= rst | (data_last_in & data_strobe_out | dword_val & rcvd_dword[CODE_DMATP]) ? 1'b0 : frame_req ? 1'b1 : data_txing;

// list of bits of rcvd_dword
localparam  CODE_DATA   = 0; 
localparam  CODE_HOLDP  = 1;
localparam  CODE_SYNCP  = 2;
localparam  CODE_DMATP  = 3;

// form a response to transport layer
wire    frame_done;
assign  frame_done      = frame_done_good | frame_done_bad;
assign  frame_done_good = dword_val & rcvd_dword[CODE_OKP];
assign  frame_done_bad  = dword_val & rcvd_dword[CODE_ERRP];

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
                  | ~state_nocommerr
                  | ~state_nocomm
                  | ~state_align
                  | ~state_reset
                  | ~state_send_rdy
                  | ~state_send_sof
                  | ~state_send_data
                  | ~state_send_rhold
                  | ~state_send_shold
                  | ~state_send_crc
                  | ~state_send_eof
                  | ~state_wait
                  | ~state_rcvr_wait
                  | ~state_rcvr_rdy
                  | ~state_rcvr_data
                  | ~state_rcvr_rhold
                  | ~state_rcvr_shold
                  | ~state_rcvr_eof
                  | ~state_rcvr_goodcrc
                  | ~state_rcvr_goodend
                  | ~state_rcvr_badend;


assign  set_sync_esc        = 
assign  set_nocommerr       =
assign  set_nocomm          =
assign  set_align           =
assign  set_reset           =
assign  set_send_rdy        = state_idle        & frame_req;
assign  set_send_sof        = state_send_rdy    & phy_ready;
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
assign  set_rcvr_wait       = state_idle        & dword_val &  rcvd_dword[CODE_RDYP];
                            | state_send_rdy    & dword_val &  rcvd_dword[CODE_RDYP];
assign  set_rcvr_rdy        = state_rcv_wait    & dword_val &  rcvd_dword[CODE_RDYP]  & ~data_busy_in;
assign  set_rcvr_data       = state_rcvr_rdy    & dword_val &  rcvd_dword[CODE_SOFP];
                            | state_rcvr_rhold  & dword_val & ~rcvd_dword[CODE_HOLDP] & ~rcvd_dword[CODE_EOFP] & ~rcvd_dword[CODE_SYNCP] & ~data_busy_in;
                            | state_rcvr_shold  & dword_val & ~rcvd_dword[CODE_HOLDP] & ~rcvd_dword[CODE_EOFP] & ~rcvd_dword[CODE_SYNCP];
assign  set_rcvr_rhold      = state_rcvr_data   & dword_val &  rcvd_dword[CODE_DATA]  &  data_busy_in;
assign  set_rcvr_shold      = state_rcvr_data   & dword_val &  rcvd_dword[CODE_HOLDP];
                            | state_rcvr_rhold  & dword_val &  rcvd_dword[CODE_HOLDP] & ~data_busy_in;
assign  set_rcvr_eof        = state_rcvr_data   & dword_val &  rcvd_dword[CODE_EOFP];
                            | state_rcvr_rhold  & dword_val &  rcvd_dword[CODE_EOFP];
                            | state_rcvr_shold  & dword_val &  rcvd_dword[CODE_EOFP];
assign  set_rcvr_goodcrc    = state_rcvr_eof    & crc_good;
assign  set_rcvr_goodend    = state_rcvr_goodcrc& 
assign  set_rcvr_badend     = state_rcvr_data   & 
                            | state_rcvr_eof    & crc_bad;
                            | state_rcvr_goodcrc&

assign  clr_sync_esc        =
assign  clr_nocommerr       =
assign  clr_nocomm          =
assign  clr_align           =
assign  clr_reset           =
assign  clr_send_rdy        = 
assign  clr_send_sof        =
assign  clr_send_data       =
assign  clr_send_rhold      =
assign  clr_send_shold      =
assign  clr_send_crc        =
assign  clr_send_eof        =
assign  clr_wait            = frame_done; 
assign  clr_rcvr_wait       =
assign  clr_rcvr_rdy        =
assign  clr_rcvr_data       =
assign  clr_rcvr_rhold      =
assign  clr_rcvr_shold      =
assign  clr_rcvr_eof        =
assign  clr_rcvr_goodcrc    =
assign  clr_rcvr_goodend    =
assign  clr_rcvr_badend     =

always @ (posedge clk)
    state_sync_esc      <= (state_sync_esc     | set_sync_esc    ) & ~clr_sync_esc     & ~rst;
    state_nocommerr     <= (state_nocommerr    | set_nocommerr   ) & ~clr_nocommerr    & ~rst;
    state_nocomm        <= (state_nocomm       | set_nocomm      ) & ~clr_nocomm       & ~rst;
    state_align         <= (state_align        | set_align       ) & ~clr_align        & ~rst;
    state_reset         <= (state_reset        | set_reset       ) & ~clr_reset        & ~rst;
    state_send_rdy      <= (state_send_rdy     | set_send_rdy    ) & ~clr_send_rdy     & ~rst;
    state_send_sof      <= (state_send_sof     | set_send_sof    ) & ~clr_send_sof     & ~rst;
    state_send_data     <= (state_send_data    | set_send_data   ) & ~clr_send_data    & ~rst;
    state_send_rhold    <= (state_send_rhold   | set_send_rhold  ) & ~clr_send_rhold   & ~rst;
    state_send_shold    <= (state_send_shold   | set_send_shold  ) & ~clr_send_shold   & ~rst;
    state_send_crc      <= (state_send_crc     | set_send_crc    ) & ~clr_send_crc     & ~rst;
    state_send_eof      <= (state_send_eof     | set_send_eof    ) & ~clr_send_eof     & ~rst;
    state_wait          <= (state_wait         | set_wait        ) & ~clr_wait         & ~rst;
    state_rcvr_wait     <= (state_rcvr_wait    | set_rcvr_wait   ) & ~clr_rcvr_wait    & ~rst;
    state_rcvr_rdy      <= (state_rcvr_rdy     | set_rcvr_rdy    ) & ~clr_rcvr_rdy     & ~rst;
    state_rcvr_data     <= (state_rcvr_data    | set_rcvr_data   ) & ~clr_rcvr_data    & ~rst;
    state_rcvr_rhold    <= (state_rcvr_rhold   | set_rcvr_rhold  ) & ~clr_rcvr_rhold   & ~rst;
    state_rcvr_shold    <= (state_rcvr_shold   | set_rcvr_shold  ) & ~clr_rcvr_shold   & ~rst;
    state_rcvr_eof      <= (state_rcvr_eof     | set_rcvr_eof    ) & ~clr_rcvr_eof     & ~rst;
    state_rcvr_goodcrc  <= (state_rcvr_goodcrc | set_rcvr_goodcrc) & ~clr_rcvr_goodcrc & ~rst;
    state_rcvr_goodend  <= (state_rcvr_goodend | set_rcvr_goodend) & ~clr_rcvr_goodend & ~rst;
    state_rcvr_badend   <= (state_rcvr_badend  | set_rcvr_badend ) & ~clr_rcvr_badend  & ~rst;





















`ifdef CHECKERS_ENABLED
// States checker
reg  [STATES_COUNT - 1:0] sim_states_concat;
always @ (posedge clk)
    if (~rst)
    if ((state_idle
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
        sim_state_concat = {
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
        $display("%m: invalid states: %b", sim_state_concat);
    end
`endif

endmodule
