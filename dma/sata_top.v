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
 *******************************************************************************/
`timescale 1ns/1ps
`include "axi_regs.v"
`include "dma_regs.v"
`include "sata_host.v"
`include "dma_adapter.v"
`include "dma_control.v"
`include "membridge.v"
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
// AXI PS Master GP1: Write Responce
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
    output  wire    [2:0]   afi_awsize,
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
    output  wire    [2:0]   afi_arsize,
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
    .ACLK               (ACLK),
    .ARESETN            (ARESETN),
    .ARADDR             (ARADDR),
    .ARVALID            (ARVALID),
    .ARREADY            (ARREADY),
    .ARID               (ARID),
    .ARLEN              (ARLEN),
    .ARSIZE             (ARSIZE),
    .ARBURST            (ARBURST),
    .RDATA              (RDATA),
    .RVALID             (RVALID),
    .RREADY             (RREADY),
    .RID                (RID),
    .RLAST              (RLAST),
    .RRESP              (RRESP),
    .AWADDR             (AWADDR),
    .AWVALID            (AWVALID),
    .AWREADY            (AWREADY),
    .AWID               (AWID),
    .AWLEN              (AWLEN),
    .AWSIZE             (AWSIZE),
    .AWBURST            (AWBURST),
    .WDATA              (WDATA),
    .WVALID             (WVALID),
    .WREADY             (WREADY),
    .WID                (WID),
    .WLAST              (WLAST),
    .WSTRB              (WSTRB),
    .BVALID             (BVALID),
    .BREADY             (BREADY),
    .BID                (BID),
    .BRESP              (BRESP),
// registers iface
    .bram_rdata         (bram_rdata),
    .bram_waddr         (bram_waddr),
    .bram_wdata         (bram_wdata),
    .bram_raddr         (bram_raddr),
    .bram_wstb          (bram_wstb),
    .bram_wen           (bram_wen),
    .bram_ren           (bram_ren),
    .bram_regen         (bram_regen)
);

/*
 * Programmable sata controller registers
 */
dma_regs dma_regs(
    .rst            (sata_rst),
    .ACLK           (ACLK),
    .sclk           (sclk),
// control iface
    .mem_address    (mem_address[31:7]),
    .lba            (lba),
    .sector_cnt     (sector_cnt),
    .dma_type       (dma_type),
    .dma_start      (dma_start),
    .dma_done       (dma_done),
// axi buffer iface
    .bram_rdata     (bram_rdata),
    .bram_raddr     (bram_raddr),
    .bram_waddr     (bram_waddr),
    .bram_wdata     (bram_wdata),
    .bram_wstb      (bram_wstb),
    .bram_wen       (bram_wen),
    .bram_ren       (bram_ren),
    .bram_regen     (bram_regen),

// direct connections to the host
// tmp to cmd control
    .cmd_val_out                (cmd_val_out),
    .cmd_out                    (cmd_out),
// tmp to shadow registers
    .sh_data                    (sh_data), // write data
    .sh_data_val                (sh_data_val), // write strobe
    .sh_data_strobe             (sh_data_strobe), // read strobe
    .sh_feature                 (sh_feature),
    .sh_feature_val             (sh_feature_val),
    .sh_lba_lo                  (sh_lba_lo),
    .sh_lba_lo_val              (sh_lba_lo_val),
    .sh_lba_hi                  (sh_lba_hi),
    .sh_lba_hi_val              (sh_lba_hi_val),
    .sh_count                   (sh_count),
    .sh_count_val               (sh_count_val),
    .sh_command                 (sh_command),
    .sh_command_val             (sh_command_val),
    .sh_dev                     (sh_dev),
    .sh_dev_val                 (sh_dev_val),
    .sh_control                 (sh_control),
    .sh_control_val             (sh_control_val),
    .sh_dma_id_lo               (sh_dma_id_lo),
    .sh_dma_id_lo_val           (sh_dma_id_lo_val),
    .sh_dma_id_hi               (sh_dma_id_hi),
    .sh_dma_id_hi_val           (sh_dma_id_hi_val),
    .sh_buf_off                 (sh_buf_off),
    .sh_buf_off_val             (sh_buf_off_val),
    .sh_dma_cnt                 (sh_dma_cnt),
    .sh_dma_cnt_val             (sh_dma_cnt_val),
    .sh_tran_cnt                (sh_tran_cnt),
    .sh_tran_cnt_val            (sh_tran_cnt_val),
    .sh_autoact                 (sh_autoact),
    .sh_autoact_val             (sh_autoact_val),
    .sh_inter                   (sh_inter),
    .sh_inter_val               (sh_inter_val),
    .sh_port                    (sh_port),
    .sh_port_val                (sh_port_val),
    .sh_notif                   (sh_notif),
    .sh_notif_val               (sh_notif_val),
    .sh_dir                     (sh_dir),
    .sh_dir_val                 (sh_dir_val),

// inputs from sh registers
    .sh_data_val_in             (sh_data_val_in),
    .sh_data_in                 (sh_data_in),
    .sh_control_in              (sh_control_in),
    .sh_feature_in              (sh_feature_in),
    .sh_lba_in                  (sh_lba_in),
    .sh_count_in                (sh_count_in),
    .sh_command_in              (sh_command_in),
    .sh_err_in                  (sh_err_in),
    .sh_status_in               (sh_status_in),
    .sh_estatus_in              (sh_estatus_in), // E_Status
    .sh_dev_in                  (sh_dev_in),
    .sh_port_in                 (sh_port_in),
    .sh_inter_in                (sh_inter_in),
    .sh_dir_in                  (sh_dir_in),
    .sh_dma_id_in               (sh_dma_id_in),
    .sh_dma_off_in              (sh_dma_off_in),
    .sh_dma_cnt_in              (sh_dma_cnt_in),
    .sh_tran_cnt_in             (sh_tran_cnt_in), // Transfer Count
    .sh_notif_in                (sh_notif_in),
    .sh_autoact_in              (sh_autoact_in),
// inputs from cmd control
    .cmd_in                     (cmd_in)
);


dma_control dma_control(
    .sclk               (sclk),
    .hclk               (hclk),
    .rst                (sata_rst),

    // registers iface
    .mem_address        (mem_address[31:7]),
    .lba                (lba),
    .sector_cnt         (sector_cnt),
    .dma_type           (dma_type),
    .dma_start          (dma_start),
    .dma_done           (dma_done),

    // adapter command iface
    .adp_busy           (adp_busy),
    .adp_addr           (adp_addr[31:7]),
    .adp_type           (adp_type),
    .adp_val            (adp_val),

    // sata host command iface
    .host_ready_for_cmd (host_ready_for_cmd),
    .host_new_cmd       (host_new_cmd),
    .host_cmd_type      (host_cmd_type),
    .host_sector_count  (host_sector_count),
    .host_sector_addr   (host_sector_addr),

    // adapter data iface
    // to main memory
    .to_data            (to_data),
    .to_val             (to_val),
    .to_ack             (to_ack),
    // from main memory
    .from_data          (from_data),
    .from_val           (from_val),
    .from_ack           (from_ack),

    // sata host iface
    // data from sata host
    .in_data            (in_data),
    .in_val             (in_val),
    .in_busy            (in_busy),
    // data to sata host
    .out_data           (out_data),
    .out_val            (out_val),
    .out_busy           (out_busy)
);

//assign  rdata_done = membridge.is_last_in_page & membridge.afi_rready;

dma_adapter dma_adapter(
    .clk                    (hclk),
    .rst                    (hrst),
// command iface                            
    .cmd_type               (adp_type),
    .cmd_val                (adp_val),
    .cmd_addr               (adp_addr[31:7]),
    .cmd_busy               (adp_busy),
// data iface                            
    .wr_data_in             (to_data),
    .wr_val_in              (to_val),
    .wr_ack_out             (to_ack),
    .rd_data_out            (from_data),
    .rd_val_out             (from_val),
    .rd_ack_in              (from_ack),
// membridge iface
    .cmd_ad                 (cmd_ad),
    .cmd_stb                (cmd_stb),
    .status_ad              (status_ad),
    .status_rq              (status_rq),
    .status_start           (status_start),
    .frame_start_chn        (frame_start_chn),
    .next_page_chn          (next_page_chn),
    .cmd_wrmem              (cmd_wrmem),
    .page_ready_chn         (page_ready_chn),
    .frame_done_chn         (frame_done_chn),
    .line_unfinished_chn1   (line_unfinished_chn1),
    .suspend_chn1           (suspend_chn1),
    .xfer_reset_page_rd     (xfer_reset_page_rd),
    .buf_wpage_nxt          (buf_wpage_nxt),
    .buf_wr                 (buf_wr),
    .buf_wdata              (buf_wdata),
    .xfer_reset_page_wr     (xfer_reset_page_wr),
    .buf_rpage_nxt          (buf_rpage_nxt),
    .buf_rd                 (buf_rd),
    .buf_rdata              (buf_rdata),
    .rdata_done             (rdata_done)
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
    .mrst                   (hrst), // input
    .hrst                   (hrst), // input
    .mclk                   (hclk), // input
    .hclk                   (hclk), // input
    .cmd_ad                 (cmd_ad),
    .cmd_stb                (cmd_stb),
    .status_ad              (status_ad),
    .status_rq              (status_rq),
    .status_start           (status_start),
    .frame_start_chn        (frame_start_chn),
    .next_page_chn          (next_page_chn),
    .cmd_wrmem              (cmd_wrmem),
    .page_ready_chn         (page_ready_chn),
    .frame_done_chn         (frame_done_chn),
    .line_unfinished_chn1   (line_unfinished_chn1),
    .suspend_chn1           (suspend_chn1),
    .xfer_reset_page_rd     (xfer_reset_page_rd),
    .buf_wpage_nxt          (buf_wpage_nxt),
    .buf_wr                 (buf_wr),
    .buf_wdata              (buf_wdata),
    .xfer_reset_page_wr     (xfer_reset_page_wr),
    .buf_rpage_nxt          (buf_rpage_nxt),
    .buf_rd                 (buf_rd),
    .buf_rdata              (buf_rdata),

    .afi_awaddr             (afi_awaddr), // output[31:0] 
    .afi_awvalid            (afi_awvalid), // output
    .afi_awready            (afi_awready), // input
    .afi_awid               (afi_awid), // output[5:0] 
    .afi_awlock             (afi_awlock), // output[1:0] 
    .afi_awcache            (afi_awcache), // output[3:0] 
    .afi_awprot             (afi_awprot), // output[2:0] 
    .afi_awlen              (afi_awlen), // output[3:0] 
    .afi_awsize             (afi_awsize), // output[2:0] 
    .afi_awburst            (afi_awburst), // output[1:0] 
    .afi_awqos              (afi_awqos), // output[3:0] 
    .afi_wdata              (afi_wdata), // output[63:0] 
    .afi_wvalid             (afi_wvalid), // output
    .afi_wready             (afi_wready), // input
    .afi_wid                (afi_wid), // output[5:0] 
    .afi_wlast              (afi_wlast), // output
    .afi_wstrb              (afi_wstrb), // output[7:0] 
    .afi_bvalid             (afi_bvalid), // input
    .afi_bready             (afi_bready), // output
    .afi_bid                (afi_bid), // input[5:0] 
    .afi_bresp              (afi_bresp), // input[1:0] 
    .afi_wcount             (afi_wcount), // input[7:0] 
    .afi_wacount            (afi_wacount), // input[5:0] 
    .afi_wrissuecap1en      (afi_wrissuecap1en), // output
    .afi_araddr             (afi_araddr), // output[31:0] 
    .afi_arvalid            (afi_arvalid), // output
    .afi_arready            (afi_arready), // input
    .afi_arid               (afi_arid), // output[5:0] 
    .afi_arlock             (afi_arlock), // output[1:0] 
    .afi_arcache            (afi_arcache), // output[3:0] 
    .afi_arprot             (afi_arprot), // output[2:0] 
    .afi_arlen              (afi_arlen), // output[3:0] 
    .afi_arsize             (afi_arsize), // output[2:0] 
    .afi_arburst            (afi_arburst), // output[1:0] 
    .afi_arqos              (afi_arqos), // output[3:0] 
    .afi_rdata              (afi_rdata), // input[63:0] 
    .afi_rvalid             (afi_rvalid), // input
    .afi_rready             (afi_rready), // output
    .afi_rid                (afi_rid), // input[5:0] 
    .afi_rlast              (afi_rlast), // input
    .afi_rresp              (afi_rresp), // input[2:0] 
    .afi_rcount             (afi_rcount), // input[7:0] 
    .afi_racount            (afi_racount), // input[2:0] 
    .afi_rdissuecap1en      (afi_rdissuecap1en)/*, // output
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

// outputs from shadow registers

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
