/*******************************************************************************
 * Module: axi_regs
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: slave axi interface buffer
 *
 * Copyright (c) 2015 Elphel, Inc.
 * axi_regs.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * axi_regs.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
//`include "axibram_read.v"
//`include "axibram_write.v"
module axi_regs(
    input   wire                ACLK,              // AXI PS Master GP1 Clock , input
    input   wire                ARESETN,           // AXI PS Master GP1 Reset, output
// AXI PS Master GP1: Read Address    
    input   wire    [31:0]      ARADDR,            // AXI PS Master GP1 ARADDR[31:0], output  
    input   wire                ARVALID,           // AXI PS Master GP1 ARVALID, output
    output  wire                ARREADY,           // AXI PS Master GP1 ARREADY, input
    input   wire    [11:0]      ARID,              // AXI PS Master GP1 ARID[11:0], output
    input   wire    [3:0]       ARLEN,             // AXI PS Master GP1 ARLEN[3:0], output
    input   wire    [1:0]       ARSIZE,            // AXI PS Master GP1 ARSIZE[1:0], output
    input   wire    [1:0]       ARBURST,           // AXI PS Master GP1 ARBURST[1:0], output
// AXI PS Master GP1: Read Data
    output  wire    [31:0]      RDATA,             // AXI PS Master GP1 RDATA[31:0], input
    output  wire                RVALID,            // AXI PS Master GP1 RVALID, input
    input   wire                RREADY,            // AXI PS Master GP1 RREADY, output
    output  wire    [11:0]      RID,               // AXI PS Master GP1 RID[11:0], input
    output  wire                RLAST,             // AXI PS Master GP1 RLAST, input
    output  wire    [1:0]       RRESP,             // AXI PS Master GP1 RRESP[1:0], input
// AXI PS Master GP1: Write Address    
    input   wire    [31:0]      AWADDR,            // AXI PS Master GP1 AWADDR[31:0], output
    input   wire                AWVALID,           // AXI PS Master GP1 AWVALID, output
    output  wire                AWREADY,           // AXI PS Master GP1 AWREADY, input
    input   wire    [11:0]      AWID,              // AXI PS Master GP1 AWID[11:0], output
    input   wire    [3:0]       AWLEN,             // AXI PS Master GP1 AWLEN[3:0], outpu:t
    input   wire    [1:0]       AWSIZE,            // AXI PS Master GP1 AWSIZE[1:0], output
    input   wire    [1:0]       AWBURST,           // AXI PS Master GP1 AWBURST[1:0], output
// AXI PS Master GP1: Write Data
    input   wire    [31:0]      WDATA,             // AXI PS Master GP1 WDATA[31:0], output
    input   wire                WVALID,            // AXI PS Master GP1 WVALID, output
    output  wire                WREADY,            // AXI PS Master GP1 WREADY, input
    input   wire    [11:0]      WID,               // AXI PS Master GP1 WID[11:0], output
    input   wire                WLAST,             // AXI PS Master GP1 WLAST, output
    input   wire    [3:0]       WSTRB,             // AXI PS Master GP1 WSTRB[3:0], output
// AXI PS Master GP1: Write Responce
    output  wire                BVALID,            // AXI PS Master GP1 BVALID, input
    input   wire                BREADY,            // AXI PS Master GP1 BREADY, output
    output  wire    [11:0]      BID,               // AXI PS Master GP1 BID[11:0], input
    output  wire    [1:0]       BRESP,             // AXI PS Master GP1 BRESP[1:0], input
// registers iface
    input   wire    [31:0]      bram_rdata,
    output  wire    [31:0]      bram_waddr,
    output  wire    [31:0]      bram_wdata,
    output  wire    [31:0]      bram_raddr,
    output  wire    [3:0]       bram_wstb,
    output  wire                bram_wen,
    output  wire                bram_ren,
    output  wire                bram_regen
);
/*
 * Converntional MAXI interface from x393 project
 */
// Interface's instantiation
axibram_write #(
    .ADDRESS_BITS(16)
)
axibram_write(
    .aclk           (ACLK),
    .arst           (ARESETN),
    .awaddr         (AWADDR),
    .awvalid        (AWVALID),
    .awready        (AWREADY),
    .awid           (AWID),
    .awlen          (AWLEN),
    .awsize         (AWSIZE),
    .awburst        (AWBURST),
    .wdata          (WDATA),
    .wvalid         (WVALID),
    .wready         (WREADY),
    .wid            (WID),
    .wlast          (WLAST),
    .wstb           (WSTRB),
    .bvalid         (BVALID),
    .bready         (BREADY),
    .bid            (BID),
    .bresp          (BRESP),
    .pre_awaddr     (),
    .start_burst    (),
    .dev_ready      (1'b1),
    .bram_wclk      (),
    .bram_waddr     (bram_waddr[15:0]),
    .bram_wen       (bram_wen),
    .bram_wstb      (bram_wstb),
    .bram_wdata     (bram_wdata)
);
axibram_read #(
    .ADDRESS_BITS(16)
)
axibram_read(
    .aclk           (ACLK),
    .arst           (ARESETN),
    .araddr         (ARADDR),
    .arvalid        (ARVALID),
    .arready        (ARREADY),
    .arid           (ARID),
    .arlen          (ARLEN),
    .arsize         (ARSIZE),
    .arburst        (ARBURST),
    .rdata          (RDATA),
    .rvalid         (RVALID),
    .rready         (RREADY),
    .rid            (RID),
    .rlast          (RLAST),
    .rresp          (RRESP),
    .pre_araddr     (),
    .start_burst    (),
    .dev_ready      (1'b1),
    .bram_rclk      (),
    .bram_raddr     (bram_raddr[15:0]),
    .bram_ren       (bram_ren),
    .bram_regen     (bram_regen),
    .bram_rdata     (bram_rdata)
);

endmodule
