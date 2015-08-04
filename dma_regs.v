/*******************************************************************************
 * Module: dma_regs
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: temporary registers, connected to axi bus
 *
 * Copyright (c) 2015 Elphel, Inc.
 * dma_regs.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * dma_regs.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
module dma_regs #(
    parameter REGISTERS_CNT = 20
)
(
    input   wire            rst,
    input   wire            ACLK,
    input   wire            sclk,
// registers iface
    output  wire    [31:7]  mem_address,
    output  wire    [31:0]  lba,
    output  wire    [31:0]  sector_cnt,
    output  wire            dma_type,
    output  wire            dma_start,
    input   wire            dma_done,
// axi buffer iface
    output  wire    [31:0]  bram_rdata,
    input   wire    [31:0]  bram_raddr,
    input   wire    [31:0]  bram_waddr,
    input   wire    [31:0]  bram_wdata,
    input   wire    [3:0]   bram_wstb,
    input   wire            bram_wen,
    input   wire            bram_ren,
    input   wire            bram_regen
);
//reg     [32*REGISTERS_CNT - 1:0]  mem;
/*
 * Converntional MAXI interface from x393 project, uses fifos, writes to/reads from memory
 */
/*
 * Temporary mapping:
 * rw  0x00: dma address (will automatically align to 128-bytes boundary, i.e. [6:0] -> 0
 * rw  0x04: lba
 * rw  0x08: sector count
 * rw  0x0c: dma type (any(0x0c) => write)
 * r1c 0x10: writes: dma start (any(0x10) => start)
 *           reads:  dma status of last issued transfer (0xffffffff => done)
 * ro  0x14: dma last issued dma_address
 */
reg [31:0]  reg00;
reg [31:0]  reg04;
reg [31:0]  reg08;
reg [31:0]  reg0c;
reg [31:0]  reg10;
reg [31:0]  reg14;

wire            dma_done_aclk;
wire            dma_start_aclk;
reg             dma_issued;
wire    [31:0]  wdata;

pulse_cross_clock dma_done_pulse(
    .rst        (rst),
    .src_clk    (sclk),
    .dst_clk    (ACLK),
    .in_pulse   (dma_done),
    .out_pulse  (dma_done_aclk),
    .busy       ()
);

pulse_cross_clock dma_start_pulse(
    .rst        (rst),
    .src_clk    (ACLK),
    .dst_clk    (sclk),
    .in_pulse   (dma_start_aclk & ~dma_issued),
    .out_pulse  (dma_start),
    .busy       ()
);

assign  dma_start_aclk  = bram_wen & (bram_waddr[3:0] == 4'h4) & |wdata;
assign  wdata           = bram_wdata[31:0] & {{8{bram_wstb[3]}}, {8{bram_wstb[2]}}, {8{bram_wstb[1]}}, {8{bram_wstb[0]}}};

always @ (posedge ACLK)
    dma_issued <= (dma_issued | dma_start_aclk) & ~rst & ~dma_done_aclk;

assign  mem_address = reg00[31:7];
assign  lba         = reg04;
assign  sector_cnt  = reg08;
assign  dma_type    = |reg0c;

always @ (posedge ACLK)
begin
    reg00 <= rst ? 32'h0 : bram_wen & (bram_waddr[3:0] == 4'h0) ? wdata : reg00;
    reg04 <= rst ? 32'h0 : bram_wen & (bram_waddr[3:0] == 4'h1) ? wdata : reg04;
    reg08 <= rst ? 32'h0 : bram_wen & (bram_waddr[3:0] == 4'h2) ? wdata : reg08;
    reg0c <= rst ? 32'h0 : bram_wen & (bram_waddr[3:0] == 4'h3) ? wdata : reg0c;
    reg10 <= rst ? 32'h0 : dma_start_aclk ? 32'h0 : dma_done_aclk ? 32'hffffffff : reg10; // status reg
    reg14 <= rst ? 32'h0 : dma_done_aclk ? reg00 : reg14;
end

// read from registers. Interface's protocol assumes returning data with a delay
reg     [3:0]   bram_raddr_r;
reg     [31:0]  bram_rdata_r;
always @ (posedge ACLK) begin
    bram_raddr_r <= bram_ren   ? bram_raddr[3:0] : bram_raddr_r;
    bram_rdata_r <=          ~bram_regen ? bram_rdata_r :
                    bram_raddr_r == 4'h0 ? reg00 :
                    bram_raddr_r == 4'h1 ? reg04 :
                    bram_raddr_r == 4'h2 ? reg08 :
                    bram_raddr_r == 4'h3 ? reg0c :
                    bram_raddr_r == 4'h4 ? reg10 :
                    bram_raddr_r == 4'h5 ? reg14 :
                                           32'hd34db33f;
end
assign  bram_rdata = bram_rdata_r;

/*
// for testing purposes the 'memory' is a set of registers for now
// later on will try to use them as an application level registers
genvar ii;
generate
for (ii = 0; ii < REGISTERS_CNT; ii = ii + 1)
begin: write_to_mem
    always @ (posedge ACLK)
    begin
        mem[32*ii + 31-:8] <= bram_wen & (bram_waddr[3:0] == ii) ? bram_wdata[31-:8] & {8{bram_wstb[3]}}: mem[32*ii + 31-:8];
        mem[32*ii + 23-:8] <= bram_wen & (bram_waddr[3:0] == ii) ? bram_wdata[23-:8] & {8{bram_wstb[2]}}: mem[32*ii + 23-:8];
        mem[32*ii + 15-:8] <= bram_wen & (bram_waddr[3:0] == ii) ? bram_wdata[15-:8] & {8{bram_wstb[1]}}: mem[32*ii + 15-:8];
        mem[32*ii +  7-:8] <= bram_wen & (bram_waddr[3:0] == ii) ? bram_wdata[ 7-:8] & {8{bram_wstb[0]}}: mem[32*ii +  7-:8];
    end
end
endgenerate

// read from memory. Interface's protocol assumes returning data with a delay
reg     [3:0]   bram_raddr_r;
reg     [31:0]  bram_rdata_r;
always @ (posedge ACLK) begin
    bram_raddr_r <= bram_ren   ? bram_raddr[3:0] : bram_raddr_r;
    bram_rdata_r <= bram_regen ? mem[32*bram_raddr_r + 31-:32] : bram_rdata_r;
end
assign  bram_rdata = bram_rdata_r;
*/
endmodule
