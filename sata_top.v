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
`timescale 1ns/1ns
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
    input   wire    [1:0]       ARLOCK,            // AXI PS Master GP1 ARLOCK[1:0], output
    input   wire    [3:0]       ARCACHE,           // AXI PS Master GP1 ARCACHE[3:0], output
    input   wire    [2:0]       ARPROT,            // AXI PS Master GP1 ARPROT[2:0], output
    input   wire    [3:0]       ARLEN,             // AXI PS Master GP1 ARLEN[3:0], output
    input   wire    [1:0]       ARSIZE,            // AXI PS Master GP1 ARSIZE[1:0], output
    input   wire    [1:0]       ARBURST,           // AXI PS Master GP1 ARBURST[1:0], output
    input   wire    [3:0]       ARQOS,             // AXI PS Master GP1 ARQOS[3:0], output
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
    input   wire    [1:0]       AWLOCK,            // AXI PS Master GP1 AWLOCK[1:0], output
    input   wire    [3:0]       AWCACHE,           // AXI PS Master GP1 AWCACHE[3:0], output
    input   wire    [2:0]       AWPROT,            // AXI PS Master GP1 AWPROT[2:0], output
    input   wire    [3:0]       AWLEN,             // AXI PS Master GP1 AWLEN[3:0], outpu:t
    input   wire    [1:0]       AWSIZE,            // AXI PS Master GP1 AWSIZE[1:0], output
    input   wire    [1:0]       AWBURST,           // AXI PS Master GP1 AWBURST[1:0], output
    input   wire    [3:0]       AWQOS,             // AXI PS Master GP1 AWQOS[3:0], output
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
    output  wire            RXN,
    output  wire            RXP,

    input   wire            REFCLK_PAD_P_IN,
    input   wire            REFCLK_PAD_N_IN
 );
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
wire            rst;
// sata clk
wire            sclk;
// dma_regs <-> dma_control
wire    [31:7]  mem_address;
wire    [31:0]  lba;
wire    [31:0]  sector_cnt;
wire            dma_type;
wire            dma_start;
wire            dma_done;
// axi-hp clock
wire            hclk;
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
// sata_host timer
wire            host_sata_timer;
// sata_host diag
wire            host_linkup;
wire            host_plllkdet;
wire            host_dcmlocked;
// temporary 150Mhz clk
wire            gtrefclk;

assign  rst = ARESETN;


axi_regs axi_regs(
// axi iface
    .ACLK               (ACLK),
    .ARESETN            (ARESETN),
    .ARADDR             (ARADDR),
    .ARVALID            (ARVALID),
    .ARREADY            (ARREADY),
    .ARID               (ARID),
    .ARLOCK             (ARLOCK),
    .ARCACHE            (ARCACHE),
    .ARPROT             (ARPROT),
    .ARLEN              (ARLEN),
    .ARSIZE             (ARSIZE),
    .ARBURST            (ARBURST),
    .ARQOS              (ARQOS),
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
    .AWLOCK             (AWLOCK),
    .AWCACHE            (AWCACHE),
    .AWPROT             (AWPROT),
    .AWLEN              (AWLEN),
    .AWSIZE             (AWSIZE),
    .AWBURST            (AWBURST),
    .AWQOS              (AWQOS),
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
    .rst            (rst),
    .ACLK           (ACLK),
    .sclk           (sclk),
// control iface
    .mem_address    (mem_address),
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
    .bram_regen     (bram_regen)
);


dma_control dma_control(
    .sclk               (sclk),
    .hclk               (hclk),
    .rst                (rst),

    // registers iface
    .mem_address        (mem_address),
    .lba                (lba),
    .sector_cnt         (sector_cnt),
    .dma_type           (dma_type),
    .dma_start          (dma_start),
    .dma_done           (dma_done),

    // adapter command iface
    .adp_busy           (adp_busy),
    .adp_addr           (adp_addr),
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
    .rst                    (rst),
// command iface                            
    .cmd_type               (adp_type),
    .cmd_val                (adp_val),
    .cmd_addr               (adp_addr),
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
    .rst                    (rst), // input
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
    .afi_rdissuecap1en      (afi_rdissuecap1en), // output
    .rdata_done             (rdata_done)
);

sata_host sata_host(
    .ready_for_cmd      (host_ready_for_cmd),
    .new_cmd            (host_new_cmd),
    .cmd_type           (host_cmd_type),
    .sector_count       (host_sector_count),
    .sector_addr        (host_sector_addr),

    .sata_din           (out_data),
    .sata_din_we        (out_val),
    .sata_core_full     (out_busy),
    .sata_dout          (in_data),
    .sata_dout_re       (in_val),
    .sata_core_empty    (in_busy),
    .data_clk_in        (sclk),
    .data_clk_out       (sclk),

    .sata_timer         (host_sata_timer),

    .clkin_150          (gtrefclk),
    .reset              (rst),

    .linkup             (host_linkup),
    .txp_out            (TXP),
    .txn_out            (TXN),
    .rxp_in             (RXP),
    .rxn_in             (RXN),

    .plllkdet           (host_plllkdet),
    .dcmlocked          (host_dcmlocked)
);

/*
 * Padding for an external input clock @ 150 MHz
 * TODO!!! Shall be done on phy-level
 */
localparam [1:0] CLKSWING_CFG = 2'b11;
IBUFDS_GTE2 #(
    .CLKRCV_TRST    ("TRUE"),
    .CLKCM_CFG      ("TRUE"),
    .CLKSWING_CFG   (CLKSWING_CFG)
)
ext_clock_buf(
    .I      (REFCLK_PAD_P_IN),
    .IB     (REFCLK_PAD_N_IN),
    .CEB    (1'b0),
    .O      (gtrefclk),
    .ODIV2  ()
);

endmodule
