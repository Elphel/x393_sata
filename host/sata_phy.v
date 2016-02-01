/*******************************************************************************
 * Module: sata_phy
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: phy-level, including oob, clock generation and GTXE2 
 *
 * Copyright (c) 2015 Elphel, Inc.
 * sata_phy.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * sata_phy.v file is distributed in the hope that it will be useful,
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
//`include "oob_ctrl.v"
//`include "gtx_wrap.v"
module sata_phy #(
    parameter   DATA_BYTE_WIDTH = 4
)
(
    // initial reset, resets PLL. After pll is locked, an internal sata reset is generated.
    input   wire        extrst,
    // sata clk, generated in pll as usrclk2
    output  wire        clk, // 75MHz, bufg
    output  wire        rst,

    // reliable clock to source drp and cpll lock det circuits
    input   wire        reliable_clk,

    // state
    output  wire        phy_ready,
    // tmp output TODO
    output  wire        gtx_ready,
    output  wire  [11:0] debug_cnt,

    // top-level ifaces
    // ref clk from an external source, shall be connected to pads
    input   wire        extclk_p, 
    input   wire        extclk_n,
    // sata link data pins
    output  wire        txp_out,
    output  wire        txn_out,
    input   wire        rxp_in,
    input   wire        rxn_in,

    // to link layer
    output  wire    [DATA_BYTE_WIDTH * 8 - 1:0] ll_data_out,
    output  wire    [DATA_BYTE_WIDTH - 1:0]     ll_charisk_out,
    output  wire    [DATA_BYTE_WIDTH - 1:0]     ll_err_out, // TODO!!!

    // from link layer
    input   wire    [DATA_BYTE_WIDTH * 8 - 1:0] ll_data_in,
    input   wire    [DATA_BYTE_WIDTH - 1:0]     ll_charisk_in,
    
    input                                       set_offline,     // electrically idle
    input                                       comreset_send,   // Not possible yet?
    output  wire                                cominit_got,
    output  wire                                comwake_got,
    output                                      cplllock_debug,
    output                                      usrpll_locked_debug,
    output                               [31:0] debug_sata
);

wire    [DATA_BYTE_WIDTH * 8 - 1:0] txdata;
wire    [DATA_BYTE_WIDTH * 8 - 1:0] rxdata;
wire    [DATA_BYTE_WIDTH * 8 - 1:0] rxdata_out;
wire    [DATA_BYTE_WIDTH * 8 - 1:0] txdata_in;
wire    [DATA_BYTE_WIDTH - 1:0]     txcharisk;
wire    [DATA_BYTE_WIDTH - 1:0]     rxcharisk;
wire    [DATA_BYTE_WIDTH - 1:0]     txcharisk_in;
wire    [DATA_BYTE_WIDTH - 1:0]     rxcharisk_out;
wire    [DATA_BYTE_WIDTH - 1:0]     rxdisperr;
wire    [DATA_BYTE_WIDTH - 1:0]     rxnotintable;

assign  ll_err_out = rxdisperr | rxnotintable;

// once gtx_ready -> 1, gtx_configured latches
// after this point it's possible to perform additional resets and reconfigurations by higher-level logic
reg             gtx_configured;
// after external rst -> 0, after sata logic resets -> 1
wire            sata_reset_done;

wire            rxcomwakedet;
wire            rxcominitdet;
wire            cplllock;
wire            txcominit;
wire            txcomwake;
wire            rxreset;
wire            rxelecidle;
wire            txelecidle;
wire            rxbyteisaligned;
wire            txpcsreset_req;
wire            recal_tx_done;
wire            rxreset_req;
wire            rxreset_ack;
wire            rxreset_oob;
// elastic buffer status signals TODO
wire            rxelsfull;
wire            rxelsempty;

//wire            gtx_ready;
assign cominit_got = rxcominitdet; // For AHCI
assign comwake_got = rxcomwakedet; // For AHCI
wire dummy;



oob_ctrl oob_ctrl(
    // sata clk = usrclk2
    .clk                (clk),
    // reset oob
    .rst                (rst),
    // gtx is ready = all resets are done
    .gtx_ready          (gtx_ready),
    .debug ({dummy,debug_cnt[10:0]}),
    // oob responses
    .rxcominitdet_in    (rxcominitdet),
    .rxcomwakedet_in    (rxcomwakedet),
    .rxelecidle_in      (rxelecidle),
    // oob issues
    .txcominit          (txcominit),
    .txcomwake          (txcomwake),
    .txelecidle         (txelecidle),

    .txpcsreset_req     (txpcsreset_req),
    .recal_tx_done      (recal_tx_done),

    .rxreset_req        (rxreset_req),
    .rxreset_ack        (rxreset_ack),

    // input data stream (if any data during OOB setting => ignored)
    .txdata_in          (txdata_in),
    .txcharisk_in       (txcharisk_in),
    // output data stream to gtx
    .txdata_out         (txdata),
    .txcharisk_out      (txcharisk),
    // input data from gtx
    .rxdata_in          (rxdata[31:0]),
    .rxcharisk_in       (rxcharisk[3:0]),
    // bypassed data from gtx
    .rxdata_out         (rxdata_out),
    .rxcharisk_out      (rxcharisk_out),

    // receiving data is aligned
    .rxbyteisaligned    (rxbyteisaligned),

    // shows if channel is ready
    .phy_ready          (phy_ready),
    // To/from AHCI
    .set_offline        (set_offline), // input
    .comreset_send      (comreset_send) // input
    
);

wire    cplllockdetclk; // TODO
wire    drpclk; // TODO
wire    cpllreset;
wire    gtrefclk;
wire    rxresetdone;
wire    txresetdone;
wire    txpcsreset;
wire    txreset;
wire    txuserrdy;
wire    rxuserrdy;
wire    txusrclk;
wire    txusrclk2;
wire    rxusrclk;
wire    rxusrclk2;
wire    txp;
wire    txn;
wire    rxp;
wire    rxn;
wire    txoutclk;
wire    txpmareset_done;
wire    rxeyereset_done;

// tx reset sequence; waves @ ug476 p67
localparam  TXPMARESET_TIME = 5'h1;
reg     [2:0]   txpmareset_cnt;
assign  txpmareset_done = txpmareset_cnt == TXPMARESET_TIME;
always @ (posedge gtrefclk)
    txpmareset_cnt  <= txreset ? 3'h0 : txpmareset_done ? txpmareset_cnt : txpmareset_cnt + 1'b1;

// rx reset sequence; waves @ ug476 p77
localparam  RXPMARESET_TIME     = 5'h11;
localparam  RXCDRPHRESET_TIME   = 5'h1;
localparam  RXCDRFREQRESET_TIME = 5'h1;
localparam  RXDFELPMRESET_TIME  = 7'hf;
localparam  RXISCANRESET_TIME   = 5'h1;
localparam  RXEYERESET_TIME     = 7'h0 + RXPMARESET_TIME + RXCDRPHRESET_TIME + RXCDRFREQRESET_TIME + RXDFELPMRESET_TIME + RXISCANRESET_TIME;
reg     [6:0]   rxeyereset_cnt;
assign  rxeyereset_done = rxeyereset_cnt == RXEYERESET_TIME;
always @ (posedge gtrefclk) begin 
    if      (rxreset)          rxeyereset_cnt  <= 0;
    else if (!rxeyereset_done) rxeyereset_cnt  <= rxeyereset_cnt + 1;
end
/*
 * Resets
 */
wire    usrpll_locked;

// make tx/rxreset synchronous to gtrefclk - gather singals from different domains: async, aclk, usrclk2, gtrefclk
localparam [7:0] RST_TIMER_LIMIT = 8'b1000;
reg rxreset_f;
reg txreset_f;
reg rxreset_f_r;
reg txreset_f_r;
reg rxreset_f_rr;
reg txreset_f_rr;
//reg pre_sata_reset_done;
reg sata_areset;
reg [2:0] sata_reset_done_r;
reg [7:0]   rst_timer;
//reg         rst_r = 1;
assign  rst = !sata_reset_done_r;

assign  sata_reset_done = sata_reset_done_r[1];


assign cplllock_debug = cplllock;
assign usrpll_locked_debug = usrpll_locked;

// generate internal reset after a clock is established
// !!!ATTENTION!!!
// async rst block
//localparam [7:0] RST_TIMER_LIMIT = 8'b1000;
/*
always @ (posedge clk or posedge extrst)
//    rst_timer <= extrst | ~cplllock | ~usrpll_locked ? 8'h0 : sata_reset_done ? rst_timer : rst_timer + 1'b1;
    if      (extrst)                     rst_timer <= 0;
    else if (~cplllock | ~usrpll_locked) rst_timer <= 0;
    else if (!sata_reset_done)           rst_timer <= rst_timer + 1;
//    else        rst_timer <= ~cplllock | ~usrpll_locked ? 8'h0 : sata_reset_done ? rst_timer : rst_timer + 1'b1;

always @ (posedge clk or posedge extrst)
    if      (extrst)       rst_r <= 1; 
    else if (~|rst_timer)  rst_r <= 0;
    else                   rst_r <= !sata_reset_done;
//    else        rst_r <= ~|rst_timer ? 1'b0 : sata_reset_done ? 1'b0 : 1'b1;
///assign  sata_reset_done = rst_timer == RST_TIMER_LIMIT;
*/
always @ (posedge clk or  posedge sata_areset) begin
    if      (sata_areset)  sata_reset_done_r <= 0;
    else                   sata_reset_done_r <= {sata_reset_done_r[1:0], 1'b1};
end


always @ (posedge gtrefclk) begin
    rxreset_f <= ~cplllock | cpllreset | rxreset_oob & gtx_configured;
    txreset_f <= ~cplllock | cpllreset;

///    rxreset_f <= ~cplllock | cpllreset | ~usrpll_locked | ~sata_reset_done | rxreset_oob & gtx_configured;
///    txreset_f <= ~cplllock | cpllreset | ~usrpll_locked;

    txreset_f_r <= txreset_f;
    rxreset_f_r <= rxreset_f;
    txreset_f_rr <= txreset_f_r;
    rxreset_f_rr <= rxreset_f_r;
    
    if (!(cplllock  && usrpll_locked)) rst_timer <= RST_TIMER_LIMIT;
    else if (|rst_timer)               rst_timer <= rst_timer - 1;
    
    sata_areset <= !(cplllock  &&  usrpll_locked && !(|rst_timer));
    
end
assign  rxreset = rxreset_f_rr;
assign  txreset = txreset_f_rr;
assign  cpllreset = extrst;
assign  rxuserrdy = usrpll_locked & cplllock & ~cpllreset & ~rxreset & rxeyereset_done & sata_reset_done;
assign  txuserrdy = usrpll_locked & cplllock & ~cpllreset & ~txreset & txpmareset_done & sata_reset_done;

assign  gtx_ready = rxuserrdy & txuserrdy & rxresetdone & txresetdone;

// assert gtx_configured. Once gtx_ready -> 1, gtx_configured latches
always @ (posedge clk or posedge extrst)
//    gtx_configured <= extrst ? 1'b0 : gtx_ready | gtx_configured;
    if (extrst) gtx_configured <= 0;
    else        gtx_configured <= gtx_ready | gtx_configured;






// issue partial tx reset to restore functionality after oob sequence. Let it lasts 8 clock lycles
reg [3:0]   txpcsreset_cnt;
wire        txpcsreset_stop;

assign  txpcsreset_stop = txpcsreset_cnt[3];
assign  txpcsreset = txpcsreset_req & ~txpcsreset_stop & gtx_configured;
assign  recal_tx_done = txpcsreset_stop & gtx_ready;

always @ (posedge clk or posedge extrst)
//    txpcsreset_cnt <= extrst | rst | ~txpcsreset_req ? 4'h0 : txpcsreset_stop ? txpcsreset_cnt : txpcsreset_cnt + 1'b1;
    if (extrst) txpcsreset_cnt <= 1;
    else        txpcsreset_cnt <= rst | ~txpcsreset_req ? 4'h0 : txpcsreset_stop ? txpcsreset_cnt : txpcsreset_cnt + 1'b1;

// issue rx reset to restore functionality after oob sequence. Let it lasts 8 clock lycles
reg [3:0]   rxreset_oob_cnt;
wire        rxreset_oob_stop;

assign  rxreset_oob_stop = rxreset_oob_cnt[3];
assign  rxreset_oob      = rxreset_req & ~rxreset_oob_stop;
assign  rxreset_ack      = rxreset_oob_stop & gtx_ready;

always @ (posedge clk or posedge extrst)
//    rxreset_oob_cnt <= extrst | rst | ~rxreset_req ? 4'h0 : rxreset_oob_stop ? rxreset_oob_cnt : rxreset_oob_cnt + 1'b1;
    if (extrst) rxreset_oob_cnt <= 1; 
    else        rxreset_oob_cnt <= rst | ~rxreset_req ? 4'h0 : rxreset_oob_stop ? rxreset_oob_cnt : rxreset_oob_cnt + 1'b1;


/*
 * USRCLKs generation. USRCLK @ 150MHz, same as TXOUTCLK; USRCLK2 @ 75Mhz -> sata_clk === sclk
 * It's recommended to use MMCM instead of PLL, whatever
 */
wire    usrpll_fb_clk;
wire    usrclk;
wire    usrclk2;

wire usrclk_global;
BUFG bufg_usrclk (.O(usrclk_global),.I(usrclk));
assign  txusrclk  = usrclk_global; // 150MHz
assign  txusrclk2 = clk; // usrclk2;       // should not use non-buffered clock!
assign  rxusrclk  = usrclk_global; // 150MHz
assign  rxusrclk2 = clk; // usrclk2;       // should not use non-buffered clock!

PLLE2_ADV #(
    .BANDWIDTH              ("OPTIMIZED"),
    .CLKFBOUT_MULT          (8),
    .CLKFBOUT_PHASE         (0.000),
    .CLKIN1_PERIOD          (6.666),
    .CLKIN2_PERIOD          (0.000),
    .CLKOUT0_DIVIDE         (8),
    .CLKOUT0_DUTY_CYCLE     (0.500),
    .CLKOUT0_PHASE          (0.000),
    .CLKOUT1_DIVIDE         (16),
    .CLKOUT1_DUTY_CYCLE     (0.500),
    .CLKOUT1_PHASE          (0.000),
/*    .CLKOUT2_DIVIDE = 1,
    .CLKOUT2_DUTY_CYCLE = 0.500,
    .CLKOUT2_PHASE = 0.000,
    .CLKOUT3_DIVIDE = 1,
    .CLKOUT3_DUTY_CYCLE = 0.500,
    .CLKOUT3_PHASE = 0.000,
    .CLKOUT4_DIVIDE = 1,
    .CLKOUT4_DUTY_CYCLE = 0.500,
    .CLKOUT4_PHASE = 0.000,
    .CLKOUT5_DIVIDE = 1,
    .CLKOUT5_DUTY_CYCLE = 0.500,
    .CLKOUT5_PHASE = 0.000,*/
    .COMPENSATION           ("ZHOLD"),
    .DIVCLK_DIVIDE          (1),
    .IS_CLKINSEL_INVERTED   (1'b0),
    .IS_PWRDWN_INVERTED     (1'b0),
    .IS_RST_INVERTED        (1'b0),
    .REF_JITTER1            (0.010),
    .REF_JITTER2            (0.010),
    .STARTUP_WAIT           ("FALSE")
)
usrclk_pll(
  .CLKFBOUT (usrpll_fb_clk),
  .CLKOUT0  (usrclk),   //150Mhz
  .CLKOUT1  (usrclk2), // 75MHz
  .CLKOUT2  (),
  .CLKOUT3  (),
  .CLKOUT4  (),
  .CLKOUT5  (),
  .DO       (),
  .DRDY     (),
  .LOCKED   (usrpll_locked),

  .CLKFBIN  (usrpll_fb_clk),
  .CLKIN1   (txoutclk),
  .CLKIN2   (1'b0),
  .CLKINSEL (1'b1),
  .DADDR    (7'h0),
  .DCLK     (drpclk),
  .DEN      (1'b0),
  .DI       (16'h0),
  .DWE      (1'b0),
  .PWRDWN   (1'b0),
  .RST      (~cplllock)
);

/*
 * Padding for an external input clock @ 150 MHz
 */
localparam [1:0] CLKSWING_CFG = 2'b11;
IBUFDS_GTE2 #(
    .CLKRCV_TRST   ("TRUE"),
    .CLKCM_CFG      ("TRUE"),
    .CLKSWING_CFG   (CLKSWING_CFG)
)
ext_clock_buf(
    .I      (extclk_p),
    .IB     (extclk_n),
    .CEB    (1'b0),
    .O      (gtrefclk),
    .ODIV2  ()
);

gtx_wrap #(
    .DATA_BYTE_WIDTH        (DATA_BYTE_WIDTH),
    .TXPMARESET_TIME        (TXPMARESET_TIME),
    .RXPMARESET_TIME        (RXPMARESET_TIME),
    .RXCDRPHRESET_TIME      (RXCDRPHRESET_TIME),
    .RXCDRFREQRESET_TIME    (RXCDRFREQRESET_TIME),
    .RXDFELPMRESET_TIME     (RXDFELPMRESET_TIME),
    .RXISCANRESET_TIME      (RXISCANRESET_TIME)
)
gtx_wrap
(
    .debug              (debug_cnt[11]),   // output reg 
    .cplllock           (cplllock),        // output wire 
    .cplllockdetclk     (cplllockdetclk),  // input wire 
    .cpllreset          (cpllreset),       // input wire 
    .gtrefclk           (gtrefclk),        // input wire 
    .drpclk             (drpclk),          // input wire 
    .rxuserrdy          (rxuserrdy),       // input wire 
    .txuserrdy          (txuserrdy),       // input wire 
    .rxusrclk           (rxusrclk),        // input wire 
    .rxusrclk2          (rxusrclk2),       // input wire 
    .rxp                (rxp),             // input wire 
    .rxn                (rxn),             // input wire 
    .rxbyteisaligned    (rxbyteisaligned), // output wire
    .rxreset            (rxreset),         // input wire 
    .rxcomwakedet       (rxcomwakedet),    // output wire
    .rxcominitdet       (rxcominitdet),    // output wire
    .rxelecidle         (rxelecidle),      // output wire
    .rxresetdone        (rxresetdone),     // output wire
    .txreset            (txreset),         // input wire 
    .txusrclk           (txusrclk),        // input wire 
    .txusrclk2          (txusrclk2),       // input wire 
    .txelecidle         (txelecidle),      // input wire 
    .txp                (txp),             // output wire
    .txn                (txn),             // output wire
    .txoutclk           (txoutclk),        // output wire
    .txpcsreset         (txpcsreset),      // input wire 
    .txresetdone        (txresetdone),     // output wire
    .txcominit          (txcominit),       // input wire 
    .txcomwake          (txcomwake),       // input wire 
    .rxelsfull          (rxelsfull),       // output wire
    .rxelsempty         (rxelsempty),      // output wire
    .txdata             (txdata),          // input [31:0] wire 
    .txcharisk          (txcharisk),       // input [3:0] wire 
    .rxdata             (rxdata),          // output[31:0] wire 
    .rxcharisk          (rxcharisk),       // output[3:0] wire 
    .rxdisperr          (rxdisperr),       // output[3:0] wire 
    .rxnotintable       (rxnotintable)     // output[3:0] wire 
);



/*
 * Interfaces
 */
assign  cplllockdetclk  = reliable_clk; //gtrefclk;
assign  drpclk          = reliable_clk; //gtrefclk;

//assign  clk             = usrclk2;
BUFG bufg_sclk   (.O(clk),.I(usrclk2));
assign  rxn             = rxn_in;
assign  rxp             = rxp_in;
assign  txn_out         = txn;
assign  txp_out         = txp;
assign  ll_data_out     = rxdata_out;
assign  ll_charisk_out  = rxcharisk_out;
assign  txdata_in       = ll_data_in;
assign  txcharisk_in    = ll_charisk_in;

reg [3:0] debug_cntr1;
reg [3:0] debug_cntr2;
reg [3:0] debug_cntr3;
reg [3:0] debug_cntr4;
//txoutclk
always @ (posedge gtrefclk) begin
    if (extrst) debug_cntr1 <= 0;
    else        debug_cntr1 <= debug_cntr1 + 1;
end

always @ (posedge clk) begin
    if (rst) debug_cntr2 <= 0;
    else        debug_cntr2 <= debug_cntr2 + 1;
end

always @ (posedge reliable_clk) begin
    if (extrst) debug_cntr3 <= 0;
    else        debug_cntr3 <= debug_cntr3 + 1;
end

always @ (posedge txoutclk) begin
    if (extrst) debug_cntr4 <= 0;
    else        debug_cntr4 <= debug_cntr4 + 1;
end

assign debug_sata[ 3: 0] = debug_cntr1;
assign debug_sata[ 7: 4] = debug_cntr2;
assign debug_sata[11: 8] = debug_cntr3;
assign debug_sata[12] =    debug_cnt[11];
assign debug_sata[13] =    cplllock;
assign debug_sata[14] =    cpllreset;
assign debug_sata[15] =    rxelecidle;
assign debug_sata[16] =    usrpll_locked;
assign debug_sata[17] =    txreset;
assign debug_sata[18] =    txpcsreset;
assign debug_sata[19] =    txelecidle;
assign debug_sata[23:20] = debug_cntr4;

endmodule
