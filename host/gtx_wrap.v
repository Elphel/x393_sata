/*******************************************************************************
 * Module: gtx_wrap
 * Date: 2015-08-24
 * Author: Alexey     
 * Description: shall replace gtx's PCS part functions, bypassing PCS itself in gtx
 *
 * Copyright (c) 2015 Elphel, Inc.
 * gtx_wrap.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * gtx_wrap.v file is distributed in the hope that it will be useful,
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
//`include "gtx_8x10enc.v"
//`include "gtx_10x8dec.v"
//`include "gtx_comma_align.v"
//`include "gtx_elastic.v"
// All computations have been done in assumption of GTX interface being 20 bits wide!
module gtx_wrap #(
    parameter DATA_BYTE_WIDTH     = 4,
    parameter TXPMARESET_TIME     = 5'h1,
    parameter RXPMARESET_TIME     = 5'h11,
    parameter RXCDRPHRESET_TIME   = 5'h1,
    parameter RXCDRFREQRESET_TIME = 5'h1,
    parameter RXDFELPMRESET_TIME  = 7'hf,
    parameter RXISCANRESET_TIME   = 5'h1
)
(
    output  reg     debug = 0,
    output  wire    cplllock,
    input   wire    cplllockdetclk,
    input   wire    cpllreset,
    input   wire    gtrefclk,
    input   wire    drpclk,
    input   wire    rxuserrdy,
    input   wire    txuserrdy,
    input   wire    rxusrclk,
    input   wire    rxusrclk2,
    input   wire    rxp,
    input   wire    rxn,
    output  wire    rxbyteisaligned,
    input   wire    rxreset,
    output  wire    rxcomwakedet,
    output  wire    rxcominitdet,
    output  wire    rxelecidle,
    output  wire    rxresetdone,
    input   wire    txreset,
    input   wire    txusrclk,
    input   wire    txusrclk2,
    input   wire    txelecidle,
    output  wire    txp,
    output  wire    txn,
    output  wire    txoutclk,
    input   wire    txpcsreset,
    output  wire    txresetdone,
    input   wire    txcominit,
    input   wire    txcomwake,
    // elastic buffer status
    output  wire    rxelsfull,
    output  wire    rxelsempty,

    input   wire    [DATA_BYTE_WIDTH * 8 - 1:0] txdata,
    input   wire    [DATA_BYTE_WIDTH - 1:0]     txcharisk,
    output  wire    [DATA_BYTE_WIDTH * 8 - 1:0] rxdata,
    output  wire    [DATA_BYTE_WIDTH - 1:0]     rxcharisk,
    output  wire    [DATA_BYTE_WIDTH - 1:0]     rxnotintable,
    output  wire    [DATA_BYTE_WIDTH - 1:0]     rxdisperr,
    
    output  wire    dbg_rxphaligndone,
    output  wire    dbg_rx_clocks_aligned,
    output  wire    dbg_rxcdrlock,
    output  wire    dbg_rxdlysresetdone
);

wire    rxresetdone_gtx; 
wire    txresetdone_gtx;
reg     rxresetdone_gtx_r; 
reg     txresetdone_gtx_r;
reg     wrap_rxreset_;
reg     wrap_txreset_;
// resets while PCS resets, active low
always @ (posedge rxusrclk2)
    wrap_rxreset_ <= rxuserrdy & rxresetdone_gtx_r;
always @ (posedge txusrclk2)
    wrap_txreset_ <= txuserrdy & txresetdone_gtx_r;

wire    [63:0]  rxdata_gtx;
wire    [7:0]   rxcharisk_gtx;
wire    [7:0]   rxdisperr_gtx;
wire    [63:0]  txdata_gtx;
wire    [7:0]   txcharisk_gtx;
wire    [7:0]   txchardispval_gtx;
wire    [7:0]   txchardispmode_gtx;
// 8/10 encoder ifaces
wire    [19:0]  txdata_enc_out;
wire    [15:0]  txdata_enc_in;
wire    [1:0]   txcharisk_enc_in;

/*
 * TX PCS, minor changes: 8/10 encoder + user interface resync
 */
// assuming GTX interface width = 20 bits
assign  txdata_gtx          = {48'h0, txdata_enc_out[17:10], txdata_enc_out[7:0]};
assign  txcharisk_gtx       = 8'h0; // 8/10 encoder is bypassed in gtx
assign  txchardispmode_gtx  = {6'h0, txdata_enc_out[19], txdata_enc_out[9]};
assign  txchardispval_gtx   = {6'h0, txdata_enc_out[18], txdata_enc_out[8]};

// Interface part
/*
    input   wire    cpllreset,  - async
    input   wire    wrap_rxreset_,  - async
    input   wire    wrap_txreset_,  - async
    input   wire    rxreset,    - async
    input   wire    txreset,    - async
    input   wire    txelecidle, - txusrclk2 - need to resync to gtx iface clk - txusrclk
    input   wire    txpcsreset, - async
    input   wire    txcominit,  - txusrclk2 - need to resync to gtx iface clk - txusrclk
    input   wire    txcomwake,  - txusrclk2 - need to resync to gtx iface clk - txusrclk
*/
// @ gtx iface clk
wire    txcominit_gtx; 
wire    txcomwake_gtx;
wire    txelecidle_gtx;

// insert resync if it's necessary
generate 
if (DATA_BYTE_WIDTH == 4) begin
    // resync to txusrclk
    // 2*Fin = Fout => WIDTHin = 2*WIDTHout
    // Andrey:
    reg            txdata_resync_strobe;
    reg     [15:0] txdata_enc_in_r;     // TODO: remove async reset
    reg     [ 1:0] txcharisk_enc_in_r;  // TODO: remove async reset
    wire    [38:0] txdata_resync_out;
    wire           txdata_resync_valid;
    reg      [1:0] txcomwake_gtx_f; // 2 registers just to match latency (data to the 3 next) in Alexey's code, probbaly not needed
    reg      [1:0] txcominit_gtx_f;
    reg      [1:0] txelecidle_gtx_f;
    
    resync_data #( // TODO: update output register..  OK as it is
        .DATA_WIDTH(39),
        .DATA_DEPTH(3),
        .INITIAL_VALUE(39'h4000000000) // All 0 but txelecidle_gtx
    ) txdata_resynchro (
        .arst     (txreset),                                               // input
        .srst     (~wrap_txreset_),                                        // input
        .wclk     (txusrclk2),                                             // input
        .rclk     (txusrclk),                                              // input
        .we       (1'b1),                                                  // input
        .re       (txdata_resync_strobe),                                  // input
        .data_in  ({txelecidle, txcominit, txcomwake, txcharisk, txdata}), // input[15:0] 
        .data_out (txdata_resync_out),                                     // output[15:0] reg 
        .valid    (txdata_resync_valid)                                    // output reg 
    );
    always @ (posedge txreset or posedge txusrclk) begin
        if      (txreset)             txdata_resync_strobe <= 0;
        else if (txdata_resync_valid) txdata_resync_strobe <= ~txdata_resync_strobe;
/*        
        if (txreset) begin
            txdata_enc_in_r <=    0;
            txcharisk_enc_in_r <= 0;
        end else if (txdata_resync_valid) begin
            txdata_enc_in_r <=    txdata_resync_strobe? txdata_resync_out[31:16]: txdata_resync_out[15:0];
            txcharisk_enc_in_r <= txdata_resync_strobe? txdata_resync_out[35:34]: txdata_resync_out[33:32];
        end
*/        
        if (txreset) begin
            txcomwake_gtx_f  <= 0;
            txcominit_gtx_f  <= 0;
            txelecidle_gtx_f <= ~0;
        end else begin
            txcomwake_gtx_f  <= {txdata_resync_out[36],txcomwake_gtx_f[1]};
            txcominit_gtx_f  <= {txdata_resync_out[37],txcominit_gtx_f[1]};
            txelecidle_gtx_f <= {txdata_resync_out[38],txelecidle_gtx_f[1]};
        end
    end
// Changing to sync reset (otherwise WARNING: [DRC 23-20] Rule violation (REQP-1839) RAMB36 async control check ...)
    always @ (posedge txusrclk) begin
        if (txreset) begin
            txdata_enc_in_r <=    0;
            txcharisk_enc_in_r <= 0;
        end else if (txdata_resync_valid) begin
            txdata_enc_in_r <=    txdata_resync_strobe? txdata_resync_out[31:16]: txdata_resync_out[15:0];
            txcharisk_enc_in_r <= txdata_resync_strobe? txdata_resync_out[35:34]: txdata_resync_out[33:32];
        end
    
    end


    assign  txdata_enc_in       = txdata_enc_in_r;
    assign  txcharisk_enc_in    = txcharisk_enc_in_r;
    assign  txcominit_gtx       = txcominit_gtx_f[0];
    assign  txcomwake_gtx       = txcomwake_gtx_f[0];
    assign  txelecidle_gtx      = txelecidle_gtx_f[0];
    
    
    /*wire    txdata_resync_nempty;
    reg     txdata_resync_nempty_r;
    reg     txdata_resync_nempty_rr;
    reg     txdata_resync_strobe;
    wire    [38:0] txdata_resync_out;
    reg     [35:0] txdata_resync;

    assign  txdata_enc_in       = {16{~txdata_resync_strobe}} & txdata_resync[15:0] | {16{txdata_resync_strobe}} & txdata_resync[31:16];
    assign  txcharisk_enc_in   = {2{~txdata_resync_strobe}} & txdata_resync[33:32] | {2{txdata_resync_strobe}} & txdata_resync[35:34];
    // Andrey: wrap_txreset_ has different clock domain
    always @ (posedge txusrclk)
    begin
        txdata_resync        <= ~wrap_txreset_ ? 36'h0 : ((txdata_resync_nempty & txdata_resync_strobe) ? txdata_resync_out[35:0] : txdata_resync);
        txdata_resync_strobe <= ~wrap_txreset_ ? 1'b0  : ((~txdata_resync_nempty) ? txdata_resync_strobe : ~txdata_resync_strobe); // -> 1 once every resynced dword = signal to latch it
    end

    // nempty_rr & nempty => shall be at least 2 elements in fifo
    always @ (posedge txusrclk2) 
    begin
        txdata_resync_nempty_r  <= txdata_resync_nempty;
        txdata_resync_nempty_rr <= txdata_resync_nempty_r;
    end

    fifo_cross_clocks #(
      .DATA_WIDTH (39),
      .DATA_DEPTH (4)
    )
    txdata_resynchro(
        .rst        (txreset),
        .rrst       (txreset),
        .wrst       (txreset),
        .rclk       (txusrclk),
        .wclk       (txusrclk2),
        .we         (1'b1),
        .re         (txdata_resync_nempty & txdata_resync_nempty_rr & txdata_resync_strobe),
        .data_in    ({txelecidle, txcominit, txcomwake, txcharisk, txdata}),
        .data_out   (txdata_resync_out),
        .nempty     (txdata_resync_nempty),
        .half_empty ()
    );


    reg txcomwake_gtx_f;
    reg txcominit_gtx_f;
    reg txelecidle_gtx_f;
    always @ (posedge txusrclk)
    begin
        txcomwake_gtx_f  <= txdata_resync_out[36];
        txcominit_gtx_f  <= txdata_resync_out[37];
        txelecidle_gtx_f <= txdata_resync_out[38];
    end
    assign  txcomwake_gtx  = txcomwake_gtx_f;
    assign  txcominit_gtx  = txcominit_gtx_f;
    assign  txelecidle_gtx = txelecidle_gtx_f;
    */
end

else
if (DATA_BYTE_WIDTH == 2) begin
    // no resync is needed => straightforward assignments
    assign  txdata_enc_in       = txdata[15:0];
    assign  txcharisk_enc_in    = txcharisk[1:0];
    assign  txcominit_gtx       = txcominit;
    assign  txcomwake_gtx       = txcomwake;
    assign  txelecidle_gtx      = txelecidle;
end
else begin
    // unconsidered case
    always @ (posedge txusrclk)
    begin
        $display("Wrong width set in %m, value is %d", DATA_BYTE_WIDTH);
    end
end
endgenerate

// 8/10 encoder @ txusrclk, 16 + 1 bits -> 20
gtx_8x10enc gtx_8x10enc(
    .rst        (~wrap_txreset_),
    .clk        (txusrclk),
    .indata     (txdata_enc_in),
    .inisk      (txcharisk_enc_in),
    .outdata    (txdata_enc_out)
);

// Adjust RXOUTCLK so RXUSRCLK (==xclk) matches SIPO output data

wire rxcdrlock; // Marked as "reserved" - maybe not use it, only rxelecidle?
reg rxdlysreset = 0;
wire rxphaligndone;
wire rxdlysresetdone; 
reg rx_clocks_aligned = 0;
reg [2:0] rxdlysreset_cntr = 7;
reg  rxdlysresetdone_r;

assign dbg_rxphaligndone =     rxphaligndone;     // never gets up?
assign dbg_rx_clocks_aligned = rx_clocks_aligned;
assign dbg_rxcdrlock =         rxcdrlock;         //goes in/out (because of the SS ?
assign dbg_rxdlysresetdone =   rxdlysresetdone_r;
always @ (posedge xclk) begin
//    if (rxelecidle || !rxcdrlock) rxdlysreset_cntr <= 5;
    if (rxelecidle)               rxdlysreset_cntr <= 5;
    else if (|rxdlysreset_cntr)   rxdlysreset_cntr <=  rxdlysreset_cntr - 1;
    
//    if (rxelecidle || !rxcdrlock) rxdlysreset <= 0;
    if (rxelecidle)               rxdlysreset <= 0;
    else                          rxdlysreset <= |rxdlysreset_cntr;
    
//    if (rxelecidle || !rxcdrlock || rxdlysreset || |rxdlysreset_cntr) rx_clocks_aligned <= 0;
//    if (rxelecidle || rxdlysreset || |rxdlysreset_cntr) rx_clocks_aligned <= 0;
    if (rxelecidle)                  rx_clocks_aligned <= 0;
//    else if (rxphaligndone)                             rx_clocks_aligned <= 1;
    else if (rxphaligndone)          rx_clocks_aligned <= 1;

    if (rxelecidle || rxdlysreset || |rxdlysreset_cntr) rxdlysresetdone_r <= 0;
    else if (rxdlysresetdone)                             rxdlysresetdone_r <= 1;
end

/*
 * RX PCS part: comma detect + align module, 10/8 decoder, elastic buffer, interface resynchronisation
 * all modules before elastic buffer shall work on a restored clock - xclk
 */
wire    xclk;
// assuming GTX interface width = 20 bits
// comma aligner
reg     [19:0]  rxdata_comma_in;
wire    [19:0]  rxdata_comma_out;
always @ (posedge xclk) 
    rxdata_comma_in <= {rxdisperr_gtx[1], rxcharisk_gtx[1], rxdata_gtx[15:8], rxdisperr_gtx[0], rxcharisk_gtx[0], rxdata_gtx[7:0]};

// aligner status generation
// if we detected comma & there was 1st realign after non-aligned state -> triggered, we wait until the next comma
// if no realign would be issued, assumes, that we've aligned to the stream otherwise go back to non-aligned state
wire    comma;
wire    realign;
wire    state_nonaligned;
reg     state_aligned;
reg     state_triggered;
wire    set_aligned;
wire    set_triggered;
wire    clr_aligned;
wire    clr_triggered;

assign  state_nonaligned = ~state_aligned & ~state_triggered;
assign  set_aligned     = state_triggered & comma & ~realign;
assign  set_triggered   = state_nonaligned & comma;
assign  clr_aligned     = realign;
assign  clr_triggered   = realign;

always @ (posedge xclk)
begin
    state_aligned   <= (set_aligned   | state_aligned  ) & wrap_rxreset_ & ~clr_aligned; 
    state_triggered <= (set_triggered | state_triggered) & wrap_rxreset_ & ~clr_triggered; 
end

gtx_comma_align gtx_comma_align(
//    .rst        (~rx_clocks_aligned), // ~wrap_rxreset_),
    .rst        (~wrap_rxreset_),
    
    .clk        (xclk),
    .indata     (rxdata_comma_in),
    .outdata    (rxdata_comma_out),
    .comma      (comma),
    .realign    (realign)
);

//

// 10x8 decoder
wire    [15:0]  rxdata_dec_out;
wire    [1:0]   rxcharisk_dec_out;
wire    [1:0]   rxnotintable_dec_out;
wire    [1:0]   rxdisperr_dec_out;

gtx_10x8dec gtx_10x8dec(
//    .rst        (~rx_clocks_aligned), // ~wrap_rxreset_),
    .rst        (~wrap_rxreset_),
    .clk        (xclk),
    .indata     (rxdata_comma_out),
    .outdata    (rxdata_dec_out),
    .outisk     (rxcharisk_dec_out),
    .notintable (rxnotintable_dec_out),
    .disperror  (rxdisperr_dec_out)
);

// elastic buffer: transition from xclk to rxusrclk
wire    [15:0]  rxdata_els_out;
wire    [1:0]   rxcharisk_els_out;
wire    [1:0]   rxnotintable_els_out;
wire    [1:0]   rxdisperr_els_out;
wire            lword_strobe;
wire            isaligned;
wire            elastic_full;
wire            elastic_empty;

gtx_elastic #(
    .DEPTH_LOG2 (3),
    .OFFSET     (4)
)
gtx_elastic(
//    .rst            (~rx_clocks_aligned), // ~wrap_rxreset_),
    .rst            (~wrap_rxreset_),
    .wclk           (xclk),
    .rclk           (rxusrclk),

///    .isaligned_in   (state_aligned),
    .isaligned_in   (state_aligned && rxdlysresetdone_r), // rx_clocks_aligned), //Allow to align early, but do not tell it is aligned until xclk is aligned to SIPO par. clock
    .charisk_in     (rxcharisk_dec_out),
    .notintable_in  (rxnotintable_dec_out),
    .disperror_in   (rxdisperr_dec_out),
    .data_in        (rxdata_dec_out),

    .isaligned_out  (isaligned),
    .charisk_out    (rxcharisk_els_out),
    .notintable_out (rxnotintable_els_out),
    .disperror_out  (rxdisperr_els_out),
    .data_out       (rxdata_els_out),

    .lword_strobe   (lword_strobe),

    .full           (elastic_full),
    .empty          (elastic_empty)
);

// iface resync

/*
    output  wire    cplllock,       - async
    output  wire    rxbyteisaligned,- rxusrclk2
    output  wire    rxcomwakedet,   - rxusrclk2
    output  wire    rxcominitdet,   - rxusrclk2
    output  wire    rxelecidle,     - async
    output  wire    rxresetdone,    - rxusrclk2
    output  wire    txresetdone,    - txusrclk2
*/
wire    rxcomwakedet_gtx;
wire    rxcominitdet_gtx;
reg     rxcomwakedet_gtx_r;
reg     rxcominitdet_gtx_r;


// insert resync if it's necessary
generate 
if (DATA_BYTE_WIDTH == 4) begin
    // resync to rxusrclk
    // Fin = 2*Fout => 2*WIDTHin = WIDTHout
    // first data word arrived = last word of a primitive, second arrived - first one
    // lword_strobe indicates that second data word is arrived
    wire    rxdata_resync_nempty;
    reg     rxdata_resync_nempty_r;
    wire    rxdata_resync_strobe;
    wire    [50:0] rxdata_resync_in;
    wire    [50:0] rxdata_resync_out;
    reg     [25:0] rxdata_resync_buf;

    assign  rxdata_resync_strobe = lword_strobe;
    assign  rxdata_resync_in = {
                                isaligned,                                  // 1
                                rxcomwakedet_gtx_r | rxdata_resync_buf[25], // 1
                                rxcominitdet_gtx_r | rxdata_resync_buf[24], // 1
                                rxresetdone_gtx_r,                          // 1 
                                txresetdone_gtx_r,                          // 1
                                elastic_full  | rxdata_resync_buf[23], // 1 
                                elastic_empty | rxdata_resync_buf[22], // 1
                                rxdisperr_els_out,                     // 2
                                rxnotintable_els_out,                  // 2
                                rxcharisk_els_out,                     // 2
                                rxdata_els_out,                        // 16
                                rxdata_resync_buf[21:0]};              // 22 / 51 total
    always @ (posedge rxusrclk)
        rxdata_resync_buf    <= ~wrap_rxreset_ ? 26'h0 : ~rxdata_resync_strobe ? {rxcomwakedet_gtx_r, rxcominitdet_gtx_r, elastic_full, elastic_empty, rxdisperr_els_out, rxnotintable_els_out, rxcharisk_els_out, rxdata_els_out} : rxdata_resync_buf;

    always @ (posedge rxusrclk2)
        rxdata_resync_nempty_r <= rxdata_resync_nempty;

    fifo_cross_clocks #(
      .DATA_WIDTH (51),
      .DATA_DEPTH (4)
    )
    rxdata_resynchro(
//        .rst        (~wrap_rxreset_),
        .rst        (1'b0),
        .rrst       (~wrap_rxreset_),
        .wrst       (~wrap_rxreset_),
        .rclk       (rxusrclk2),
        .wclk       (rxusrclk),
        .we         (rxdata_resync_strobe),
        .re         (rxdata_resync_nempty & rxdata_resync_nempty_r),
        .data_in    (rxdata_resync_in),
        .data_out   (rxdata_resync_out),
        .nempty     (rxdata_resync_nempty),
        .half_empty ()
    );
    assign  rxbyteisaligned = rxdata_resync_out[50];
    assign  rxcomwakedet    = rxdata_resync_out[49];
    assign  rxcominitdet    = rxdata_resync_out[48];
    assign  rxresetdone     = rxdata_resync_out[47];
    assign  txresetdone     = rxdata_resync_out[46];
    assign  rxelsfull       = rxdata_resync_out[45];
    assign  rxelsempty      = rxdata_resync_out[44];
    assign  rxdisperr[3:0]      = {rxdata_resync_out[43:42], rxdata_resync_out[21:20]};
    assign  rxnotintable[3:0]   = {rxdata_resync_out[41:40], rxdata_resync_out[19:18]};
    assign  rxcharisk[3:0]      = {rxdata_resync_out[39:38], rxdata_resync_out[17:16]};
    assign  rxdata[31:0]        = {rxdata_resync_out[37:22], rxdata_resync_out[15:0] };
end
else
if (DATA_BYTE_WIDTH == 2) begin
    // no resync is needed => straightforward assignments
    assign  rxbyteisaligned = isaligned;
    assign  rxcomwakedet    = rxcomwakedet_gtx_r;
    assign  rxcominitdet    = rxcominitdet_gtx_r;
    assign  rxresetdone     = rxresetdone_gtx_r;
    assign  txresetdone     = txresetdone_gtx_r;
    assign  rxelsfull           = elastic_full;
    assign  rxelsempty          = elastic_empty;
    assign  rxdisperr[1:0]      = rxdisperr_els_out;
    assign  rxnotintable[1:0]   = rxnotintable_els_out;
    assign  rxcharisk[1:0]      = rxcharisk_els_out;
    assign  rxdata[15:0]        = rxdata_els_out;
end
else begin
    // unconsidered case
    always @ (posedge txusrclk)
    begin
        $display("Wrong width set in %m, value is %d", DATA_BYTE_WIDTH);
    end
end
endgenerate

// latching gtx outputs, synchronous to RXUSRCLK2 = rxusrclk
always @ (posedge rxusrclk)
begin
    rxcomwakedet_gtx_r  <= rxcomwakedet_gtx;
    rxcominitdet_gtx_r  <= rxcominitdet_gtx;
    rxresetdone_gtx_r   <= rxresetdone_gtx;
    txresetdone_gtx_r   <= txresetdone_gtx;
end

wire    txoutclk_gtx;
wire    xclk_gtx;
//wire    xclk_mr;
BUFG bufg_txoutclk (.O(txoutclk),.I(txoutclk_gtx));
//BUFR bufr_xclk  (.O(xclk),.I(xclk_mr),.CE(1'b1),.CLR(1'b0));
//BUFMR bufmr_xclk  (.O(xclk_mr),.I(xclk_gtx));

BUFG bug_xclk  (.O(xclk),.I(xclk_gtx));

gtxe2_channel_wrapper #(
    .SIM_RECEIVER_DETECT_PASS               ("TRUE"),
    .SIM_TX_EIDLE_DRIVE_LEVEL               ("X"),
    .SIM_RESET_SPEEDUP                      ("FALSE"),
    .SIM_CPLLREFCLK_SEL                     (3'b001),
    .SIM_VERSION                            ("4.0"),
    .ALIGN_COMMA_DOUBLE                     ("FALSE"),
    .ALIGN_COMMA_ENABLE                     (10'b1111111111),
    .ALIGN_COMMA_WORD                       (1),
    .ALIGN_MCOMMA_DET                       ("TRUE"),
    .ALIGN_MCOMMA_VALUE                     (10'b1010000011),
    .ALIGN_PCOMMA_DET                       ("TRUE"),
    .ALIGN_PCOMMA_VALUE                     (10'b0101111100),
    .SHOW_REALIGN_COMMA                     ("TRUE"),
    .RXSLIDE_AUTO_WAIT                      (7),
    .RXSLIDE_MODE                           ("OFF"),
    .RX_SIG_VALID_DLY                       (10),
    .RX_DISPERR_SEQ_MATCH                   ("TRUE"),
    .DEC_MCOMMA_DETECT                      ("TRUE"),
    .DEC_PCOMMA_DETECT                      ("TRUE"),
    .DEC_VALID_COMMA_ONLY                   ("FALSE"),
    .CBCC_DATA_SOURCE_SEL                   ("DECODED"),
    .CLK_COR_SEQ_2_USE                      ("FALSE"),
    .CLK_COR_KEEP_IDLE                      ("FALSE"),
    .CLK_COR_MAX_LAT                        (9),
    .CLK_COR_MIN_LAT                        (7),
    .CLK_COR_PRECEDENCE                     ("TRUE"),
    .CLK_COR_REPEAT_WAIT                    (0),
    .CLK_COR_SEQ_LEN                        (1),
    .CLK_COR_SEQ_1_ENABLE                   (4'b1111),
    .CLK_COR_SEQ_1_1                        (10'b0100000000),
    .CLK_COR_SEQ_1_2                        (10'b0000000000),
    .CLK_COR_SEQ_1_3                        (10'b0000000000),
    .CLK_COR_SEQ_1_4                        (10'b0000000000),
    .CLK_CORRECT_USE                        ("FALSE"),
    .CLK_COR_SEQ_2_ENABLE                   (4'b1111),
    .CLK_COR_SEQ_2_1                        (10'b0100000000),
    .CLK_COR_SEQ_2_2                        (10'b0000000000),
    .CLK_COR_SEQ_2_3                        (10'b0000000000),
    .CLK_COR_SEQ_2_4                        (10'b0000000000),
    .CHAN_BOND_KEEP_ALIGN                   ("FALSE"),
    .CHAN_BOND_MAX_SKEW                     (1),
    .CHAN_BOND_SEQ_LEN                      (1),
    .CHAN_BOND_SEQ_1_1                      (10'b0000000000),
    .CHAN_BOND_SEQ_1_2                      (10'b0000000000),
    .CHAN_BOND_SEQ_1_3                      (10'b0000000000),
    .CHAN_BOND_SEQ_1_4                      (10'b0000000000),
    .CHAN_BOND_SEQ_1_ENABLE                 (4'b1111),
    .CHAN_BOND_SEQ_2_1                      (10'b0000000000),
    .CHAN_BOND_SEQ_2_2                      (10'b0000000000),
    .CHAN_BOND_SEQ_2_3                      (10'b0000000000),
    .CHAN_BOND_SEQ_2_4                      (10'b0000000000),
    .CHAN_BOND_SEQ_2_ENABLE                 (4'b1111),
    .CHAN_BOND_SEQ_2_USE                    ("FALSE"),
    .FTS_DESKEW_SEQ_ENABLE                  (4'b1111),
    .FTS_LANE_DESKEW_CFG                    (4'b1111),
    .FTS_LANE_DESKEW_EN                     ("FALSE"),
    .ES_CONTROL                             (6'b000000),
    .ES_ERRDET_EN                           ("FALSE"),
    .ES_EYE_SCAN_EN                         ("TRUE"),
    .ES_HORZ_OFFSET                         (12'h000),
    .ES_PMA_CFG                             (10'b0000000000),
    .ES_PRESCALE                            (5'b00000),
    .ES_QUALIFIER                           (80'h00000000000000000000),
    .ES_QUAL_MASK                           (80'h00000000000000000000),
    .ES_SDATA_MASK                          (80'h00000000000000000000),
    .ES_VERT_OFFSET                         (9'b000000000),
    .RX_DATA_WIDTH                          (20),
    .OUTREFCLK_SEL_INV                      (2'b11),
    .PMA_RSV                                (32'h00018480),
    .PMA_RSV2                               (16'h2050),
    .PMA_RSV3                               (2'b00),
    .PMA_RSV4                               (32'h00000000),
    .RX_BIAS_CFG                            (12'b000000000100),
    .DMONITOR_CFG                           (24'h000A00),
    .RX_CM_SEL                              (2'b11),
    .RX_CM_TRIM                             (3'b010),
    .RX_DEBUG_CFG                           (12'b000000000000),
    .RX_OS_CFG                              (13'b0000010000000),
    .TERM_RCAL_CFG                          (5'b10000),
    .TERM_RCAL_OVRD                         (1'b0),
    .TST_RSV                                (32'h00000000),
    .RX_CLK25_DIV                           (6),
    .TX_CLK25_DIV                           (6),
    .UCODEER_CLR                            (1'b0),
    .PCS_PCIE_EN                            ("FALSE"),
    .PCS_RSVD_ATTR                          (48'h0100),
    .RXBUF_ADDR_MODE                        ("FAST"),
    .RXBUF_EIDLE_HI_CNT                     (4'b1000),
    .RXBUF_EIDLE_LO_CNT                     (4'b0000),
    .RXBUF_EN                               ("FALSE"),
    .RX_BUFFER_CFG                          (6'b000000),
    .RXBUF_RESET_ON_CB_CHANGE               ("TRUE"),
    .RXBUF_RESET_ON_COMMAALIGN              ("FALSE"),
    .RXBUF_RESET_ON_EIDLE                   ("FALSE"),
    .RXBUF_RESET_ON_RATE_CHANGE             ("TRUE"),
    .RXBUFRESET_TIME                        (5'b00001),
    .RXBUF_THRESH_OVFLW                     (61),
    .RXBUF_THRESH_OVRD                      ("FALSE"),
    .RXBUF_THRESH_UNDFLW                    (4),
    .RXDLY_CFG                              (16'h001F),
    .RXDLY_LCFG                             (9'h030),
    .RXDLY_TAP_CFG                          (16'h0000),
    .RXPH_CFG                               (24'h000000),
    .RXPHDLY_CFG                            (24'h084020),
    .RXPH_MONITOR_SEL                       (5'b00000),
    .RX_XCLK_SEL                            ("RXUSR"), // ("RXREC"), // Andrey: Now they are the same, just using p.247 "Using RX Buffer Bypass..."
    .RX_DDI_SEL                             (6'b000000),
    .RX_DEFER_RESET_BUF_EN                  ("TRUE"),
/// .RXCDR_CFG                              (72'h03000023ff10200020),// 1.6G - 6.25G, No SS, RXOUT_DIV=2
///    .RXCDR_CFG                              (72'h03800023ff10200008),// Guess for SS
    .RXCDR_CFG                              (72'h03_8800_8BFF_4020_0008),// http://www.xilinx.com/support/answers/53364.html - SATA-2, div=2
    .RXCDR_FR_RESET_ON_EIDLE                (1'b0),
    .RXCDR_HOLD_DURING_EIDLE                (1'b0),
    .RXCDR_PH_RESET_ON_EIDLE                (1'b0),
    .RXCDR_LOCK_CFG                         (6'b010101),
    .RXCDRFREQRESET_TIME                    (RXCDRFREQRESET_TIME),
    .RXCDRPHRESET_TIME                      (RXCDRPHRESET_TIME),
    .RXISCANRESET_TIME                      (RXISCANRESET_TIME),
    .RXPCSRESET_TIME                        (5'b00001),
    .RXPMARESET_TIME                        (RXPMARESET_TIME),
    .RXOOB_CFG                              (7'b0000110),
    .RXGEARBOX_EN                           ("FALSE"),
    .GEARBOX_MODE                           (3'b000),
    .RXPRBS_ERR_LOOPBACK                    (1'b0),
    .PD_TRANS_TIME_FROM_P2                  (12'h03c),
    .PD_TRANS_TIME_NONE_P2                  (8'h3c),
    .PD_TRANS_TIME_TO_P2                    (8'h64),
    .SAS_MAX_COM                            (64),
    .SAS_MIN_COM                            (36),
    .SATA_BURST_SEQ_LEN                     (4'b0101),
    .SATA_BURST_VAL                         (3'b100),
    .SATA_EIDLE_VAL                         (3'b100),
    .SATA_MAX_BURST                         (8),
    .SATA_MAX_INIT                          (21),
    .SATA_MAX_WAKE                          (7),
    .SATA_MIN_BURST                         (4),
    .SATA_MIN_INIT                          (12),
    .SATA_MIN_WAKE                          (4),
    .TRANS_TIME_RATE                        (8'h0E),
    .TXBUF_EN                               ("TRUE"),
    .TXBUF_RESET_ON_RATE_CHANGE             ("TRUE"),
    .TXDLY_CFG                              (16'h001F),
    .TXDLY_LCFG                             (9'h030),
    .TXDLY_TAP_CFG                          (16'h0000),
    .TXPH_CFG                               (16'h0780),
    .TXPHDLY_CFG                            (24'h084020),
    .TXPH_MONITOR_SEL                       (5'b00000),
    .TX_XCLK_SEL                            ("TXOUT"),
    .TX_DATA_WIDTH                          (20),
    .TX_DEEMPH0                             (5'b00000),
    .TX_DEEMPH1                             (5'b00000),
    .TX_EIDLE_ASSERT_DELAY                  (3'b110),
    .TX_EIDLE_DEASSERT_DELAY                (3'b100),
    .TX_LOOPBACK_DRIVE_HIZ                  ("FALSE"),
    .TX_MAINCURSOR_SEL                      (1'b0),
    .TX_DRIVE_MODE                          ("DIRECT"),
    .TX_MARGIN_FULL_0                       (7'b1001110),
    .TX_MARGIN_FULL_1                       (7'b1001001),
    .TX_MARGIN_FULL_2                       (7'b1000101),
    .TX_MARGIN_FULL_3                       (7'b1000010),
    .TX_MARGIN_FULL_4                       (7'b1000000),
    .TX_MARGIN_LOW_0                        (7'b1000110),
    .TX_MARGIN_LOW_1                        (7'b1000100),
    .TX_MARGIN_LOW_2                        (7'b1000010),
    .TX_MARGIN_LOW_3                        (7'b1000000),
    .TX_MARGIN_LOW_4                        (7'b1000000),
    .TXGEARBOX_EN                           ("FALSE"),
    .TXPCSRESET_TIME                        (5'b00001),
    .TXPMARESET_TIME                        (TXPMARESET_TIME),
    .TX_RXDETECT_CFG                        (14'h1832),
    .TX_RXDETECT_REF                        (3'b100),
    .CPLL_CFG                               (24'hBC07DC),
    .CPLL_FBDIV                             (4),
    .CPLL_FBDIV_45                          (5),
    .CPLL_INIT_CFG                          (24'h00001E),
    .CPLL_LOCK_CFG                          (16'h01E8),
    .CPLL_REFCLK_DIV                        (1),
    .RXOUT_DIV                              (2),
    .TXOUT_DIV                              (2),
    .SATA_CPLL_CFG                          ("VCO_3000MHZ"),
    .RXDFELPMRESET_TIME                     (RXDFELPMRESET_TIME),
    .RXLPM_HF_CFG                           (14'b00000011110000),
    .RXLPM_LF_CFG                           (14'b00000011110000),
    .RX_DFE_GAIN_CFG                        (23'h020FEA),
    .RX_DFE_H2_CFG                          (12'b000000000000),
    .RX_DFE_H3_CFG                          (12'b000001000000),
    .RX_DFE_H4_CFG                          (11'b00011110000),
    .RX_DFE_H5_CFG                          (11'b00011100000),
    .RX_DFE_KL_CFG                          (13'b0000011111110),
///    .RX_DFE_LPM_CFG                         (16'h0954),
    .RX_DFE_LPM_CFG                         (16'h0904),
    .RX_DFE_LPM_HOLD_DURING_EIDLE           (1'b0),
    .RX_DFE_UT_CFG                          (17'b10001111000000000),
    .RX_DFE_VP_CFG                          (17'b00011111100000011),
    .RX_CLKMUX_PD                           (1'b1),
    .TX_CLKMUX_PD                           (1'b1),
    .RX_INT_DATAWIDTH                       (0),
    .TX_INT_DATAWIDTH                       (0),
    .TX_QPI_STATUS_EN                       (1'b0),
    .RX_DFE_KL_CFG2                         (32'h301148AC),
    .RX_DFE_XYD_CFG                         (13'b0000000000000),
    .TX_PREDRIVER_MODE                      (1'b0)
) 
gtxe2_channel_wrapper(
    .CPLLFBCLKLOST                  (),
    .CPLLLOCK                       (cplllock),
    .CPLLLOCKDETCLK                 (cplllockdetclk),
    .CPLLLOCKEN                     (1'b1),
    .CPLLPD                         (1'b0),
    .CPLLREFCLKLOST                 (),
    .CPLLREFCLKSEL                  (3'b001),
    .CPLLRESET                      (cpllreset),
    .GTRSVD                         (16'b0),
    .PCSRSVDIN                      (16'b0),
    .PCSRSVDIN2                     (5'b0),
    .PMARSVDIN                      (5'b0),
    .PMARSVDIN2                     (5'b0),
    .TSTIN                          (20'h1),
    .TSTOUT                         (),
    .CLKRSVD                        (4'b0000),
    .GTGREFCLK                      (1'b0),
    .GTNORTHREFCLK0                 (1'b0),
    .GTNORTHREFCLK1                 (1'b0),
    .GTREFCLK0                      (gtrefclk),
    .GTREFCLK1                      (1'b0),
    .GTSOUTHREFCLK0                 (1'b0),
    .GTSOUTHREFCLK1                 (1'b0),
    .DRPADDR                        (9'b0),
    .DRPCLK                         (drpclk),
    .DRPDI                          (16'b0),
    .DRPDO                          (),
    .DRPEN                          (1'b0),
    .DRPRDY                         (),
    .DRPWE                          (1'b0),
    .GTREFCLKMONITOR                (),
    .QPLLCLK                        (1'b0/*gtrefclk*/),
    .QPLLREFCLK                     (1'b0/*gtrefclk*/),
    .RXSYSCLKSEL                    (2'b00),
    .TXSYSCLKSEL                    (2'b00),
    .DMONITOROUT                    (),
    .TX8B10BEN                      (1'b0),
    .LOOPBACK                       (3'd0),
    .PHYSTATUS                      (),
    .RXRATE                         (3'd0),
    .RXVALID                        (),
    .RXPD                           (2'b00),
    .TXPD                           (2'b00),
    .SETERRSTATUS                   (1'b0),
    .EYESCANRESET                   (1'b0),//rxreset), // p78
    .RXUSERRDY                      (rxuserrdy),
    .EYESCANDATAERROR               (),
    .EYESCANMODE                    (1'b0),
    .EYESCANTRIGGER                 (1'b0),
    .RXCDRFREQRESET                 (1'b0),
    .RXCDRHOLD                      (1'b0),
    .RXCDRLOCK                      (rxcdrlock),
    .RXCDROVRDEN                    (1'b0),
    .RXCDRRESET                     (1'b0),
    .RXCDRRESETRSV                  (1'b0),
    .RXCLKCORCNT                    (),
    .RX8B10BEN                      (1'b0),
    
///    .RXUSRCLK                       (rxusrclk),
///    .RXUSRCLK2                      (rxusrclk),
/// When internal elastic buffer is bypassed, these clocks should be restored clock synchronous
    .RXUSRCLK                       (xclk),
    .RXUSRCLK2                      (xclk),
    
    .RXDATA                         (rxdata_gtx),
    .RXPRBSERR                      (),
    .RXPRBSSEL                      (3'd0),
    .RXPRBSCNTRESET                 (1'b0),
    .RXDFEXYDEN                     (1'b1),
    .RXDFEXYDHOLD                   (1'b0),
    .RXDFEXYDOVRDEN                 (1'b0),
    .RXDISPERR                      (rxdisperr_gtx),
    .RXNOTINTABLE                   (),
    .GTXRXP                         (rxp),
    .GTXRXN                         (rxn),
    .RXBUFRESET                     (1'b0),
    .RXBUFSTATUS                    (),
//    .RXDDIEN                        (1'b0),
    .RXDDIEN                        (1'b1), // Andrey: p.243: "Set high in RX buffer bypass mode"
//    .RXDLYBYPASS                    (1'b1),
    .RXDLYBYPASS                    (1'b0), // Andrey: p.243: "0: Uses the RX delay alignment circuit."
    .RXDLYEN                        (1'b0),
    .RXDLYOVRDEN                    (1'b0),
    .RXDLYSRESET                    (rxdlysreset),
    .RXDLYSRESETDONE                (rxdlysresetdone),
    .RXPHALIGN                      (1'b0),
    .RXPHALIGNDONE                  (rxphaligndone),
    .RXPHALIGNEN                    (1'b0),
    .RXPHDLYPD                      (1'b0),
    .RXPHDLYRESET                   (1'b0),
    .RXPHMONITOR                    (),
    .RXPHOVRDEN                     (1'b0),
    .RXPHSLIPMONITOR                (),
    .RXSTATUS                       (),
    .RXBYTEISALIGNED                (),
    .RXBYTEREALIGN                  (),
    .RXCOMMADET                     (),
    .RXCOMMADETEN                   (1'b0),
    .RXMCOMMAALIGNEN                (1'b0),
    .RXPCOMMAALIGNEN                (1'b0),
    .RXCHANBONDSEQ                  (),
    .RXCHBONDEN                     (1'b0),
    .RXCHBONDLEVEL                  (3'd0),
    .RXCHBONDMASTER                 (1'b0),
    .RXCHBONDO                      (),
    .RXCHBONDSLAVE                  (1'b0),
    .RXCHANISALIGNED                (),
    .RXCHANREALIGN                  (),
    .RXLPMHFHOLD                    (1'b0),
    .RXLPMHFOVRDEN                  (1'b0),
    .RXLPMLFHOLD                    (1'b0),
    .RXDFEAGCHOLD                   (1'b0),
    .RXDFEAGCOVRDEN                 (1'b0),
    .RXDFECM1EN                     (1'b0),
    .RXDFELFHOLD                    (1'b0),
    .RXDFELFOVRDEN                  (1'b1),
    .RXDFELPMRESET                  (rxreset),
    .RXDFETAP2HOLD                  (1'b0),
    .RXDFETAP2OVRDEN                (1'b0),
    .RXDFETAP3HOLD                  (1'b0),
    .RXDFETAP3OVRDEN                (1'b0),
    .RXDFETAP4HOLD                  (1'b0),
    .RXDFETAP4OVRDEN                (1'b0),
    .RXDFETAP5HOLD                  (1'b0),
    .RXDFETAP5OVRDEN                (1'b0),
    .RXDFEUTHOLD                    (1'b0),
    .RXDFEUTOVRDEN                  (1'b0),
    .RXDFEVPHOLD                    (1'b0),
    .RXDFEVPOVRDEN                  (1'b0),
//    .RXDFEVSEN                      (1'b0),
    .RXLPMLFKLOVRDEN                (1'b0),
    .RXMONITOROUT                   (),
    .RXMONITORSEL                   (2'b01),
    .RXOSHOLD                       (1'b0),
    .RXOSOVRDEN                     (1'b0),
    .RXRATEDONE                     (),
    .RXOUTCLK                       (xclk_gtx),
    .RXOUTCLKFABRIC                 (),
    .RXOUTCLKPCS                    (),
    .RXOUTCLKSEL                    (3'b010),
    .RXDATAVALID                    (),
    .RXHEADER                       (),
    .RXHEADERVALID                  (),
    .RXSTARTOFSEQ                   (),
    .RXGEARBOXSLIP                  (1'b0),
    .GTRXRESET                      (rxreset),
    .RXOOBRESET                     (1'b0),
    .RXPCSRESET                     (1'b0),
    .RXPMARESET                     (1'b0),//rxreset), // p78
    .RXLPMEN                        (1'b0),
    .RXCOMSASDET                    (),
    .RXCOMWAKEDET                   (rxcomwakedet_gtx),
    .RXCOMINITDET                   (rxcominitdet_gtx),
    .RXELECIDLE                     (rxelecidle),
    .RXELECIDLEMODE                 (2'b00),
    .RXPOLARITY                     (1'b0),
    .RXSLIDE                        (1'b0),
    .RXCHARISCOMMA                  (),
    .RXCHARISK                      (rxcharisk_gtx),
    .RXCHBONDI                      (5'b00000),
    .RXRESETDONE                    (rxresetdone_gtx),
    .RXQPIEN                        (1'b0),
    .RXQPISENN                      (),
    .RXQPISENP                      (),
    .TXPHDLYTSTCLK                  (1'b0),
    .TXPOSTCURSOR                   (5'b00000),
    .TXPOSTCURSORINV                (1'b0),
    .TXPRECURSOR                    (5'd0),
    .TXPRECURSORINV                 (1'b0),
    .TXQPIBIASEN                    (1'b0),
    .TXQPISTRONGPDOWN               (1'b0),
    .TXQPIWEAKPUP                   (1'b0),
    .CFGRESET                       (1'b0),
    .GTTXRESET                      (txreset),
    .PCSRSVDOUT                     (),
    .TXUSERRDY                      (txuserrdy),
    .GTRESETSEL                     (1'b0),
    .RESETOVRD                      (1'b0),
    .TXCHARDISPMODE                 (txchardispmode_gtx),
    .TXCHARDISPVAL                  (txchardispval_gtx),
    .TXUSRCLK                       (txusrclk),
    .TXUSRCLK2                      (txusrclk),
    .TXELECIDLE                     (txelecidle_gtx),
    .TXMARGIN                       (3'd0),
    .TXRATE                         (3'd0),
    .TXSWING                        (1'b0),
    .TXPRBSFORCEERR                 (1'b0),
    .TXDLYBYPASS                    (1'b1),
    .TXDLYEN                        (1'b0),
    .TXDLYHOLD                      (1'b0),
    .TXDLYOVRDEN                    (1'b0),
    .TXDLYSRESET                    (1'b0),
    .TXDLYSRESETDONE                (),
    .TXDLYUPDOWN                    (1'b0),
    .TXPHALIGN                      (1'b0),
    .TXPHALIGNDONE                  (),
    .TXPHALIGNEN                    (1'b0),
    .TXPHDLYPD                      (1'b0),
    .TXPHDLYRESET                   (1'b0),
    .TXPHINIT                       (1'b0),
    .TXPHINITDONE                   (),
    .TXPHOVRDEN                     (1'b0),
    .TXBUFSTATUS                    (),
    .TXBUFDIFFCTRL                  (3'b100),
    .TXDEEMPH                       (1'b0),
    .TXDIFFCTRL                     (4'b1000),
    .TXDIFFPD                       (1'b0),
    .TXINHIBIT                      (1'b0),
    .TXMAINCURSOR                   (7'b0000000),
    .TXPISOPD                       (1'b0),
    .TXDATA                         (txdata_gtx),
    .GTXTXN                         (txn),
    .GTXTXP                         (txp),
    .TXOUTCLK                       (txoutclk_gtx),
    .TXOUTCLKFABRIC                 (),
    .TXOUTCLKPCS                    (),
    .TXOUTCLKSEL                    (3'b010),
    .TXRATEDONE                     (),
    .TXCHARISK                      (txcharisk_gtx),
    .TXGEARBOXREADY                 (),
    .TXHEADER                       (3'd0),
    .TXSEQUENCE                     (7'd0),
    .TXSTARTSEQ                     (1'b0),
    .TXPCSRESET                     (txpcsreset),
    .TXPMARESET                     (1'b0),
    .TXRESETDONE                    (txresetdone_gtx),
    .TXCOMFINISH                    (),
    .TXCOMINIT                      (txcominit_gtx),
    .TXCOMSAS                       (1'b0),
    .TXCOMWAKE                      (txcomwake_gtx),
    .TXPDELECIDLEMODE               (1'b0),
    .TXPOLARITY                     (1'b0),
    .TXDETECTRX                     (1'b0),
    .TX8B10BBYPASS                  (8'd0),
    .TXPRBSSEL                      (3'd0),
    .TXQPISENN                      (),
    .TXQPISENP                      ()
);

always @ (posedge gtrefclk)
    debug <= ~rxelecidle | debug;

endmodule
