/*******************************************************************************
 * Module: command
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: sata command layer temporary implementation
 *
 * Copyright (c) 2015 Elphel, Inc.
 * command.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * command.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
/*
 * For testing purposes almost neat, manually-controlled
 */
module command(
    input   rst,
    input   clk,

    // temporary TODO
    input   wire    gtx_ready,
    input   wire    phy_ready,
    input   wire    [11:0]  debug_cnt,

    // tl cmd iface
    output  wire    [2:0]   cmd_type,
    output  wire            cmd_val,
    output  wire    [3:0]   cmd_port,
    input   wire            cmd_busy,
    input   wire            cmd_done_good,
    input   wire            cmd_done_bad,

    // temporary TODO
    input   wire    [31:0]  al_cmd_in, // == {cmd_type, cmd_port, cmd_val, cmd_done_bad, cmd_done_good, cmd_busy}
    input   wire            al_cmd_val_in,
    output  wire    [31:0]  al_cmd_out, // same

    // data from tl
    input   wire    [31:0]  tl_data_in,
    input   wire            tl_data_val_in,
    input   wire            tl_data_last_in,
    output  wire            tl_data_busy_out,
    // to tl
    output  wire    [31:0]  tl_data_out,
    output  wire            tl_data_last_out,
    output  wire            tl_data_val_out,
    input   wire            tl_data_strobe_in,

    // tmp inputs directly from registers for each and every shadow register and control bit
    // from al
    input   wire    [31:0]  al_sh_data_in, // write data
    input   wire            al_sh_data_val_in, // write strobe
    input   wire            al_sh_data_strobe_in, // read strobe
    input   wire    [15:0]  al_sh_feature_in,
    input   wire            al_sh_feature_val_in,
    input   wire    [23:0]  al_sh_lba_lo_in,
    input   wire            al_sh_lba_lo_val_in,
    input   wire    [23:0]  al_sh_lba_hi_in,
    input   wire            al_sh_lba_hi_val_in,
    input   wire    [15:0]  al_sh_count_in,
    input   wire            al_sh_count_val_in,
    input   wire    [7:0]   al_sh_command_in,
    input   wire            al_sh_command_val_in,
    input   wire    [7:0]   al_sh_dev_in,
    input   wire            al_sh_dev_val_in,
    input   wire    [7:0]   al_sh_control_in,
    input   wire            al_sh_control_val_in,
    input   wire    [31:0]  al_sh_dma_id_lo_in,
    input   wire            al_sh_dma_id_lo_val_in,
    input   wire    [31:0]  al_sh_dma_id_hi_in,
    input   wire            al_sh_dma_id_hi_val_in,
    input   wire    [31:0]  al_sh_buf_off_in,
    input   wire            al_sh_buf_off_val_in,
    input   wire    [15:0]  al_sh_tran_cnt_in,
    input   wire            al_sh_tran_cnt_val_in,
    input   wire            al_sh_autoact_in,
    input   wire            al_sh_autoact_val_in,
    input   wire            al_sh_inter_in,
    input   wire            al_sh_inter_val_in,
    input   wire            al_sh_dir_in,
    input   wire            al_sh_dir_val_in,
    input   wire    [31:0]  al_sh_dma_cnt_in,
    input   wire            al_sh_dma_cnt_val_in,
    input   wire            al_sh_notif_in,
    input   wire            al_sh_notif_val_in,
    input   wire    [3:0]   al_sh_port_in,
    input   wire            al_sh_port_val_in,

    // from tl
    input   wire    [47:0]  tl_sh_lba_in,
    input   wire    [15:0]  tl_sh_count_in,
    input   wire    [7:0]   tl_sh_command_in,
    input   wire    [7:0]   tl_sh_err_in,
    input   wire    [7:0]   tl_sh_status_in,
    input   wire    [7:0]   tl_sh_estatus_in, // E_Status
    input   wire    [7:0]   tl_sh_dev_in,
    input   wire    [3:0]   tl_sh_port_in,
    input   wire            tl_sh_inter_in,
    input   wire            tl_sh_dir_in,
    input   wire    [63:0]  tl_sh_dma_id_in,
    input   wire    [31:0]  tl_sh_dma_off_in,
    input   wire    [31:0]  tl_sh_dma_cnt_in,
    input   wire    [15:0]  tl_sh_tran_cnt_in, // Transfer Count
    input   wire            tl_sh_notif_in,
    input   wire            tl_sh_autoact_in,
    input   wire            tl_sh_lba_val_in,
    input   wire            tl_sh_count_val_in,
    input   wire            tl_sh_command_val_in,
    input   wire            tl_sh_err_val_in,
    input   wire            tl_sh_status_val_in,
    input   wire            tl_sh_estatus_val_in, // E_Status
    input   wire            tl_sh_dev_val_in,
    input   wire            tl_sh_port_val_in,
    input   wire            tl_sh_inter_val_in,
    input   wire            tl_sh_dir_val_in,
    input   wire            tl_sh_dma_id_val_in,
    input   wire            tl_sh_dma_off_val_in,
    input   wire            tl_sh_dma_cnt_val_in,
    input   wire            tl_sh_tran_cnt_val_in, // Transfer Count
    input   wire            tl_sh_notif_val_in,
    input   wire            tl_sh_autoact_val_in,

    // all regs to output
    output  wire            sh_data_val_out,
    output  wire    [31:0]  sh_data_out,
    output  wire    [7:0]   sh_control_out,
    output  wire    [15:0]  sh_feature_out,
    output  wire    [47:0]  sh_lba_out,
    output  wire    [15:0]  sh_count_out,
    output  wire    [7:0]   sh_command_out,
    output  wire    [7:0]   sh_err_out,
    output  wire    [7:0]   sh_status_out,
    output  wire    [7:0]   sh_estatus_out, // E_Status
    output  wire    [7:0]   sh_dev_out,
    output  wire    [3:0]   sh_port_out,
    output  wire            sh_inter_out,
    output  wire            sh_dir_out,
    output  wire    [63:0]  sh_dma_id_out,
    output  wire    [31:0]  sh_dma_off_out,
    output  wire    [31:0]  sh_dma_cnt_out,
    output  wire    [15:0]  sh_tran_cnt_out, // Transfer Count
    output  wire            sh_notif_out,
    output  wire            sh_autoact_out
);


// shadow registers
wire    [31:0]  sh_data;
reg     [7:0]   sh_control;
reg     [15:0]  sh_feature;
reg     [47:0]  sh_lba;
reg     [15:0]  sh_count;
reg     [7:0]   sh_command;
reg     [7:0]   sh_err;
reg     [7:0]   sh_status;
reg     [7:0]   sh_estatus; // E_Status
reg     [7:0]   sh_dev;
reg     [3:0]   sh_port;
reg             sh_inter;
reg             sh_dir;
reg     [63:0]  sh_dma_id;
reg     [31:0]  sh_dma_off;
reg     [31:0]  sh_dma_cnt;
reg     [15:0]  sh_tran_cnt; // Transfer Count
reg             sh_notif;
reg             sh_autoact;

always @ (posedge clk)
begin
//    sh_data          <= rst ? 32'h0 : al_sh_data_val_in       ? al_sh_data_in      : /*tl_sh_data_val_in       ? tl_sh_data_in      :*/ sh_data;
    sh_control       <= rst ? 8'h0  : al_sh_control_val_in    ? al_sh_control_in   : /*tl_sh_control_val_in    ? tl_sh_control_in   :*/ sh_control;
    sh_feature       <= rst ? 16'h0 : al_sh_feature_val_in    ? al_sh_feature_in   : /*tl_sh_feature_val_in    ? tl_sh_feature_in   :*/ sh_feature;
    sh_lba[23:0]     <= rst ? 24'h0 : al_sh_lba_lo_val_in     ? al_sh_lba_lo_in    : tl_sh_lba_val_in     ? tl_sh_lba_in[23:0]    : sh_lba[23:0];
    sh_lba[47:24]    <= rst ? 24'h0 : al_sh_lba_hi_val_in     ? al_sh_lba_hi_in    : tl_sh_lba_val_in     ? tl_sh_lba_in[47:24]   : sh_lba[47:24];
    sh_count         <= rst ? 16'h0 : al_sh_count_val_in      ? al_sh_count_in     : tl_sh_count_val_in      ? tl_sh_count_in     : sh_count;
    sh_command       <= rst ? 8'h0  : al_sh_command_val_in    ? al_sh_command_in   : tl_sh_command_val_in    ? tl_sh_command_in   : sh_command;
    sh_err           <= rst ? 8'h0  :/* al_sh_err_val_in        ? al_sh_err_in       :*/ tl_sh_err_val_in        ? tl_sh_err_in       : sh_err;
    sh_status        <= rst ? 8'h0  :/* al_sh_status_val_in     ? al_sh_status_in    :*/ tl_sh_status_val_in     ? tl_sh_status_in    : sh_status;
    sh_estatus       <= rst ? 8'h0  :/* al_sh_estatus_val_in    ? al_sh_estatus_in   :*/ tl_sh_estatus_val_in    ? tl_sh_estatus_in   : sh_estatus;
    sh_dev           <= rst ? 8'h0  : al_sh_dev_val_in        ? al_sh_dev_in       : tl_sh_dev_val_in        ? tl_sh_dev_in       : sh_dev;
    sh_port          <= rst ? 4'h0  : al_sh_port_val_in       ? al_sh_port_in      : tl_sh_port_val_in       ? tl_sh_port_in      : sh_port;
    sh_inter         <= rst ? 1'h0  : al_sh_inter_val_in      ? al_sh_inter_in     : tl_sh_inter_val_in      ? tl_sh_inter_in     : sh_inter;
    sh_dir           <= rst ? 1'h0  : al_sh_dir_val_in        ? al_sh_dir_in       : tl_sh_dir_val_in        ? tl_sh_dir_in       : sh_dir;
    sh_dma_id[31:0]  <= rst ? 32'h0 : al_sh_dma_id_lo_val_in  ? al_sh_dma_id_lo_in : tl_sh_dma_id_val_in ? tl_sh_dma_id_in[31:0]  : sh_dma_id[31:0];
    sh_dma_id[63:32] <= rst ? 32'h0 : al_sh_dma_id_hi_val_in  ? al_sh_dma_id_hi_in : tl_sh_dma_id_val_in ? tl_sh_dma_id_in[63:32] : sh_dma_id[63:32];
    sh_dma_off       <= rst ? 32'h0 : al_sh_buf_off_val_in    ? al_sh_buf_off_in   : tl_sh_dma_off_val_in    ? tl_sh_dma_off_in   : sh_dma_off;
    sh_dma_cnt       <= rst ? 32'h0 : al_sh_dma_cnt_val_in    ? al_sh_dma_cnt_in   : tl_sh_dma_cnt_val_in    ? tl_sh_dma_cnt_in   : sh_dma_cnt;
    sh_tran_cnt      <= rst ? 16'h0 : al_sh_tran_cnt_val_in   ? al_sh_tran_cnt_in  : tl_sh_tran_cnt_val_in   ? tl_sh_tran_cnt_in  : sh_tran_cnt;
    sh_notif         <= rst ? 1'h0  : al_sh_notif_val_in      ? al_sh_notif_in     : tl_sh_notif_val_in      ? tl_sh_notif_in     : sh_notif;
    sh_autoact       <= rst ? 1'h0  : al_sh_autoact_val_in    ? al_sh_autoact_in   : tl_sh_autoact_val_in    ? tl_sh_autoact_in   : sh_autoact;
end

// outputs assignment
assign  sh_data_out     = sh_data;
assign  sh_control_out  = sh_control;
assign  sh_feature_out  = sh_feature;
assign  sh_lba_out      = sh_lba;
assign  sh_count_out    = sh_count;
assign  sh_command_out  = sh_command;
assign  sh_err_out      = sh_err;
assign  sh_status_out   = sh_status;
assign  sh_estatus_out  = sh_estatus;
assign  sh_dev_out      = sh_dev;
assign  sh_port_out     = sh_port;
assign  sh_inter_out    = sh_inter;
assign  sh_dir_out      = sh_dir;
assign  sh_dma_id_out   = sh_dma_id;
assign  sh_dma_off_out  = sh_dma_off;
assign  sh_dma_cnt_out  = sh_dma_cnt;
assign  sh_tran_cnt_out = sh_tran_cnt;
assign  sh_notif_out    = sh_notif;
assign  sh_autoact_out  = sh_autoact;


// temporaty command register TODO
reg [31:0]  cmd;
assign  al_cmd_out[31:12] = cmd[31:12];
assign  al_cmd_out[11:0]  = debug_cnt;
always @ (posedge clk)
begin
    cmd[27:4]   <= rst ? 24'h0 : al_cmd_val_in ? al_cmd_in[27:4] : cmd[27:4];
    cmd[31]     <= rst ? 1'b1 : cmd[31];
    cmd[30:28]  <= rst ? 3'h0 : {1'b0, phy_ready, gtx_ready};
    cmd[3]      <= rst ? 1'b0 : al_cmd_val_in ? al_cmd_in[3] : cmd_val ? 1'b0 : cmd[3];
    cmd[2]      <= rst ? 1'b0 : al_cmd_val_in ? 1'b0 : cmd_done_bad ? 1'b1 : cmd[2];
    cmd[1]      <= rst ? 1'b0 : al_cmd_val_in ? 1'b0 : cmd_done_good ? 1'b1 : cmd[1];
    cmd[0]      <= rst ? 1'b0 : al_cmd_val_in ? 1'b0 : cmd_busy;
end

assign  cmd_val     = ~cmd_busy & cmd[3];
assign  cmd_type    = cmd[10:8];
assign  cmd_port    = cmd[7:4];


// data read buffer, 2048 dwords
reg     [9:0]   raddr;
reg     [9:0]   waddr;

assign  tl_data_busy_out = 1'b0;

assign  tl_data_out = 32'h0;
assign  tl_data_last_out = 1'b0;
assign  tl_data_val_out = 1'b0;

always @ (posedge clk)
    waddr   <= rst ? 10'b0 : ~tl_data_val_in ? waddr : (raddr == waddr + 1'b1) ? waddr : waddr + 1'b1;
always @ (posedge clk)
    raddr   <= rst ? 10'b0 : al_sh_data_strobe_in ? raddr + 1'b1 : raddr;

// Application layer has different clock ?

ram_1kx32_1kx32 rbuf(
      .rclk     (clk),      // clock for read port
      .raddr    (raddr),    // read address
      .ren      (al_sh_data_strobe_in),         // read port enable
      .regen    (1'b0),     // output register enable
      .data_out (sh_data),    // data out 
      
      .wclk     (clk),      // clock for read port
      .waddr    (waddr),    // write address
      .we       (tl_data_val_in),         // write port enable
      .web      (4'hf),
      .data_in  (tl_data_in)    // data out
);












endmodule
