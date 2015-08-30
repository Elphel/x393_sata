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
  * Later on most of address evaluation logic could be divided into 2 parts, which
  * could be presented as 2 instances of 1 parameterized module
  * + split data and address parts. Didnt do that because not sure if
  * virtual channels would be implemented in the future
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

   // adapter command iface
   input   wire            adp_busy,
   output  wire    [31:7]  adp_addr,
   output  wire            adp_type,
   output  wire            adp_val,

   // sata host command iface
   input   wire            host_ready_for_cmd,
   output  wire            host_new_cmd,
   output  wire    [1:0]   host_cmd_type,
   output  wire    [31:0]  host_sector_count,
   output  wire    [31:0]  host_sector_addr,

   // adapter data iface
   // to main memory
   output  wire    [63:0]  to_data,
   output  wire            to_val,
   input   wire            to_ack,
   // from main memory
   input   wire    [63:0]  from_data,
   input   wire            from_val,
   output  wire            from_ack,

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
//////////////////////////////////////////////////////////////////////////////////////
//// ADDRESS
//////////////////////////////////////////////////////////////////////////////////////
wire    dma_done_adp;
wire    dma_done_host;
assign  dma_done = dma_done_host & dma_done_adp;

reg     adp_busy_sclk;
/*
 * Commands to sata host fsm
 */
// for now only 2 states: idle and send a pulse
reg     host_issued;
wire    host_issued_set;
wire    host_issued_clr;

assign  dma_done_host   = host_issued;

assign  host_issued_set = ~adp_busy_sclk & host_ready_for_cmd & dma_start;
assign  host_issued_clr = dma_done;

always @ (posedge sclk)
    host_issued <= (host_issued | host_issued_set) & ~host_issued_clr & ~rst;

// drive iface signals
assign  host_new_cmd        = host_issued_set;
assign  host_cmd_type       = dma_type;
assign  host_sector_count   = sector_cnt;
assign  host_sector_addr    = lba;

/*
 * Commands to adapter fsm
 */
reg     [33:0]  quarter_sector_cnt;
wire            last_data; // last 128 bytes of data are transmitted now
wire            adp_val_sclk;
reg     [31:7]  current_addr;
reg             current_type;


// fsm itself
wire    state_idle;
reg     state_wait_busy;
reg     state_wait_done;

wire    set_wait_busy;
wire    set_wait_done;
wire    clr_wait_busy;
wire    clr_wait_done;

assign  set_wait_busy = state_idle      & host_issued_set // same start pulse for both fsms
                      | state_wait_done & clr_wait_done & ~last_data; // still have some data to transmit within a current dma request
assign  set_wait_done = state_wait_busy & clr_wait_busy;

assign  clr_wait_busy =  adp_busy_sclk;
assign  clr_wait_done = ~adp_busy_sclk;

assign  state_idle = ~state_wait_busy & ~state_wait_done;
always @ (posedge sclk)
begin
    state_wait_busy <= (state_wait_busy | set_wait_busy) & ~clr_wait_busy & ~rst;
    state_wait_done <= (state_wait_done | set_wait_done) & ~clr_wait_done & ~rst;
end

// conrol signals resync
reg             adp_val_r;
reg             adp_val_rr;
always @ (posedge hclk)
begin
    adp_val_r   <= adp_val_sclk;
    adp_val_rr  <= adp_val_r;
end

assign  adp_addr = current_addr;
assign  adp_type = current_type;
assign  adp_val  = adp_val_rr;

// Maintaining correct adp_busy level @ sclk
// assuming busy won't toggle rapidly, can afford not implementing handshakes
wire    adp_busy_sclk_set;
wire    adp_busy_sclk_clr;
wire    adp_busy_set;
wire    adp_busy_clr;
reg     adp_busy_r;

assign  adp_busy_set = adp_busy & ~adp_busy_r;
assign  adp_busy_clr = ~adp_busy & adp_busy_r;

always @ (posedge sclk)
    adp_busy_sclk   <= (adp_busy_sclk | adp_busy_sclk_set) & ~rst & ~adp_busy_sclk_clr;

always @ (posedge hclk)
    adp_busy_r <= adp_busy;

pulse_cross_clock adp_busy_set_pulse(
    .rst        (rst),
    .src_clk    (hclk),
    .dst_clk    (sclk),
    .in_pulse   (adp_busy_set),
    .out_pulse  (adp_busy_sclk_set),
    .busy       ()
);

pulse_cross_clock adp_busy_clr_pulse(
    .rst        (rst),
    .src_clk    (hclk),
    .dst_clk    (sclk),
    .in_pulse   (adp_busy_clr),
    .out_pulse  (adp_busy_sclk_clr),
    .busy       ()
);

// synchronize with host fsm
reg     adp_done;
wire    adp_done_clr;
wire    adp_done_set;

assign  dma_done_adp = adp_done;

assign  adp_done_set = state_wait_done & clr_wait_done & ~set_wait_busy; // = state_wait_done & set_idle;
assign  adp_done_clr = dma_done;
always @ (posedge sclk)
    adp_done <= (adp_done | adp_done_set) & ~adp_done_clr & ~rst;


// calculate sent sector count
// 1 sector = 512 bytes for now => 1 quarter_sector = 128 bytes
always @ (posedge sclk)
    quarter_sector_cnt <= ~set_wait_busy ? quarter_sector_cnt :
                              state_idle ? 34'h0 :                    // new dma request
                                           quarter_sector_cnt + 1'b1; // same dma request, next 128 bytes

// flags if we're currently sending the last data piece of dma transaction
assign  last_data = (sector_cnt == quarter_sector_cnt[33:2] + 1'b1) & (&quarter_sector_cnt[1:0]);

// calculate outgoing address
// increment every transaction to adapter
always @ (posedge sclk)
    current_addr <= ~set_wait_busy ? current_addr :
                        state_idle ? mem_address :           // new dma request
                                     current_addr + 1'b1; // same dma request, next 128 bytes

always @ (posedge sclk)
    current_type <= ~set_wait_busy ? current_type :
                        state_idle ? dma_type :           // new dma request
                                     current_type;        // same dma request, next 128 bytes

//////////////////////////////////////////////////////////////////////////////////////
//// DATA
//////////////////////////////////////////////////////////////////////////////////////
/*
 * from main memory resyncronisation circuit
 */
reg     [9:0]   from_rd_addr;
reg     [8:0]   from_wr_addr;
// incremened addresses
wire    [8:0]   from_wr_next_addr;
wire    [9:0]   from_rd_next_addr;
// gray coded addresses
reg     [9:0]   from_rd_addr_gr;
reg     [8:0]   from_wr_addr_gr;
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
    from_wr_addr_gr_rr  <= rst ?  9'h0 : from_wr_addr_gr_r;
end
// read address -> hclk (wr) domain to compare 
always @ (posedge hclk)
begin
    from_rd_addr_gr_r   <= rst ? 10'h0 : from_rd_addr;
    from_rd_addr_gr_rr  <= rst ? 10'h0 : from_rd_addr_gr_r;
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
reg     [8:0]   to_rd_addr_gr;
reg     [9:0]   to_wr_addr_gr;
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
// sclk domain counters
always @ (posedge sclk)
begin
    to_wr_addr        <= rst ? 10'h0 : to_we ? to_wr_next_addr : to_wr_addr;
    to_wr_addr_gr     <= rst ? 10'h0 : to_we ? to_wr_next_addr ^ {1'b0, to_wr_next_addr[9:1]} : to_wr_addr_gr;
end
// hclk domain counters
always @ (posedge hclk)
begin
    to_rd_addr        <= rst ?  9'h0 : to_re ? to_rd_next_addr : to_rd_addr;
    to_rd_addr_gr     <= rst ?  9'h0 : to_re ? to_rd_next_addr ^ {1'b0, to_rd_next_addr[8:1]} : to_rd_addr_gr;
end
// write address -> hclk (rd) domain to compare 
always @ (posedge hclk)
begin
    to_wr_addr_gr_r   <= rst ? 10'h0 : to_wr_addr;
    to_wr_addr_gr_rr  <= rst ? 10'h0 : to_wr_addr_gr_r;
end
// read address -> sclk (wr) domain to compare 
always @ (posedge sclk)
begin
    to_rd_addr_gr_r   <= rst ?  9'h0 : to_rd_addr;
    to_rd_addr_gr_rr  <= rst ?  9'h0 : to_rd_addr_gr_r;
end
// translate resynced write address into ordinary (non-gray) address
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
// sclk domain: to_wr_addr   - current write address
//              to_rd_addr_r - read address some sclk ticks ago
//  => we can say if the fifo have the possibility to be full
//     since actual to_rd_addr could only be incremented
//
// hclk domain: to_rd_addr   - current read address
//              to_wr_addr_r - write address some hclk ticks ago
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
