/*******************************************************************************
 * Module: tb
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: testbench for top.v
 *
 * Copyright (c) 2015 Elphel, Inc.
 * tb_top.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * tb_top.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
/*
 * using x393_testbench01.tf style, contains a lot of copy-pasted code from there
 */
`timescale 1ns/1ps
`include "top.v"

module tb #(
`include "includes/x393_parameters.vh" // SuppressThisWarning VEditor - not used
`include "includes/x393_simulation_parameters.vh"
)
(
);
initial #1 $display("HI THERE");
initial
begin
    $dumpfile("test.vcd");
    $dumpvars(0,tb);
end

reg     [11:0]  ARID_IN_r;
reg     [31:0]  ARADDR_IN_r;
reg     [3:0]   ARLEN_IN_r;
reg     [2:0]   ARSIZE_IN_r;
reg     [1:0]   ARBURST_IN_r;
reg     [11:0]  AWID_IN_r;
reg     [31:0]  AWADDR_IN_r;
reg     [3:0]   AWLEN_IN_r;
reg     [2:0]   AWSIZE_IN_r;
reg     [1:0]   AWBURST_IN_r;

reg     [11:0]  WID_IN_r;
reg     [31:0]  WDATA_IN_r;
reg     [3:0]   WSTRB_IN_r;
reg             WLAST_IN_r;
reg DEBUG1, DEBUG2, DEBUG3;
reg [11:0] GLOBAL_WRITE_ID=0;
reg [11:0] GLOBAL_READ_ID=0;
reg [11:0] LAST_ARID; // last issued ARID
// SuppressWarnings VEditor : assigned in $readmem() system task
wire [SIMUL_AXI_READ_WIDTH-1:0] SIMUL_AXI_ADDR_W;
// SuppressWarnings VEditor
wire        SIMUL_AXI_MISMATCH;
// SuppressWarnings VEditor
reg  [31:0] SIMUL_AXI_READ;
// SuppressWarnings VEditor
reg  [SIMUL_AXI_READ_WIDTH-1:0] SIMUL_AXI_ADDR;
// SuppressWarnings VEditor
reg         SIMUL_AXI_FULL; // some data available
wire        SIMUL_AXI_EMPTY= ~rvalid && rready && (rid==LAST_ARID); //SuppressThisWarning VEditor : may be unused, just for simulation // use it to wait for?
reg  [31:0] registered_rdata; // here read data from task

reg        CLK;
reg        RST;
reg        AR_SET_CMD_r;
wire       AR_READY;

reg        AW_SET_CMD_r;
wire       AW_READY;

reg        W_SET_CMD_r;
wire       W_READY;
reg  [3:0] RD_LAG;  // ready signal lag in axi read channel (0 - RDY=1, 1..15 - RDY is asserted N cycles after valid)   
reg  [3:0] B_LAG;   // ready signal lag in axi arete response channel (0 - RDY=1, 1..15 - RDY is asserted N cycles after valid)   

// Simulation modules interconnection
wire [11:0] arid;
wire [31:0] araddr;
wire [3:0]  arlen;
wire [2:0]  arsize;
wire [1:0]  arburst;
// SuppressWarnings VEditor : assigned in $readmem(14) system task
wire [3:0]  arcache;
// SuppressWarnings VEditor : assigned in $readmem() system task
wire [2:0]  arprot;
wire        arvalid;
wire        arready;

wire [11:0] awid;
wire [31:0] awaddr;
wire [3:0]  awlen;
wire [2:0]  awsize;
wire [1:0]  awburst;
// SuppressWarnings VEditor : assigned in $readmem() system task
wire [3:0]  awcache;
// SuppressWarnings VEditor : assigned in $readmem() system task
wire [2:0]  awprot;
wire        awvalid;
wire        awready;

wire [11:0] wid;
wire [31:0] wdata;
wire [3:0]  wstrb;
wire        wlast;
wire        wvalid;
wire        wready;

wire [31:0] rdata;
// SuppressWarnings VEditor : assigned in $readmem() system task
wire [11:0] rid;
wire        rlast;
// SuppressWarnings VEditor : assigned in $readmem() system task
wire  [1:0] rresp;
wire        rvalid;
wire        rready;
wire        rstb=rvalid && rready;

// SuppressWarnings VEditor : assigned in $readmem() system task
wire  [1:0] bresp;
// SuppressWarnings VEditor : assigned in $readmem() system task
wire [11:0] bid;
wire        bvalid;
wire        bready;
integer     NUM_WORDS_READ;
integer     NUM_WORDS_EXPECTED;
reg  [15:0] ENABLED_CHANNELS = 0; // currently enabled memory channels
//  integer     SCANLINE_CUR_X;
//  integer     SCANLINE_CUR_Y;
wire AXI_RD_EMPTY=NUM_WORDS_READ==NUM_WORDS_EXPECTED; //SuppressThisWarning VEditor : may be unused, just for simulation

wire [11:0]  #(AXI_TASK_HOLD) ARID_IN = ARID_IN_r;
wire [31:0]  #(AXI_TASK_HOLD) ARADDR_IN = ARADDR_IN_r;
wire  [3:0]  #(AXI_TASK_HOLD) ARLEN_IN = ARLEN_IN_r;
wire  [2:0]  #(AXI_TASK_HOLD) ARSIZE_IN = ARSIZE_IN_r;
wire  [1:0]  #(AXI_TASK_HOLD) ARBURST_IN = ARBURST_IN_r;
wire [11:0]  #(AXI_TASK_HOLD) AWID_IN = AWID_IN_r;
wire [31:0]  #(AXI_TASK_HOLD) AWADDR_IN = AWADDR_IN_r;
wire  [3:0]  #(AXI_TASK_HOLD) AWLEN_IN = AWLEN_IN_r;
wire  [2:0]  #(AXI_TASK_HOLD) AWSIZE_IN = AWSIZE_IN_r;
wire  [1:0]  #(AXI_TASK_HOLD) AWBURST_IN = AWBURST_IN_r;
wire [11:0]  #(AXI_TASK_HOLD) WID_IN = WID_IN_r;
wire [31:0]  #(AXI_TASK_HOLD) WDATA_IN = WDATA_IN_r;
wire [ 3:0]  #(AXI_TASK_HOLD) WSTRB_IN = WSTRB_IN_r;
wire         #(AXI_TASK_HOLD) WLAST_IN = WLAST_IN_r;
wire         #(AXI_TASK_HOLD) AR_SET_CMD = AR_SET_CMD_r;
wire         #(AXI_TASK_HOLD) AW_SET_CMD = AW_SET_CMD_r;
wire         #(AXI_TASK_HOLD) W_SET_CMD =  W_SET_CMD_r;

always #(CLKIN_PERIOD/2) CLK = ~CLK;

/*
 * connect axi ports to the dut
 */
assign dut.ps7_i.FCLKCLK=        {4{CLK}};
assign dut.ps7_i.FCLKRESETN=     {RST,~RST,RST,~RST};
// Read address
assign dut.ps7_i.MAXIGP0ARADDR=  araddr;
assign dut.ps7_i.MAXIGP0ARVALID= arvalid;
assign arready=                            dut.ps7_i.MAXIGP0ARREADY;
assign dut.ps7_i.MAXIGP0ARID=    arid; 
assign dut.ps7_i.MAXIGP0ARLEN=   arlen;
assign dut.ps7_i.MAXIGP0ARSIZE=  arsize[1:0]; // arsize[2] is not used
assign dut.ps7_i.MAXIGP0ARBURST= arburst;
// Read data
assign rdata=                              dut.ps7_i.MAXIGP0RDATA; 
assign rvalid=                             dut.ps7_i.MAXIGP0RVALID;
assign dut.ps7_i.MAXIGP0RREADY=  rready;
assign rid=                                dut.ps7_i.MAXIGP0RID;
assign rlast=                              dut.ps7_i.MAXIGP0RLAST;
assign rresp=                              dut.ps7_i.MAXIGP0RRESP;
// Write address
assign dut.ps7_i.MAXIGP0AWADDR=  awaddr;
assign dut.ps7_i.MAXIGP0AWVALID= awvalid;

assign awready=                            dut.ps7_i.MAXIGP0AWREADY;

//assign awready= AWREADY_AAAA;
assign dut.ps7_i.MAXIGP0AWID=awid;

      // SuppressWarnings VEditor all
//  wire [ 1:0] AWLOCK;
      // SuppressWarnings VEditor all
//  wire [ 3:0] AWCACHE;
      // SuppressWarnings VEditor all
//  wire [ 2:0] AWPROT;
assign dut.ps7_i.MAXIGP0AWLEN=   awlen;
assign dut.ps7_i.MAXIGP0AWSIZE=  awsize[1:0]; // awsize[2] is not used
assign dut.ps7_i.MAXIGP0AWBURST= awburst;
      // SuppressWarnings VEditor all
//  wire [ 3:0] AWQOS;
// Write data
assign dut.ps7_i.MAXIGP0WDATA=   wdata;
assign dut.ps7_i.MAXIGP0WVALID=  wvalid;
assign wready=                             dut.ps7_i.MAXIGP0WREADY;
assign dut.ps7_i.MAXIGP0WID=     wid;
assign dut.ps7_i.MAXIGP0WLAST=   wlast;
assign dut.ps7_i.MAXIGP0WSTRB=   wstrb;
// Write response
assign bvalid=                             dut.ps7_i.MAXIGP0BVALID;
assign dut.ps7_i.MAXIGP0BREADY=  bready;
assign bid=                                dut.ps7_i.MAXIGP0BID;
assign bresp=                              dut.ps7_i.MAXIGP0BRESP;


// Simulation modules    
simul_axi_master_rdaddr
#(
  .ID_WIDTH(12),
  .ADDRESS_WIDTH(32),
  .LATENCY(AXI_RDADDR_LATENCY),          // minimal delay between inout and output ( 0 - next cycle)
  .DEPTH(8),            // maximal number of commands in FIFO
  .DATA_DELAY(3.5),
  .VALID_DELAY(4.0)
) simul_axi_master_rdaddr_i (
    .clk(CLK),
    .reset(RST),
    .arid_in(ARID_IN[11:0]),
    .araddr_in(ARADDR_IN[31:0]),
    .arlen_in(ARLEN_IN[3:0]),
    .arsize_in(ARSIZE_IN[2:0]),
    .arburst_in(ARBURST_IN[1:0]),
    .arcache_in(4'b0),
    .arprot_in(3'b0), //     .arprot_in(2'b0),
    .arid(arid[11:0]),
    .araddr(araddr[31:0]),
    .arlen(arlen[3:0]),
    .arsize(arsize[2:0]),
    .arburst(arburst[1:0]),
    .arcache(arcache[3:0]),
    .arprot(arprot[2:0]),
    .arvalid(arvalid),
    .arready(arready),
    .set_cmd(AR_SET_CMD),  // latch all other input data at posedge of clock
    .ready(AR_READY)     // command/data FIFO can accept command
);

simul_axi_master_wraddr
#(
  .ID_WIDTH(12),
  .ADDRESS_WIDTH(32),
  .LATENCY(AXI_WRADDR_LATENCY),          // minimal delay between inout and output ( 0 - next cycle)
  .DEPTH(8),            // maximal number of commands in FIFO
  .DATA_DELAY(3.5),
  .VALID_DELAY(4.0)
) simul_axi_master_wraddr_i (
    .clk(CLK),
    .reset(RST),
    .awid_in(AWID_IN[11:0]),
    .awaddr_in(AWADDR_IN[31:0]),
    .awlen_in(AWLEN_IN[3:0]),
    .awsize_in(AWSIZE_IN[2:0]),
    .awburst_in(AWBURST_IN[1:0]),
    .awcache_in(4'b0),
    .awprot_in(3'b0), //.awprot_in(2'b0),
    .awid(awid[11:0]),
    .awaddr(awaddr[31:0]),
    .awlen(awlen[3:0]),
    .awsize(awsize[2:0]),
    .awburst(awburst[1:0]),
    .awcache(awcache[3:0]),
    .awprot(awprot[2:0]),
    .awvalid(awvalid),
    .awready(awready),
    .set_cmd(AW_SET_CMD),  // latch all other input data at posedge of clock
    .ready(AW_READY)     // command/data FIFO can accept command
);

simul_axi_master_wdata
#(
  .ID_WIDTH(12),
  .DATA_WIDTH(32),
  .WSTB_WIDTH(4),
  .LATENCY(AXI_WRDATA_LATENCY),          // minimal delay between inout and output ( 0 - next cycle)
  .DEPTH(8),            // maximal number of commands in FIFO
  .DATA_DELAY(3.2),
  .VALID_DELAY(3.6)
) simul_axi_master_wdata_i (
    .clk(CLK),
    .reset(RST),
    .wid_in(WID_IN[11:0]),
    .wdata_in(WDATA_IN[31:0]),
    .wstrb_in(WSTRB_IN[3:0]),
    .wlast_in(WLAST_IN),
    .wid(wid[11:0]),
    .wdata(wdata[31:0]),
    .wstrb(wstrb[3:0]),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),
    .set_cmd(W_SET_CMD),  // latch all other input data at posedge of clock
    .ready(W_READY)        // command/data FIFO can accept command
);

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

simul_axi_read #(
    .ADDRESS_WIDTH(SIMUL_AXI_READ_WIDTH)
  ) simul_axi_read_i(
  .clk(CLK),
  .reset(RST),
  .last(rlast),
  .data_stb(rstb),
  .raddr(ARADDR_IN[SIMUL_AXI_READ_WIDTH+1:2]), 
  .rlen(ARLEN_IN),
  .rcmd(AR_SET_CMD),
  .addr_out(SIMUL_AXI_ADDR_W[SIMUL_AXI_READ_WIDTH-1:0]),
  .burst(),     // burst in progress - just debug
  .err_out());  // data last does not match predicted or FIFO over/under run - just debug

`include "includes/x393_tasks01.vh"

// device-under-test instance
top dut(
);

// testing itself
`include  "test_top.v"

endmodule
