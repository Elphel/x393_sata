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
module dma_regs(
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
    input   wire            bram_regen,

// tmp to cmd control
    output  wire            cmd_val_out,
    output  wire    [31:0]  cmd_out,
// tmp to shadow registers
    output  wire    [31:0]  sh_data, // write data
    output  wire            sh_data_val, // write strobe
    output  wire            sh_data_strobe, // read strobe
    output  wire    [15:0]  sh_feature,
    output  wire            sh_feature_val,
    output  wire    [23:0]  sh_lba_lo,
    output  wire            sh_lba_lo_val,
    output  wire    [23:0]  sh_lba_hi,
    output  wire            sh_lba_hi_val,
    output  wire    [15:0]  sh_count,
    output  wire            sh_count_val,
    output  wire    [7:0]   sh_command,
    output  wire            sh_command_val,
    output  wire    [7:0]   sh_dev,
    output  wire            sh_dev_val,
    output  wire    [7:0]   sh_control,
    output  wire            sh_control_val,
    output  wire    [31:0]  sh_dma_id_lo,
    output  wire            sh_dma_id_lo_val,
    output  wire    [31:0]  sh_dma_id_hi,
    output  wire            sh_dma_id_hi_val,
    output  wire    [31:0]  sh_buf_off,
    output  wire            sh_buf_off_val,
    output  wire    [31:0]  sh_dma_cnt,
    output  wire            sh_dma_cnt_val,
    output  wire    [15:0]  sh_tran_cnt,
    output  wire            sh_tran_cnt_val,
    output  wire            sh_autoact,
    output  wire            sh_autoact_val,
    output  wire            sh_inter,
    output  wire            sh_inter_val,
    output  wire    [3:0]   sh_port,
    output  wire            sh_port_val,
    output  wire            sh_notif,
    output  wire            sh_notif_val,
    output  wire            sh_dir,
    output  wire            sh_dir_val,

// inputs from sh registers
    input   wire            sh_data_val_in,
    input   wire    [31:0]  sh_data_in,
    input   wire    [7:0]   sh_control_in,
    input   wire    [15:0]  sh_feature_in,
    input   wire    [47:0]  sh_lba_in,
    input   wire    [15:0]  sh_count_in,
    input   wire    [7:0]   sh_command_in,
    input   wire    [7:0]   sh_err_in,
    input   wire    [7:0]   sh_status_in,
    input   wire    [7:0]   sh_estatus_in, // E_Status
    input   wire    [7:0]   sh_dev_in,
    input   wire    [3:0]   sh_port_in,
    input   wire            sh_inter_in,
    input   wire            sh_dir_in,
    input   wire    [63:0]  sh_dma_id_in,
    input   wire    [31:0]  sh_dma_off_in,
    input   wire    [31:0]  sh_dma_cnt_in,
    input   wire    [15:0]  sh_tran_cnt_in, // Transfer Count
    input   wire            sh_notif_in,
    input   wire            sh_autoact_in,
// inputs from cmd control
    input   wire    [31:0]  cmd_in
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

assign  dma_start_aclk  = bram_wen & (bram_waddr[7:0] == 8'hf4) & |wdata;
assign  wdata           = bram_wdata[31:0] & {{8{bram_wstb[3]}}, {8{bram_wstb[2]}}, {8{bram_wstb[1]}}, {8{bram_wstb[0]}}};

always @ (posedge ACLK)
    dma_issued <= (dma_issued | dma_start_aclk) & ~rst & ~dma_done_aclk;

assign  mem_address = reg00[31:7];
assign  lba         = reg04;
assign  sector_cnt  = reg08;
assign  dma_type    = |reg0c;

always @ (posedge ACLK)
begin
    reg00 <= rst ? 32'h0 : bram_wen & (bram_waddr[7:0] == 8'hf0) ? wdata : reg00;
    reg04 <= rst ? 32'h0 : bram_wen & (bram_waddr[7:0] == 8'hf1) ? wdata : reg04;
    reg08 <= rst ? 32'h0 : bram_wen & (bram_waddr[7:0] == 8'hf2) ? wdata : reg08;
    reg0c <= rst ? 32'h0 : bram_wen & (bram_waddr[7:0] == 8'hf3) ? wdata : reg0c;
    reg10 <= rst ? 32'h0 : dma_start_aclk ? 32'h0 : {31'h0, dma_done_aclk} ? 32'hffffffff : reg10; // status reg
    reg14 <= rst ? 32'h0 : dma_done_aclk ? reg00 : reg14;
end

// writes to shadow registers:
assign sh_data_val      = bram_wen & (bram_waddr[7:0] == 8'h0);
assign sh_feature_val   = bram_wen & (bram_waddr[7:0] == 8'h1);
assign sh_lba_lo_val    = bram_wen & (bram_waddr[7:0] == 8'h2);
assign sh_lba_hi_val    = bram_wen & (bram_waddr[7:0] == 8'h3);
assign sh_count_val     = bram_wen & (bram_waddr[7:0] == 8'h4);
assign sh_command_val   = bram_wen & (bram_waddr[7:0] == 8'h5);
assign sh_dev_val       = bram_wen & (bram_waddr[7:0] == 8'h6);
assign sh_control_val   = bram_wen & (bram_waddr[7:0] == 8'h7);
assign sh_dma_id_lo_val = bram_wen & (bram_waddr[7:0] == 8'h8);
assign sh_dma_id_hi_val = bram_wen & (bram_waddr[7:0] == 8'h9);
assign sh_buf_off_val   = bram_wen & (bram_waddr[7:0] == 8'ha);
assign sh_tran_cnt_val  = bram_wen & (bram_waddr[7:0] == 8'hb);
assign sh_autoact_val   = bram_wen & (bram_waddr[7:0] == 8'hc);
assign sh_inter_val     = bram_wen & (bram_waddr[7:0] == 8'hd);
assign sh_dir_val       = bram_wen & (bram_waddr[7:0] == 8'he);
assign cmd_val_out      = bram_wen & (bram_waddr[7:0] == 8'hf);
assign sh_port_val      = bram_wen & (bram_waddr[7:0] == 8'h13);
assign sh_dma_cnt_val   = bram_wen & (bram_waddr[7:0] == 8'h14);
assign sh_notif_val     = bram_wen & (bram_waddr[7:0] == 8'h15);

assign sh_data          = wdata;
assign sh_feature       = wdata[15:0];
assign sh_lba_lo        = wdata[23:0];
assign sh_lba_hi        = wdata[23:0];
assign sh_count         = wdata[15:0];
assign sh_command       = wdata[7:0];
assign sh_dev           = wdata[7:0];
assign sh_control       = wdata[7:0];
assign sh_dma_id_lo     = wdata;
assign sh_dma_id_hi     = wdata;
assign sh_buf_off       = wdata;
assign sh_tran_cnt      = wdata[15:0];
assign sh_autoact       = wdata[0];
assign sh_inter         = wdata[0];
assign sh_dir           = wdata[0];
assign sh_port          = wdata[3:0];
assign sh_notif         = wdata[0];
assign sh_dma_cnt       = wdata;
assign cmd_out          = wdata;



reg     [7:0]   bram_raddr_r;
assign sh_data_strobe   = bram_ren & bram_raddr[7:0] == 8'h00;

// read from registers. Interface's protocol assumes returning data with a delay
reg     [31:0]  bram_rdata_r;
always @ (posedge ACLK) begin
    bram_raddr_r <= bram_ren   ? bram_raddr[7:0] : bram_raddr_r;
    bram_rdata_r <=          ~bram_regen ? bram_rdata_r :
                    bram_raddr_r == 8'hf0 ? reg00 :
                    bram_raddr_r == 8'hf1 ? reg04 :
                    bram_raddr_r == 8'hf2 ? reg08 :
                    bram_raddr_r == 8'hf3 ? reg0c :
                    bram_raddr_r == 8'hf4 ? reg10 :
                    bram_raddr_r == 8'hf5 ? reg14 :
                    bram_raddr_r == 8'h00 ? sh_data_in :
                    bram_raddr_r == 8'h01 ? {16'h0, sh_feature_in} :
                    bram_raddr_r == 8'h02 ? {8'h0, sh_lba_in[23:0]} :
                    bram_raddr_r == 8'h03 ? {8'h0, sh_lba_in[47:24]} :
                    bram_raddr_r == 8'h04 ? {16'h0, sh_count_in} :
                    bram_raddr_r == 8'h05 ? {24'h0, sh_command_in} :
                    bram_raddr_r == 8'h06 ? {24'h0, sh_dev_in} :
                    bram_raddr_r == 8'h07 ? {24'h0, sh_control_in} :
                    bram_raddr_r == 8'h08 ? sh_dma_id_in[31:0] :
                    bram_raddr_r == 8'h09 ? sh_dma_id_in[63:32] :
                    bram_raddr_r == 8'h0a ? sh_dma_off_in :
                    bram_raddr_r == 8'h0b ? {16'h0, sh_tran_cnt_in} : // Transfer Count
                    bram_raddr_r == 8'h0c ? {31'h0, sh_autoact_in} :
                    bram_raddr_r == 8'h0d ? {31'h0, sh_inter_in} :
                    bram_raddr_r == 8'h0e ? {31'h0, sh_dir_in} :
                    bram_raddr_r == 8'h0f ? cmd_in :
                    bram_raddr_r == 8'h10 ? {24'h0, sh_err_in} :
                    bram_raddr_r == 8'h11 ? {24'h0, sh_status_in} :
                    bram_raddr_r == 8'h12 ? {24'h0, sh_estatus_in} : // E_Status
                    bram_raddr_r == 8'h13 ? {28'h0, sh_port_in} :
                    bram_raddr_r == 8'h14 ? sh_dma_cnt_in :
                    bram_raddr_r == 8'h15 ? {31'h0, sh_notif_in} :
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
