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
    @ (posedge ARESETN);
    AWVALID <= 1'b0;
    AWADDR  <= 1'b0;
    AWID    <= 1'b0;
    AWLOCK  <= 1'b0;
    AWCACHE <= 1'b0;
    AWPROT  <= 1'b0;
    AWLEN   <= 1'b0;
    AWSIZE  <= 1'b0;
    AWBURST <= 1'b0;
    repeat (10) 
        @ (posedge ACLK);
    AWVALID <= 1'b1;
    AWADDR  <= 32'h4;
    AWID    <= 1'b0;
    AWLOCK  <= 1'b0;
    AWCACHE <= 1'b0;
    AWPROT  <= 1'b0;
    AWLEN   <= 1'b0;
    AWSIZE  <= 1'b10;
    AWBURST <= 1'b0;
    

end

// Trying to read a word
initial
begin
    @ (posedge ARESETN);
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
    repeat (10) 
        @ (posedge ACLK);
    ARADDR  <= 1'b0;
    ARVALID <= 1'b1;
    ARID    <= 1'b0;
    ARLOCK  <= 1'b0;
    ARCACHE <= 1'b0;
    ARPROT  <= 1'b0;
    ARLEN   <= 1'b0;
    ARSIZE  <= 1'b0;
    ARBURST <= 1'b0;
    repeat (2) 
        @ (posedge ACLK);
    ARVALID <= 1'b0;
    repeat (5) 
        @ (posedge ACLK);
    RREADY  <= 1'b1;
    

end



endmodule
