/*******************************************************************************
 * Module: dma_control
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: temporary dma request control logic
 *
 * Copyright (c) 2015 Elphel, Inc.
 * dma_control.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * dma_control.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
 /*
  * Later on most of address evaluation logic could divided into 2 parts, which
  * could be presented as 2 instances of 1 parameterized module
  */
 module dma_control(
    input   wire            sclk,   // sata clock
    input   wire            hclk,   // axi-hp clock
    input   wire            rst,

    // registers iface
    input   wire    [31:7]  mem_address,
    input   wire    [31:0]  lba,
    input   wire    [31:0]  sector_cnt,
    input   wire            dma_type,
    input   wire            dma_start,
    output  wire            dma_done,

    // adapter data iface
    // to main memory
    output  wire    [63:0]  to_data,
    output  wire            to_val,
    input   wire            to_ack,
    // from main memory
    input   wire    [63:0]  from_data,
    input   wire            from_val,
    input   wire            from_ack

    // sata host iface
    // data from sata host
    input   wire    [31:0]  in_data,
    output  wire            in_val,
    input   wire            in_busy,
    // data to sata host
    output  wire    [31:0]  out_data,
    output  wire            out_val,
    input   wire            out_busy
 );

/*
 * from main memory resyncronisation circuit
 */
reg     [9:0]   from_rd_addr;
reg     [8:0]   from_wr_addr;
// incremened addresses
wire    [8:0]   from_wr_next_addr;
wire    [9:0]   from_rd_next_addr;
// gray coded addresses
reg     [9:0]   from_rd_addr;
reg     [8:0]   from_wr_addr;
// anti-metastability shift registers for gray-coded addresses
reg     [9:0]   from_rd_addr_gr_r;
reg     [8:0]   from_wr_addr_gr_r;
reg     [9:0]   from_rd_addr_gr_rr;
reg     [8:0]   from_wr_addr_gr_rr;
// resynced to opposite clks addresses 
wire    [9:0]   from_rd_addr_r;
wire    [8:0]   from_wr_addr_r;
// fifo states
wire            from_full;      // MAY BE full. ~full -> MUST NOT be full
wire            from_empty;     // MAY BE empty. ~empty -> MUST NOT be empty
wire            from_re;
wire            from_we;

assign  from_wr_next_addr = from_wr_addr + 1'b1;
assign  from_rd_next_addr = from_rd_addr + 1'b1;
// hclk domain counters
always @ (posedge hclk)
begin
    from_wr_addr        <= rst ?  9'h0 : from_we ? from_wr_next_addr : from_wr_addr;
    from_wr_addr_gr     <= rst ?  9'h0 : from_we ? from_wr_next_addr ^ {1'b0, from_wr_next_addr[8:1]} : from_wr_addr_gr;
end
// sclk domain counters
always @ (posedge sclk)
begin
    from_rd_addr        <= rst ? 10'h0 : from_re ? from_rd_next_addr : from_rd_addr;
    from_rd_addr_gr     <= rst ? 10'h0 : from_re ? from_rd_next_addr ^ {1'b0, from_rd_next_addr[9:1]} : from_rd_addr_gr;
end
// write address -> sclk (rd) domain to compare 
always @ (posedge sclk)
begin
    from_wr_addr_gr_r   <= rst ?  9'h0 : from_wr_addr;
    from_wr_addr_gr_rr  <= rst ?  9'h0 : from_wr_addr_rr;
end
// read address -> hclk (wr) domain to compare 
always @ (posedge hclk)
begin
    from_rd_addr_gr_r   <= rst ? 10'h0 : from_rd_addr;
    from_rd_addr_gr_rr  <= rst ? 10'h0 : from_rd_addr_rr;
end
// translate resynced write address into ordinary (non-gray) address
genvar ii;
generate
for (ii = 0; ii < 9; ii = ii + 1)
begin: from_wr_antigray
    assign  from_wr_addr_r[ii] = ^from_wr_addr_gr_rr[8:ii];
end
endgenerate
// translate resynced read address into ordinary (non-gray) address
generate
for (ii = 0; ii < 10; ii = ii + 1)
begin: from_rd_antigray
    assign  from_rd_addr_r[ii] = ^from_rd_addr_gr_rr[9:ii];
end
endgenerate
// so we've got the following:
// hclk domain: from_wr_addr   - current write address
//              from_rd_addr_r - read address some hclk ticks ago
//  => we can say if the fifo have the possibility to be full
//     since actual from_rd_addr could only be incremented
//
// sclk domain: from_rd_addr   - current read address
//              from_wr_addr_r - write address some sclk ticks ago
//  => we can say if the fifo have the possibility to be empty
//     since actual from_wr_addr could only be incremented
assign  from_full   = {from_wr_addr, 1'b0}  == from_rd_addr_r + 1'b1;
assign  from_empty  = {from_wr_addr_r, 1'b0} == from_rd_addr; // overflows must never be achieved
// calculate bus responses in order to fifo status:
assign  from_ack    = from_val & ~from_full;
assign  out_val     = ~out_busy & ~from_empty;

assign  from_re     = out_val;
assign  from_we     = from_ack;

// data buffer, recieves 64-bit data from main memory, directs it to sata host
ram_512x64w_1kx32r #(
    .REGISTERS  (0)
)
dma_data_from_mem (
    .rclk       (sclk),
    .raddr      (from_rd_addr),
    .ren        (from_re),
    .regen      (1'b0),
    .data_out   (out_data),
    .wclk       (hclk),
    .waddr      (from_wr_addr),
    .we         (from_we),
    .web        (8'hff),
    .data_in    (from_data)
);

/////////////////////////////////////////////////////////////////////////////////
/*
 * to main memory resyncronisation circuit
 */

reg     [8:0]   to_rd_addr;
reg     [9:0]   to_wr_addr;
// incremened addresses
wire    [9:0]   to_wr_next_addr;
wire    [8:0]   to_rd_next_addr;
// gray coded addresses
reg     [8:0]   to_rd_addr;
reg     [9:0]   to_wr_addr;
// anti-metastability shift registers for gray-coded addresses
reg     [8:0]   to_rd_addr_gr_r;
reg     [9:0]   to_wr_addr_gr_r;
reg     [8:0]   to_rd_addr_gr_rr;
reg     [9:0]   to_wr_addr_gr_rr;
// resynced to opposite clks addresses 
wire    [8:0]   to_rd_addr_r;
wire    [9:0]   to_wr_addr_r;
// fifo states
wire            to_full;      // MAY BE full. ~full -> MUST NOT be full
wire            to_empty;     // MAY BE empty. ~empty -> MUST NOT be empty
wire            to_re;
wire            to_we;


assign  to_wr_next_addr = to_wr_addr + 1'b1;
assign  to_rd_next_addr = to_rd_addr + 1'b1;
// hclk domain counters
always @ (posedge hclk)
begin
    to_wr_addr        <= rst ? 10'h0 : to_we ? to_wr_next_addr : to_wr_addr;
    to_wr_addr_gr     <= rst ? 10'h0 : to_we ? to_wr_next_addr ^ {1'b0, to_wr_next_addr[9:1]} : to_wr_addr_gr;
end
// sclk domain counters
always @ (posedge sclk)
begin
    to_rd_addr        <= rst ?  9'h0 : to_re ? to_rd_next_addr : to_rd_addr;
    to_rd_addr_gr     <= rst ?  9'h0 : to_re ? to_rd_next_addr ^ {1'b0, to_rd_next_addr[8:1]} : to_rd_addr_gr;
end
// write address -> sclk (rd) domain to compare 
always @ (posedge sclk)
begin
    to_wr_addr_gr_r   <= rst ? 10'h0 : to_wr_addr;
    to_wr_addr_gr_rr  <= rst ? 10'h0 : to_wr_addr_rr;
end
// read address -> hclk (wr) domain to compare 
always @ (posedge hclk)
begin
    to_rd_addr_gr_r   <= rst ?  9'h0 : to_rd_addr;
    to_rd_addr_gr_rr  <= rst ?  9'h0 : to_rd_addr_rr;
end
// translate resynced write address into ordinary (non-gray) address
genvar ii;
generate
for (ii = 0; ii < 10; ii = ii + 1)
begin: to_wr_antigray
    assign  to_wr_addr_r[ii] = ^to_wr_addr_gr_rr[9:ii];
end
endgenerate
// translate resynced read address into ordinary (non-gray) address
generate
for (ii = 0; ii < 9; ii = ii + 1)
begin: to_rd_antigray
    assign  to_rd_addr_r[ii] = ^to_rd_addr_gr_rr[8:ii];
end
endgenerate
// so we've got the following:
// hclk domain: to_wr_addr   - current write address
//              to_rd_addr_r - read address some hclk ticks ago
//  => we can say if the fifo have the possibility to be full
//     since actual to_rd_addr could only be incremented
//
// sclk domain: to_rd_addr   - current read address
//              to_wr_addr_r - write address some sclk ticks ago
//  => we can say if the fifo have the possibility to be empty
//     since actual to_wr_addr could only be incremented
assign  to_full   = {to_wr_addr, 1'b0}  == to_rd_addr_r + 1'b1;
assign  to_empty  = {to_wr_addr_r, 1'b0} == to_rd_addr; // overflows must never be achieved
// calculate bus responses in order to fifo status:
assign  to_val    = ~to_empty;
assign  in_val    = ~in_busy & ~to_full;

assign  to_re     = to_ack;
assign  to_we     = in_val;

// data buffer, recieves 32-bit data from sata host, directs it to the main memory
ram_1kx32w_512x64r #(
    .REGISTERS  (0)
)
dma_data_to_mem (
    .rclk       (hclk),
    .raddr      (to_rd_addr),
    .ren        (to_re),
    .regen      (1'b0),
    .data_out   (to_data),
    .wclk       (sclk),
    .waddr      (to_wr_addr),
    .we         (to_we),
    .web        (4'hf),
    .data_in    (in_data)
);


 endmodule
