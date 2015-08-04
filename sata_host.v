/*******************************************************************************
 * Module: sata_host
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: is a wrapper for command + transport + link + phy levels
 *
 * Copyright (c) 2015 Elphel, Inc.
 * sata_host.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * sata_host.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
/*
 * For now assuming the actual rtl would be Ashwin's
 */
module sata_host(
    // command, control and status
    output  wire            ready_for_cmd,
    input   wire            new_cmd,
    input   wire    [1:0]   cmd_type,
    input   wire    [31:0]  sector_count,
    input   wire    [31:0]  sector_addr,

    // data and user clock
    input   wire    [31:0]  sata_din,
    input   wire            sata_din_we,
    output  wire            sata_core_full,
    output  wire    [31:0]  sata_dout,
    input   wire            sata_dout_re,
    output  wire            sata_core_empty,
    input   wire            data_clk_in,
    input   wire            data_clk_out,

    // timer
    output  wire    [31:0]  sata_timer,
    
    // phy
    input   wire            clkin_150,
    input   wire            reset,

    output  wire            linkup,
    output  wire            txp_out,
    output  wire            txn_out,
    input   wire            rxp_in,
    input   wire            rxn_in,

    output  wire            plllkdet,
    output  wire            dcmlocked
);/*
assign  ready_for_cmd = 1'b0;
assign  sata_core_full = 1'b0;
assign  sata_dout = 32'b0;
assign  sata_core_empty = 1'b0;
assign  sata_timer = 1'b0;
assign  linkup = 1'b0;
assign  txp_out = 1'b0;
assign  txn_out = 1'b0;
assign  plllkdet = 1'b0;
assign  dcmlocked = 1'b0;*/
  
sata_core sata_core(
    .ready_for_cmd          (ready_for_cmd),
    .new_cmd                (new_cmd),
    .cmd_type               (cmd_type),
    .sector_count           (sector_count),
    .sector_addr            (sector_addr),
    .sata_din               (sata_din),
    .sata_din_we            (sata_din_we),
    .sata_core_full         (sata_core_full),
    .sata_dout              (sata_dout),
    .sata_dout_re           (sata_dout_re),
    .sata_core_empty        (sata_core_empty),
    .SATA_USER_DATA_CLK_IN  (data_clk_in),
    .SATA_USER_DATA_CLK_OUT (data_clk_out),
    .sata_timer             (sata_timer),
    .CLKIN_150              (clkin_150),
    .reset                  (reset),
    .LINKUP                 (linkup),
    .TXP0_OUT               (txp_out),
    .TXN0_OUT               (txn_out),
    .RXP0_IN                (rxp_in),
    .RXN0_IN                (rxn_in),
    .PLLLKDET_OUT_N         (plllkdet),
    .DCMLOCKED_OUT          (dcmlocked)
);
  

endmodule
