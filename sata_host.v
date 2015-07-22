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
    output  wire            sata_timer,
    
    // phy
    input   wire            clkin_150,
    input   wire            reset,

    output  wire            linkup,
    output  wire            txp_out,
    output  wire            txn_out,
    input   wire            rxp_in,
    input   wire            rxn_in
);



endmodule
