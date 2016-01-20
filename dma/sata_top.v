/*******************************************************************************
 * Module: sata_top
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: sata for z7nq top-level module
 *
 * Copyright (c) 2015 Elphel, Inc.
 * sata_top.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * sata_top.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *
 * Additional permission under GNU GPL version 3 section 7:
 * If you modify this Program, or any covered work, by linking or combining it
 * with independent modules provided by the FPGA vendor only (this permission
 * does not extend to any 3-rd party modules, "soft cores" or macros) under
 * different license terms solely for the purpose of generating binary "bitstream"
 * files and/or simulating the code, the copyright holders of this Program give
 * you the right to distribute the covered work without those independent modules
 * as long as the source code for them is available from the FPGA vendor free of
 * charge, and there is no dependence on any encrypted modules for simulating of
 * the combined code. This permission applies to you if the distributed code
 * contains all the components and scripts required to completely simulate it
 * with at least one of the Free Software programs.
 *******************************************************************************/
`timescale 1ns/1ps
//`include "axi_regs.v"
//`include "dma_regs.v"
//`include "sata_host.v"
//`include "dma_adapter.v"
//`include "dma_control.v"
//`include "membridge.v"
/*
 * Takes commands from axi iface as a slave, transfers data with another axi iface as a master
 */
 module sata_top(
    output  wire    sclk,
    output  wire    sata_rst,
    input   wire    extrst,
    
    // reliable clock to source drp and cpll lock det circuits
    input   wire    reliable_clk,
    
    input   wire    hclk,
    
/*
 * Commands interface
 */
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
// AXI PS Master GP1: Write response
    output  wire                BVALID,            // AXI PS Master GP1 BVALID, input
    input   wire                BREADY,            // AXI PS Master GP1 BREADY, output
    output  wire    [11:0]      BID,               // AXI PS Master GP1 BID[11:0], input
    output  wire    [1:0]       BRESP,             // AXI PS Master GP1 BRESP[1:0], input

/*
 * Data interface
 */
    output  wire    [31:0]  afi_awaddr,
    output  wire            afi_awvalid,
    input   wire            afi_awready,
    output  wire    [5:0]   afi_awid,
    output  wire    [1:0]   afi_awlock,
    output  wire    [3:0]   afi_awcache,
    output  wire    [2:0]   afi_awprot,
    output  wire    [3:0]   afi_awlen,
    output  wire    [1:0]   afi_awsize,
    output  wire    [1:0]   afi_awburst,
    output  wire    [3:0]   afi_awqos,
    // write data
    output  wire    [63:0]  afi_wdata,
    output  wire            afi_wvalid,
    input   wire            afi_wready,
    output  wire    [5:0]   afi_wid,
    output  wire            afi_wlast,
    output  wire    [7:0]   afi_wstrb,
    // write response
    input   wire            afi_bvalid,
    output  wire            afi_bready,
    input   wire    [5:0]   afi_bid,
    input   wire    [1:0]   afi_bresp,
    // PL extra (non-AXI) signals
    input   wire    [7:0]   afi_wcount,
    input   wire    [5:0]   afi_wacount,
    output  wire            afi_wrissuecap1en,
    // AXI_HP signals - read channel
    // read address
    output  wire    [31:0]  afi_araddr,
    output  wire            afi_arvalid,
    input   wire            afi_arready,
    output  wire    [5:0]   afi_arid,
    output  wire    [1:0]   afi_arlock,
    output  wire    [3:0]   afi_arcache,
    output  wire    [2:0]   afi_arprot,
    output  wire    [3:0]   afi_arlen,
    output  wire    [1:0]   afi_arsize,
    output  wire    [1:0]   afi_arburst,
    output  wire    [3:0]   afi_arqos,
    // read data
    input   wire    [63:0]  afi_rdata,
    input   wire            afi_rvalid,
    output  wire            afi_rready,
    input   wire    [5:0]   afi_rid,
    input   wire            afi_rlast,
    input   wire    [1:0]   afi_rresp,
    // PL extra (non-AXI) signals
    input   wire    [7:0]   afi_rcount,
    input   wire    [2:0]   afi_racount,
    output  wire            afi_rdissuecap1en,

/*
 * PHY
 */
    output  wire            TXN,
    output  wire            TXP,
    input   wire            RXN,
    input   wire            RXP,

    input   wire            EXTCLK_P,
    input   wire            EXTCLK_N
 );

//wire    sata_rst;
// dma_regs <-> sata host
// tmp to cmd control
wire            cmd_val_out;
wire    [31:0]  cmd_out;
// tmp to shadow registers
wire    [31:0]  sh_data; // write data
wire            sh_data_val; // write strobe
wire            sh_data_strobe; // read strobe
wire    [15:0]  sh_feature;
wire            sh_feature_val;
wire    [23:0]  sh_lba_lo;
wire            sh_lba_lo_val;
wire    [23:0]  sh_lba_hi;
wire            sh_lba_hi_val;
wire    [15:0]  sh_count;
wire            sh_count_val;
wire    [7:0]   sh_command;
wire            sh_command_val;
wire    [7:0]   sh_dev;
wire            sh_dev_val;
wire    [7:0]   sh_control;
wire            sh_control_val;
wire    [31:0]  sh_dma_id_lo;
wire            sh_dma_id_lo_val;
wire    [31:0]  sh_dma_id_hi;
wire            sh_dma_id_hi_val;
wire    [31:0]  sh_buf_off;
wire            sh_buf_off_val;
wire    [31:0]  sh_dma_cnt;
wire            sh_dma_cnt_val;
wire    [15:0]  sh_tran_cnt;
wire            sh_tran_cnt_val;
wire            sh_autoact;
wire            sh_autoact_val;
wire            sh_inter;
wire            sh_inter_val;
wire    [3:0]   sh_port;
wire            sh_port_val;
wire            sh_notif;
wire            sh_notif_val;
wire            sh_dir;
wire            sh_dir_val;
// inputs from sh registers
wire            sh_data_val_in;
wire    [31:0]  sh_data_in;
wire    [7:0]   sh_control_in;
wire    [15:0]  sh_feature_in;
wire    [47:0]  sh_lba_in;
wire    [15:0]  sh_count_in;
wire    [7:0]   sh_command_in;
wire    [7:0]   sh_err_in;
wire    [7:0]   sh_status_in;
wire    [7:0]   sh_estatus_in; // E_Status
wire    [7:0]   sh_dev_in;
wire    [3:0]   sh_port_in;
wire            sh_inter_in;
wire            sh_dir_in;
wire    [63:0]  sh_dma_id_in;
wire    [31:0]  sh_dma_off_in;
wire    [31:0]  sh_dma_cnt_in;
wire    [15:0]  sh_tran_cnt_in; // Transfer Count
wire            sh_notif_in;
wire            sh_autoact_in;
// inputs from cmd control
wire    [31:0]  cmd_in;

// axi_regs <-> data regs
wire    [31:0]      bram_rdata;
wire    [31:0]      bram_waddr;
wire    [31:0]      bram_wdata;
wire    [31:0]      bram_raddr;
wire    [3:0]       bram_wstb;
wire                bram_wen;
wire                bram_ren;
wire                bram_regen;
// sata logic reset
//wire            rst;
// sata clk
//wire            sclk;
// dma_regs <-> dma_control
wire    [31:7]  mem_address;
wire    [31:0]  lba;
wire    [31:0]  sector_cnt;
wire            dma_type;
wire            dma_start;
wire            dma_done;
// axi-hp clock
//wire            hclk;
// dma_control <-> dma_adapter command iface
wire            adp_busy;
wire    [31:7]  adp_addr;
wire            adp_type;
wire            adp_val;
// dma_control <-> sata_host command iface
wire            host_ready_for_cmd;
wire            host_new_cmd;
wire    [1:0]   host_cmd_type;
wire    [31:0]  host_sector_count;
wire    [31:0]  host_sector_addr;
// dma_control <-> dma_adapter data iface
wire    [63:0]  to_data;
wire            to_val;
wire            to_ack;
wire    [63:0]  from_data;
wire            from_val;
wire            from_ack;
// dma_control <-> sata_host data iface
wire    [31:0]  in_data;
wire            in_val;
wire            in_busy;
wire    [31:0]  out_data;
wire            out_val;
wire            out_busy;
// adapter <-> membridge iface
wire    [7:0]   cmd_ad;
wire            cmd_stb;
wire    [7:0]   status_ad;
wire            status_rq;
wire            status_start;
wire            frame_start_chn;
wire            next_page_chn;
wire            cmd_wrmem;
wire            page_ready_chn;
wire            frame_done_chn;
wire    [15:0]  line_unfinished_chn1;
wire            suspend_chn1;
wire            xfer_reset_page_rd;
wire            buf_wpage_nxt;
wire            buf_wr;
wire    [63:0]  buf_wdata;
wire            xfer_reset_page_wr;
wire            buf_rpage_nxt;
wire            buf_rd;
wire    [63:0]  buf_rdata;
// additional adapter <-> membridge wire
wire            rdata_done; // = membridge.is_last_in_page & membridge.afi_rready;

//assign  rst = ARESETN;
reg hrst;
always @ (posedge hclk)
    hrst <= sata_rst;

axi_regs axi_regs(
// axi iface
    .ACLK               (ACLK),      // input wire
    .ARESETN            (ARESETN),   // input wire 
    .ARADDR             (ARADDR),    // input[31:0] wire
    .ARVALID            (ARVALID),   // input wire 
    .ARREADY            (ARREADY),   // output wire
    .ARID               (ARID),      // input[11:0] wire
    .ARLEN              (ARLEN),     // input[3:0] wire 
    .ARSIZE             (ARSIZE),    // input[1:0] wire 
    .ARBURST            (ARBURST),   // input[1:0] wire
    .RDATA              (RDATA),     // output[31:0] wire
    .RVALID             (RVALID),    // output wire
    .RREADY             (RREADY),    // input wire
    .RID                (RID),       // output[11:0] wire 
    .RLAST              (RLAST),     // output wire 
    .RRESP              (RRESP),     // output[1:0] wire
    .AWADDR             (AWADDR),    // input[31:0] wire 
    .AWVALID            (AWVALID),   // input wire
    .AWREADY            (AWREADY),   // output wire
    .AWID               (AWID),      // input[11:0] wire 
    .AWLEN              (AWLEN),     // input[3:0] wire 
    .AWSIZE             (AWSIZE),    // input[1:0] wire
    .AWBURST            (AWBURST),   // input[1:0] wire
    .WDATA              (WDATA),     // input[31:0] wire 
    .WVALID             (WVALID),    // input wire 
    .WREADY             (WREADY),    // output wire
    .WID                (WID),       // input[11:0] wire 
    .WLAST              (WLAST),     // input wire
    .WSTRB              (WSTRB),     // input wire
    .BVALID             (BVALID),    // output wire 
    .BREADY             (BREADY),    // input wire
    .BID                (BID),       // output[11:0] wire
    .BRESP              (BRESP),     // output[1:0] wire 
// registers iface
    .bram_rdata         (bram_rdata),// input[31:0] wire 
    .bram_waddr         (bram_waddr),// output[31:0] wire 
    .bram_wdata         (bram_wdata),// output[31:0] wire
    .bram_raddr         (bram_raddr),// output[31:0] wire
    .bram_wstb          (bram_wstb), // output[3:0] wire
    .bram_wen           (bram_wen),  // output wire
    .bram_ren           (bram_ren),  // output wire
    .bram_regen         (bram_regen) // output wire
);


/*
 * Programmable sata controller registers
 */
dma_regs dma_regs(
    .rst            (ARESETN),                     // input wire 
    .ACLK           (ACLK),                        // input wire
    .sclk           (sclk),                        // input wire
// control iface
    .mem_address    (mem_address[31:7]),           // output[31:7] wire
    .lba            (lba),                         // output[31:0] wire
    .sector_cnt     (sector_cnt),                  // output[31:0] wire
    .dma_type       (dma_type),                    // output wire 
    .dma_start      (dma_start),                   // output wire 
    .dma_done       (dma_done),                    // input wire
// axi buffer iface
    .bram_rdata     (bram_rdata),                  // output[31:0] wire 
    .bram_raddr     (bram_raddr),                  // input[31:0] wire
    .bram_waddr     (bram_waddr),                  // input[31:0] wire
    .bram_wdata     (bram_wdata),                  // input[31:0] wire
    .bram_wstb      (bram_wstb),                   // input[ 3:0] wire
    .bram_wen       (bram_wen),                    // input wire
    .bram_ren       (bram_ren),                    // input wire
    .bram_regen     (bram_regen),                  // input wire

// direct connections to the host
// tmp to cmd control
    .cmd_val_out                (cmd_val_out),     // output wire 
    .cmd_out                    (cmd_out),         // output[31:0] wire 
// tmp to shadow registers
    .sh_data                    (sh_data),         // output[31:0] wire : write data
    .sh_data_val                (sh_data_val),     // output wire: write strobe
    .sh_data_strobe             (sh_data_strobe),  // output wire: read strobe
    .sh_feature                 (sh_feature),      // output[15:0] wire 
    .sh_feature_val             (sh_feature_val),  // output wire
    .sh_lba_lo                  (sh_lba_lo),       // output[23:0] wire
    .sh_lba_lo_val              (sh_lba_lo_val),   // output wire
    .sh_lba_hi                  (sh_lba_hi),       // output[23:0] wire 
    .sh_lba_hi_val              (sh_lba_hi_val),   // output wire
    .sh_count                   (sh_count),        // output[15:0] wire
    .sh_count_val               (sh_count_val),    // output wire
    .sh_command                 (sh_command),      // output[7:0] wire
    .sh_command_val             (sh_command_val),  // output wire
    .sh_dev                     (sh_dev),          // output[7:0] wire
    .sh_dev_val                 (sh_dev_val),  // output wire
    .sh_control                 (sh_control),      // output[7:0] wire
    .sh_control_val             (sh_control_val),  // output wire
    .sh_dma_id_lo               (sh_dma_id_lo),    // output[31:0] wire 
    .sh_dma_id_lo_val           (sh_dma_id_lo_val),// output wire
    .sh_dma_id_hi               (sh_dma_id_hi),    // output[31:0] wire 
    .sh_dma_id_hi_val           (sh_dma_id_hi_val),// output wire
    .sh_buf_off                 (sh_buf_off),      // output[31:0] wire 
    .sh_buf_off_val             (sh_buf_off_val),  // output wire
    .sh_dma_cnt                 (sh_dma_cnt),      // output[31:0] wire 
    .sh_dma_cnt_val             (sh_dma_cnt_val),  // output wire
    .sh_tran_cnt                (sh_tran_cnt),     // output[15:0] wire 
    .sh_tran_cnt_val            (sh_tran_cnt_val), // output wire
    .sh_autoact                 (sh_autoact),      // output wire
    .sh_autoact_val             (sh_autoact_val),  // output wire
    .sh_inter                   (sh_inter),        // output wire
    .sh_inter_val               (sh_inter_val),    // output wire
    .sh_port                    (sh_port),         // output[3:0] wire 
    .sh_port_val                (sh_port_val),     // output wire
    .sh_notif                   (sh_notif),        // output wire
    .sh_notif_val               (sh_notif_val),    // output wire
    .sh_dir                     (sh_dir),          // output wire
    .sh_dir_val                 (sh_dir_val),      // output wire

// inputs from sh registers
    .sh_data_val_in             (sh_data_val_in),  // input wire 
    .sh_data_in                 (sh_data_in),      // input[31:0] wire
    .sh_control_in              (sh_control_in),   // input[7:0] wire
    .sh_feature_in              (sh_feature_in),   // input[15:0] wire 
    .sh_lba_in                  (sh_lba_in),       // input[47:0] wire 
    .sh_count_in                (sh_count_in),     // input[15:0] wire 
    .sh_command_in              (sh_command_in),   // input[7:0] wire 
    .sh_err_in                  (sh_err_in),       // input[7:0] wire 
    .sh_status_in               (sh_status_in),    // input[7:0] wire 
    .sh_estatus_in              (sh_estatus_in),   // input[7:0] wire :  E_Status
    .sh_dev_in                  (sh_dev_in),       // input[7:0] wire 
    .sh_port_in                 (sh_port_in),      // input[3:0] wire 
    .sh_inter_in                (sh_inter_in),     // input wire
    .sh_dir_in                  (sh_dir_in),       // input wire
    .sh_dma_id_in               (sh_dma_id_in),    // input[63:0] wire 
    .sh_dma_off_in              (sh_dma_off_in),   // input[31:0] wire
    .sh_dma_cnt_in              (sh_dma_cnt_in),   // input[31:0] wire
    .sh_tran_cnt_in             (sh_tran_cnt_in),  // Transfer Count
    .sh_notif_in                (sh_notif_in),     // input wire
    .sh_autoact_in              (sh_autoact_in),   // input wire
// inputs from cmd control
    .cmd_in                     (cmd_in)           // input[31:0] wire
);


dma_control dma_control(
    .sclk               (sclk),               // input wire
    .hclk               (hclk),               // input wire
    .rst                (sata_rst),           // input wire

    // registers iface
    .mem_address        (mem_address[31:7]),  // input[31:7] wire
    .lba                (lba),                // input[31:0] wire 
    .sector_cnt         (sector_cnt),         // input[31:0] wire
    .dma_type           (dma_type),           // input wire
    .dma_start          (dma_start),          // input wire
    .dma_done           (dma_done),           // output wire

    // adapter command iface
    .adp_busy           (adp_busy),           // input wire
    .adp_addr           (adp_addr[31:7]),     // output[31:7] wire 
    .adp_type           (adp_type),           // output wire
    .adp_val            (adp_val),            // output wire

    // sata host command iface
    .host_ready_for_cmd (host_ready_for_cmd), // input wire
    .host_new_cmd       (host_new_cmd),       // output wire
    .host_cmd_type      (host_cmd_type),      // output[1:0] wire 
    .host_sector_count  (host_sector_count),  // output[31:0] wire
    .host_sector_addr   (host_sector_addr),   // output[31:0] wire

    // adapter data iface
    // to main memory
    .to_data            (to_data),            // output[63:0] wire
    .to_val             (to_val),             // output wire
    .to_ack             (to_ack),             // input wire
    // from main memory
    .from_data          (from_data),          // input[63:0] wire
    .from_val           (from_val),           // input wire
    .from_ack           (from_ack),           // output wire

    // sata host iface
    // data from sata host
    .in_data            (in_data),            // input[31:0] wire
    .in_val             (in_val),             // output wire
    .in_busy            (in_busy),            // input wire
    // data to sata host
    .out_data           (out_data),           // output[31:0] wire
    .out_val            (out_val),            // output wire
    .out_busy           (out_busy)            // input wire
);

//assign  rdata_done = membridge.is_last_in_page & membridge.afi_rready;

dma_adapter dma_adapter(
    .clk                    (hclk),                // input wire
    .rst                    (hrst),                // input wire
// command iface                            
    .cmd_type               (adp_type),            // input wire
    .cmd_val                (adp_val),             // input wire
    .cmd_addr               (adp_addr[31:7]),      // input[31:7] wire
    .cmd_busy               (adp_busy),            // output wire
// data iface                            
    .wr_data_in             (to_data),             // input[63:0] wire
    .wr_val_in              (to_val),              // input wire
    .wr_ack_out             (to_ack),              // output wire
    .rd_data_out            (from_data),           // output[63:0] wire
    .rd_val_out             (from_val),            // output wire
    .rd_ack_in              (from_ack),            // input wire
// membridge iface
    .cmd_ad                 (cmd_ad),              // output[7:0] wire 
    .cmd_stb                (cmd_stb),             // output wire
    .status_ad              (status_ad),           // input[7:0] wire Not used
    .status_rq              (status_rq),           // input wire  Not used
    .status_start           (status_start),        // output wire
    .frame_start_chn        (frame_start_chn),     // input wire  Not used
    .next_page_chn          (next_page_chn),       // input wire  Not used
    .cmd_wrmem              (cmd_wrmem),           // output wire
    .page_ready_chn         (page_ready_chn),      // output wire
    .frame_done_chn         (frame_done_chn),      // output wire
    .line_unfinished_chn1   (line_unfinished_chn1),// output[15:0] wire  Not used
    .suspend_chn1           (suspend_chn1),        // input wire  Not used
    .xfer_reset_page_rd     (xfer_reset_page_rd),  // output wire
    .buf_wpage_nxt          (buf_wpage_nxt),       // output wire
    .buf_wr                 (buf_wr),              // output wire
    .buf_wdata              (buf_wdata),           // output[63:0] wire
    .xfer_reset_page_wr     (xfer_reset_page_wr),  // output wire
    .buf_rpage_nxt          (buf_rpage_nxt),       // output wire
    .buf_rd                 (buf_rd),              // output wire
    .buf_rdata              (buf_rdata),           // input[63:0] wire
    .rdata_done             (rdata_done)           // input wire 
);


membridge /*#(
V    .MEMBRIDGE_ADDR         (),
    .MEMBRIDGE_MASK         (),
    .MEMBRIDGE_CTRL         (),
    .MEMBRIDGE_STATUS_CNTRL (),
    .MEMBRIDGE_LO_ADDR64    (),
    .MEMBRIDGE_SIZE64       (),
    .MEMBRIDGE_START64      (),
    .MEMBRIDGE_LEN64        (),
    .MEMBRIDGE_WIDTH64      (),
    .MEMBRIDGE_MODE         (),
    .MEMBRIDGE_STATUS_REG   (),
    .FRAME_HEIGHT_BITS      (),
    .FRAME_WIDTH_BITS       ()
)*/ membridge(
    .mrst                   (sata_rst), // hrst),   // input Andrey: Wrong, should be @sclk
    .hrst                   (hrst),                 // input
    .mclk                   (sclk),                 // input
    .hclk                   (hclk),                 // input
    .cmd_ad                 (cmd_ad),               // input[7:0]
    .cmd_stb                (cmd_stb),              // input // Nothing here
    .status_ad              (status_ad),            // output[7:0] 
    .status_rq              (status_rq),            // output
    .status_start           (status_start),         // input
    .frame_start_chn        (frame_start_chn),      // output
    .next_page_chn          (next_page_chn),        // output
    .cmd_wrmem              (cmd_wrmem),            // input
    .page_ready_chn         (page_ready_chn),       // input
    .frame_done_chn         (frame_done_chn),       // input
    .line_unfinished_chn1   (line_unfinished_chn1), // input[15:0]
    .suspend_chn1           (suspend_chn1),         // output
    .xfer_reset_page_rd     (xfer_reset_page_rd),   // input
    .buf_wpage_nxt          (buf_wpage_nxt),        // input
    .buf_wr                 (buf_wr),               // input
    .buf_wdata              (buf_wdata),            // input[63:0] 
    .xfer_reset_page_wr     (xfer_reset_page_wr),   // input
    .buf_rpage_nxt          (buf_rpage_nxt),        // input
    .buf_rd                 (buf_rd),               // input
    .buf_rdata              (buf_rdata),            // output[63:0]

    .afi_awaddr             (afi_awaddr),           // output[31:0] 
    .afi_awvalid            (afi_awvalid),          // output
    .afi_awready            (afi_awready),          // input
    .afi_awid               (afi_awid),             // output[5:0] 
    .afi_awlock             (afi_awlock),           // output[1:0] 
    .afi_awcache            (afi_awcache),          // output[3:0] 
    .afi_awprot             (afi_awprot),           // output[2:0] 
    .afi_awlen              (afi_awlen),            // output[3:0] 
    .afi_awsize             (afi_awsize),           // output[2:0] 
    .afi_awburst            (afi_awburst),          // output[1:0] 
    .afi_awqos              (afi_awqos),            // output[3:0] 
    .afi_wdata              (afi_wdata),            // output[63:0] 
    .afi_wvalid             (afi_wvalid),           // output
    .afi_wready             (afi_wready),           // input
    .afi_wid                (afi_wid),              // output[5:0] 
    .afi_wlast              (afi_wlast),            // output
    .afi_wstrb              (afi_wstrb),            // output[7:0] 
    .afi_bvalid             (afi_bvalid),           // input
    .afi_bready             (afi_bready),           // output
    .afi_bid                (afi_bid),              // input[5:0] 
    .afi_bresp              (afi_bresp),            // input[1:0] 
    .afi_wcount             (afi_wcount),           // input[7:0] 
    .afi_wacount            (afi_wacount),          // input[5:0] 
    .afi_wrissuecap1en      (afi_wrissuecap1en),    // output
    .afi_araddr             (afi_araddr),           // output[31:0] 
    .afi_arvalid            (afi_arvalid),          // output
    .afi_arready            (afi_arready),          // input
    .afi_arid               (afi_arid),             // output[5:0] 
    .afi_arlock             (afi_arlock),           // output[1:0] 
    .afi_arcache            (afi_arcache),          // output[3:0] 
    .afi_arprot             (afi_arprot),           // output[2:0] 
    .afi_arlen              (afi_arlen),            // output[3:0] 
    .afi_arsize             (afi_arsize),           // output[2:0] 
    .afi_arburst            (afi_arburst),          // output[1:0] 
    .afi_arqos              (afi_arqos),            // output[3:0] 
    .afi_rdata              (afi_rdata),            // input[63:0] 
    .afi_rvalid             (afi_rvalid),           // input
    .afi_rready             (afi_rready),           // output
    .afi_rid                (afi_rid),              // input[5:0] 
    .afi_rlast              (afi_rlast),            // input
    .afi_rresp              (afi_rresp),            // input[2:0] 
    .afi_rcount             (afi_rcount),           // input[7:0] 
    .afi_racount            (afi_racount),          // input[2:0] 
    .afi_rdissuecap1en      (afi_rdissuecap1en)/*,  // output
    .rdata_done             (rdata_done)*/
);
assign rdata_done = 1'b0;

sata_host sata_host(
    .extrst                     (extrst),
    // sata rst
    .rst                        (sata_rst),
    // sata clk
    .clk                        (sclk),
    // reliable clock to source drp and cpll lock det circuits
    .reliable_clk               (reliable_clk),
// temporary
    .al_cmd_in                  (cmd_out), // == {cmd_type, cmd_port, cmd_val, cmd_done_bad, cmd_done_good; cmd_busy}
    .al_cmd_val_in              (cmd_val_out),
    .al_cmd_out                 (cmd_in), // same

// tmp inputs directly from registers for each and every shadow register and control bit
// from al
    .al_sh_data_in              (sh_data), // write data
    .al_sh_data_val_in          (sh_data_val), // write strobe
    .al_sh_data_strobe_in       (sh_data_strobe), // read strobe
    .al_sh_feature_in           (sh_feature),
    .al_sh_feature_val_in       (sh_feature_val),
    .al_sh_lba_lo_in            (sh_lba_lo),
    .al_sh_lba_lo_val_in        (sh_lba_lo_val),
    .al_sh_lba_hi_in            (sh_lba_hi),
    .al_sh_lba_hi_val_in        (sh_lba_hi_val),
    .al_sh_count_in             (sh_count),
    .al_sh_count_val_in         (sh_count_val),
    .al_sh_command_in           (sh_command),
    .al_sh_command_val_in       (sh_command_val),
    .al_sh_dev_in               (sh_dev),
    .al_sh_dev_val_in           (sh_dev_val),
    .al_sh_control_in           (sh_control),
    .al_sh_control_val_in       (sh_control_val),
    .al_sh_dma_id_lo_in         (sh_dma_id_lo),
    .al_sh_dma_id_lo_val_in     (sh_dma_id_lo_val),
    .al_sh_dma_id_hi_in         (sh_dma_id_hi),
    .al_sh_dma_id_hi_val_in     (sh_dma_id_hi_val),
    .al_sh_buf_off_in           (sh_buf_off),
    .al_sh_buf_off_val_in       (sh_buf_off_val),
    .al_sh_tran_cnt_in          (sh_tran_cnt),
    .al_sh_tran_cnt_val_in      (sh_tran_cnt_val),
    .al_sh_autoact_in           (sh_autoact),
    .al_sh_autoact_val_in       (sh_autoact_val),
    .al_sh_inter_in             (sh_inter),
    .al_sh_inter_val_in         (sh_inter_val),
    .al_sh_dir_in               (sh_dir),
    .al_sh_dir_val_in           (sh_dir_val),
    .al_sh_dma_cnt_in           (sh_dma_cnt),
    .al_sh_dma_cnt_val_in       (sh_dma_cnt_val),
    .al_sh_notif_in             (sh_notif),
    .al_sh_notif_val_in         (sh_notif_val),
    .al_sh_port_in              (sh_port),
    .al_sh_port_val_in          (sh_port_val),

// outputs from shadow registers - no registers, just MUX-ed and read @ACLK

    .sh_data_val_out            (sh_data_val_in),
    .sh_data_out                (sh_data_in),
    .sh_control_out             (sh_control_in),
    .sh_feature_out             (sh_feature_in),
    .sh_lba_out                 (sh_lba_in),
    .sh_count_out               (sh_count_in),
    .sh_command_out             (sh_command_in),
    .sh_err_out                 (sh_err_in),
    .sh_status_out              (sh_status_in),
    .sh_estatus_out             (sh_estatus_in), // E_Status
    .sh_dev_out                 (sh_dev_in),
    .sh_port_out                (sh_port_in),
    .sh_inter_out               (sh_inter_in),
    .sh_dir_out                 (sh_dir_in),
    .sh_dma_id_out              (sh_dma_id_in),
    .sh_dma_off_out             (sh_dma_off_in),
    .sh_dma_cnt_out             (sh_dma_cnt_in),
    .sh_tran_cnt_out            (sh_tran_cnt_in), // Transfer Count
    .sh_notif_out               (sh_notif_in),
    .sh_autoact_out             (sh_autoact_in),

// top-level ifaces
// ref clk from an external source, shall be connected to pads
    .extclk_p                   (EXTCLK_P),
    .extclk_n                   (EXTCLK_N),
// sata physical link data pins      
    .txp_out                    (TXP),
    .txn_out                    (TXN),
    .rxp_in                     (RXP),
    .rxn_in                     (RXN)
);

endmodule
