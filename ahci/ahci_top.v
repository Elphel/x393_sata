/*******************************************************************************
 * Module: ahci_top
 * Date:2016-01-09  
 * Author: Andrey Filippov     
 * Description: Top module of the AHCI implementation
 * 
 * Copyright (c) 2016 Elphel, Inc .
 * ahci_top.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  ahci_top.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  ahci_top#(
    parameter ADDRESS_BITS = 10 // number of memory address bits - now fixed. Low half - RO/RW/RWC,RW1 (2-cycle write), 2-nd just RW (single-cycle)
)(
    input             aclk,    // clock - should be buffered
    input             arst,     // @aclk sync reset, active high
// MAXIGP1   
// AXI Write Address
    input      [31:0] awaddr,  // AWADDR[31:0], input
    input             awvalid, // AWVALID, input
    output            awready, // AWREADY, output
    input      [11:0] awid,    // AWID[11:0], input
    input      [ 3:0] awlen,   // AWLEN[3:0], input
    input      [ 1:0] awsize,  // AWSIZE[1:0], input
    input      [ 1:0] awburst, // AWBURST[1:0], input
// AXI PS Master GP0: Write Data
    input      [31:0] wdata,   // WDATA[31:0], input
    input             wvalid,  // WVALID, input
    output            wready,  // WREADY, output
    input      [11:0] wid,     // WID[11:0], input
    input             wlast,   // WLAST, input
    input      [ 3:0] wstb,    // WSTRB[3:0], input
// AXI PS Master GP0: Write Responce
    output            bvalid,  // BVALID, output
    input             bready,  // BREADY, input
    output     [11:0] bid,     // BID[11:0], output
    output     [ 1:0] bresp,    // BRESP[1:0], output
// AXI Read Address   
    input      [31:0] araddr,  // ARADDR[31:0], input 
    input             arvalid, // ARVALID, input
    output            arready, // ARREADY, output
    input      [11:0] arid,    // ARID[11:0], input
    input      [ 3:0] arlen,   // ARLEN[3:0], input
    input      [ 1:0] arsize,  // ARSIZE[1:0], input
    input      [ 1:0] arburst, // ARBURST[1:0], input
// AXI Read Data
    output     [31:0] rdata,   // RDATA[31:0], output
    output            rvalid,  // RVALID, output
    input             rready,  // RREADY, input
    output     [11:0] rid,     // RID[11:0], output
    output            rlast,   // RLAST, output
    output     [ 1:0] rresp,   // RRESP
// SAXIHP3    
    // axi_hp signals write channel
    // write address
    output     [31:0] afi_awaddr,
    output            afi_awvalid,
    input             afi_awready, // @SuppressThisWarning VEditor unused - used FIF0 level
    output     [ 5:0] afi_awid,
    output     [ 1:0] afi_awlock,
    output     [ 3:0] afi_awcache,
    output     [ 2:0] afi_awprot,
    output     [ 3:0] afi_awlen,
    output     [ 1:0] afi_awsize,
    output     [ 1:0] afi_awburst,
    output     [ 3:0] afi_awqos,
    // write data
    output     [63:0] afi_wdata,
    output            afi_wvalid,
    input             afi_wready,  // @SuppressThisWarning VEditor unused - used FIF0 level
    output     [ 5:0] afi_wid,
    output            afi_wlast,
    output     [ 7:0] afi_wstrb,
    // write response
    input             afi_bvalid,   // @SuppressThisWarning VEditor unused
    output            afi_bready,
    input      [ 5:0] afi_bid,      // @SuppressThisWarning VEditor unused
    input      [ 1:0] afi_bresp,    // @SuppressThisWarning VEditor unused
    // PL extra (non-AXI) signals
    input      [ 7:0] afi_wcount,
    input      [ 5:0] afi_wacount,
    output            afi_wrissuecap1en,
    // AXI_HP signals - read channel
    // read address
    output     [31:0] afi_araddr,
    output               afi_arvalid,
    input                afi_arready,  // @SuppressThisWarning VEditor unused - used FIF0 level
    output     [ 5:0] afi_arid,
    output     [ 1:0] afi_arlock,
    output     [ 3:0] afi_arcache,
    output     [ 2:0] afi_arprot,
    output     [ 3:0] afi_arlen,
    output     [ 1:0] afi_arsize,
    output     [ 1:0] afi_arburst,
    output     [ 3:0] afi_arqos,
    // read data
    input      [63:0] afi_rdata,
    input             afi_rvalid,
    output            afi_rready,
    input      [ 5:0] afi_rid,     // @SuppressThisWarning VEditor unused
    input             afi_rlast,   // @SuppressThisWarning VEditor unused
    input      [ 1:0] afi_rresp,   // @SuppressThisWarning VEditor unused
    // PL extra (non-AXI) signals
    input      [ 7:0] afi_rcount,
    input      [ 2:0] afi_racount,
    output            afi_rdissuecap1en
    
);
// axi_ahci_regs signals:
// 1. Notification of data written @ hba_clk
    wire [ADDRESS_BITS-1:0] soft_write_addr;  // register address written by software
    wire             [31:0] soft_write_data;  // register data written (after applying wstb and type (RO, RW, RWC, RW1)
    wire                    soft_write_en;     // write enable for data write
    wire                    soft_arst;        // reset SATA PHY not relying on SATA clock
                                                // TODO: Decode from {bram_addr, ahci_regs_di}, bram_wen_d
// 2. HBA R/W registers, use hba clock
    wire                    hba_clk;
    wire                    hba_rst;
    wire [ADDRESS_BITS-1:0] hba_addr;
    wire                    hba_we;
    wire              [1:0] hba_re; // [0] - re, [1] - regen
    wire             [31:0] hba_din;
    wire             [31:0] hba_dout;
    
//---------------------    

    axi_ahci_regs #(
        .ADDRESS_BITS(10)
    ) axi_ahci_regs_i (
        .aclk             (aclk),            // input
        .arst             (arst),            // input
        .awaddr           (awaddr),          // input[31:0] 
        .awvalid          (awvalid),         // input
        .awready          (awready),         // output
        .awid             (awid),            // input[11:0] 
        .awlen            (awlen),           // input[3:0] 
        .awsize           (awsize),          // input[1:0] 
        .awburst          (awburst),         // input[1:0] 
        .wdata            (wdata),           // input[31:0] 
        .wvalid           (wvalid),          // input
        .wready           (wready),          // output
        .wid              (wid),             // input[11:0] 
        .wlast            (wlast),           // input
        .wstb             (wstb),            // input[3:0] 
        .bvalid           (bvalid),          // output
        .bready           (bready),          // input
        .bid              (bid),             // output[11:0] 
        .bresp            (bresp),           // output[1:0] 
        .araddr           (araddr),          // input[31:0] 
        .arvalid          (arvalid),         // input
        .arready          (arready),         // output
        .arid             (arid),            // input[11:0] 
        .arlen            (arlen),           // input[3:0] 
        .arsize           (arsize),          // input[1:0] 
        .arburst          (arburst),         // input[1:0] 
        .rdata            (rdata),           // output[31:0] 
        .rvalid           (rvalid),          // output
        .rready           (rready),          // input
        .rid              (rid),             // output[11:0] 
        .rlast            (rlast),           // output
        .rresp            (rresp),           // output[1:0] 
        .soft_write_addr  (soft_write_addr), // output[9:0] 
        .soft_write_data  (soft_write_data), // output[31:0] 
        .soft_write_en    (soft_write_en),   // output
        .soft_arst        (soft_arst),       // output
        .hba_clk          (hba_clk),         // input
        .hba_rst          (hba_rst),         // input
        .hba_addr         (hba_addr),        // input[9:0] 
        .hba_we           (hba_we),          // input
        .hba_re           (hba_re),          // input[1:0] 
        .hba_din          (hba_din),         // input[31:0] 
        .hba_dout         (hba_dout)         // output[31:0] 
    );


    /* Instance template for module ahci_dma */
    ahci_dma ahci_dma_i (
        .mrst(), // input
        .hrst(), // input
        .mclk(), // input
        .hclk(), // input
        .ctba(), // input[31:7] 
        .ctba_ld(), // input
        .prdtl(), // input[15:0] 
        .dev_wr(), // input
        .cmd_start(), // input
        .prd_start(), // input
        .cmd_abort(), // input
        .axi_wr_cache_mode(), // input[3:0] 
        .axi_rd_cache_mode(), // input[3:0] 
        .set_axi_wr_cache_mode(), // input
        .set_axi_rd_cache_mode(), // input
        .ct_busy(), // output reg 
        .ct_addr(), // input[4:0] 
        .ct_re(), // input
        .ct_data(), // output[31:0] reg 
        .prd_done(), // output
        .prd_irq(), // output
        .cmd_busy(), // output reg 
        .cmd_done(), // output
        .sys_out(), // output[31:0] 
        .sys_dav(), // output
        .sys_re(), // input
        .sys_in(), // input[31:0] 
        .sys_nfull(), // output
        .sys_we(), // input
        
        .afi_awaddr        (afi_awaddr),        // output[31:0] 
        .afi_awvalid       (afi_awvalid),       // output
        .afi_awready       (afi_awready),       // input
        .afi_awid          (afi_awid),          // output[5:0] 
        .afi_awlock        (afi_awlock),        // output[1:0] 
        .afi_awcache       (afi_awcache),       // output[3:0] reg 
        .afi_awprot        (afi_awprot),        // output[2:0] 
        .afi_awlen         (afi_awlen),         // output[3:0] 
        .afi_awsize        (afi_awsize),        // output[1:0] 
        .afi_awburst       (afi_awburst),       // output[1:0] 
        .afi_awqos         (afi_awqos),         // output[3:0] 
        .afi_wdata         (afi_wdata),         // output[63:0] 
        .afi_wvalid        (afi_wvalid),        // output
        .afi_wready        (afi_wready),        // input
        .afi_wid           (afi_wid),           // output[5:0] 
        .afi_wlast         (afi_wlast),         // output
        .afi_wstrb         (afi_wstrb),         // output[7:0] 
        .afi_bvalid        (afi_bvalid),        // input
        .afi_bready        (afi_bready),        // output
        .afi_bid           (afi_bid),           // input[5:0] 
        .afi_bresp         (afi_bresp),         // input[1:0] 
        .afi_wcount        (afi_wcount),        // input[7:0] 
        .afi_wacount       (afi_wacount),       // input[5:0] 
        .afi_wrissuecap1en (afi_wrissuecap1en), // output
        .afi_araddr        (afi_araddr),        // output[31:0] 
        .afi_arvalid       (afi_arvalid),       // output
        .afi_arready       (afi_arready),       // input
        .afi_arid          (afi_arid),          // output[5:0] 
        .afi_arlock        (afi_arlock),        // output[1:0] 
        .afi_arcache       (afi_arcache),       // output[3:0] reg 
        .afi_arprot        (afi_arprot),        // output[2:0] 
        .afi_arlen         (afi_arlen),         // output[3:0] 
        .afi_arsize        (afi_arsize),        // output[1:0] 
        .afi_arburst       (afi_arburst),       // output[1:0] 
        .afi_arqos         (afi_arqos),         // output[3:0] 
        .afi_rdata         (afi_rdata),         // input[63:0] 
        .afi_rvalid        (afi_rvalid),        // input
        .afi_rready        (afi_rready),        // output
        .afi_rid           (afi_rid),           // input[5:0] 
        .afi_rlast         (afi_rlast),         // input
        .afi_rresp         (afi_rresp),         // input[1:0] 
        .afi_rcount        (afi_rcount),        // input[7:0] 
        .afi_racount       (afi_racount),       // input[2:0] 
        .afi_rdissuecap1en (afi_rdissuecap1en)  // output
    );

    ahci_fis_receive #(
        .ADDRESS_BITS(10)
    ) ahci_fis_receive_i (
        .hba_rst(), // input
        .mclk(), // input
        .get_sig(), // input
        .get_dsfis(), // input
        .get_psfis(), // input
        .get_rfis(), // input
        .get_sdbfis(), // input
        .get_ufis(), // input
        .get_data_fis(), // input
        .get_ignore(), // input
        .get_fis_busy(), // output reg 
        .fis_first_vld(), // output reg 
        .fis_ok(), // output reg 
        .fis_err(), // output reg 
        .fis_ferr(), // output
        .update_err_sts(), // input
        .update_prdbc(), // input
        .clear_bsy_drq(), // input
        .set_bsy(), // input
        .set_sts_7f(), // input
        .set_sts_80(), // input
        .decr_dwc(), // input
        .decr_DXC_dw(), // input[11:2] 
        .tfd_sts(), // output[7:0] 
        .tfd_err(), // output[7:0] 
        .fis_i(), // output reg 
        .sdb_n(), // output reg 
        .dma_a(), // output reg 
        .dma_d(), // output reg 
        .pio_i(), // output reg 
        .pio_d(), // output reg 
        .pio_es(), // output[7:0] reg 
        .xfer_cntr(), // output[31:2] 
        .xfer_cntr_zero(), // output reg 
        .reg_addr(), // output[9:0] reg 
        .reg_we(), // output reg 
        .reg_data(), // output[31:0] reg 
        .hda_data_in(), // input[31:0] 
        .hda_data_in_type(), // input[1:0] 
        .hba_data_in_avalid(), // input
        .hba_data_in_many(), // input
        .hba_data_in_ready(), // output
        .dma_in_ready(), // input
        .dma_in_valid() // output
    );

    ahci_fis_transmit #(
        .PREFETCH_ALWAYS(0),
        .READ_REG_LATENCY(2),
        .READ_CT_LATENCY(2),
        .ADDRESS_BITS(10)
    ) ahci_fis_transmit_i (
        .hba_rst(), // input
        .mclk(), // input
        .fetch_cmd(), // input
        .cfis_xmit(), // input
        .dx_transmit(), // input
        .atapi_xmit(), // input
        .done(), // output reg 
        .busy(), // output reg 
        .clearCmdToIssue(), // input
        .pCmdToIssue(), // output
        .fetch_cmd_busy(), // output reg 
        .syncesc_recv(), // input
        .xmit_err(), // input
        .dx_err(), // output[1:0] 
        .ch_prdtl(), // output[15:0] 
        .ch_c(), // output
        .ch_b(), // output
        .ch_r(), // output
        .ch_p(), // output
        .ch_w(), // output
        .ch_a(), // output
        .ch_cfl(), // output[4:0] 
        .dwords_sent(), // output[11:2] reg 
        .reg_addr(), // output[9:0] reg 
        .reg_re(), // output
        .reg_rdata(), // input[31:0] 
        .xfer_cntr(), // input[31:2] 
        .dma_ctba_ld(), // output
        .dma_start(), // output
        .dma_dev_wr(), // output
        .dma_ct_busy(), // input
        .dma_prd_start(), // output reg 
        .cmd_abort(), // output reg 
        .ct_addr(), // output[4:0] reg 
        .ct_re(), // output
        .ct_data(), // input[31:0] 
        .dma_out(), // input[31:0] 
        .dma_dav(), // input
        .dma_re(), // output
        .todev_data(), // output[31:0] reg 
        .todev_type(), // output[1:0] reg 
        .todev_valid(), // output
        .todev_ready() // input
    );


endmodule

