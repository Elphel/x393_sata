/*******************************************************************************
 * Module: tb_ahci
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: testbench for ahci_top.v
 *
 * Copyright (c) 2015 Elphel, Inc.
 * tb_ahci.tf is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * tb_ahci.tf file is distributed in the hope that it will be useful,
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
// global defines
`define IVERILOG
`define SIMULATION
`define OPEN_SOURCE_ONLY
`define PRELOAD_BRAMS
`define CHECKERS_ENABLED
`define use200Mhz 1

/*
 * using x393_testbench01.tf style, contains a lot of copy-pasted code from there
 */
`timescale 1ns/1ps
//`include "top.v"
//`include "sata_device.v"

module tb_ahci #(
`include "includes/x393_parameters.vh" // SuppressThisWarning VEditor - partially used
`include "includes/x393_simulation_parameters.vh" // SuppressThisWarning VEditor - partially used
)
(
);

`ifdef IVERILOG              
    `include "IVERILOG_INCLUDE.v"
`else // IVERILOG
    `ifdef CVC
        `include "IVERILOG_INCLUDE.v"
    `else
         parameter fstname = "x393_sata.fst";
    `endif // CVC
`endif // IVERILOG

parameter HOST_CLK_PERIOD = 6.666; //nsec
//parameter DEVICE_CLK_PERIOD = 6.653; //nsec
parameter DEVICE_CLK_PERIOD = 6.666; //nsec TODO: Implement actual CDR

reg [639:0] TESTBENCH_TITLE = 'bz; // to show human-readable state in the GTKWave
reg  [31:0] TESTBENCH_DATA;
reg  [11:0] TESTBENCH_ID;

reg [639:0] DEVICE_TITLE = 'bz; // to show human-readable state in the GTKWave
reg  [31:0] DEVICE_DATA;
reg  [11:0] Device_ID;

initial #1 $display("HI THERE");
initial
begin
    $dumpfile(fstname);
    $dumpvars(0, tb_ahci);       // SuppressThisWarning VEditor - no idea why here was a warning
    $dumpvars(0, glbl);       // SuppressThisWarning VEditor - no idea why here was a warning
end

reg EXTCLK_P = 1'b1;
reg EXTCLK_N = 1'b0;
reg DEV_EXTCLK_P = 1'b1;
reg DEV_EXTCLK_N = 1'b0;
//reg serial_clk = 1'b1;

reg      [11:0] ARID_IN_r;
reg      [31:0] ARADDR_IN_r;
reg       [3:0] ARLEN_IN_r;
reg       [1:0] ARSIZE_IN_r;
reg       [1:0] ARBURST_IN_r;
reg      [11:0] AWID_IN_r;
reg      [31:0] AWADDR_IN_r;
reg       [3:0] AWLEN_IN_r;
reg       [1:0] AWSIZE_IN_r;
reg       [1:0] AWBURST_IN_r;

reg      [11:0] WID_IN_r;
reg      [31:0] WDATA_IN_r;
reg       [3:0] WSTRB_IN_r;
reg             WLAST_IN_r;
reg DEBUG1, DEBUG2, DEBUG3; // SuppressThisWarnings VEditor not used, just for simulation (inside included tasks)
reg      [11:0] GLOBAL_WRITE_ID=0;
reg      [11:0] GLOBAL_READ_ID=0;
reg      [11:0] LAST_ARID; // last issued ARID

wire [SIMUL_AXI_READ_WIDTH-1:0] SIMUL_AXI_ADDR_W;

//wire        SIMUL_AXI_MISMATCH;
// SuppressWarnings VEditor
reg      [31:0] SIMUL_AXI_READ;
// SuppressWarnings VEditor
reg [SIMUL_AXI_READ_WIDTH-1:0] SIMUL_AXI_ADDR;
// SuppressWarnings VEditor
reg             SIMUL_AXI_FULL; // some data available
wire            SIMUL_AXI_EMPTY;  // SuppressThisWarnings VEditor not used, just for simulation
reg      [31:0] registered_rdata; // here read data from task SuppressThisWarnings VEditor not used, just for simulation

reg             CLK;
//wire    CLK;
//reg             RST;
tri0 RST = glbl.GSR;

reg             AR_SET_CMD_r;
wire            AR_READY;

reg             AW_SET_CMD_r;
wire            AW_READY;

reg             W_SET_CMD_r;
wire            W_READY;
reg       [3:0] RD_LAG;  // ready signal lag in axi read channel (0 - RDY=1, 1..15 - RDY is asserted N cycles after valid)   
reg       [3:0] B_LAG;   // ready signal lag in axi arete response channel (0 - RDY=1, 1..15 - RDY is asserted N cycles after valid)   

// Simulation modules interconnection

wire     [31:0] rdata;
wire     [11:0] rid;
wire            rlast;
wire      [1:0] rresp; // SuppressThisWarnings VEditor not used, just for simulation
wire            rvalid;
wire            rready;
wire            rstb=rvalid && rready;

wire      [1:0] bresp; // SuppressThisWarnings VEditor not used, just for simulation
wire     [11:0] bid; // SuppressThisWarnings VEditor not used, just for simulation
wire            bvalid;
wire            bready;
integer     NUM_WORDS_READ;
integer     NUM_WORDS_EXPECTED;
//  integer     SCANLINE_CUR_X;
//  integer     SCANLINE_CUR_Y;
wire AXI_RD_EMPTY=NUM_WORDS_READ==NUM_WORDS_EXPECTED; //SuppressThisWarning VEditor : may be unused, just for simulation
assign  SIMUL_AXI_EMPTY= ~rvalid && rready && (rid==LAST_ARID); //SuppressThisWarning VEditor : may be unused, just for simulation // use it to wait for?
wire                          IRQ = dut.ps7_i.IRQF2P[0];

wire [11:0]  #(AXI_TASK_HOLD) ARID_IN = ARID_IN_r;
wire [31:0]  #(AXI_TASK_HOLD) ARADDR_IN = ARADDR_IN_r;
wire  [3:0]  #(AXI_TASK_HOLD) ARLEN_IN = ARLEN_IN_r;
wire  [1:0]  #(AXI_TASK_HOLD) ARSIZE_IN = ARSIZE_IN_r;
wire  [1:0]  #(AXI_TASK_HOLD) ARBURST_IN = ARBURST_IN_r;
wire [11:0]  #(AXI_TASK_HOLD) AWID_IN = AWID_IN_r;
wire [31:0]  #(AXI_TASK_HOLD) AWADDR_IN = AWADDR_IN_r;
wire  [3:0]  #(AXI_TASK_HOLD) AWLEN_IN = AWLEN_IN_r;
wire  [1:0]  #(AXI_TASK_HOLD) AWSIZE_IN = AWSIZE_IN_r;
wire  [1:0]  #(AXI_TASK_HOLD) AWBURST_IN = AWBURST_IN_r;
wire [11:0]  #(AXI_TASK_HOLD) WID_IN = WID_IN_r;
wire [31:0]  #(AXI_TASK_HOLD) WDATA_IN = WDATA_IN_r;
wire [ 3:0]  #(AXI_TASK_HOLD) WSTRB_IN = WSTRB_IN_r;
wire         #(AXI_TASK_HOLD) WLAST_IN = WLAST_IN_r;
wire         #(AXI_TASK_HOLD) AR_SET_CMD = AR_SET_CMD_r;
wire         #(AXI_TASK_HOLD) AW_SET_CMD = AW_SET_CMD_r;
wire         #(AXI_TASK_HOLD) W_SET_CMD =  W_SET_CMD_r;

/*
 * connect axi ports to the dut
 */
assign dut.ps7_i.FCLKCLK=        {4{CLK}};
assign dut.ps7_i.FCLKRESETN=     {RST,~RST,RST,~RST};
// Read data
assign rdata=                              dut.ps7_i.MAXIGP1RDATA; 
assign rvalid=                             dut.ps7_i.MAXIGP1RVALID;
assign dut.ps7_i.MAXIGP1RREADY=  rready;
assign rid=                                dut.ps7_i.MAXIGP1RID;
assign rlast=                              dut.ps7_i.MAXIGP1RLAST;
assign rresp=                              dut.ps7_i.MAXIGP1RRESP;
// Write response
assign bvalid=                             dut.ps7_i.MAXIGP1BVALID;
assign dut.ps7_i.MAXIGP1BREADY=  bready;
assign bid=                                dut.ps7_i.MAXIGP1BID;
assign bresp=                              dut.ps7_i.MAXIGP1BRESP;


// Simulation modules    
simul_axi_master_rdaddr
#(
  .ID_WIDTH        (12),
  .ADDRESS_WIDTH   (32),
  .LATENCY         (AXI_RDADDR_LATENCY),         // minimal delay between inout and output ( 0 - next cycle)
  .DEPTH           (8),                          // maximal number of commands in FIFO
  .DATA_DELAY      (3.5),
  .VALID_DELAY     (4.0)
) simul_axi_master_rdaddr_i (
    .clk        (CLK),                           // input
    .reset      (RST),                           // input
    .arid_in    (ARID_IN[11:0]),                 // input[11:0]
    .araddr_in  (ARADDR_IN[31:0]),               // input[31:0]
    .arlen_in   (ARLEN_IN[3:0]),                 // input[3:0]
    .arsize_in  (ARSIZE_IN[1:0]),                // input[1:0]
    .arburst_in (ARBURST_IN[1:0]),               // input[1:0]
    .arcache_in (4'b0),                          // input[3:0]
    .arprot_in  (3'b0),                          // input[2:0]//     .arprot_in(2'b0),
    .arid       (dut.ps7_i.MAXIGP1ARID[11:0]),   // output[11:0]
    .araddr     (dut.ps7_i.MAXIGP1ARADDR[31:0]), // output[31:0]
    .arlen      (dut.ps7_i.MAXIGP1ARLEN[3:0]),   // output[3:0]
    .arsize     (dut.ps7_i.MAXIGP1ARSIZE[1:0]),  // output[1:0]
    .arburst    (dut.ps7_i.MAXIGP1ARBURST[1:0]), // output[1:0]
    .arcache    (dut.ps7_i.MAXIGP1ARCACHE[3:0]), // output3:0]
    .arprot     (dut.ps7_i.MAXIGP1ARPROT[2:0]),  // output[2:0]
    .arvalid    (dut.ps7_i.MAXIGP1ARVALID),      // output
    .arready    (dut.ps7_i.MAXIGP1ARREADY),      // input
    .set_cmd    (AR_SET_CMD),                    // input// latch all other input data at posedge of clock
    .ready      (AR_READY)                       // command/data FIFO can accept command
);

simul_axi_master_wraddr
#(
  .ID_WIDTH        (12),
  .ADDRESS_WIDTH   (32),
  .LATENCY         (AXI_WRADDR_LATENCY),         // minimal delay between inout and output ( 0 - next cycle)
  .DEPTH           (8),                          // maximal number of commands in FIFO
  .DATA_DELAY      (3.5),
  .VALID_DELAY     (4.0)
) simul_axi_master_wraddr_i (
    .clk        (CLK),                           // input
    .reset      (RST),                           // input
    .awid_in    (AWID_IN[11:0]),                 // input[11:0]
    .awaddr_in  (AWADDR_IN[31:0]),               // input[31:0]
    .awlen_in   (AWLEN_IN[3:0]),                 // input[3:0]
    .awsize_in  (AWSIZE_IN[1:0]),                // input[2:0]
    .awburst_in (AWBURST_IN[1:0]),               // input[1:0]
    .awcache_in (4'b0),                          // input[1:0]
    .awprot_in  (3'b0),                          // input[2:0]//.awprot_in(2'b0),
    .awid       (dut.ps7_i.MAXIGP1AWID[11:0]),   // output[11:0]
    .awaddr     (dut.ps7_i.MAXIGP1AWADDR[31:0]), // output[31:0]
    .awlen      (dut.ps7_i.MAXIGP1AWLEN[3:0]),   // output[31:0]
    .awsize     (dut.ps7_i.MAXIGP1AWSIZE[1:0]),  // output[2:0]
    .awburst    (dut.ps7_i.MAXIGP1AWBURST[1:0]), // output[1:0]
    .awcache    (dut.ps7_i.MAXIGP1AWCACHE[3:0]), // output[3:0]
    .awprot     (dut.ps7_i.MAXIGP1AWPROT[2:0]),  // output[2:0]
    .awvalid    (dut.ps7_i.MAXIGP1AWVALID),      // output
    .awready    (dut.ps7_i.MAXIGP1AWREADY),      // input
    
    .set_cmd    (AW_SET_CMD),                    // input // latch all other input data at posedge of clock
    .ready      (AW_READY)                       // output// command/data FIFO can accept command
);


simul_axi_master_wdata #(
  .ID_WIDTH        (12),
  .DATA_WIDTH      (32),
  .WSTB_WIDTH      (4),
  .LATENCY         (AXI_WRDATA_LATENCY),         // minimal delay between inout and output ( 0 - next cycle)
  .DEPTH           (8),                          // maximal number of commands in FIFO
  .DATA_DELAY(3.2),
  .VALID_DELAY(3.6)
) simul_axi_master_wdata_i (
    .clk       (CLK),                           // input
    .reset     (RST),                           // input
    .wid_in    (WID_IN[11:0]),                  // input[11:0]
    .wdata_in  (WDATA_IN[31:0]),                // input[31:0]
    .wstrb_in  (WSTRB_IN[3:0]),                 // input[3:0]
    .wlast_in  (WLAST_IN),                      // input
    .wid       (dut.ps7_i.MAXIGP1WID[11:0]),    // output[11:0]
    .wdata     (dut.ps7_i.MAXIGP1WDATA[31:0]),  // output[31:0]
    .wstrb     (dut.ps7_i.MAXIGP1WSTRB[3:0]),   // output[3:0]
    .wlast     (dut.ps7_i.MAXIGP1WLAST),        // output
    .wvalid    (dut.ps7_i.MAXIGP1WVALID),       // output
    .wready    (dut.ps7_i.MAXIGP1WREADY),       // input
    .set_cmd   (W_SET_CMD),                     // input // latch all other input data at posedge of clock
    .ready     (W_READY)                        // output        // command/data FIFO can accept command
);

simul_axi_read #(
  .ADDRESS_WIDTH   (SIMUL_AXI_READ_WIDTH)
  ) simul_axi_read_i(
  .clk         (CLK),                           // input
  .reset       (RST),                           // input
  .last        (rlast),                         // input
  .data_stb    (rstb),                          // input
  .raddr       (ARADDR_IN[SIMUL_AXI_READ_WIDTH+1:2]), // input[9:0]
  .rlen        (ARLEN_IN),                      // input[3:0] 
  .rcmd        (AR_SET_CMD),                    // input
  .addr_out    (SIMUL_AXI_ADDR_W[SIMUL_AXI_READ_WIDTH-1:0]),  // output[9:0] 
  .burst       (),                              // output // burst in progress - just debug
  .err_out     ());                             // output reg // data last does not match predicted or FIFO over/under run - just debug



simul_axi_slow_ready simul_axi_slow_ready_read_i(
    .clk(CLK),
    .reset(RST), //input         reset,
    .delay(RD_LAG), //input  [3:0]  delay,
    .valid(rvalid), // input         valid,
    .ready(rready)  //output        ready
    );

simul_axi_slow_ready simul_axi_slow_ready_write_resp_i(
    .clk(CLK),
    .reset(RST), //input         reset,
    .delay(B_LAG), //input  [3:0]  delay,
    .valid(bvalid), // input       ADDRESS_NUMBER+2:0  valid,
    .ready(bready)  //output        ready
    );


// device-under-test instance
wire    rxn;
wire    rxp;
wire    txn;
wire    txp;
wire    device_rst;

localparam  TEST_ELASTIC_PERIOD_SLOW = 13.40;
localparam  TEST_ELASTIC_PERIOD_FAST = 13.27;


wire        test_elastic_wclk =          dut.sata_top.ahci_sata_layers_i.phy.gtx_wrap.xclk;
//wire        test_elastic_rclk =          dut.sata_top.ahci_sata_layers_i.phy.gtx_wrap.rxusrclk2;
wire        test_elastic_isaligned_in =  dut.sata_top.ahci_sata_layers_i.phy.gtx_wrap.state_aligned && dut.sata_top.ahci_sata_layers_i.phy.gtx_wrap.rxdlysresetdone_r;
wire  [1:0] test_elastic_charisk_in =    dut.sata_top.ahci_sata_layers_i.phy.gtx_wrap.rxcharisk_dec_out;
wire  [1:0] test_elastic_notintable_in = dut.sata_top.ahci_sata_layers_i.phy.gtx_wrap.rxnotintable_dec_out;
wire  [1:0] test_elastic_disperror_in =  dut.sata_top.ahci_sata_layers_i.phy.gtx_wrap.rxdisperr_dec_out;
wire [15:0] test_elastic_data_in =       dut.sata_top.ahci_sata_layers_i.phy.gtx_wrap.rxdata_dec_out;

wire        test_elastic_slow_isaligned_out;
wire  [3:0] test_elastic_slow_charisk_out;
wire  [3:0] test_elastic_slow_notintable_out;
wire  [3:0] test_elastic_slow_disperror_out;
wire [31:0] test_elastic_slow_data_out;
wire        test_elastic_slow_full;
wire        test_elastic_slow_empty;

wire        test_elastic_fast_isaligned_out;
wire  [3:0] test_elastic_fast_charisk_out;
wire  [3:0] test_elastic_fast_notintable_out;
wire  [3:0] test_elastic_fast_disperror_out;
wire [31:0] test_elastic_fast_data_out;
wire        test_elastic_fast_full;
wire        test_elastic_fast_empty;


reg test_elastic_slow_rclk = 0;
reg test_elastic_fast_rclk = 0;

always #(TEST_ELASTIC_PERIOD_SLOW/2) test_elastic_slow_rclk =!test_elastic_slow_rclk;
always #(TEST_ELASTIC_PERIOD_FAST/2) test_elastic_fast_rclk =!test_elastic_fast_rclk;

    elastic1632 #(
        .DEPTH_LOG2(4),
        .OFFSET(5)
    ) elastic1632_slow_i (
        .wclk           (test_elastic_wclk),                // input
        .rclk           (test_elastic_slow_rclk),           // input
        .isaligned_in   (test_elastic_isaligned_in),        // input
        .charisk_in     (test_elastic_charisk_in),          // input[1:0] 
        .notintable_in  (test_elastic_notintable_in),       // input[1:0] 
        .disperror_in   (test_elastic_disperror_in),        // input[1:0] 
        .data_in        (test_elastic_data_in),             // input[15:0] 
        .isaligned_out  (test_elastic_slow_isaligned_out),  // output
        .charisk_out    (test_elastic_slow_charisk_out),    // output[3:0] reg 
        .notintable_out (test_elastic_slow_notintable_out), // output[3:0] reg 
        .disperror_out  (test_elastic_slow_disperror_out),  // output[3:0] reg 
        .data_out       (test_elastic_slow_data_out),       // output[31:0] reg 
        .full           (test_elastic_slow_full),           // output
        .empty          (test_elastic_slow_empty)           // output
    );

    elastic1632 #(
        .DEPTH_LOG2(4),
        .OFFSET(5)
    ) elastic1632_fast_i (
        .wclk           (test_elastic_wclk),                // input
        .rclk           (test_elastic_fast_rclk),           // input
        .isaligned_in   (test_elastic_isaligned_in),        // input
        .charisk_in     (test_elastic_charisk_in),          // input[1:0] 
        .notintable_in  (test_elastic_notintable_in),       // input[1:0] 
        .disperror_in   (test_elastic_disperror_in),        // input[1:0] 
        .data_in        (test_elastic_data_in),             // input[15:0] 
        .isaligned_out  (test_elastic_fast_isaligned_out),  // output
        .charisk_out    (test_elastic_fast_charisk_out),    // output[3:0] reg 
        .notintable_out (test_elastic_fast_notintable_out), // output[3:0] reg 
        .disperror_out  (test_elastic_fast_disperror_out),  // output[3:0] reg 
        .data_out       (test_elastic_fast_data_out),       // output[31:0] reg 
        .full           (test_elastic_fast_full),           // output
        .empty          (test_elastic_fast_empty)           // output
    );





top dut(
    .RXN             (rxn),
    .RXP             (rxp),
    .TXN             (txn),
    .TXP             (txp),
    .EXTCLK_P (EXTCLK_P),
    .EXTCLK_N (EXTCLK_N)
);

assign device_rst = dut.axi_rst;
sata_device dev(
//    .rst      (1'b1), // FOREVER device_rst),
    .rst      (device_rst),
    .RXN      (txn),
    .RXP      (txp),
    .TXN      (rxn),
    .TXP      (rxp),
    .EXTCLK_P (DEV_EXTCLK_P),
    .EXTCLK_N (DEV_EXTCLK_N)
);

// SAXI HP interface

// axi_hp simulation signals
  wire HCLK;
  wire HRST;
  wire [31:0] afi_sim_rd_address;    // output[31:0] 
  wire [ 5:0] afi_sim_rid;           // output[5:0]  SuppressThisWarning VEditor - not used - just view
//  reg         afi_sim_rd_valid;      // input
  wire        afi_sim_rd_valid;      // input
  wire        afi_sim_rd_ready;      // output
//  reg  [63:0] afi_sim_rd_data;       // input[63:0] 
  wire [63:0] afi_sim_rd_data;       // input[63:0] 
  wire [ 2:0] afi_sim_rd_cap;        // output[2:0]  SuppressThisWarning VEditor - not used - just view
  wire [ 3:0] afi_sim_rd_qos;        // output[3:0]  SuppressThisWarning VEditor - not used - just view
  wire  [ 1:0] afi_sim_rd_resp;       // input[1:0] 
//  reg  [ 1:0] afi_sim_rd_resp;       // input[1:0] 

  wire [31:0] afi_sim_wr_address;    // output[31:0]
  wire [ 5:0] afi_sim_wid;           // output[5:0]  SuppressThisWarning VEditor - not used - just view
  wire        afi_sim_wr_valid;      // output
  wire        afi_sim_wr_ready;      // input
//  reg         afi_sim_wr_ready;      // input
  wire [63:0] afi_sim_wr_data;       // output[63:0]
  wire [ 7:0] afi_sim_wr_stb;        // output[7:0]
  wire [ 3:0] afi_sim_bresp_latency; // input[3:0] 
//  reg  [ 3:0] afi_sim_bresp_latency; // input[3:0] 
  wire [ 2:0] afi_sim_wr_cap;        // output[2:0]  SuppressThisWarning VEditor - not used - just view
  wire [ 3:0] afi_sim_wr_qos;        // output[3:0]  SuppressThisWarning VEditor - not used - just view

  assign HCLK = dut.ps7_i.SAXIHP3ACLK; // shortcut name
  assign HRST = dut.sata_top.hrst;  // shortcut name
/*
//  assign HCLK = dut.ps7_i.SAXIHP3ACLK; // shortcut name
// afi loopback
  assign #1 afi_sim_rd_data=  afi_sim_rd_ready?{2'h0,afi_sim_rd_address[31:3],1'h1,  2'h0,afi_sim_rd_address[31:3],1'h0}:64'bx;
  assign #1 afi_sim_rd_valid = afi_sim_rd_ready;
  assign #1 afi_sim_rd_resp = afi_sim_rd_ready?2'b0:2'bx;
  assign #1 afi_sim_wr_ready = afi_sim_wr_valid;
  assign #1 afi_sim_bresp_latency=4'h5; 
*/
// axi_hp register access
  // PS memory mapped registers to read/write over a separate simulation bus running at HCLK, no waits
  reg  [31:0] PS_REG_ADDR;
  reg         PS_REG_WR;
  reg         PS_REG_RD;
  reg         PS_REG_WR1;
  reg         PS_REG_RD1;
  reg  [31:0] PS_REG_DIN;
  wire [31:0] PS_REG_DOUT;
  wire [31:0] PS_REG_DOUT1;
  reg  [31:0] PS_RDATA;  // SuppressThisWarning VEditor - not used - just view
/*  
  reg  [31:0] afi_reg_addr; 
  reg         afi_reg_wr;
  reg         afi_reg_rd;
  reg  [31:0] afi_reg_din;
  wire [31:0] afi_reg_dout;
  reg  [31:0] AFI_REG_RD; // SuppressThisWarning VEditor - not used - just view
*/  
  initial begin
    PS_REG_ADDR <= 'bx;
    PS_REG_WR   <= 0;
    PS_REG_RD   <= 0;
    PS_REG_WR1  <= 0;
    PS_REG_RD1  <= 0;
    PS_REG_DIN  <= 'bx;
    PS_RDATA    <= 'bx;
  end 
  always @ (posedge HCLK) begin
      if      (PS_REG_RD)  PS_RDATA <= PS_REG_DOUT;
      else if (PS_REG_RD1) PS_RDATA <= PS_REG_DOUT1;
  end 

simul_axi_hp_rd #(
        .HP_PORT(3)
    ) simul_axi_hp_rd_i (
        .rst            (HRST), // RST),                            // input
        .aclk           (dut.ps7_i.SAXIHP3ACLK),          // input
        .aresetn        (),                               // output
        .araddr         (dut.ps7_i.SAXIHP3ARADDR[31:0]),  // input[31:0] 
        .arvalid        (dut.ps7_i.SAXIHP3ARVALID),       // input
        .arready        (dut.ps7_i.SAXIHP3ARREADY),       // output
        .arid           (dut.ps7_i.SAXIHP3ARID),          // input[5:0] 
        .arlock         (dut.ps7_i.SAXIHP3ARLOCK),        // input[1:0] 
        .arcache        (dut.ps7_i.SAXIHP3ARCACHE),       // input[3:0] 
        .arprot         (dut.ps7_i.SAXIHP3ARPROT),        // input[2:0] 
        .arlen          (dut.ps7_i.SAXIHP3ARLEN),         // input[3:0] 
        .arsize         (dut.ps7_i.SAXIHP3ARSIZE),        // input[2:0] 
        .arburst        (dut.ps7_i.SAXIHP3ARBURST),       // input[1:0] 
        .arqos          (dut.ps7_i.SAXIHP3ARQOS),         // input[3:0] 
        .rdata          (dut.ps7_i.SAXIHP3RDATA),         // output[63:0] 
        .rvalid         (dut.ps7_i.SAXIHP3RVALID),        // output
        .rready         (dut.ps7_i.SAXIHP3RREADY),        // input
        .rid            (dut.ps7_i.SAXIHP3RID),           // output[5:0] 
        .rlast          (dut.ps7_i.SAXIHP3RLAST),         // output
        .rresp          (dut.ps7_i.SAXIHP3RRESP),         // output[1:0] 
        .rcount         (dut.ps7_i.SAXIHP3RCOUNT),        // output[7:0] 
        .racount        (dut.ps7_i.SAXIHP3RACOUNT),       // output[2:0] 
        .rdissuecap1en  (dut.ps7_i.SAXIHP3RDISSUECAP1EN), // input
        .sim_rd_address (afi_sim_rd_address),             // output[31:0] 
        .sim_rid        (afi_sim_rid),                    // output[5:0] 
        .sim_rd_valid   (afi_sim_rd_valid),               // input
        .sim_rd_ready   (afi_sim_rd_ready),               // output
        .sim_rd_data    (afi_sim_rd_data),                // input[63:0] 
        .sim_rd_cap     (afi_sim_rd_cap),                 // output[2:0] 
        .sim_rd_qos     (afi_sim_rd_qos),                 // output[3:0] 
        .sim_rd_resp    (afi_sim_rd_resp),                // input[1:0] 
        .reg_addr       (PS_REG_ADDR),                    // input[31:0] 
        .reg_wr         (PS_REG_WR),                      // input
        .reg_rd         (PS_REG_RD),                      // input
        .reg_din        (PS_REG_DIN),                     // input[31:0] 
        .reg_dout       (PS_REG_DOUT)                     // output[31:0] 
    );

simul_axi_hp_wr #(
        .HP_PORT(3)
    ) simul_axi_hp_wr_i (
        .rst            (HRST), // RST), // input
        .aclk           (dut.ps7_i.SAXIHP3ACLK),          // input
        .aresetn        (),                               // output
        .awaddr         (dut.ps7_i.SAXIHP3AWADDR),        // input[31:0] 
        .awvalid        (dut.ps7_i.SAXIHP3AWVALID),       // input
        .awready        (dut.ps7_i.SAXIHP3AWREADY),       // output
        .awid           (dut.ps7_i.SAXIHP3AWID),          // input[5:0] 
        .awlock         (dut.ps7_i.SAXIHP3AWLOCK),        // input[1:0] 
        .awcache        (dut.ps7_i.SAXIHP3AWCACHE),       // input[3:0] 
        .awprot         (dut.ps7_i.SAXIHP3AWPROT),        // input[2:0] 
        .awlen          (dut.ps7_i.SAXIHP3AWLEN),         // input[3:0] 
        .awsize         (dut.ps7_i.SAXIHP3AWSIZE),        // input[2:0] 
        .awburst        (dut.ps7_i.SAXIHP3AWBURST),       // input[1:0] 
        .awqos          (dut.ps7_i.SAXIHP3AWQOS),         // input[3:0] 
        .wdata          (dut.ps7_i.SAXIHP3WDATA),         // input[63:0] 
        .wvalid         (dut.ps7_i.SAXIHP3WVALID),        // input
        .wready         (dut.ps7_i.SAXIHP3WREADY),        // output
        .wid            (dut.ps7_i.SAXIHP3WID),           // input[5:0] 
        .wlast          (dut.ps7_i.SAXIHP3WLAST),         // input
        .wstrb          (dut.ps7_i.SAXIHP3WSTRB),         // input[7:0] 
        .bvalid         (dut.ps7_i.SAXIHP3BVALID),        // output
        .bready         (dut.ps7_i.SAXIHP3BREADY),        // input
        .bid            (dut.ps7_i.SAXIHP3BID),           // output[5:0] 
        .bresp          (dut.ps7_i.SAXIHP3BRESP),         // output[1:0] 
        .wcount         (dut.ps7_i.SAXIHP3WCOUNT),        // output[7:0] 
        .wacount        (dut.ps7_i.SAXIHP3WACOUNT),       // output[5:0] 
        .wrissuecap1en  (dut.ps7_i.SAXIHP3WRISSUECAP1EN), // input
        .sim_wr_address (afi_sim_wr_address),             // output[31:0] 
        .sim_wid        (afi_sim_wid),                    // output[5:0] 
        .sim_wr_valid   (afi_sim_wr_valid),               // output
        .sim_wr_ready   (afi_sim_wr_ready),               // input
        .sim_wr_data    (afi_sim_wr_data),                // output[63:0] 
        .sim_wr_stb     (afi_sim_wr_stb),                 // output[7:0] 
        .sim_bresp_latency(afi_sim_bresp_latency),        // input[3:0] 
        .sim_wr_cap     (afi_sim_wr_cap),                 // output[2:0] 
        .sim_wr_qos     (afi_sim_wr_qos),                 // output[3:0] 
        .reg_addr       (PS_REG_ADDR),                    // input[31:0] 
        .reg_wr         (PS_REG_WR1),                      // input
        .reg_rd         (PS_REG_RD1),                      // input
        .reg_din        (PS_REG_DIN),                     // input[31:0] 
        .reg_dout       (PS_REG_DOUT1)                     // output[31:0] 
    );

    
    //  wire [ 3:0] SIMUL_ADD_ADDR; 
    always @ (posedge CLK) begin
        if      (RST) SIMUL_AXI_FULL <=0;
        else if (rstb) SIMUL_AXI_FULL <=1;
        
        if (RST) begin
              NUM_WORDS_READ <= 0;
        end else if (rstb) begin
            NUM_WORDS_READ <= NUM_WORDS_READ + 1; 
        end    
        if (rstb) begin
            SIMUL_AXI_ADDR <= SIMUL_AXI_ADDR_W;
            SIMUL_AXI_READ <= rdata;
`ifdef DEBUG_RD_DATA
        $display (" Read data (addr:data): 0x%x:0x%x @%t",SIMUL_AXI_ADDR_W,rdata,$time);
`endif  
            
        end 
        
    end

//tasks
`include "includes/x393_tasks01.vh"     // SuppressThisWarning VEditor - partially used
//`include "includes/x393_tasks_afi.vh"   // SuppressThisWarning VEditor - partially used

/*
 * Monitor maxi bus read data. 
 * No burst assumed, so we're interested only in 3 signals to monitor on.
 * Every time something is on a bus, data and id of a transaction are pushed into a fifo
 * Fifo can be read by maxiMonitorPop function. Check if fifo is empty by calling maxiMonitorIsEmpty()
 */
// path to these signals
wire    [31:0] maxi_monitor_rdata;
wire    [11:0] maxi_monitor_rid;
wire           maxi_monitor_rvalid;
assign maxi_monitor_rdata   = dut.ps7_i.MAXIGP1RDATA;
assign maxi_monitor_rid     = dut.ps7_i.MAXIGP1RID;
assign maxi_monitor_rvalid  = dut.ps7_i.MAXIGP1RVALID;

localparam maxi_monitor_fifo_size = 2049;
reg [43:0] maxi_monitor_fifo [maxi_monitor_fifo_size - 1:0];
integer maxi_monitor_raddr  = 0;
integer maxi_monitor_waddr  = 0;
reg     maxi_monitor_fifo_empty = 1;

function maxiMonitorIsEmpty( // SuppressThisWarning VEditor - it's ok
    input dummy // SuppressThisWarning VEditor - it's ok
    );
    begin
        maxiMonitorIsEmpty = maxi_monitor_fifo_empty;
    end
endfunction

task maxiMonitorPop;
    output reg [31:0] data;
    output integer id;
    begin
        if ((maxi_monitor_waddr == maxi_monitor_raddr) && maxi_monitor_fifo_empty) begin
            $display("[Testbench] maxiMonitorPop: Trying to pop from an empty fifo");
            $finish;
        end
        data = maxi_monitor_fifo[maxi_monitor_raddr][31:0]; // RDATA
        id = maxi_monitor_fifo[maxi_monitor_raddr][43:32]; // RID // SuppressThisWarning VEditor - it's ok
        maxi_monitor_raddr = (maxi_monitor_raddr + 1) % maxi_monitor_fifo_size;
        if (maxi_monitor_waddr == maxi_monitor_raddr) begin
            maxi_monitor_fifo_empty = 1;
        end
    end
endtask

task maxiMonitorPush;
    input  [31:0] data;
    input  [11:0] id;
    begin
        if (maxi_monitor_raddr == (maxi_monitor_waddr + 1)) begin
            $display("[Testbench] maxiMonitorPush: trying to push to a full fifo");
            TESTBENCH_TITLE = "trying to push to a full fifo";
            $display("[Testbench] maxiMonitorPush %s = %h, id = %h @%t", TESTBENCH_TITLE, $time);
            $finish;
        end
        maxi_monitor_fifo[maxi_monitor_waddr][31:0]  = data;
        maxi_monitor_fifo[maxi_monitor_waddr][43:32] = id;
        maxi_monitor_fifo_empty = 1'b0;
//        $display("[Testbench] MAXI: Got data = %h, id = %h", data, id);
        TESTBENCH_TITLE = "Got data";
        TESTBENCH_DATA =  data;
        TESTBENCH_ID =    id;
        $display("[Testbench] MAXI   %s = %h, id = %h @%t", TESTBENCH_TITLE, TESTBENCH_DATA, TESTBENCH_ID, $time);
        
        
        //[Testbench] MAXI:   %
        maxi_monitor_waddr = (maxi_monitor_waddr + 1) % maxi_monitor_fifo_size;
    end
endtask

initial forever @ (posedge CLK) begin
    if (~RST) begin
        if (maxi_monitor_rvalid) begin
            maxiMonitorPush(maxi_monitor_rdata, maxi_monitor_rid);
        end
    end
end

//always #3.333 begin
always #(DEVICE_CLK_PERIOD/2) begin
    EXTCLK_P = ~EXTCLK_P;
    EXTCLK_N = ~EXTCLK_N;
end

always #(HOST_CLK_PERIOD/2) begin
    DEV_EXTCLK_P = ~DEV_EXTCLK_P;
    DEV_EXTCLK_N = ~DEV_EXTCLK_N;
end
/*
// MAXI clock
always #10
begin
    CLK = ~CLK;
end
*/
initial CLK = 0;
always #(CLKIN_PERIOD/2) CLK = ~CLK;
//always #(10) CLK = ~CLK;

// Simulation 
`include "includes/ahci_localparams.vh" // SuppressThisWarning VEditor - many unused defines
`include "includes/fis_types.vh"       // SuppressThisWarning VEditor - some unused defines
localparam MAXIGP1 = 32'h80000000; // Start of the MAXIGP1 address range (use ahci_localparams.vh offsets)
localparam DRP_OFFSET = 'hfec;
localparam DEBUG_OFFSET = 'hff0;


    task maxigp1_write_single; // address in bytes, not words
        input [31:0] address;
        input [31:0] data;
        begin
            axi_write_single(address + MAXIGP1, data);
        end
    endtask

    task maxigp1_writep; // address in bytes, not words
        input [31:0] address;
        input [31:0] data;
        begin
            axi_write_single(address + MAXIGP1, data);
            $display ("%x <- %x @ %t",address + MAXIGP1, data,$time);
        end
    endtask

    task drp_write;
        input  [14:0] addr;
        input  [15:0] data;
        begin
            $display ("[DRP]: %x <- %x @ %t",addr, data,$time);
            maxigp1_write_single (DRP_OFFSET, {1'b1, addr, data});
            maxigp1_read (DRP_OFFSET);
            while (!registered_rdata[31]) maxigp1_read (DRP_OFFSET);
        end
    endtask

    task drp_read;
        input      [14:0] addr;
        output reg [15:0] data;
        begin
            maxigp1_write_single (DRP_OFFSET, {1'b0, addr, 16'b0});
            maxigp1_read (DRP_OFFSET);
            while (!registered_rdata[31]) maxigp1_read (DRP_OFFSET);
            data = registered_rdata[15:0];
            $display ("[DRP]: %x -> %x @ %t",addr, data,$time);
        end
    endtask

    task read_sipo_meas;
        input      [31:0] mask;
        input      [15:0] duration;
        output reg [14:0] early_count;
        output reg [14:0] late_count;
        reg               running;
//        wire       [15:0] data;
        begin
            drp_write ('h200, mask[15:0]);
            drp_write ('h201, mask[31:16]);
            drp_write ('h208, duration);
            drp_read  ('h209, {running,early_count});
            drp_read  ('h209, {running,early_count});
            while (running) drp_read ('h209,{running, early_count});
            drp_read  ('h20a, {running, late_count});             
            $display ("[DRP] read_sipo_meas(): early:%x/%x, late: %x/%x @ %t",early_count,duration,late_count,duration,$time);
        end
    endtask

    task maxigp1_read;
    input [31:0] address;
        begin
            read_and_wait (address + MAXIGP1);
        end
    endtask

    task maxigp1_print;
        input [31:0] address;
        input [319:0] msg;
        begin
            read_and_wait (address + MAXIGP1);
            $display ("%x -> %x (%s)@ %t",address + MAXIGP1, registered_rdata,msg,$time);
        end
    endtask

localparam CLB_OFFS32 =        'h200; //  # In the second half of the register space (0x800..0xbff - 1KB)
localparam HBA_OFFS32 =         0;
localparam HBA_PORT0_OFFS32  = 'h40;
localparam PXSIG_OFFS32 = HBA_OFFS32 + HBA_PORT0_OFFS32 + 'h9; 
localparam PXTFD_OFFS32 = HBA_OFFS32 + HBA_PORT0_OFFS32 + 'h8;

localparam SYS_MEM_START = 32'h3fffc000; // 16384 bytes (4096 DWORDs of teh system memory for R/W over AXI_HP) 
localparam SYS_MEM_SIZE =  16384; // bytes - size of system memory 
// realtive to the system memory area
localparam COMMAND_TABLE = 32'h3f00; // 256 bytes for a command table in the system memory
localparam IDENTIFY_BUF =  32'h3d00; // 512 bytes for a command table in the system memory
localparam PRD_OFFSET = 'h80;        // start of PRD table - 128-th byte in command table
localparam ATA_IDFY =     'hec; // Identify command
localparam ATA_WDMA =     'hca; // Write to device in DMA mode
localparam ATA_WBUF_PIO = 'he8; // Write 512 bytes to device buffer in PIO mode   @SuppressThisWarning VEditor - not yet used
localparam ATA_WBUF_DMA = 'heb; // Write 512 bytes to device buffer in DMA mode   @SuppressThisWarning VEditor - not yet used
localparam ATA_RDMA =     'hc8; // Read from device in DMA mode                   @SuppressThisWarning VEditor - not yet used
localparam ATA_RBUF_PIO = 'he4; // Read  512 bytes from device buffer in PIO mode @SuppressThisWarning VEditor - not yet used
localparam ATA_RBUF_DMA = 'he9; // Read  512 bytes from device buffer in DMA mode @SuppressThisWarning VEditor - not yet used

    reg  [31:0] sysmem[0:4095]; 

    // connect system memory ty AXI_NP RD and WR channels
//  assign HCLK = dut.ps7_i.SAXIHP3ACLK; // shortcut name
// afi loopback
    // This is for no-delay memory
//    assign #1 afi_sim_rd_valid = afi_sim_rd_ready;
    // Make long delay for the first memory read, zero - for the next
    reg afi_sim_rd_ready_r;
    integer read_system_delay;
    localparam SYSTEM_MEMORY_READ_LATENCY = 10; // HCLK cycles
    always @ (posedge HCLK) begin
        if      (!afi_sim_rd_ready)      read_system_delay <= SYSTEM_MEMORY_READ_LATENCY;
        else if (read_system_delay != 0) read_system_delay <= read_system_delay - 1;
        
        afi_sim_rd_ready_r <= afi_sim_rd_ready && (read_system_delay == 0); 
    end
    assign #1 afi_sim_rd_valid = afi_sim_rd_ready && afi_sim_rd_ready_r;
    
    
    
    assign #1 afi_sim_rd_resp = afi_sim_rd_ready?2'b0:2'bx;
    assign #1 afi_sim_wr_ready = 1; // afi_sim_wr_valid;
    assign #1 afi_sim_bresp_latency=4'h5; 
//  assign #1 afi_sim_rd_data=  afi_sim_rd_ready?{2'h0,afi_sim_rd_address[31:3],1'h1,  2'h0,afi_sim_rd_address[31:3],1'h0}:64'bx;
    wire MEM_SEL = (afi_sim_rd_address[31:3] >= (SYS_MEM_START >> 3)) && (afi_sim_rd_address[31:3] < ((SYS_MEM_START + SYS_MEM_SIZE) >> 3));
    wire [31:2] sysmem_dworda_rd = {(afi_sim_rd_address[31:3] - (SYS_MEM_START >> 3)),1'b0};
    assign #1 afi_sim_rd_data=  afi_sim_rd_ready?(MEM_SEL? {sysmem[sysmem_dworda_rd[31:2]+1], sysmem[sysmem_dworda_rd[31:2]]} :64'bx):64'bz;
    wire [31:2] sysmem_dworda_wr = {(afi_sim_wr_address[31:3] - (SYS_MEM_START >> 3)),1'b0};
    wire [31:0] sysmem_di_low =  ({{8{~afi_sim_wr_stb[3]}},{8{~afi_sim_wr_stb[2]}},{8{~afi_sim_wr_stb[1]}},{8{~afi_sim_wr_stb[0]}}} &
                                (sysmem[sysmem_dworda_wr[31:2]] ^ afi_sim_wr_data[31:0])) ^ afi_sim_wr_data[31:0];
    
    wire [31:0] sysmem_di_high = ({{8{~afi_sim_wr_stb[7]}},{8{~afi_sim_wr_stb[6]}},{8{~afi_sim_wr_stb[5]}},{8{~afi_sim_wr_stb[4]}}} &
                                (sysmem[sysmem_dworda_wr[31:2]+1] ^ afi_sim_wr_data[63:32])) ^ afi_sim_wr_data[63:32];
    always @ (posedge HCLK) if (afi_sim_wr_ready && afi_sim_wr_valid) begin
        if (|afi_sim_wr_stb[3:0]) sysmem[sysmem_dworda_wr[31:2]    ] <= sysmem_di_low;
        if (|afi_sim_wr_stb[7:4]) sysmem[sysmem_dworda_wr[31:2] + 1] <= sysmem_di_high;
    end
    
    task sysmem_print;
        input integer start_w;  // start word
        input integer len_w;    // number of words
        integer i,j;
        reg [15:0] data[0:7];
        reg [31:0] d;
        begin
            for (i = 0; i < len_w; i = i + 8) begin
                for (j = 0; j < 8; j = j+1) begin
                    d = sysmem[(start_w + i + j) >> 1];
//                    $display ("%h: %h", (start_w + i ) >> 1, d);
                    data[j] = ((start_w + i + j) & 1) ? d[31:16] : d [15:0]; 
                end
                $display("%h: %h %h %h %h %h %h %h %h ",start_w + i, data[0],  data[1], data[2], data[3], data[4], data[5], data[6], data[7]);
            end 
        end
    endtask
    
    
    task setup_pio_read_identify_command_simple;
        input integer data_len;
        input integer prd_int; // [0] - first prd interrupt, ... [31] - 31-st

        integer i;
        begin
            // clear system memory for command
            for (i = 0; i < 64; i = i+1)  sysmem[(COMMAND_TABLE >> 2) + i] = 0;
            // fill ATA command 
            sysmem[(COMMAND_TABLE >> 2) + 0] = FIS_H2DR |         // FIS type - H2D register (0x27)
                                               ('h80 << 8) |      // set C = 1
                                               (ATA_IDFY << 16) | // Command = 0xEC (IDFY)
                                              ( 0 << 24);        // features = 0 ?
            // All other 4 DWORDs are 0 for this command
            // Set PRDT (single item) TODO: later check multiple small ones
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) + 0] = SYS_MEM_START + IDENTIFY_BUF;
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) + 3] = (prd_int[0] << 31) | (data_len-1); // 512 bytes in this PRDT
            // Setup command header
            maxigp1_writep       ((CLB_OFFS32 + 0) << 2,     (5 <<  0) | // 'CFL' - number of DWORDs in thes CFIS
                                                         (0 <<  5) | // 'A' Not ATAPI
                                                         (0 <<  6) | // 'W' Not write to device
                                                         (1 <<  7) | // 'P' Prefetchable = 1
                                                         (0 <<  8) | // 'R' Not a Reset
                                                         (0 <<  9) | // 'B' Not a BIST
//                                                         (0 << 10) | // 'C' Do not clear BSY/CI after transmitting this command
                                                         (1 << 10) | // 'C' Do clear BSY/CI after transmitting this command
                                                         (1 << 16)); // 'PRDTL' - number of PRDT entries (just one)
            maxigp1_writep       ((CLB_OFFS32 +2 ) << 2, (SYS_MEM_START + COMMAND_TABLE) & 32'hffffffc0); // 'CTBA' - Command table base address
            // Set Command Issued
            maxigp1_writep       (HBA_PORT__PxCI__CI__ADDR << 2, 1); // 'PxCI' - Set 'Command issue' for slot 0 (the only one)
            // relax and enjoy
        end
    endtask

    task setup_pio_read_identify_command_shifted;
        input integer prd_int; // [0] - first prd interrupt, ... [31] - 31-st
        integer i;
        begin
            // clear system memory for command
            for (i = 0; i < 64; i = i+1)  sysmem[(COMMAND_TABLE >> 2) + i] = 0;
            // fill ATA command 
            sysmem[(COMMAND_TABLE >> 2) + 0] = FIS_H2DR |         // FIS type - H2D register (0x27)
                                               ('h80 << 8) |      // set C = 1
                                               (ATA_IDFY << 16) | // Command = 0xEC (IDFY)
                                              ( 0 << 24);        // features = 0 ?
            // All other 4 DWORDs are 0 for this command
            // Set PRDT (single item) TODO: later check multiple small ones
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) + 0] = SYS_MEM_START + IDENTIFY_BUF + 2; // shift by 2 bytes
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) + 3] = (prd_int[0] << 32) | 511; // 512 bytes in this PRDT
            // Setup command header
            maxigp1_writep       ((CLB_OFFS32 + 0) << 2,     (5 <<  0) | // 'CFL' - number of DWORDs in thes CFIS
                                                         (0 <<  5) | // 'A' Not ATAPI
                                                         (0 <<  6) | // 'W' Not write to device
                                                         (1 <<  7) | // 'P' Prefetchable = 1
                                                         (0 <<  8) | // 'R' Not a Reset
                                                         (0 <<  9) | // 'B' Not a BIST
//                                                         (0 << 10) | // 'C' Do not clear BSY/CI after transmitting this command
                                                         (1 << 10) | // 'C' Do clear BSY/CI after transmitting this command
                                                         (1 << 16)); // 'PRDTL' - number of PRDT entries (just one)
            maxigp1_writep       ((CLB_OFFS32 +2 ) << 2, (SYS_MEM_START + COMMAND_TABLE) & 32'hffffffc0); // 'CTBA' - Command table base address
            // Set Command Issued
            maxigp1_writep       (HBA_PORT__PxCI__CI__ADDR << 2, 1); // 'PxCI' - Set 'Command issue' for slot 0 (the only one)
            // relax and enjoy
        end
    endtask

    task setup_pio_read_identify_command_multi4;
        input integer prd_int; // [0] - first prd interrupt, ... [31] - 31-st
        input integer nw1; // first segment lengtth (in words)
        input integer nw2; // second segment lengtth (in words)
        input integer nw3; // third segment lengtth (in words)
        
        integer nw4;
        integer i;
        
        begin
            nw4 = 256 - nw1 - nw2 - nw3; // total 512 bytes, 256 words
            // clear system memory for command
            for (i = 0; i < 64; i = i+1)  sysmem[(COMMAND_TABLE >> 2) + i] = 0;
            // fill ATA command 
            sysmem[(COMMAND_TABLE >> 2) + 0] = FIS_H2DR |         // FIS type - H2D register (0x27)
                                               ('h80 << 8) |      // set C = 1
                                               (ATA_IDFY << 16) | // Command = 0xEC (IDFY)
                                              ( 0 << 24);        // features = 0 ?
            // All other 4 DWORDs are 0 for this command
            // Set PRDT (four items)
            // PRDT #1
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) +  0] = SYS_MEM_START + IDENTIFY_BUF; // not shifted
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) +  3] = (prd_int[0] << 31) | (2 * nw1 - 1); // 2 * nw1 bytes
            // PRDT #2
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) +  4] = SYS_MEM_START + IDENTIFY_BUF + (2 * nw1);
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) +  7] = (prd_int[0] << 31) | (2 * nw2 - 1); // 2 * nw2 bytes
            // PRDT #3
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) +  8] = SYS_MEM_START + IDENTIFY_BUF + (2 * nw1) + (2 * nw2);
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) + 11] = (prd_int[0] << 31) | (2 * nw3 - 1); // 2 * nw3 bytes
            // PRDT #4
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) + 12] = SYS_MEM_START + IDENTIFY_BUF + (2 * nw1) + (2 * nw2) + (2 * nw3);
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) + 15] = (prd_int[0] << 31) | (2 * nw4 - 1); // 2 * nw4 bytes
            
            // Setup command header
            maxigp1_writep       ((CLB_OFFS32 + 0) << 2,     (5 <<  0) | // 'CFL' - number of DWORDs in thes CFIS
                                                         (0 <<  5) | // 'A' Not ATAPI
                                                         (0 <<  6) | // 'W' Not write to device
                                                         (1 <<  7) | // 'P' Prefetchable = 1
                                                         (0 <<  8) | // 'R' Not a Reset
                                                         (0 <<  9) | // 'B' Not a BIST
//                                                         (0 << 10) | // 'C' Do not clear BSY/CI after transmitting this command
                                                         (1 << 10) | // 'C' Do clear BSY/CI after transmitting this command
                                                         (4 << 16)); // 'PRDTL' - number of PRDT entries (4)
            maxigp1_writep       ((CLB_OFFS32 +2 ) << 2, (SYS_MEM_START + COMMAND_TABLE) & 32'hffffffc0); // 'CTBA' - Command table base address
            // Set Command Issued
            maxigp1_writep       (HBA_PORT__PxCI__CI__ADDR << 2, 1); // 'PxCI' - Set 'Command issue' for slot 0 (the only one)
            // relax and enjoy
        end
    endtask
    
    task setup_dma_write_identify_command_multi4; // Write DMA, use data received during read identify
        input integer lba;
        input integer prd_int; // [0] - first prd interrupt, ... [31] - 31-st
        input integer nw1; // first segment lengtth (in words)
        input integer nw2; // second segment lengtth (in words)
        input integer nw3; // third segment lengtth (in words)
        
        integer nw4;
        integer i;
        
        begin
            nw4 = 256 - nw1 - nw2 - nw3; // total 512 bytes, 256 words
            // clear system memory for command
            for (i = 0; i < 64; i = i+1)  sysmem[(COMMAND_TABLE >> 2) + i] = 0;
            // fill ATA command 
            sysmem[(COMMAND_TABLE >> 2) + 0] = FIS_H2DR |         // FIS type - H2D register (0x27)
                                               ('h80 << 8) |      // set C = 1
                                               (ATA_WDMA << 16) | // Command = 0xCA
                                              ( 0 << 24);         // features = 0 ?
            sysmem[(COMMAND_TABLE >> 2) + 1] = lba & 'hffffff;    // 24 LSBs of LBA (48-bit require different ATA command)
            sysmem[(COMMAND_TABLE >> 2) + 3] = 1;                 // 1 logical sector (0 means 256)
            // All other DWORDs are 0 for this command
            // Set PRDT (four items)
            // PRDT #1
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) +  0] = SYS_MEM_START + IDENTIFY_BUF; // not shifted
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) +  3] = (prd_int[0] << 31) | (2 * nw1 - 1); // 2 * nw1 bytes
            // PRDT #2
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) +  4] = SYS_MEM_START + IDENTIFY_BUF + (2 * nw1);
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) +  7] = (prd_int[0] << 31) | (2 * nw2 - 1); // 2 * nw2 bytes
            // PRDT #3
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) +  8] = SYS_MEM_START + IDENTIFY_BUF + (2 * nw1) + (2 * nw2);
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) + 11] = (prd_int[0] << 31) | (2 * nw3 - 1); // 2 * nw3 bytes
            // PRDT #4
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) + 12] = SYS_MEM_START + IDENTIFY_BUF + (2 * nw1) + (2 * nw2) + (2 * nw3);
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) + 15] = (prd_int[0] << 31) | (2 * nw4 - 1); // 2 * nw4 bytes
            
            // Setup command header
            maxigp1_writep       ((CLB_OFFS32 + 0) << 2,     (5 <<  0) | // 'CFL' - number of DWORDs in thes CFIS
                                                         (0 <<  5) | // 'A' Not ATAPI
                                                         (1 <<  6) | // 'W' Is write to device
                                                         (1 <<  7) | // 'P' Prefetchable = 1
                                                         (0 <<  8) | // 'R' Not a Reset
                                                         (0 <<  9) | // 'B' Not a BIST
//                                                         (0 << 10) | // 'C' Do not clear BSY/CI after transmitting this command
                                                         (1 << 10) | // 'C' Do clear BSY/CI after transmitting this command
                                                         (4 << 16)); // 'PRDTL' - number of PRDT entries (4)
            maxigp1_writep       ((CLB_OFFS32 +2 ) << 2, (SYS_MEM_START + COMMAND_TABLE) & 32'hffffffc0); // 'CTBA' - Command table base address
            // Set Command Issued
            maxigp1_writep       (HBA_PORT__PxCI__CI__ADDR << 2, 1); // 'PxCI' - Set 'Command issue' for slot 0 (the only one)
            // relax and enjoy
        end
    endtask
    
    task setup_dma_write_identify_command_simple; // Write DMA, use data received during read identify
        input integer lba;
        input integer prd_int; // [0] - first prd interrupt, ... [31] - 31-st
        integer i;
        
        begin
            // clear system memory for command
            for (i = 0; i < 64; i = i+1)  sysmem[(COMMAND_TABLE >> 2) + i] = 0;
            // fill ATA command 
            sysmem[(COMMAND_TABLE >> 2) + 0] = FIS_H2DR |         // FIS type - H2D register (0x27)
                                               ('h80 << 8) |      // set C = 1
                                               (ATA_WDMA << 16) | // Command = 0xCA
                                              ( 0 << 24);         // features = 0 ?
            sysmem[(COMMAND_TABLE >> 2) + 1] = lba & 'hffffff;    // 24 LSBs of LBA (48-bit require different ATA command)
            sysmem[(COMMAND_TABLE >> 2) + 3] = 1;                 // 1 logical sector (0 means 256)
            // All other DWORDs are 0 for this command
            // Set PRDT (four items)
            // PRDT #1
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) +  0] = SYS_MEM_START + IDENTIFY_BUF; // not shifted
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) +  3] = (prd_int[0] << 31) | (512 - 1); // 512 bytes in this PRDT
            
            // Setup command header
            maxigp1_writep       ((CLB_OFFS32 + 0) << 2,     (5 <<  0) | // 'CFL' - number of DWORDs in thes CFIS
                                                         (0 <<  5) | // 'A' Not ATAPI
                                                         (1 <<  6) | // 'W' Is write to device
                                                         (1 <<  7) | // 'P' Prefetchable = 1
                                                         (0 <<  8) | // 'R' Not a Reset
                                                         (0 <<  9) | // 'B' Not a BIST
//                                                         (0 << 10) | // 'C' Do not clear BSY/CI after transmitting this command
                                                         (1 << 10) | // 'C' Do clear BSY/CI after transmitting this command
                                                         (1 << 16)); // 'PRDTL' - number of PRDT entries (1)
            maxigp1_writep       ((CLB_OFFS32 +2 ) << 2, (SYS_MEM_START + COMMAND_TABLE) & 32'hffffffc0); // 'CTBA' - Command table base address
            // Set Command Issued
            maxigp1_writep       (HBA_PORT__PxCI__CI__ADDR << 2, 1); // 'PxCI' - Set 'Command issue' for slot 0 (the only one)
            // relax and enjoy
        end
    endtask
    
    
reg [15:0] drp_read_data;    
reg [14:0] early_count;
reg [14:0] late_count;

initial begin //Host
    NUM_WORDS_EXPECTED =0;
    wait (!RST);
//reg [639:0] TESTBENCH_TITLE = "RESET"; // to show human-readable state in the GTKWave
    TESTBENCH_TITLE = "NO_RESET";
    $display("[Testbench]:       %s @%t", TESTBENCH_TITLE, $time);
    repeat (10) @ (posedge CLK);
    axi_set_rd_lag(0);
    axi_set_b_lag(0);
    
    //simulate DRP write/read
    // disable waiting for phase aligned:
//  drp_write ('h20b, 'h400); // no-bypass, clock align
    drp_write ('h20b, 'h401); // bypass, clock align

    drp_write ('h10, 'h1234);
    drp_write ('h11, 'h2345);
    drp_write ('h12, 'h3456);

    drp_read  ('h10, drp_read_data);
    drp_read  ('h11, drp_read_data);
    drp_read  ('h12, drp_read_data);
    
    drp_read  ('h20b, drp_read_data);

    maxigp1_writep       (PXSIG_OFFS32   << 2, 'h12345678); // 
    maxigp1_writep       (PXTFD_OFFS32   << 2, 'h87654321); // 
    maxigp1_writep       (CLB_OFFS32     << 2, 'h12345678); // 
    maxigp1_writep       ((CLB_OFFS32+1) << 2, 'h87654321); // 


    maxigp1_print        (PXSIG_OFFS32 << 2,"PXSIG_OFFS32"); // OK to read wrong - it is RO with default 'hffffffff
    maxigp1_print        (PXTFD_OFFS32 << 2,"PXTFD_OFFS32"); // OK to read wrong - it is RO with default 0
    maxigp1_print        (CLB_OFFS32     << 2,"CLB_OFFS32"); // 
    maxigp1_print        ((CLB_OFFS32+1) << 2,"CLB_OFFS32+1"); // 



    
    maxigp1_print        (PCI_Header__CAP__CAP__ADDR << 2,"PCI_Header__CAP__CAP__ADDR");
    maxigp1_print        (GHC__PI__PI__ADDR << 2,"GHC__PI__PI__ADDR");
    maxigp1_print        (HBA_PORT__PxCMD__ICC__ADDR << 2,"HBA_PORT__PxCMD__ICC__ADDR");
    maxigp1_print        (GHC__GHC__IE__ADDR << 2,"GHC__GHC__IE__ADDR");
    maxigp1_writep       (GHC__GHC__IE__ADDR << 2, GHC__GHC__IE__MASK); // enable interrupts (global)
    maxigp1_print        (HBA_PORT__PxIE__CPDE__ADDR << 2,"HBA_PORT__PxIE__CPDE__ADDR");
//    maxigp1_writep       (HBA_PORT__PxIE__CPDE__ADDR << 2, ~0); // allow all interrupts
    maxigp1_writep       (HBA_PORT__PxIE__CPDE__ADDR << 2, HBA_PORT__PxIE__DHRE__MASK); // =='h1: allow DHRS only interrupts (D2HR received (signature)
    maxigp1_print        (GHC__GHC__IE__ADDR << 2,"GHC__GHC__IE__ADDR");
    maxigp1_print        (HBA_PORT__PxIE__CPDE__ADDR << 2,"HBA_PORT__PxIE__CPDE__ADDR");
    
    maxigp1_print        (PXSIG_OFFS32 << 2,"PXSIG_OFFS32");
    maxigp1_print        (PXTFD_OFFS32 << 2,"PXTFD_OFFS32");
    
    
    TESTBENCH_TITLE = "Waiting D2H IRQ";
    $display("[Testbench]:       %s @%t", TESTBENCH_TITLE, $time);
    wait (IRQ);
    TESTBENCH_TITLE = "Got D2H IRQ";
    $display("[Testbench]:       %s @%t", TESTBENCH_TITLE, $time);
    
    
    maxigp1_print        (DEBUG_OFFSET +  0, "DEBUG0");
    maxigp1_print        (DEBUG_OFFSET +  4, "DEBUG1");
    maxigp1_print        (DEBUG_OFFSET +  8 ,"DEBUG2");
    maxigp1_print        (DEBUG_OFFSET + 12, "DEBUG3");
    
    read_sipo_meas ('hfffff, 256,  early_count, late_count);
    read_sipo_meas ('h00001, 256,  early_count, late_count);


    drp_write ('h20b, 'h8401); // bypass, clock align and invert xclk
    
    
    maxigp1_print        (GHC__IS__IPS__ADDR << 2,"GHC__IS__IPS__ADDR"); // Should be 1 (port 0)
    maxigp1_writep       (GHC__IS__IPS__ADDR << 2, 1); // clear that interrupt
    maxigp1_print        (GHC__IS__IPS__ADDR << 2,"GHC__IS__IPS__ADDR"); // Now it should be 0
    
    maxigp1_print        (HBA_PORT__PxIS__DHRS__ADDR << 2,"HBA_PORT__PxIS__DHRS__ADDR"); // It should be 400041 - DHR inerrupt (and others)
//    maxigp1_writep       (HBA_PORT__PxIS__DHRS__ADDR << 2, HBA_PORT__PxIS__DHRS__MASK); // clear that interrupt
    maxigp1_writep       (HBA_PORT__PxIS__DHRS__ADDR << 2, ~0); // clear all interrupt
    maxigp1_print        (HBA_PORT__PxIS__DHRS__ADDR << 2,"HBA_PORT__PxIS__DHRS__ADDR"); // Now it should be 0400040 (DHR cleared)
    maxigp1_print        (HBA_PORT__PxSERR__DIAG__X__ADDR << 2,"HBA_PORT__PxSERR"); //
    maxigp1_writep       (HBA_PORT__PxSERR__DIAG__X__ADDR << 2, ~0); // clear all errors
    maxigp1_print        (HBA_PORT__PxIS__DHRS__ADDR << 2,     "cleared all i/e: HBA_PORT__PxIS__DHRS__ADDR"); //
    maxigp1_print        (HBA_PORT__PxSERR__DIAG__X__ADDR << 2,"cleared all i/e: HBA_PORT__PxSERR"); //
    maxigp1_print        (HBA_PORT__PxIS__DHRS__ADDR << 2,     "re-read: HBA_PORT__PxIS__DHRS__ADDR"); //
    maxigp1_print        (HBA_PORT__PxSERR__DIAG__X__ADDR << 2,"re-read: HBA_PORT__PxSERR"); //
    maxigp1_print        (HBA_PORT__PxIS__DHRS__ADDR << 2,     "re-read: HBA_PORT__PxIS__DHRS__ADDR"); //
    maxigp1_print        (HBA_PORT__PxSERR__DIAG__X__ADDR << 2,"re-read: HBA_PORT__PxSERR"); //
     
//HBA_PORT__PxIS__DHRS__ADDR    

    maxigp1_print        (PXSIG_OFFS32 << 2,"PXSIG_OFFS32");
    maxigp1_print        (PXTFD_OFFS32 << 2,"PXTFD_OFFS32");
    maxigp1_print        (HBA_PORT__PxSERR__DIAG__X__ADDR,"HBA_PORT__PxSERR__DIAG__X__ADDR");
    
// Request ACTIVE, see it will be cleared
    maxigp1_writep       (HBA_PORT__PxCMD__FRE__ADDR << 2, 32'h10000000); //
    repeat (3) begin  
        maxigp1_print        (HBA_PORT__PxCMD__FRE__ADDR << 2,"HBA_PORT__PxCMD__ after ACTIVE request");
    end
    
    maxigp1_print        (HBA_PORT__PxCMD__FRE__ADDR << 2,"HBA_PORT__PxCMD__FRE__ADDR");
    maxigp1_writep       (HBA_PORT__PxCMD__FRE__ADDR << 2, HBA_PORT__PxCMD__FRE__MASK); // Enable FR, some RO bits already set 
    maxigp1_print        (HBA_PORT__PxCMD__FRE__ADDR << 2,"HBA_PORT__PxCMD__FRE__ADDR");
    maxigp1_writep       (HBA_PORT__PxCMD__FRE__ADDR << 2, HBA_PORT__PxCMD__FRE__MASK |HBA_PORT__PxCMD__ST__MASK); // Enable FR and ST 
    maxigp1_print        (HBA_PORT__PxCMD__FRE__ADDR << 2,"HBA_PORT__PxCMD__FRE__ADDR");
    
    maxigp1_print        (HBA_PORT__PxSSTS__DET__ADDR << 2,"HBA_PORT__PxSSTS__DET__ADDR");
    
//  setup_pio_read_identify_command_simple(512,1); // prdt interrupt for entry 0
  setup_pio_read_identify_command_simple(2560,1); // intentionally too long
///  setup_pio_read_identify_command_shifted(1); // prdt interrupt for entry 0
/// setup_pio_read_identify_command_multi4(1,27,71,83); // prdt interrupt for entry 0
/// setup_pio_read_identify_command_multi4(1,27,64,83); // prdt interrupt for entry 0
///    setup_pio_read_identify_command_multi4(1,64,63,64); // prdt interrupt for entry 0 // last used
    maxigp1_print        (HBA_PORT__PxCI__CI__ADDR << 2,"HBA_PORT__PxCI__CI__ADDR");
`ifdef TEST_ABORT_COMMAND    
// Abort command by clearing ST    
    maxigp1_writep       (HBA_PORT__PxCMD__FRE__ADDR << 2, HBA_PORT__PxCMD__FRE__MASK); // Enable FR, 0-> ST
    maxigp1_print        (HBA_PORT__PxCI__CI__ADDR << 2,"HBA_PORT__PxCI__CI__ADDR");
    repeat (300)  @(posedge CLK);
//    maxigp1_writep       (HBA_PORT__PxCMD__FRE__ADDR << 2, HBA_PORT__PxCMD__FRE__MASK); // Enable FR, 0-> ST
    maxigp1_print        (HBA_PORT__PxCI__CI__ADDR << 2,"HBA_PORT__PxCI__CI__ADDR");
//    maxigp1_writep       (HBA_PORT__PxCMD__FRE__ADDR << 2, HBA_PORT__PxCMD__FRE__MASK); // Enable FR, 0-> ST
    maxigp1_print        (HBA_PORT__PxCI__CI__ADDR << 2,"HBA_PORT__PxCI__CI__ADDR");
`endif     
    
    
    maxigp1_writep       (HBA_PORT__PxIE__PSE__ADDR << 2, HBA_PORT__PxIE__PSE__MASK); // allow PS only interrupts (PIO setup)
    maxigp1_writep       (HBA_PORT__PxIS__PSS__ADDR << 2, HBA_PORT__PxIS__PSS__MASK); // clear that interrupt
    wait (IRQ);
    TESTBENCH_TITLE = "Got Identify";
    $display("[Testbench]:       %s @%t", TESTBENCH_TITLE, $time);
    maxigp1_print        (HBA_PORT__PxIS__PSS__ADDR << 2,"HBA_PORT__PxIS__PSS__ADDR");
    maxigp1_writep       (HBA_PORT__PxIS__PSS__ADDR << 2, HBA_PORT__PxIS__PSS__MASK); // clear PS interrupt
    maxigp1_writep       (GHC__IS__IPS__ADDR << 2, 1); // clear global interrupts
    wait (~IRQ);
    
// Reset command with abort_dma

    maxigp1_writep       (HBA_PORT__PxCMD__FRE__ADDR << 2, HBA_PORT__PxCMD__FRE__MASK); //  ST: 1 -> 0
    repeat (50)  @(posedge CLK);
    maxigp1_writep       (HBA_PORT__PxCMD__FRE__ADDR << 2, HBA_PORT__PxCMD__FRE__MASK |HBA_PORT__PxCMD__ST__MASK); // ST: 0 -> 1 

    
    
// Print datascope - contents of the last CFIS sent
    maxigp1_print        ('h1000,"DATASCOPE 0"); // 
    maxigp1_print        ('h1004,"DATASCOPE 1"); // 
    maxigp1_print        ('h1008,"DATASCOPE 2"); // 
    maxigp1_print        ('h100c,"DATASCOPE 3"); // 
    maxigp1_print        ('h1010,"DATASCOPE 4"); // 
    maxigp1_print        ('h1014,"DATASCOPE 5"); // 
    maxigp1_print        ('h1018,"DATASCOPE 6"); // 
    maxigp1_print        ('h101c,"DATASCOPE 7"); // 
    
//    sysmem_print ('h1e81,'h180); // for shifted
    sysmem_print ('h1e80,'h180); // Compact dump of "system memory" in hex word format

// Second time read identify:

    // Prepare for D2H register FIS with interrupt bit set (expected to be sent after all data will be written to the device)
    maxigp1_writep       (HBA_PORT__PxIS__DHRS__ADDR << 2, HBA_PORT__PxIS__DHRS__MASK); // clear DHR (D2H register FIS with "I" bit) interrupt
    maxigp1_writep       (HBA_PORT__PxIE__PSE__ADDR << 2, HBA_PORT__PxIE__DHRE__MASK); // allow only D2H Register interrupts
    maxigp1_writep       (GHC__IS__IPS__ADDR << 2, 1); // clear global interrupts for port 0 (the only one)
    wait (~IRQ);

    setup_pio_read_identify_command_simple(512,1);                                         // prdt interrupt for entry 0
    maxigp1_print        (HBA_PORT__PxCI__CI__ADDR << 2,"HBA_PORT__PxCI__CI__ADDR");
    maxigp1_writep       (HBA_PORT__PxIE__PSE__ADDR << 2, HBA_PORT__PxIE__PSE__MASK); // allow PS only interrupts (PIO setup)
    maxigp1_writep       (HBA_PORT__PxIS__PSS__ADDR << 2, HBA_PORT__PxIS__PSS__MASK); // clear that interrupt
    wait (IRQ);
    TESTBENCH_TITLE = "Got second Identify";
    $display("[Testbench]:       %s @%t", TESTBENCH_TITLE, $time);
    maxigp1_print        (HBA_PORT__PxIS__PSS__ADDR << 2,"HBA_PORT__PxIS__PSS__ADDR");
    maxigp1_writep       (HBA_PORT__PxIS__PSS__ADDR << 2, HBA_PORT__PxIS__PSS__MASK); // clear PS interrupt
    maxigp1_writep       (GHC__IS__IPS__ADDR << 2, 1); // clear global interrupts
    wait (~IRQ);

// end of the second identify insertion

    // Prepare for D2H register FIS with interrupt bit set (expected to be sent after all data will be written to the device)
    maxigp1_writep       (HBA_PORT__PxIS__DHRS__ADDR << 2, HBA_PORT__PxIS__DHRS__MASK); // clear DHR (D2H register FIS with "I" bit) interrupt
    maxigp1_writep       (HBA_PORT__PxIE__PSE__ADDR << 2, HBA_PORT__PxIE__DHRE__MASK); // allow only D2H Register interrupts
    maxigp1_writep       (GHC__IS__IPS__ADDR << 2, 1); // clear global interrupts for port 0 (the only one)
    wait (~IRQ);
    
//    setup_dma_write_identify_command_multi4(1,'h123456, 27,71,83); // LBA = 'h123456 seems wrong order
    setup_dma_write_identify_command_multi4('h123456, 1, 27,71,83); // LBA = 'h123456
///    setup_dma_write_identify_command_simple('h123456, 1);    
    TESTBENCH_TITLE = "Set DMA Write command for device";
    $display("[Testbench]:       %s @%t", TESTBENCH_TITLE, $time);
    
    wait (IRQ);
    TESTBENCH_TITLE = "DMA transfer to device completed";
    $display("[Testbench]:       %s @%t", TESTBENCH_TITLE, $time);
    repeat (50)  @(posedge CLK);

// Print datascope - contents of the last CFIS sent
    maxigp1_print        ('h1000,"DATASCOPE 0"); // 
    maxigp1_print        ('h1004,"DATASCOPE 1"); // 
    maxigp1_print        ('h1008,"DATASCOPE 2"); // 
    maxigp1_print        ('h100c,"DATASCOPE 3"); // 
    maxigp1_print        ('h1010,"DATASCOPE 4"); // 
    maxigp1_print        ('h1014,"DATASCOPE 5"); // 
    maxigp1_print        ('h1018,"DATASCOPE 6"); // 
    maxigp1_print        ('h101c,"DATASCOPE 7"); // 
/*    
// Reset HBA
    maxigp1_writep       (GHC__GHC__HR__ADDR << 2, 1); // Reset HBA
    #12000; 
    @(posedge CLK);     
    maxigp1_print        (GHC__GHC__HR__ADDR << 2,"GHC__GHC__HR__ADDR after pause");
*/    
// Reset port
    maxigp1_print        ('h3ff << 2,"DEBUG_REGISTER");
    maxigp1_writep       (HBA_PORT__PxSCTL__DET__ADDR << 2, 1); // Reset SATA 
    maxigp1_print        ('h3ff << 2,"DEBUG_REGISTER");
    repeat (50)  @(posedge CLK);
    maxigp1_print        ('h3ff << 2,"DEBUG_REGISTER");
    maxigp1_writep       (HBA_PORT__PxSCTL__DET__ADDR << 2, 0); // Reset Off 
    repeat (1000)  @(posedge CLK);
    maxigp1_print        ('h3ff << 2,"DEBUG_REGISTER");
//DET    
//    $finish;
//HBA_PORT__PxIE__DHRE__MASK = 'h1;
end

function func_is_dev_identify;
    input [31:0] dw;
    begin
        func_is_dev_identify = ((dw & 'hff) == FIS_H2DR ) && (((dw >> 16) & 'hff) == ATA_IDFY);
    end
endfunction

function func_is_dev_dma_write;
    input [31:0] dw;
    begin
        func_is_dev_dma_write = ((dw & 'hff) == FIS_H2DR ) && (((dw >> 16) & 'hff) == ATA_WDMA);
    end
endfunction

function func_is_h2d_data;
    input [31:0] dw;
    begin
        func_is_h2d_data = (dw & 'hff) == FIS_DATA ;
    end
endfunction

integer status;
initial begin //Device
    dev.clear_transmit_pause(0);  
//    dev.linkTransmitFIS(66, 5, 0, status);
//    wait (dev.phy_ready);
    dev.wait_ready(3);
    DEVICE_TITLE = "NO_RESET";
    $display("[Dev-TB]:       %s @%t", DEVICE_TITLE, $time);
    dev.send_good_status (66,      // input integer id;
                          5,       // input    [2:0] dev_specific_status_bits;
                          1,       // IRQ
                          status); // output integer status;
    DEVICE_TITLE = "Device sent D2H FIS";
    $display("[Dev-TB]:            %s, status = 0x%x @%t", DEVICE_TITLE, status, $time);
    
    // Wait for host requests 'identify'
    forever @(dev.receive_id) begin
        if (func_is_dev_identify(dev.receive_data[0])) begin
            DEVICE_TITLE = "Got Identify";
            $display("[Dev-TB]:       %s @%t", DEVICE_TITLE, $time);
            $display("[Dev-TB]:       %h @%t", dev.receive_data[0], $time);
            dev.send_pio_setup   (67,      // input integer id;
                                   1,      // input          d2h; // 'D' bit: 1 - Data will be D2H, 0 - H2D
                                   1,      // input          irq; // Set I bit
                                   'h30,   // input    [7:0] xmit_status; // something different to check host
                                   0,      // input    [7:0] xmit_error;
                                   'h60,   // input    [7:0] xmit_e_status;
                                   512,    // input   [15:0] xfer_count; Identify block size
                                   0,      // input   [ 7:0] dev;    
                                   0,      // input   [23:0] lba_low;  // LBA_low dword
                                   0,      // input   [23:0] lba_high; // LBA high dword 
                                   0,      // input   [15:0] count; // 
                                   status); // output integer status;
            DEVICE_TITLE = "Device sent PIOS FIS";
            $display("[Dev-TB]:            %s, status = 0x%x @%t", DEVICE_TITLE, status, $time);
            dev.send_identify_data(68,      // input integer id;
                                   status); // output integer status;
            DEVICE_TITLE = "Device sent Data FIS (Identify)";
            $display("[Dev-TB]:            %s, status = 0x%x @%t", DEVICE_TITLE, status, $time);
        end else if (func_is_dev_dma_write(dev.receive_data[0])) begin
            DEVICE_TITLE = "Got DMA Write";
            $display("[Dev-TB]:       %s @%t", DEVICE_TITLE, $time);
            $display("[Dev-TB]:       %h @%t", dev.receive_data[0], $time);

            dev.send_dma_activate (69,      // input integer id;
                                   status); // output integer status;

        end else if (func_is_h2d_data(dev.receive_data[0])) begin
            DEVICE_TITLE = "Got H2D data";
            $display("[Dev-TB]:       %s @%t", DEVICE_TITLE, $time);
            $display("[Dev-TB]:       %hh payload DWORDs got (%d bytes) @%t", dev.received_size, dev.received_size << 2, $time);
            // Assuming device got what it needed, otherwise send DMA Activate again
            dev.send_D2HR(70,
               1, // irq,
               8'h0,                                // status
               0,                                   // error
               0,                                   // device
               0,                                   // lba_low
               0,                                   // lba_high
               0,                                   // count
               status);                             // output: result status
            
        end else begin
            DEVICE_TITLE = "Expected Identify or DMA Write, got else";
            $display("[Dev-TB]:       %s @%t", DEVICE_TITLE, $time);
            $display("[Dev-TB]:       %h @%t", dev.receive_data[0], $time);
        end
    end
end

  initial begin
//       #30000;
     #100000;
//     #29630;
//     #30000;
//     #250000;
//     #60000;
    $display("finish testbench 2");
  $finish;
  end

// testing itself
//`include  "test_top.v" // S uppressThisWarning VEditor - to avoid strange warnings

endmodule

//`include "x393/glbl.v" // SuppressThisWarning VEditor - duplicate module 
