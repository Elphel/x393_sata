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
    .rst      (device_rst),
    .RXN      (txn),
    .RXP      (txp),
    .TXN      (rxn),
    .TXP      (rxp),
    .EXTCLK_P (EXTCLK_P),
    .EXTCLK_N (EXTCLK_N)
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

always #3.333 begin
    EXTCLK_P = ~EXTCLK_P;
    EXTCLK_N = ~EXTCLK_N;
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
localparam ATA_IDFY = 'hec; // Identify command

    reg  [31:0] sysmem[0:4095]; 

    // connect system memory ty AXI_NP RD and WR channels
//  assign HCLK = dut.ps7_i.SAXIHP3ACLK; // shortcut name
// afi loopback
    assign #1 afi_sim_rd_valid = afi_sim_rd_ready;
    assign #1 afi_sim_rd_resp = afi_sim_rd_ready?2'b0:2'bx;
    assign #1 afi_sim_wr_ready = afi_sim_wr_valid;
    assign #1 afi_sim_bresp_latency=4'h5; 
//  assign #1 afi_sim_rd_data=  afi_sim_rd_ready?{2'h0,afi_sim_rd_address[31:3],1'h1,  2'h0,afi_sim_rd_address[31:3],1'h0}:64'bx;
    wire MEM_SEL = (afi_sim_rd_address[31:3] >= (SYS_MEM_START >> 3)) && (afi_sim_rd_address[31:3] < ((SYS_MEM_START + SYS_MEM_SIZE) >> 3));
    wire [31:2] sysmem_dworda_rd = {(afi_sim_rd_address[31:3] - (SYS_MEM_START >> 3)),1'b0};
    assign #1 afi_sim_rd_data=  afi_sim_rd_ready?(MEM_SEL? {sysmem[sysmem_dworda_rd[31:2]+1], sysmem[sysmem_dworda_rd[31:2]]} :64'bx):64'bz;
    wire [31:2] sysmem_dworda_wr = {(afi_sim_wr_address[31:3] - (SYS_MEM_START >> 3)),1'b0};
    wire [31:0] sysmem_di_low =  ({{8{afi_sim_wr_stb[3]}},{8{afi_sim_wr_stb[2]}},{8{afi_sim_wr_stb[1]}},{8{afi_sim_wr_stb[0]}}} &
                                (sysmem[sysmem_dworda_wr[31:2]] ^ afi_sim_wr_data[31:0])) ^ sysmem[sysmem_dworda_wr[31:2]];
    
    wire [31:0] sysmem_di_high = ({{8{afi_sim_wr_stb[7]}},{8{afi_sim_wr_stb[6]}},{8{afi_sim_wr_stb[5]}},{8{afi_sim_wr_stb[4]}}} &
                                (sysmem[sysmem_dworda_wr[31:2]+1] ^ afi_sim_wr_data[63:32])) ^ sysmem[sysmem_dworda_wr[31:2]+1];
    always @ (posedge HCLK) begin
        if (|afi_sim_wr_stb[3:0]) sysmem[sysmem_dworda_wr[31:2]    ] <= sysmem_di_low;
        if (|afi_sim_wr_stb[7:4]) sysmem[sysmem_dworda_wr[31:2] + 1] <= sysmem_di_high;
    end
    
    
    task setup_pio_read_identify_command;
        input integer prd_int; // [0] - first prd interrupt, ... [31] - 31-st
        integer i;
        begin
            // clear system memory for command
            for (i = 0; i < 63; i = i+1)  sysmem[(COMMAND_TABLE >> 2) + i] = 0;
            // fill ATA command 
            sysmem[(COMMAND_TABLE >> 2) + 0] = FIS_H2DR |         // FIS type - H2D register (0x27)
                                               ('h80 << 8) |      // set C = 1
                                               (ATA_IDFY << 16) | // Command = 0xEC (IDFY)
                                              ( 0 << 24);        // features = 0 ?
            // All other 4 DWORDs are 0 for this command
            // Set PRDT (single item) TODO: later check multiple small ones
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) + 0] = SYS_MEM_START + IDENTIFY_BUF;
            sysmem[((COMMAND_TABLE + PRD_OFFSET) >> 2) + 3] = (prd_int[0] << 31) | 511; // 512 bytes in this PRDT
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
initial begin //Host
    wait (!RST);
//reg [639:0] TESTBENCH_TITLE = "RESET"; // to show human-readable state in the GTKWave
    TESTBENCH_TITLE = "NO_RESET";
    $display("[Testbench]:       %s @%t", TESTBENCH_TITLE, $time);
    repeat (10) begin
        @ (posedge CLK);
    end 
    axi_set_rd_lag(0);
    axi_set_b_lag(0);

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
    maxigp1_print        (GHC__IS__IPS__ADDR << 2,"GHC__IS__IPS__ADDR"); // Should be 1 (port 0)
    maxigp1_writep       (GHC__IS__IPS__ADDR << 2, 1); // clear that interrupt
    maxigp1_print        (GHC__IS__IPS__ADDR << 2,"GHC__IS__IPS__ADDR"); // Now it should be 0
    
    maxigp1_print        (HBA_PORT__PxIS__DHRS__ADDR << 2,"HBA_PORT__PxIS__DHRS__ADDR"); // It should be 400041 - DHR inerrupt (and others)
    maxigp1_writep       (HBA_PORT__PxIS__DHRS__ADDR << 2, HBA_PORT__PxIS__DHRS__MASK); // clear that interrupt
    maxigp1_print        (HBA_PORT__PxIS__DHRS__ADDR << 2,"HBA_PORT__PxIS__DHRS__ADDR"); // Now it should be 0400040 (DHR cleared)
//HBA_PORT__PxIS__DHRS__ADDR    

    maxigp1_print        (PXSIG_OFFS32 << 2,"PXSIG_OFFS32");
    maxigp1_print        (PXTFD_OFFS32 << 2,"PXTFD_OFFS32");
    maxigp1_print        (HBA_PORT__PxSERR__DIAG__X__ADDR,"HBA_PORT__PxSERR__DIAG__X__ADDR");
    maxigp1_print        (HBA_PORT__PxCMD__FRE__ADDR << 2,"HBA_PORT__PxCMD__FRE__ADDR");
    maxigp1_writep       (HBA_PORT__PxCMD__FRE__ADDR << 2, HBA_PORT__PxCMD__FRE__MASK); // Enable FR, some RO bits already set 
    maxigp1_print        (HBA_PORT__PxCMD__FRE__ADDR << 2,"HBA_PORT__PxCMD__FRE__ADDR");
    maxigp1_writep       (HBA_PORT__PxCMD__FRE__ADDR << 2, HBA_PORT__PxCMD__FRE__MASK |HBA_PORT__PxCMD__ST__MASK); // Enable FR and ST 
    maxigp1_print        (HBA_PORT__PxCMD__FRE__ADDR << 2,"HBA_PORT__PxCMD__FRE__ADDR");
    
    maxigp1_print        (HBA_PORT__PxSSTS__DET__ADDR << 2,"HBA_PORT__PxSSTS__DET__ADDR");
    
    setup_pio_read_identify_command(1); // prdt interrupt for entry 0
    maxigp1_print        (HBA_PORT__PxCI__CI__ADDR << 2,"HBA_PORT__PxCI__CI__ADDR");
//    $finish;
//HBA_PORT__PxIE__DHRE__MASK = 'h1;
end

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
                          1,       // input          irq;
                          status); // output integer status;
    DEVICE_TITLE = "Device sent D2H RS";
    $display("[Dev-TB]:            %s, status = 0x%x @%t", DEVICE_TITLE, status, $time);
                      
end
  initial begin
//       #30000;
     #50000;
//     #250000;
//     #60000;
    $display("finish testbench 2");
  $finish;
  end

// testing itself
//`include  "test_top.v" // S uppressThisWarning VEditor - to avoid strange warnings

endmodule

//`include "x393/glbl.v" // SuppressThisWarning VEditor - duplicate module 
