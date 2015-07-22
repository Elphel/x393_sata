/*******************************************************************************
 * Module: dma_adapter
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: temporary interconnect to membridge testing purposes only
 *
 * Copyright (c) 2015 Elphel, Inc.
 * dma_adapter.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * dma_adapter.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
/*
 * The module is temporary
 * It could make transactions from DMA data buffer to membridge and vice versa.
 * Processes 1 transaction of 16 x 64bit-words at a time. 
 * Waits until 1 read or 1 write is completely done.
 * After that it deasserts busy and is ready to process a new transaction.
 *
 * The whole purpose of a module as a system block is to be a buffer between 
 * a big dma data storage and axi interface. So it shall recieve data and control
 * for 1 burst and pass it to axi.
 */
module send_dma #(
    parameter   REGISTERS_CNT = 20
)
(
    input   wire                                clk,
    input   wire                                rst,

    // cmd iface
    input   wire                                cmd_type, // 1 = wr, 0 = rd
    input   wire                                cmd_val, // issue a cmd
    input   wire    [31:7]                      cmd_addr, // [2:0] - 64-bit (8-bytes) word offset, [6:3] - 16-words transfer offset
    output  wire                                cmd_busy, // no-pipelined cmd execution, 1 cmd at a time

    // data iface
    input   wire    [63:0]                      wr_data_in,
    input   wire                                wr_val_in,
    output  wire                                wr_ack_out,
    output  wire    [63:0]                      rd_data_out,
    output  wire                                rd_val_out,
    input   wire                                rd_ack_in,

    // membridge iface
    output  wire    [7:0]                       cmd_ad,
    output  wire                                cmd_stb,
    input   wire    [7:0]                       status_ad,
    input   wire                                status_rq,
    output  wire                                status_start,
    input   wire                                frame_start_chn,
    input   wire                                next_page_chn,
    output  wire                                cmd_wrmem,
    output  wire                                page_ready_chn,
    output  wire                                frame_done_chn,
    output  wire    [15:0]                      line_unfinished_chn1,
    input   wire                                suspend_chn1,
    output  wire                                xfer_reset_page_rd,
    output  wire                                buf_wpage_nxt,
    output  wire                                buf_wr,
    output  wire    [63:0]                      buf_wdata,
    output  wire                                xfer_reset_page_wr,
    output  wire                                buf_rpage_nxt,
    output  wire                                buf_rd,
    input   wire    [63:0]                      buf_rdata,
    // additinal wire to indicate if membridge recieved a packet
    input   wire                                rdata_done // = membridge.is_last_in_page & membridge.afi_rready;
);
// cmd handling
// if not busy and got cmd with val => cmd recieved, assert busy, start a respective algorithm
wire            wr_start;
wire            rd_start;
wire            dma_start;
reg             wr_done;
reg             rd_done;

reg             cmd_type_r;
reg     [31:7]  cmd_addr_r;
reg             cmd_busy_r;
wire            set_busy;
wire            clr_busy;

assign  set_busy = ~cmd_busy_r & cmd_val;
assign  clr_busy = cmd_busy_r & (wr_done | rd_done);

assign  cmd_busy = cmd_busy_r;
assign  wr_start = set_busy & cmd_type;
assign  rd_start = set_busy & ~cmd_type;

always @ (posedge clk)
begin
    cmd_type_r  <= rst ? 1'b0 : set_busy ? cmd_type : cmd_type_r;
    cmd_addr_r  <= rst ? 1'b0 : set_busy ? cmd_addr : cmd_addr_r;
    cmd_busy_r  <= (cmd_busy_r | set_busy) & ~rst & ~clr_busy;
end

/*
 * Read/write data state machine
 * For better readability the state machine is splitted to two pieces:
 * the first one is responsible only for the CMD WRITE case handling, 
 * the second one, respectively, for CMD READ
 *
 * Simultaniously with each fsm starts a membridge fsm, which, if being 1st time launched, 
 * sets up membridge's registers, or, if have been launched before, just programs read/write 
 * address.
 *
 * Current implementation is extremely slow, but simple and reliable
 * After all other parts are implemented and this place occurs to be a bottleneck
 * then replace it (and may be membridge too) with something more ... pipelined
 */
// check if memberidge was already set up
reg             membr_is_set;
always @ (posedge clk)
    membr_is_set <= (membr_is_set | dma_start) & ~rst;

// common state register
reg     [3:0]   rdwr_state;

// Get data from buffer
localparam READ_IDLE        = 0;
localparam READ_WAIT_ADDR   = 3;
localparam READ_DATA        = 4;
reg             rd_reset_page;
reg             rd_next_page;
reg             rd_data;
reg     [6:0]   rd_data_count;

wire            rd_stop;
wire            rd_cnt_to_pull;

assign  rd_cnt_to_pull == 7'hf;
assign  rd_stop = rd_ack_in & rd_data_count == rd_cnt_to_pull;

assign  rd_data_out = rd_data;

always @ (posedge clk)
    if (rst)
    begin
        rdwr_state      <= READ_IDLE;
        rd_done         <= 1'b0;
        rd_data_count   <= 7'h0;
        rd_next_page    <= 1'b0;
        rd_en           <= 1'b0;
    end
    else
        case (rst)
        READ_IDLE:
        begin
            rdwr_state      <= rd_start ? READ_WAIT_ADDR : READ_IDLE;
            rd_done         <= 1'b0;
            rd_data_count   <= 7'h0;
            rd_next_page    <= 1'b0;
            rd_en           <= 1'b0;
        end
        READ_WAIT_ADDR: // wait until address information is sent to the bus and input buffer got data
        begin
            rdwr_state      <= membr_state == IDLE & rdata_done ? READ_DATA : READ_WAIT_ADDR;
            rd_done         <= 1'b0;
            rd_data_count   <= 7'h0;
            rd_next_page    <= 1'b0;
            rd_en           <= 1'b0;
        end
        READ_DATA: 
        begin
            rdwr_state      <= rd_stop ? READ_IDLE : READ_DATA;
            rd_done         <= rd_stop ? 1'b1 : 1'b0;
            rd_data_count   <= rd_ack_in ? rd_data_count + 1'b1 : rd_data_count;
            rd_next_page    <= rd_stop ? 1'b1 : 1'b0;
            rd_en           <= rd_ack_in ? 1'b1 : 1'b0;
        end
        default: // write is processing
        begin
            rdwr_state      <= READ_IDLE;
            rd_done         <= 1'b0;
            rd_data_count   <= 7'h0;
            rd_next_page    <= 1'b0;
            rd_en           <= 1'b0;
        end


// Put data into buffer
localparam WRITE_IDLE       = 0;
localparam WRITE_DATA       = 1;
localparam WRITE_WAIT_ADDR  = 2;
reg             wr_en;
reg             wr_reset_page;
reg             wr_next_page;
reg     [63:0]  wr_data;
reg     [6:0]   wr_data_count;
reg             wr_page_ready;
reg             wr_val;

wire    [6:0]   wr_cnt_to_push;
wire            wr_stop;

assign  wr_cnt_to_push  = 7'hf;
assign  wr_stop         = wr_val_in & wr_data_count == wr_cnt_to_push;

assign  wr_ack_out   = wr_val_in & rdwr_state == WRITE_DATA;
assign  wr_data_in   = wr_data;


// assuming for now we write only pre-defined 16 64-bit words
always @ (posedge clk)
    if (rst)
    begin
        wr_done         <= 1'b0;
        wr_data_count   <= 7'd0;
        wr_val          <= 1'b0;
        wr_data         <= 64'h0;
        wr_next_page    <= 1'b0;
        wr_reset_page   <= 1'b0;
        wr_en           <= 1'b0;
        wr_page_ready   <= 1'b0;
        rdwr_state      <= WRITE_IDLE;
    end
    else
        case (wr_state)
            WRITE_IDLE:
            begin
                wr_data_count   <= 7'd0;
                wr_done         <= 1'b0;
                wr_data         <= 64'h0;
                wr_next_page    <= 1'b0;
                wr_reset_page   <= wr_start ? 1'b1 : 1'b0;
                wr_en           <= 1'b0;
                wr_page_ready   <= 1'b0;
                rdwr_state      <= wr_start ? WRITE_DATA : WRITE_IDLE;
            end
            WRITE_DATA:
            begin
                wr_done         <= wr_stop & membr_state == IDLE ? 1'b1 : 1'b0;
                wr_data_count   <= wr_val_in ? wr_data_count + 1'b1 : wr_data_count;
                wr_data         <= in_data : 
                wr_next_page    <= wr_stop ? 1'b1 : 1'b0;
                wr_reset_page   <= 1'b0;
                wr_en           <= wr_val_in;
                wr_page_ready   <= wr_stop ? 1'b1 : 1'b0;
                rdwr_state      <= wr_stop & membr_state == IDLE ? WRITE_IDLE : 
                                   wr_stop                       ? WRITE_WAIT_ADDR : WRITE_DATA;
            end
            WRITE_WAIT_ADDR: // in case all data is written into a buffer, but address is still being issued on axi bus
            begin
                wr_done         <= membr_state == IDLE ? 1'b1 : 1'b0;
                wr_data_count   <= 7'd0;
                wr_data         <= 64'h0;
                wr_next_page    <= 1'b0;
                wr_reset_page   <= 1'b0;
                wr_en           <= 1'b0;
                wr_page_ready   <= 1'b0;
                rdwr_state      <= membr_state == IDLE ? WRITE_IDLE : WRITE_WAIT_ADDR;
            end
            default: // read is executed
            begin
                wr_done         <= 1'b0;
                wr_data_count   <= 7'd0;
                wr_data         <= 64'h0;
                wr_next_page    <= 1'b0;
                wr_reset_page   <= 1'b0;
                wr_en           <= 1'b0;
                wr_page_ready   <= 1'b0;
                rdwr_state      <= rdwr_state;
            end
        endcase

// membridge interface assigments
assign  status_start        = 1'b0; // no need until status is used
assign  cmd_wrmem           = ~cmd_type_r;
assign  xfer_reset_page_wr  = rd_reset_page;
assign  buf_rpage_nxt       = rd_next_page;
assign  buf_rd              = rd_en;
assign  buf_wdata           = wr_data;
assign  buf_wr              = wr_en;
assign  buf_wpage_nxt       = wr_next_page;
assign  xfer_reset_page_rd  = wr_reset_page;
assign  page_ready_chn      = cmd_wrmem ? 1'b0 : wr_page_ready;
assign  frame_done_chn      = 1'b1;

/*
 * Transfer address and membridge set-ups state machine
 */
localparam MEMBR_IDLE   = 0;
localparam MEMBR_MODE   = 1;
localparam MEMBR_WIDTH  = 2;
localparam MEMBR_LEN    = 3;
localparam MEMBR_START  = 4;
localparam MEMBR_SIZE   = 5;
localparam MEMBR_LOADDR = 6;
localparam MEMBR_CTRL   = 7;

reg     [32:0]  membr_data;
reg     [15:0]  membr_addr;
reg             membr_start;
reg             membr_done;
reg     [2:0]   membr_state;
reg             membr_setup; // indicates the first tick of the state
wire            membr_inprocess;

assign  dma_start = wr_start | rd_start;

always @ (posedge clk)
    if (rst)
    begin
        membr_data  <= 32'h0;
        membr_addr  <= 16'h0;
        membr_start <= 1'b0;
        membr_setup <= 1'b0;
        membr_done  <= 1'b0;
        membr_state <= MEMBR_IDLE;
    end
    else
        case (membr_state)
            MEMBR_IDLE:
            begin
                membr_data  <= 32'h0;
                membr_addr  <= 16'h200;
                membr_start <= dma_start ? 1'b1 : 1'b0;
                membr_setup <= dma_start ? 1'b1 : 1'b0;
                membr_done  <= 1'b0;
                membr_state <= dma_start &  membr_is_set ? MEMBR_LOADDDR : 
                               dma_start                 ? MEMBR_MODE : MEMBR_IDLE;
            end
            MEMBR_MODE:
            begin
                membr_data  <= 32'h3;
                membr_addr  <= 16'h207;
                membr_start <= membr_inprocess ? 1'b0 : 1'b1;
                membr_setup <= membr_inprocess | membr_setup ? 1'b0 : 1'b1;
                membr_done  <= 1'b0;
                membr_state <= membr_inprocess | membr_setup ? MEMBR_MODE : MEMBR_WIDTH;
            end
            MEMBR_WIDTH:
            begin
                membr_data  <= 32'h10;
                membr_addr  <= 16'h206;
                membr_start <= membr_inprocess ? 1'b0 : 1'b1;
                membr_setup <= membr_inprocess | membr_setup ? 1'b0 : 1'b1;
                membr_done  <= 1'b0;
                membr_state <= membr_inprocess | membr_setup ? MEMBR_WIDTH : MEMBR_LEN;
            end
            MEMBR_LEN:
            begin
                membr_data  <= 32'h10;
                membr_addr  <= 16'h205;
                membr_start <= membr_inprocess ? 1'b0 : 1'b1;
                membr_setup <= membr_inprocess | membr_setup ? 1'b0 : 1'b1;
                membr_done  <= 1'b0;
                membr_state <= membr_inprocess | membr_setup ? MEMBR_LEN : MEMBR_START;
            end
            MEMBR_START:
            begin
                membr_data  <= 32'h0;
                membr_addr  <= 16'h204;
                membr_start <= membr_inprocess ? 1'b0 : 1'b1;
                membr_setup <= membr_inprocess | membr_setup ? 1'b0 : 1'b1;
                membr_done  <= 1'b0;
                membr_state <= membr_inprocess | membr_setup ? MEMBR_START : MEMBR_SIZE;
            end
            MEMBR_SIZE:
            begin
                membr_data  <= 32'h10;
                membr_addr  <= 16'h203;
                membr_start <= membr_inprocess ? 1'b0 : 1'b1;
                membr_setup <= membr_inprocess | membr_setup ? 1'b0 : 1'b1;
                membr_done  <= 1'b0;
                membr_state <= membr_inprocess | membr_setup ? MEMBR_SIZE : MEMBR_LOADDR;
            end
            MEMBR_LOADDR:
            begin
                membr_data  <= cmd_addr_r;
                membr_addr  <= 16'h202;
                membr_start <= membr_inprocess ? 1'b0 : 1'b1;
                membr_setup <= membr_inprocess | membr_setup ? 1'b0 : 1'b1;
                membr_done  <= 1'b0;
                membr_state <= membr_inprocess | membr_setup ? MEMBR_LOADDR : MEMBR_CTRL;
            end
            MEMBR_CTRL:
            begin
                membr_data  <= {28'h0000000, 4'b0011};
                membr_addr  <= 16'h200;
                membr_start <= membr_inprocess ? 1'b0 : 1'b1;
                membr_setup <= 1'b0;
                membr_done  <= membr_inprocess | membr_setup ? 1'b0 : 1'b1;
                membr_state <= membr_inprocess | membr_setup ? MEMBR_CTRL : MEMBR_IDLE;
            end
            default:
            begin
                membr_data  <= 32'h0;
                membr_addr  <= 16'h0;
                membr_start <= 1'b0;
                membr_setup <= 1'b0;
                membr_done  <= 1'b0;
                membr_state <= MEMBR_IDLE;
            end
        endcase

// write to memridge registers fsm
localparam STATE_IDLE   = 3'h0;
localparam STATE_CMD_0  = 3'h1;
localparam STATE_CMD_1  = 3'h2;
localparam STATE_DATA_0 = 3'h3;
localparam STATE_DATA_1 = 3'h4;
localparam STATE_DATA_2 = 3'h5;
localparam STATE_DATA_3 = 3'h6;

reg     [2:0]   state;
reg     [7:0]   out_ad;
reg             out_stb;

assign  membr_inprocess = state != STATE_IDLE;
assign  cmd_ad          = out_ad;
assign  cmd_stb         = out_stb;

always @ (posedge clk)
    if (rst)
    begin
        state   <= STATE_IDLE;
        out_ad  <= 8'h0;
        out_stb <= 1'b0;
    end
    else
        case (state)
            STATE_IDLE: 
            begin
                out_ad  <= 8'h0;
                out_stb <= 1'b0;
                state   <= membr_setup ? STATE_CMD_0 : STATE_IDLE;
            end
            STATE_CMD_0:
            begin
                out_ad  <= membr_addr[7:0];
                out_stb <= 1'b1;
                state   <= STATE_CMD_1;
            end
            STATE_CMD_1:
            begin
                out_ad  <= membr_addr[15:8];
                out_stb <= 1'b0;
                state   <= STATE_DATA_0;
            end
            STATE_DATA_0:
            begin
                out_ad  <= membr_data[7:0];
                out_stb <= 1'b0;
                state   <= STATE_DATA_1;
            end
            STATE_DATA_1:
            begin
                out_ad  <= membr_data[15:8];
                out_stb <= 1'b0;
                state   <= STATE_DATA_2;
            end
            STATE_DATA_2:
            begin
                out_ad  <= membr_data[23:16];
                out_stb <= 1'b0;
                state   <= STATE_DATA_3;
            end
            STATE_DATA_3:
            begin
                out_ad  <= membr_data[31:24];
                out_stb <= 1'b0;
                state   <= STATE_IDLE;
            end
            default:
            begin
                out_ad  <= 8'hff;
                out_stb <= 1'b0;
                state   <= STATE_IDLE;
            end
        endcase

endmodule
