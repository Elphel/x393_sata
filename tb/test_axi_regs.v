/*******************************************************************************
 * Module: test_axi_regs
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: test generator for axi_regs.v
 *
 * Copyright (c) 2015 Elphel, Inc.
 * test_axi_regs.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * test_axi_regs.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
module test_axi_regs(
    output  reg                 ACLK,
    output  reg                 ARESETN,
// AXI PS Master GP1: Read Address    
    output  reg     [31:0]      ARADDR,
    output  reg                 ARVALID,
    input   wire                ARREADY,
    output  reg     [11:0]      ARID,
    output  reg     [1:0]       ARLOCK,
    output  reg     [3:0]       ARCACHE,
    output  reg     [2:0]       ARPROT,
    output  reg     [3:0]       ARLEN,
    output  reg     [1:0]       ARSIZE,
    output  reg     [1:0]       ARBURST,
    output  reg     [3:0]       ARQOS,
// AXI PS Master GP1: Read Data
    input   wire    [31:0]      RDATA,
    input   wire                RVALID,
    output  reg                 RREADY,
    input   wire    [11:0]      RID,
    input   wire                RLAST,
    input   wire    [1:0]       RRESP,
// AXI PS Master GP1: Write Address    
    output  reg     [31:0]      AWADDR,
    output  reg                 AWVALID,
    input   wire                AWREADY,
    output  reg     [11:0]      AWID,
    output  reg     [1:0]       AWLOCK,
    output  reg     [3:0]       AWCACHE,
    output  reg     [2:0]       AWPROT,
    output  reg     [3:0]       AWLEN,
    output  reg     [1:0]       AWSIZE,
    output  reg     [1:0]       AWBURST,
    output  reg     [3:0]       AWQOS,
// AXI PS Master GP1: Write Data
    output  reg     [31:0]      WDATA,
    output  reg                 WVALID,
    input   wire                WREADY,
    output  reg     [11:0]      WID,
    output  reg                 WLAST,
    output  reg     [3:0]       WSTRB,
// AXI PS Master GP1: Write Responce
    input   wire                BVALID,
    output  reg                 BREADY,
    input   wire    [11:0]      BID,
    input   wire    [1:0]       BRESP
);

// finish
initial #5000 $finish;

// clock
initial
    ACLK = 0;
always #5 
    ACLK = ~ACLK;

// reset
initial
begin
    #50;
    ARESETN <= 1'b1;
    #50;
    ARESETN <= 1'b0;
    #50;
    ARESETN <= 1'b1;
end

// Trying to write a word
initial
begin
    ARVALID <= 1'b0;
    ARADDR  <= 1'b0;
    ARID    <= 1'b0;
    ARLOCK  <= 1'b0;
    ARCACHE <= 1'b0;
    ARPROT  <= 1'b0;
    ARLEN   <= 1'b0;
    ARSIZE  <= 1'b0;
    ARBURST <= 1'b0;
    RREADY  <= 1'b0;
    AWVALID <= 1'b0;
    AWADDR  <= 1'b0;
    AWID    <= 1'b0;
    AWLOCK  <= 1'b0;
    AWCACHE <= 1'b0;
    AWPROT  <= 1'b0;
    AWLEN   <= 1'b0;
    AWSIZE  <= 1'b0;
    AWBURST <= 1'b0;
    WVALID  <= 1'b0;
    WID     <= 1'b0;
    WSTRB   <= 1'b0;
    #220;
    repeat (10) 
        @ (posedge ACLK);
    AWVALID <= 1'b1;
    AWADDR  <= 32'h5;
    AWID    <= 1'b0;
    AWLOCK  <= 1'b0;
    AWCACHE <= 1'b0;
    AWPROT  <= 1'b0;
    AWLEN   <= 1'b0;
    AWSIZE  <= 2'b10;
    AWBURST <= 1'b0;
    if (AWREADY == 1'b0)
        @ (posedge AWREADY);
    @ (posedge ACLK);
    AWVALID <= 1'b0;
    WDATA   <= 32'hdeadbeef;
    WVALID  <= 1'b1;
    WSTRB   <= 4'b1011;
    WID     <= 12'h123;
    if (WREADY == 1'b0)
        @ (posedge WREADY);
    @ (posedge ACLK);
    WVALID  <= 1'b0;
    

    repeat (10) 
        @ (posedge ACLK);

// Trying to read a word
    #170;
    repeat (10) 
        @ (posedge ACLK);
    ARADDR  <= 32'h5;
    ARVALID <= 1'b1;
    ARID    <= 1'b0;
    ARLOCK  <= 1'b0;
    ARCACHE <= 1'b0;
    ARPROT  <= 1'b0;
    ARLEN   <= 1'b0;
    ARSIZE  <= 1'b0;
    ARBURST <= 1'b0;
    if (ARREADY == 1'b0)
        @ (posedge ARREADY);
    @ (posedge ACLK);
    ARVALID <= 1'b0;
    RREADY  <= 1'b1;
    if (RVALID == 1'b0)
        @ (posedge RVALID);
    @ (posedge ACLK);
    RREADY  <= 1'b0;

    

end
*/
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



endmodule
