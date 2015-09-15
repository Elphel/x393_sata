/*******************************************************************************
 * Module: axi_regs
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: slave axi interface buffer
 *
 * Copyright (c) 2015 Elphel, Inc.
 * axi_regs.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * axi_regs.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`include "axibram_read.v"
`include "axibram_write.v"
module axi_regs #(
    parameter AXIREGS_COUNT      = 10,
    parameter AREGS_ADDR_BITS    = 4,
    parameter SREGS_ADDR_BITS    = 4
)
(
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
// registers iface
    input   wire    [31:0]      bram_rdata,
    output  wire    [31:0]      bram_waddr,
    output  wire    [31:0]      bram_wdata,
    output  wire    [31:0]      bram_raddr,
    output  wire    [3:0]       bram_wstb,
    output  wire                bram_wen,
    output  wire                bram_ren,
    output  wire                bram_regen,

// iface to registers @ sclk
    output  wire    [SREGS_ADDR_BITS - 1:0]   sregs_address_out,
    output  wire    [31:0]  sregs_wdata_out,
    output  wire            sregs_val_out,
    output  wire            sregs_req_out, // output strobe
    input   wire    [31:0]  sregs_rdata_in,
    input   wire            sregs_ack_in // input strobe OR write acknowledgement
);
/*
 * Converntional MAXI interface from x393 project
 */
// Interface's instantiation
axibram_write #(
    .ADDRESS_BITS(16)
)
axibram_write(
    .aclk           (ACLK),
    .arst           (ARESETN),
    .awaddr         (AWADDR),
    .awvalid        (AWVALID),
    .awready        (AWREADY),
    .awid           (AWID),
    .awlen          (AWLEN),
    .awsize         (AWSIZE),
    .awburst        (AWBURST),
    .wdata          (WDATA),
    .wvalid         (WVALID),
    .wready         (WREADY),
    .wid            (WID),
    .wlast          (WLAST),
    .wstb           (WSTRB),
    .bvalid         (BVALID),
    .bready         (BREADY),
    .bid            (BID),
    .bresp          (BRESP),
    .pre_awaddr     (),
    .start_burst    (),
    .dev_ready      (1'b1),
    .bram_wclk      (),
    .bram_waddr     (bram_waddr[15:0]),
    .bram_wen       (write_dev_rdy),
    .bram_wstb      (bram_wstb),
    .bram_wdata     (bram_wdata)
);

axibram_read #(
    .ADDRESS_BITS(16)
)
axibram_read(
    .aclk           (ACLK),
    .arst           (ARESETN),
    .araddr         (ARADDR),
    .arvalid        (ARVALID),
    .arready        (ARREADY),
    .arid           (ARID),
    .arlen          (ARLEN),
    .arsize         (ARSIZE),
    .arburst        (ARBURST),
    .rdata          (RDATA),
    .rvalid         (RVALID),
    .rready         (RREADY),
    .rid            (RID),
    .rlast          (RLAST),
    .rresp          (RRESP),
    .pre_araddr     (),
    .start_burst    (),
    .dev_ready      (read_dev_rdy),
    .bram_rclk      (),
    .bram_raddr     (bram_raddr[15:0]),
    .bram_ren       (bram_ren),
    .bram_regen     (bram_regen),
    .bram_rdata     (bram_rdata)
);

/*
 * Determine, if target registers works @ axi clk or sata clk
 */
reg     [31:0]  regs_rdata_r;
reg     [31:0]  regs_rdata_rr;
// issue write or read, on read addr is strobed with regs_rd, on write - with regs_wr
wire            regs_wr;
wire            regs_rd;
// indicates, that returning data is valid
wire            regs_val;

// same block of control signals for axi registers
wire    [AREGS_ADDR_BITS - 1:0]   aregs_address;
wire    [31:0]  aregs_wdata;
wire    [31:0]  aregs_rdata;
wire            aregs_wr;
wire            aregs_rd;
wire            aregs_val; 
wire            adev_rdy;
// and for sata registers
wire    [SREGS_ADDR_BITS - 1:0]   sregs_address;
wire    [31:0]  sregs_wdata;
wire    [31:0]  sregs_rdata;
wire            sregs_wr;
wire            sregs_rd;
wire            sregs_val;
wire            sdev_rdy;

// 
localparam  DEST_ACLK = 0;
localparam  DEST_SCLK = 1;
wire    dest;

assign  read_dev_rdy = adev_rdy | sdev_rdy;

assign  aregs_wr = bram_wen & dest == DEST_ACLK;
assign  aregs_rd = bram_ren & dest == DEST_ACLK;

assign  sregs_wr = bram_wen & dest == DEST_SCLK;
assign  sregs_rd = bram_ren & dest == DEST_SCLK;

/*
 * Address remap
 */

assign  dest          = bram_addr[SREGS_ADDR_BITS];
assign  sregs_address = bram_addr[SREGS_ADDR_BITS - 1:0];
assign  aregs_address = bram_addr[AREGS_ADDR_BITS - 1:0];

/*
 * Registers in ACLK domain
 * Now implemented as a set registers. If some of them can be accesses only at some specific time,
 * these registers can be replaced with a bram memory
 */
reg     [31:0]  axi_regs [AXIREGS_COUNT - 1:0];
wire    [31:0]  axi_read_data;
genvar ii;
generate 
    for (ii = 0; ii < AXIREGS_COUNT; ii = ii + 1)
    begin: axi_registers_write
        always @ (posedge ACLK)
            axi_regs[ii] <= (ii == aregs_address) & aregs_wr ? regs_wdata : axi_regs[ii];
    end
endgenerate
assign  axi_read_data = axi_regs[aregs_address];
assign  adev_rdy = aregs_rd;

/*
 * Resync to registers @ sclk
 * Can't make it pipelined - while axibram_read is used we can operate only with 1 request at a time
 * Slow as hell
 */
// ACLK -> SCLK
reg     state_wait_ack;
wire    set_wait_ack;
wire    clr_wait_ack;
// request to read data. AXI have to wait until it's done
// @ ACLK
wire    sregs_ack;
assign  set_wait_ack = sregs_rd & ~state_wait_ack;
assign  clr_wait_ack = sregs_ack;
always @ (posedge ACLK)
    state_wait_ack <= (state_wait_ack | set_wait_ack) & ~clr_wait_ack & ~ARESETN;


// tranfers control signals and data to write from @ ACLK to @ sclk
fifo_cross_clocks #(
    .DATA_WIDTH (SREGS_ADDR_BITS + 32 + 1),
    .DATA_DEPTH (3)
) 
writes_to_sclk(
    .rst        (ARESETN),
    .rrst       (ARESETN),
    .wrst       (ARESETN),
    .rclk       (sclk),
    .wclk       (ACLK),
    .we         (sregs_rd | sregs_wr),
    .re         (sregs_ack),
    .data_in    ({sregs_rd, sregs_address, sregs_wdata}),
    .data_out   ({sregs_req_out, sregs_address_out, sregs_wdata_out}),
    .nempty     (sregs_val_out),
    .half_empty ()
);

// read data @ sclk -> @ ACLK and control strobe
pulse_cross_clock bram_ack(
    .rst        (ARESETN),
    .src_clk    (sclk),
    .dst_clk    (ACLK),
    .in_pulse   (sregs_ack_in),
    .out_pulse  (sregs_ack),
    .busy       ()
);

level_cross_clocks#(
    .WIDTH      (32),
    .REGISTER   (2)
)
data_to_aclk(
    .d_in   (sregs_rdata_in),
    .d_out  (sregs_rdata)
);

endmodule
