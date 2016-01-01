/*******************************************************************************
 * Module: axi_ahci_regs
 * Date:2015-12-29  
 * Author: Andrey Filippov
 * Description: Registers for single-port AHCI over AXI implementation
 * Combination of PCI Headers, PCI power management, and HBA memory
 * 128 DWORD registers 
 * Registers, with bits being RO, RW, RWC, RW1
 *
 * Copyright (c) 2015 Elphel, Inc .
 * axi_ahci_regs.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  axi_ahci_regs.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps


module  axi_ahci_regs#(
//    parameter ADDRESS_BITS = 8 // number of memory address bits
    parameter ADDRESS_BITS = 10 // number of memory address bits - now fixed. Low half - RO/RW/RWC,RW1 (2-cycle write), 2-nd just RW (single-cycle)
)(
    input             aclk,    // clock - should be buffered
    input             arst,     // @aclk sync reset, active high
   
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
   
// HBA interface
// 1. Notification of data written @ hba_clk
    output [ADDRESS_BITS-1:0] soft_write_addr,  // register address written by software
    output             [31:0] soft_write_data,  // register data written (after applying wstb and type (RO, RW, RWC, RW1)
    output                    soft_write_en,     // write enable for data write
    output                    soft_arst,        // reset SATA PHY not relying on SATA clock
                                                // TODO: Decode from {bram_addr, ahci_regs_di}, bram_wen_d
// 2. HBA R/W registers, use hba clock
    input                     hba_clk,
    input                     hba_rst,
    input  [ADDRESS_BITS-1:0] hba_addr,
    input                     hba_we,
//   input               [3:0] hba_wstb, Needed?
    input               [1:0] hba_re, // [0] - re, [1] - regen
    input              [31:0] hba_din,
    output             [31:0] hba_dout
);
    wire   [ADDRESS_BITS-1:0] bram_waddr;
//    wire   [ADDRESS_BITS-1:0] pre_awaddr;
    wire   [ADDRESS_BITS-1:0] bram_raddr;
    wire               [31:0] bram_rdata;
    wire                      pre_bram_wen; // one cycle ahead of bram_wen, nut not masked by dev_ready
    wire                      bram_wen;
    wire               [ 3:0] bram_wstb; 
    wire               [31:0] bram_wdata; 
    wire   [ADDRESS_BITS-1:0] bram_addr; 
   

    wire             [1:0] bram_ren;
    reg                    write_busy_r;
    wire                   write_start_burst;
//    wire         nowrite;          // delay write in read-modify-write register accesses
    wire                   write_busy_w = write_busy_r || write_start_burst;
    reg             [31:0] bram_wdata_r;
    reg             [31:0] bram_rdata_r;
//    reg                    bram_wen_d;
    wire            [63:0] regbit_type;
    wire            [31:0] ahci_regs_di;
    reg             [ 3:0] bram_wstb_r;
    reg                    bram_wen_r;
//    wire  [31:0] wmask = {{8{bram_wstb[3]}},{8{bram_wstb[2]}},{8{bram_wstb[1]}},{8{bram_wstb[0]}}};
    wire            [31:0] wmask = {{8{bram_wstb_r[3]}},{8{bram_wstb_r[2]}},{8{bram_wstb_r[1]}},{8{bram_wstb_r[0]}}};
    reg [ADDRESS_BITS-1:0] bram_waddr_r;
    wire                   high_sel = bram_waddr_r[ADDRESS_BITS-1]; // high addresses - use single-cycle writes without read-modify-write
//    assign bram_addr = bram_ren[0] ? bram_raddr : (bram_wen ? bram_waddr : pre_awaddr);
    assign bram_addr = bram_ren[0] ? bram_raddr : (bram_wen_r ? bram_waddr_r : bram_waddr);
    always @(posedge aclk) begin
        if      (arst)              write_busy_r <= 0;
        else if (write_start_burst) write_busy_r <= 1;
        else if (!pre_bram_wen)     write_busy_r <= 0;

        if (bram_wen)               bram_wdata_r <= bram_wdata;
        
        if (bram_ren[1])            bram_rdata_r <= bram_rdata;
        
        bram_wstb_r <= {4{bram_wen}} & bram_wstb;
        
        bram_wen_r <= bram_wen;
        
        if (bram_wen) bram_waddr_r <= bram_waddr;
        
    end

    generate
        genvar i;
        for (i=0; i < 32; i=i+1) begin: bit_type_block
            assign ahci_regs_di[i] = (regbit_type[2*i+1] && wmask[i] && !high_sel)?
                                       ((regbit_type[2*i] && wmask[i])?
                                          (bram_rdata[i] || bram_wdata_r[i]):   // 3: RW1
                                          (bram_rdata[i] && !bram_wdata_r[i])): // 2: RWC
                                       (((regbit_type[2*i] && wmask[i]) || high_sel)?
                                          (bram_wdata_r[i]):                    // 1: RW write new data - get here for high_sel
                                          (bram_rdata[i]));                     // 0: R0 (keep old data)
        end
    endgenerate    

    axibram_write #(
        .ADDRESS_BITS(ADDRESS_BITS)
    ) axibram_write_i (
        .aclk        (aclk),                     // input
        .arst        (arst),                     // input
        .awaddr      (awaddr),                   // input[31:0] 
        .awvalid     (awvalid),                  // input
        .awready     (awready),                  // output
        .awid        (awid),                     // input[11:0] 
        .awlen       (awlen),                    // input[3:0] 
        .awsize      (awsize),                   // input[1:0] 
        .awburst     (awburst),                  // input[1:0] 
        .wdata       (wdata),                    // input[31:0] 
        .wvalid      (wvalid),                   // input
        .wready      (wready),                   // output
        .wid         (wid),                      // input[11:0] 
        .wlast       (wlast),                    // input
        .wstb        (wstb),                     // input[3:0] 
        .bvalid      (bvalid),                   // output
        .bready      (bready),                   // input
        .bid         (bid),                      // output[11:0] 
        .bresp       (bresp),                    // output[1:0] 
        .pre_awaddr  (), //pre_awaddr),          // output[9:0] 
        .start_burst (write_start_burst),        // output
//        .dev_ready   (!nowrite && !bram_ren[0]), // input
        .dev_ready   (!bram_wen),                // input   There will be no 2 bram_wen in a row
        .bram_wclk   (),                         // output
        .bram_waddr  (bram_waddr),               // output[9:0]
        .pre_bram_wen(pre_bram_wen),             // output
        .bram_wen    (bram_wen),                 // output
        .bram_wstb   (bram_wstb),                // output[3:0] 
        .bram_wdata  (bram_wdata)                // output[31:0] 
    );

    axibram_read #(
        .ADDRESS_BITS(ADDRESS_BITS)
    ) axibram_read_i (
        .aclk        (aclk),                     // input
        .arst        (arst),                     // input
        .araddr      (araddr),                   // input[31:0] 
        .arvalid     (arvalid),                  // input
        .arready     (arready),                  // output
        .arid        (arid),                     // input[11:0] 
        .arlen       (arlen),                    // input[3:0] 
        .arsize      (arsize),                   // input[1:0] 
        .arburst     (arburst),                  // input[1:0] 
        .rdata       (rdata),                    // output[31:0] 
        .rvalid      (rvalid),                   // output reg 
        .rready      (rready),                   // input
        .rid         (rid),                      // output[11:0] reg 
        .rlast       (rlast),                    // output reg 
        .rresp       (rresp),                    // output[1:0] 
        .pre_araddr  (),                         // output[9:0] 
        .start_burst (),                         // output
        .dev_ready   (!write_busy_w),            // input
        .bram_rclk   (),                         // output
        .bram_raddr  (bram_raddr),               // output[9:0] 
        .bram_ren    (bram_ren[0]),              // output
        .bram_regen  (bram_ren[1]),              // output
        .bram_rdata  (bram_rdata_r)              // input[31:0] 
    );

    // Register memory, lower half uses read-modify-write using bit type from ahci_regs_type_i ROM, 2 aclk cycles/per write and
    // high addresses half are just plain write registers, they heve single-cycle write
    // Only low registers write generates cross-clock writes over the FIFO.
    // All registers can be accessed in byte/word/dword mode over the AXI
    
    // Lower registers are used as AHCI memory registers, high - for AHCI command list(s), to eliminate the need to update transfer count
    // in the system memory.

    ramt_var_wb_var_r #(
        .REGISTERS_A (0),
        .REGISTERS_B (1),
        .LOG2WIDTH_A (5),
        .LOG2WIDTH_B (5),
        .WRITE_MODE_A("NO_CHANGE"),
        .WRITE_MODE_B("NO_CHANGE")
        `include "includes/ahci_defaults.vh" 
    ) ahci_regs_i (
        .clk_a        (aclk),                        // input
        .addr_a       (bram_addr),                   // input[9:0] 
        .en_a         (bram_ren[0] || write_busy_w), // input
        .regen_a      (1'b0),                 // input
//        .we_a         (write_busy_r && !nowrite),    // input
        .we_a         (bram_wstb_r), //bram_wen_d),  // input[3:0]
//        
        .data_out_a   (bram_rdata),                  // output[31:0] 
        .data_in_a    (ahci_regs_di),                // input[31:0] 
        .clk_b        (hba_clk),                     // input
        .addr_b       (hba_addr),                    // input[9:0] 
        .en_b         (hba_we || hba_re[0]),         // input
        .regen_b      (hba_re[1]),                   // input
        .we_b         ({4{hba_we}}),                      // input
        .data_out_b   (hba_dout),                    // output[31:0] 
        .data_in_b    (hba_din)                      // input[31:0] 
    );

    ram_var_w_var_r #(
        .REGISTERS    (0),
        .LOG2WIDTH_WR (6),
        .LOG2WIDTH_RD (6),
        .DUMMY(0)
        `include "includes/ahci_types.vh" 
    ) ahci_regs_type_i (
        .rclk         (aclk),                       // input
        .raddr        (bram_addr[8:0]),             // input[8:0] 
        .ren          (bram_wen && !bram_addr[9]),  // input
        .regen        (1'b0),                       // input
        .data_out     (regbit_type),                // output[63:0] 
        .wclk         (1'b0),                       // input
        .waddr        (9'b0),                       // input[8:0] 
        .we           (1'b0),                       // input
        .web          (8'b0),                       // input[7:0] 
        .data_in      (64'b0)                       // input[63:0] 
    );

    fifo_cross_clocks #(
        .DATA_WIDTH(ADDRESS_BITS+32),
        .DATA_DEPTH(4)
    ) ahci_regs_set_i (
        .rst        (1'b0),                              // input
        .rrst       (hba_rst),                           // input
        .wrst       (arst),                              // input
        .rclk       (hba_clk),                           // input
        .wclk       (aclk),                              // input
        .we         (bram_wen_r && !high_sel),           // input
        .re         (soft_write_en),                     // input
        .data_in    ({bram_addr, ahci_regs_di}),         // input[15:0] 
        .data_out   ({soft_write_addr,soft_write_data}), // output[15:0] 
        .nempty     (soft_write_en),                     // output
        .half_empty ()                                   // output
    );



endmodule

