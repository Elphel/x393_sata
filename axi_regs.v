/*******************************************************************************
 * Module: axi_regs
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: temporary registers, connected to axi bus
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
/*
 * Some common formulas for AXI:
 * // - integer division, % - leftover
 * addr = raddr(waddr) % device_memory_size
 * size = arsize(awsize), size_bytes = 2^size, bus_width = log2(bus_width_bytes),
 * bus_offset = addr % bus_width_bytes, aligned_bus_addr - address of the first byte on a bus
 * word_addr - current memory word's index, word_size_bytes - memory word size

 *            For the i-th byte on a bus,
 *      -------burst_cnt = 0:
 *             aligned_bus_addr = addr // bus_width_bytes * bus_width_bytes
 *             word_addr[i] = (aligned_bus_addr + i) // word_size_bytes
 *             word_data[i] = mem[word_addr[i]]
 *            >data[i] = word_data[i][i % word_size]
 *            >atrobe[i] = i[bus_width:size] == bus_offset[bus_width:size] & i[size-1:0] >= bus_offset[size-1:0]
 *      -------burst_cnt > 0:
 *              let addr_-1 be an addr of a last burst
 *  Incremental
 *      addr = addr_-1 // size_bytes * size_bytes + size_bytes
 *
 *  Wrapping
 *      addr = addr_-1 // size_bytes * size_bytes + size_bytes
 */
`include "axibram_read.v"
`include "axibram_write.v"
module axi_regs(
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
    output  wire    [1:0]       BRESP              // AXI PS Master GP1 BRESP[1:0], input
);

// register set
//reg     [31:0]  mem [3:0];
reg     [32*16 - 1:0]  mem;
`ifndef MAXI_NEW_IFACE
/*
 * Converntional MAXI interface from x393 project, uses fifos, writes to/reads from memory
 */
wire    [31:0]  bram_waddr;
wire    [31:0]  bram_raddr;
wire    [31:0]  bram_wdata;
wire    [31:0]  bram_rdata;
wire    [3:0]   bram_wstb;
wire            bram_wen;
wire            bram_ren;
wire            bram_regen;

// 'write into memory' 
// for testing purposes the 'memory' is a set of registers for now
// later on will try to use them as an application level registers
genvar ii;
generate
for (ii = 0; ii < 16; ii = ii + 1)
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

// read from memory. Interface's protocol assumes returning data to delay
reg     [3:0]   bram_raddr_r;
always @ (posedge ACLK)
    bram_raddr_r <= bram_regen ? bram_raddr[3:0] : bram_raddr_r;
assign  bram_rdata = mem[32*bram_raddr_r + 31-:32];

// Interface's instantiation
axibram_write #(
    .ADDRESS_BITS(32)
)
axibram_write(
    .aclk           (ACLK),
    .rst            (ARESETN),
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
    .bram_waddr     (bram_waddr),
    .bram_wen       (bram_wen),
    .bram_wstb      (bram_wstb),
    .bram_wdata     (bram_wdata)
);
axibram_read #(
    .ADDRESS_BITS(32)
)
axibram_read(
    .aclk           (ACLK),
    .rst            (ARESETN),
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
    .dev_ready      (1'b1),
    .bram_rclk      (),
    .bram_raddr     (bram_raddr),
    .bram_ren       (bram_ren),
    .bram_regen     (bram_regen),
    .bram_rdata     (bram_rdata)
);
`else
// read
// simple consecutive non-conveyor
reg             raval;
reg     [31:0]  raddr;
reg     [3:0]   rlen;
reg     [1:0]   rsize;
reg     [1:0]   rburst;
reg             rready;

wire            r_set;
wire            r_clr;
wire    [31:0]  rdata_w;
reg     [31:0]  rdata;
reg             rval;
reg     [11:0]  rid;
reg     [11:0]  rid_in;

reg     [3:0]   burst_cnt;
reg     [31:0]  raddr_burst;

assign  ARREADY = rready;
assign  RDATA   = rdata;
assign  RVALID  = rval;
assign  RID     = rid;
assign  RLAST   = burst_cnt == rlen;
assign  RRESP   = 2'b00;

// recieve controls
always @ *//(posedge ACLK)
begin
    raddr   = ARVALID ? ARADDR : raddr;
    raval   = ARVALID;
    rlen    = ARLEN;
    rsize   = ARSIZE;
    rburst  = ARBURST;
    rid_in  = RID;
end

// determine successful address detection and data delivery
assign  r_set   = raval & ARREADY | r_clr & ~RLAST;
assign  r_clr   = RVALID & RREADY;

// drive output signals after address detection until they are delivered
always @ (posedge ACLK)
begin
    rdata   <= {32{r_set}} & rdata_w | rdata & {32{~r_clr & ARESETN}};
    rid     <= {12{r_set}} & rid_in | rid & {12{~r_clr & ARESETN}};
    rval    <= r_set | rval & ~r_clr & ARESETN;
end

// we are ready to proceed another address after we've completely done with previous one:
// the moment last burst is sent and everytime after that
always @ (posedge ACLK)
    rready  <= ~|burst_cnt & (RLAST & r_clr | ~rval) & ARESETN;

// count bursts
always @ (posedge ACLK)
    burst_cnt   <= ~ARESETN | RLAST & r_clr ? 4'h0 : r_clr ? burst_cnt + 1'b1 : burst_cnt;

// after simplifying the introduction comment for this particular case
assign  rdata_w = mem[{|burst_cnt ? raddr_burst[5:2] : raddr[5:2], 2'b00} + 7-:8];

// compute an address for the next burst
wire    ralmost_last;
assign  ralmost_last = burst_cnt + 1'b1 == rlen;
always @ (posedge ACLK)
    raddr_burst <= ~ARESETN ? 32'h0 : ~r_clr ? raddr_burst : rburst == 2'b01 ? {raddr_burst[5:2] + 1'b1, 2'b00} : // incr
                                                             rburst == 2'b10 ? (~ralmost_last ? {raddr_burst[5:2] + 1'b1, 2'b00 } : // wrap, ordinary case
                                                                                                {raddr[5:2], 2'b00}) : // wrap, last transaction is to be 'wrapped'
                                                                               raddr; // fixed


// write
// simple consecutive non-conveyor

reg     [31:0]  waddr;
reg             waval;
reg     [11:0]  wid_in;
reg     [3:0]   wlen;
reg     [1:0]   wsize;
reg     [1:0]   wburst;
reg     [31:0]  wdata;
reg             wval;
reg     [11:0]  wid;
reg     [3:0]   wstrb;
reg             waunready;
reg             wready;
reg             wlast;

wire            w_set;
wire            w_clr;
reg     [31:0]  waddr_burst;
reg     [3:0]   wburst_cnt;
reg             wait_resp;
wire            wresp_clr;

assign  WREADY = wready;
assign  AWREADY = ~waunready & ~wait_resp;

// latching inputs
always @ *//(posedge ACLK)
begin
    waddr   = AWVALID ? AWADDR : waddr;
    waval   = AWVALID;
    wid_in  = AWID;
    wlen    = AWLEN;
    wsize   = AWSIZE;
    wburst  = AWBURST;
    wdata   = WDATA;
    wlast   = WLAST;
    wid     = WID;
    wstrb   = AWVALID ? WSTRB : wstrb;
    wval    = WVALID;
end

// determine start and end of 'transmit data' phase
assign  w_set = waval & AWREADY | w_clr & ~wlast;
assign  w_clr = WVALID & WREADY;

// as soon as data phase started, data could be recieved every tick and no control could
always @ (posedge ACLK)
begin
    wait_resp <= w_set | wait_resp & ~wresp_clr & ARESETN;
    waunready <= w_set | waunready & ~w_clr & ARESETN;
    wready    <= w_set |    wready & ~w_clr & ARESETN;
end

// write data to a corresponding memory cell
wire    waddr_cur;
assign  waddr_cur = {|wburst_cnt ? waddr_burst[5:2] : waddr[5:2], 2'b00};
genvar ii;
generate
for (ii = 0; ii < 4; ii = ii + 1)
begin: for_every_word_byte
    always @ (posedge ACLK)
    begin
        mem[waddr_cur + ii*8 + 7-:8] <= w_clr & wstrb[ii] ? wdata[ii*8+7-:8] : mem[waddr_cur + ii*8 + 7-:8];
    end
end
endgenerate

wire    walmost_last;
assign  walmost_last = wburst_cnt + 1'b1 == wlen;
always @ (posedge ACLK)
    wburst_cnt <= ~ARESETN | wlast & w_clr ? 4'h0 : w_clr ? wburst_cnt + 1'b1 : wburst_cnt;

always @ (posedge ACLK)
    waddr_burst <= ~ARESETN ? 32'h0 : ~w_clr ? waddr_burst : wburst == 2'b01 ? {waddr_burst[5:2] + 1'b1, 2'b00} : //incr
                                                             wburst == 2'b10 ? (~walmost_last ? {waddr_burst[5:2] + 1'b1, 2'b00} : // wrap, ordinary
                                                                                                {waddr[5:2], 2'b00}) : // wrap, last burst
                                                                               waddr; // fixed

// set responses
reg             bready;
reg     [11:0]  bid;
always @ (posedge ACLK)
begin
    bid <= AWVALID ? WID : bid;
    bready <= ~ARESETN | wresp_clr ? 1'b0 : wlast & w_clr ? 1'b1 : bready;
end
assign  BRESP = 2'b00;
assign  BID = bid;
assign  BREADY = bready;
assign  wresp_clr = BREADY & BVALID;


`endif


endmodule
