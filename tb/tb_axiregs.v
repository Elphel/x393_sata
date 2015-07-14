/*******************************************************************************
 * Module: tb
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: testbench for axi_regs.v
 *
 * Copyright (c) 2015 Elphel, Inc.
 * tb_axiregs.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * tb_axiregs.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ns
`include "axi_regs.v"
`include "test_axi_regs.v"

module tb();

initial #1 $display("HI THERE");
initial
begin
    $dumpfile("test.vcd");
    $dumpvars(0,tb);
end

wire                ACLK;              // AXI PS Master GP1 Clock , input
wire                ARESETN;           // AXI PS Master GP1 Reset, output
wire    [31:0]      ARADDR;            // AXI PS Master GP1 ARADDR[31:0], output  
wire                ARVALID;           // AXI PS Master GP1 ARVALID, output
wire                ARREADY;           // AXI PS Master GP1 ARREADY, input
wire    [11:0]      ARID;              // AXI PS Master GP1 ARID[11:0], output
wire    [1:0]       ARLOCK;            // AXI PS Master GP1 ARLOCK[1:0], output
wire    [3:0]       ARCACHE;           // AXI PS Master GP1 ARCACHE[3:0], output
wire    [2:0]       ARPROT;            // AXI PS Master GP1 ARPROT[2:0], output
wire    [3:0]       ARLEN;             // AXI PS Master GP1 ARLEN[3:0], output
wire    [1:0]       ARSIZE;            // AXI PS Master GP1 ARSIZE[1:0], output
wire    [1:0]       ARBURST;           // AXI PS Master GP1 ARBURST[1:0], output
wire    [3:0]       ARQOS;             // AXI PS Master GP1 ARQOS[3:0], output
wire    [31:0]      RDATA;             // AXI PS Master GP1 RDATA[31:0], input
wire                RVALID;            // AXI PS Master GP1 RVALID, input
wire                RREADY;            // AXI PS Master GP1 RREADY, output
wire    [11:0]      RID;               // AXI PS Master GP1 RID[11:0], input
wire                RLAST;             // AXI PS Master GP1 RLAST, input
wire    [1:0]       RRESP;             // AXI PS Master GP1 RRESP[1:0], input
wire    [31:0]      AWADDR;            // AXI PS Master GP1 AWADDR[31:0], output
wire                AWVALID;           // AXI PS Master GP1 AWVALID, output
wire                AWREADY;           // AXI PS Master GP1 AWREADY, input
wire    [11:0]      AWID;              // AXI PS Master GP1 AWID[11:0], output
wire    [1:0]       AWLOCK;            // AXI PS Master GP1 AWLOCK[1:0], output
wire    [3:0]       AWCACHE;           // AXI PS Master GP1 AWCACHE[3:0], output
wire    [2:0]       AWPROT;            // AXI PS Master GP1 AWPROT[2:0], output
wire    [3:0]       AWLEN;             // AXI PS Master GP1 AWLEN[3:0], outpu:t
wire    [1:0]       AWSIZE;            // AXI PS Master GP1 AWSIZE[1:0], output
wire    [1:0]       AWBURST;           // AXI PS Master GP1 AWBURST[1:0], output
wire    [3:0]       AWQOS;             // AXI PS Master GP1 AWQOS[3:0], output
wire    [31:0]      WDATA;             // AXI PS Master GP1 WDATA[31:0], output
wire                WVALID;            // AXI PS Master GP1 WVALID, output
wire                WREADY;            // AXI PS Master GP1 WREADY, input
wire    [11:0]      WID;               // AXI PS Master GP1 WID[11:0], output
wire                WLAST;             // AXI PS Master GP1 WLAST, output
wire    [3:0]       WSTRB;             // AXI PS Master GP1 WSTRB[3:0], output
wire                BVALID;            // AXI PS Master GP1 BVALID, input
wire                BREADY;            // AXI PS Master GP1 BREADY, output
wire    [11:0]      BID;               // AXI PS Master GP1 BID[11:0], input
wire    [1:0]       BRESP;             // AXI PS Master GP1 BRESP[1:0], input
/*
axibram_write dut(
	.aclk			(ACLK),
	.rst			(~ARESETN),
	.awaddr			(AWADDR),
	.awvalid		(AWVALID),
	.awready		(AWREADY),
	.awid			(AWID),
	.awlen			(AWLEN),
	.awsize			(AWSIZE),
	.awburst		(AWBURST),
	.wdata			(WDATA),
	.wvalid			(WVALID),
	.wready			(WREADY),
	.wid			(WID),
	.wlast			(WLAST),
	.wstb			(WSTRB),
	.bvalid			(BVALID),
	.bready			(BREADY),
	.bid			(BID),
	.bresp			(BRESP),
	.pre_awaddr		(),
	.start_burst	(),
	.dev_ready		(1'b1),
	.bram_wclk		(),
	.bram_waddr		(),
	.bram_wen		(),
	.bram_wstb		(),
	.bram_wdata		()
);
axibram_read dut2(
	.aclk			(ACLK),
	.rst			(~ARESETN),
	.araddr			(ARADDR),
	.arvalid		(ARVALID),
	.arready		(ARREADY),
	.arid			(ARID),
	.arlen			(ARLEN),
	.arsize			(ARSIZE),
	.arburst		(ARBURST),
	.rdata			(RDATA),
	.rvalid			(RVALID),
	.rready			(RREADY),
	.rid			(RID),
	.rlast			(RLAST),
	.rresp			(RRESP),
	.pre_araddr		(),
	.start_burst	(),
	.dev_ready		(1'b1),
	.bram_rclk		(),
	.bram_raddr		(),
	.bram_ren		(bram_ren),
	.bram_regen		(),
	.bram_rdata		(bram_ren ? 32'hdeadbeef : 0)
);
*/
axi_regs dut(
    .ACLK       (ACLK),
    .ARESETN    (ARESETN),
    .ARADDR     (ARADDR),
    .ARVALID    (ARVALID),
    .ARREADY    (ARREADY),
    .ARID       (ARID),
    .ARLOCK     (ARLOCK),
    .ARCACHE    (ARCACHE),
    .ARPROT     (ARPROT),
    .ARLEN      (ARLEN),
    .ARSIZE     (ARSIZE),
    .ARBURST    (ARBURST),
    .ARQOS      (ARQOS),
    .RDATA      (RDATA),
    .RVALID     (RVALID),
    .RREADY     (RREADY),
    .RID        (RID),
    .RLAST      (RLAST),
    .RRESP      (RRESP),
    .AWADDR     (AWADDR),
    .AWVALID    (AWVALID),
    .AWREADY    (AWREADY),
    .AWID       (AWID),
    .AWLOCK     (AWLOCK),
    .AWCACHE    (AWCACHE),
    .AWPROT     (AWPROT),
    .AWLEN      (AWLEN),
    .AWSIZE     (AWSIZE),
    .AWBURST    (AWBURST),
    .AWQOS      (AWQOS),
    .WDATA      (WDATA),
    .WVALID     (WVALID),
    .WREADY     (WREADY),
    .WID        (WID),
    .WLAST      (WLAST),
    .WSTRB      (WSTRB),
    .BVALID     (BVALID),
    .BREADY     (BREADY),
    .BID        (BID),
    .BRESP      (BRESP)
);

test_axi_regs test(
    .ACLK       (ACLK),
    .ARESETN    (ARESETN),
    .ARADDR     (ARADDR),
    .ARVALID    (ARVALID),
    .ARREADY    (ARREADY),
    .ARID       (ARID),
    .ARLOCK     (ARLOCK),
    .ARCACHE    (ARCACHE),
    .ARPROT     (ARPROT),
    .ARLEN      (ARLEN),
    .ARSIZE     (ARSIZE),
    .ARBURST    (ARBURST),
    .ARQOS      (ARQOS),
    .RDATA      (RDATA),
    .RVALID     (RVALID),
    .RREADY     (RREADY),
    .RID        (RID),
    .RLAST      (RLAST),
    .RRESP      (RRESP),
    .AWADDR     (AWADDR),
    .AWVALID    (AWVALID),
    .AWREADY    (AWREADY),
    .AWID       (AWID),
    .AWLOCK     (AWLOCK),
    .AWCACHE    (AWCACHE),
    .AWPROT     (AWPROT),
    .AWLEN      (AWLEN),
    .AWSIZE     (AWSIZE),
    .AWBURST    (AWBURST),
    .AWQOS      (AWQOS),
    .WDATA      (WDATA),
    .WVALID     (WVALID),
    .WREADY     (WREADY),
    .WID        (WID),
    .WLAST      (WLAST),
    .WSTRB      (WSTRB),
    .BVALID     (BVALID),
    .BREADY     (BREADY),
    .BID        (BID),
    .BRESP      (BRESP)
);
endmodule
