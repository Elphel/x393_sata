/*******************************************************************************
 * Module: transport
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: sata transport layer implementation
 *
 * Copyright (c) 2015 Elphel, Inc.
 * transport.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * transport.v file is distributed in the hope that it will be useful,
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
module transport #(
    parameter DATA_BYTE_WIDTH = 4
)
(
    input   wire    clk,
    input   wire    rst,

    // link layer (LL) control

    // issue a frame
    output  wire    frame_req,
    // frame started to be transmitted
    input   wire    frame_ack,
    // frame issue was rejected because of incoming frame with higher priority
    input   wire    frame_rej,
    // LL is not ready to receive a frame request. frame_req shall be low if busy is asserted
    input   wire    frame_busy,
    // frame was transmitted w/o probles and successfully received @ a device side
    input   wire    frame_done_good,
    // frame was transmitted, but device messages of problems with receiving
    input   wire    frame_done_bad,

    // LL reports of an incoming frame transmission. They're always allowed and have the highest priority
    input   wire    incom_start,
    // LL reports of a completion of an incoming frame transmission.
    input   wire    incom_done,
    // LL reports of errors in current FIS
    input   wire    incom_invalidate, // TODO
    // TL analyzes FIS and returnes if FIS makes sense.
    output  wire    incom_ack_good,
    // ... and if it doesn't
    output  wire    incom_ack_bad,

    // transmission interrupts
    // TL demands to brutally cancel current transaction TODO
    output  wire    sync_escape_req,
    // acknowlegement of a successful reception TODO
    input   wire    sync_escape_ack,
    // TL demands to stop current recieving session TODO
    output  wire    incom_stop_req,

    // controls from a command layer (CL)
    // FIS type, ordered by CL
    input   wire    [2:0]   cmd_type,
    // request itself
    input   wire            cmd_val,
    // destination port
    input   wire    [3:0]   cmd_port,
    // if cmd got into processing, busy asserts, when TL is ready to receive a new cmd, busy deasserts
    output  wire            cmd_busy,
    // indicates completion of a request
    output  wire            cmd_done_good,
    // request is completed, but device wasn't able to receive
    output  wire            cmd_done_bad,

    // shadow registers TODO reduce outputs/inputs count. or not
    // actual registers are stored in CL
    input   wire    [31:0]  sh_data_in,
    input   wire    [15:0]  sh_feature_in,
    input   wire    [47:0]  sh_lba_in,
    input   wire    [15:0]  sh_count_in,
    input   wire    [7:0]   sh_command_in,
    input   wire    [7:0]   sh_dev_in,
    input   wire    [7:0]   sh_control_in,
    input   wire            sh_autoact_in,
    input   wire            sh_inter_in,
    input   wire            sh_dir_in,
    input   wire    [63:0]  sh_dma_id_in,
    input   wire    [31:0]  sh_buf_off_in,
    input   wire    [31:0]  sh_dma_cnt_in,
    input   wire            sh_notif_in,
    input   wire    [15:0]  sh_tran_cnt_in,
    input   wire    [3:0]   sh_port_in,
    // TL decodes register writes and sends corresponding issues to CL
    output  wire    [47:0]  sh_lba_out,
    output  wire    [15:0]  sh_count_out,
    output  wire    [7:0]   sh_command_out,
    output  wire    [7:0]   sh_err_out,
    output  wire    [7:0]   sh_status_out,
    output  wire    [7:0]   sh_estatus_out, // E_Status
    output  wire    [7:0]   sh_dev_out,
    output  wire    [3:0]   sh_port_out,
    output  wire            sh_inter_out,
    output  wire            sh_dir_out,
    output  wire    [63:0]  sh_dma_id_out,
    output  wire    [31:0]  sh_dma_off_out,
    output  wire    [31:0]  sh_dma_cnt_out,
    output  wire    [15:0]  sh_tran_cnt_out, // Transfer Count
    output  wire            sh_notif_out,
    output  wire            sh_autoact_out,
    output  wire            sh_lba_val_out,
    output  wire            sh_count_val_out,
    output  wire            sh_command_val_out,
    output  wire            sh_err_val_out,
    output  wire            sh_status_val_out,
    output  wire            sh_estatus_val_out, // E_Status
    output  wire            sh_dev_val_out,
    output  wire            sh_port_val_out,
    output  wire            sh_inter_val_out,
    output  wire            sh_dir_val_out,
    output  wire            sh_dma_id_val_out,
    output  wire            sh_dma_off_val_out,
    output  wire            sh_dma_cnt_val_out,
    output  wire            sh_tran_cnt_val_out, // Transfer Count
    output  wire            sh_notif_val_out,
    output  wire            sh_autoact_val_out,


    // shows if dma activate was received (a pulse)
    output  wire            got_dma_activate,
    output  wire    [3:0]   got_dma_activate_port,
    // if CL made a mistake in controlling data FIS length
    output  wire            data_limit_exceeded,

    // LL data
    // data inputs from LL
    input   wire    [DATA_BYTE_WIDTH*8 - 1:0]   ll_data_in,
    input   wire    [DATA_BYTE_WIDTH/2 - 1:0]   ll_data_mask_in,
    input   wire                                ll_data_val_in,
    input   wire                                ll_data_last_in,
    // transport layer tells if its inner buffer is almost full
    output  wire                                ll_data_busy_out,

    // data outputs to LL
    output  wire    [DATA_BYTE_WIDTH*8 - 1:0]   ll_data_out,
    // not implemented yet TODO
    output  wire    [DATA_BYTE_WIDTH/2 - 1:0]   ll_data_mask_out,
    output  wire                                ll_data_last_out,
    output  wire                                ll_data_val_out,
    input   wire                                ll_data_strobe_in,

    // CL data
    // required content is bypassed from ll, other is trimmed
    // only content of data FIS, starting from 1st dword. Max burst = 2048 dwords
    // data outputs to CL
    output  wire    [DATA_BYTE_WIDTH*8 - 1:0]   cl_data_out,
    output  wire    [DATA_BYTE_WIDTH/2 - 1:0]   cl_data_mask_out,
    output  wire                                cl_data_val_out,
    output  wire                                cl_data_last_out,
    // transport layer tells if its inner buffer is almost full
    input   wire                                cl_data_busy_in,

    // data inputs from CL
    input   wire    [DATA_BYTE_WIDTH*8 - 1:0]   cl_data_in,
    // not implemented yet TODO
    input   wire    [DATA_BYTE_WIDTH/2 - 1:0]   cl_data_mask_in,
    input   wire                                cl_data_last_in,
    input   wire                                cl_data_val_in,
    output  wire                                cl_data_strobe_out,


    // watchdog timers calls. They shall be handled in TL, but for debug purposes are wired to the upper level
    // when eof acknowledgement is not received after sent FIS
    output  wire    watchdog_eof,
    // when too many dwords is in current FIS
    output  wire    watchdog_dwords
);

reg [7:0]   state;

//TODO
assign sync_escape_req = 1'b0;
assign incom_stop_req = 1'b0;
assign cl_data_strobe_out = 1'b0;

// How much time does device have to response on EOF
parameter [13:0]  WATCHDOG_EOF_LIMIT = 14'd1000;

// must have a local reserve copy of shadow registers in case of 
// a) received FIS with incorrect length (seems like an error, so no registers shall be written)
// b) incoming transmission overrides outcoming, so we have to latch outcoming values in real shadow registers
//    while storing incoming ones in the local copy
reg [47:0]  loc_lba;
reg [15:0]  loc_count;
reg [7:0]   loc_command;
reg [7:0]   loc_err;
reg [7:0]   loc_status;
reg [7:0]   loc_estatus; // E_Status
reg [7:0]   loc_dev;
reg [3:0]   loc_port;
reg         loc_inter;
reg         loc_dir;
reg [63:0]  loc_dma_id;
reg [31:0]  loc_dma_off;
reg [31:0]  loc_dma_cnt;
reg [15:0]  loc_tran_cnt; // Transfer Count
reg         loc_notif;
reg         loc_autoact;


// latching cmd inputs
reg [3:0]   cmd_port_r;
reg [2:0]   cmd_type_r;
always @ (posedge clk)
    cmd_type_r  <= rst ? 3'h0 : cmd_val ? cmd_type : cmd_type_r;
always @ (posedge clk)
    cmd_port_r  <= rst ? 4'h0 : cmd_val ? cmd_port : cmd_port_r;

// incomming command type decode, shows which type of FIS shall be issued
localparam [2:0] CMD_TYPE_REG_DEV     = 3'h0; // Reg H2D, bit C -> 0
localparam [2:0] CMD_TYPE_REG_CMD     = 3'h1; // Reg H2D, bit C -> 1
localparam [2:0] CMD_TYPE_DMA_SETUP   = 3'h2;
localparam [2:0] CMD_TYPE_DATA        = 3'h3;
localparam [2:0] CMD_TYPE_BIST_ACT    = 3'h4;

// current header dword
wire    [31:0]  ll_header_dword;
// current dword shall be header's
wire            ll_header_val;
// if last data dword is header's
wire            ll_header_last;
// incorrect size or unmatched type of a received FIS
reg             bad_fis_received; 
// if a FIS has wrong size, make sure it would stop, universal dword counter
reg     [13:0]  dword_cnt;
// FIS dword size exceeded condition
assign  watchdog_dwords = dword_cnt == 14'd2049;
// ask for a receiving termination in case of errors
reg             incom_stop_req_timeout;

// global TL fsm
/*
    idle -----> outcoming FIS ----> outcoming ----non-data--> fill dwords -------------------------+
      |             |if rej                     |                                                  |
      |             |                           +-----data--> make header --> bypass data from CL -+
      |             V                                                                              |
      +-------> incoming FIS -------detect type---non-data--> parse dwords, write sh regs ---------+ 
                                        |                                                          |
                                        +-------------data--> get header ---> bypass data to CL -----> done
*/

localparam  STATE_IDLE           = 8'h0;
localparam  STATE_INCOMING       = 8'h1;
localparam  STATE_OUTCOMING      = 8'h2;
localparam  STATE_IN_DATA        = 8'h10; // Data FIS from device
localparam  STATE_IN_REG_1       = 8'h20; // Register FIS Device to Host: 1st dword
localparam  STATE_IN_REG_2       = 8'h21; // Register FIS Device to Host: 2nd dword
localparam  STATE_IN_REG_3       = 8'h22; // Register FIS Device to Host: 3rd dword
localparam  STATE_IN_REG_4       = 8'h23; // Register FIS Device to Host: 4th dword
localparam  STATE_IN_REG_ERR     = 8'h24; // Register FIS Device to Host: Error happened
localparam  STATE_IN_DMAA_ERR    = 8'h30; // DMA Activate: Error Happened
localparam  STATE_IN_DMAS_1      = 8'h40; // DMA Setup FIS device to host: 1st dword
localparam  STATE_IN_DMAS_2      = 8'h41; // DMA Setup FIS device to host: 2nd dword
localparam  STATE_IN_DMAS_3      = 8'h42; // DMA Setup FIS device to host: 3rd dword
localparam  STATE_IN_DMAS_4      = 8'h43; // DMA Setup FIS device to host: 4th dword
localparam  STATE_IN_DMAS_5      = 8'h44; // DMA Setup FIS device to host: 5th dword
localparam  STATE_IN_DMAS_6      = 8'h45; // DMA Setup FIS device to host: 6th dword
localparam  STATE_IN_DMAS_ERR    = 8'h46; // DMA Setup FIS device to host: Error happened
localparam  STATE_IN_BIST_1      = 8'h50; // BIST Activate FIS Device to Host: 1st dword
localparam  STATE_IN_BIST_2      = 8'h51; // BIST Activate FIS Device to Host: 2nd dword
localparam  STATE_IN_BIST_ERR    = 8'h52; // BIST Activate FIS Device to Host: Error happened
localparam  STATE_IN_PIOS_1      = 8'h60; // PIO Setup FIS: 1st dword
localparam  STATE_IN_PIOS_2      = 8'h61; // PIO Setup FIS: 2nd dword
localparam  STATE_IN_PIOS_3      = 8'h62; // PIO Setup FIS: 3rd dword
localparam  STATE_IN_PIOS_4      = 8'h63; // PIO Setup FIS: 4th dword
localparam  STATE_IN_PIOS_ERR    = 8'h64; // PIO Setup FIS: Error happened
localparam  STATE_IN_SDB_1       = 8'h70; // Set Device Bits FIS: 1st dword
localparam  STATE_IN_SDB_ERR     = 8'h70; // Set Device Bits FIS: Error happened
localparam  STATE_OUT_DATA_H     = 8'h80; // Data FIS from host: header
localparam  STATE_OUT_DATA_D     = 8'h81; // Data FIS from host: payload
localparam  STATE_OUT_REG        = 8'h90; // Register FIS Host to Device
localparam  STATE_OUT_DMAS       = 8'ha0; // DMA Setup FIS Host to Device
localparam  STATE_OUT_BIST       = 8'hb0; // BIST Activate FIS Host to Device
localparam  STATE_OUT_WAIT_RESP  = 8'hc0; // 
localparam  STATE_IN_UNRECOG     = 8'hf0; // Unrecognized FIS from Device

always @ (posedge clk)
    if (rst)
    begin
        state                   <= STATE_IDLE;
        dword_cnt               <= 14'h0;
        incom_stop_req_timeout  <= 1'b0;
        bad_fis_received        <= 1'b0;
        loc_lba                 <= 48'h0;
        loc_count               <= 32'h0;
        loc_command             <= 8'h0;
        loc_err                 <= 8'h0;
        loc_status              <= 8'h0;
        loc_estatus             <= 8'h0;
        loc_dev                 <= 8'h0;
        loc_port                <= 4'h0;
        loc_inter               <= 1'h0;
        loc_dir                 <= 1'h0;
        loc_dma_id              <= 64'h0;
        loc_dma_off             <= 32'h0;
        loc_dma_cnt             <= 32'h0;
        loc_tran_cnt            <= 16'h0;
        loc_notif               <= 1'h0;
        loc_autoact             <= 1'h0;
    end
    else
        case (state)
            STATE_IDLE:
            begin
                dword_cnt               <= 14'h0;
                incom_stop_req_timeout  <= 1'b0;
                bad_fis_received        <= 1'b0;
                if (frame_req)
                    state   <= STATE_OUTCOMING;
                else
                if (incom_start | frame_req)
                    state   <= STATE_INCOMING;
                else
                    state   <= STATE_IDLE;

                loc_lba      <= sh_lba_in;
                loc_count    <= sh_count_in;
                loc_command  <= sh_command_in;
                loc_err      <= 8'h0;
                loc_status   <= 8'h0;
                loc_estatus  <= 8'h0;
                loc_dev      <= 8'h0;
                loc_port     <= sh_port_in;
                loc_inter    <= sh_inter_in;
                loc_dir      <= sh_dir_in;
                loc_dma_id   <= sh_dma_id_in;
                loc_dma_off  <= sh_buf_off_in;
                loc_dma_cnt  <= sh_dma_cnt_in;
                loc_tran_cnt <= sh_tran_cnt_in;
                loc_notif    <= sh_notif_in;
                loc_autoact  <= sh_autoact_in;
            end

            STATE_INCOMING:
            // enter state when we're starting to get a FIS, leave after 1st dword is received
            begin
                if (ll_data_val_in)
                // if 0-th dword came
                    case (ll_data_in[7:0])
                    // act depending on packet type

                        8'h34:
                        // register 
                        begin
                            if (~ll_data_last_in)
                            begin
                                loc_port    <= ll_data_in[11:8];
                                loc_inter   <= ll_data_in[14];
                                loc_status  <= ll_data_in[23:16];
                                loc_err     <= ll_data_in[31:24];
                                state       <= STATE_IN_REG_1;
                            end
                            else
                            // an error state, too little dwords transfered
                            begin
                                bad_fis_received    <= 1'b1;
                                state               <= STATE_IDLE;
                            end
                        end

                        8'h39:
                        // DMA Activate
                        begin
                            if (~ll_data_last_in)
                            begin
                                state       <= STATE_IN_DMAA_ERR;
                                dword_cnt   <= 14'h1;
                            end
                            else
                            begin
                                // got_dma_activate - wire assigment
                                state       <= STATE_IDLE;
                            end
                        end

                        8'h41:
                        // DMA Setup
                        begin
                            if (~ll_data_last_in)
                            begin
                                loc_port    <= ll_data_in[11:8];
                                loc_dir     <= ll_data_in[13];
                                loc_inter   <= ll_data_in[14];
                                loc_autoact <= ll_data_in[15];
                                state       <= STATE_IN_DMAS_1;
                            end
                            else
                            // an error state, too little dwords transfered
                            begin
                                bad_fis_received    <= 1'b1;
                                state               <= STATE_IDLE;
                            end
                        end

                        8'h46:
                        // Data FIS
                        begin
                            if (~ll_data_last_in)
                            begin
                                loc_port    <= ll_data_in[11:8];
                                dword_cnt   <= 14'h1;
                                state       <= STATE_IN_DATA;
                            end
                            else
                            // an error state, too little dwords transfered
                            begin
                                bad_fis_received    <= 1'b1;
                                state               <= STATE_IDLE;
                            end
                        end

                        8'h58:
                        // BIST
                        begin
                            // for now skips payload, just controls length TODO
                            state   <= STATE_IN_BIST_1;
                        end

                        8'h5f:
                        // PIO setup
                        begin
                            if (~ll_data_last_in)
                            begin
                                loc_port        <= ll_data_in[11:8];
                                loc_dir         <= ll_data_in[13];
                                loc_inter       <= ll_data_in[14];
                                loc_status      <= ll_data_in[23:16];
                                loc_err         <= ll_data_in[31:24];
                                state           <= STATE_IN_PIOS_1;
                            end
                            else
                            // an error state, too little dwords transfered
                            begin
                                bad_fis_received    <= 1'b1;
                                state               <= STATE_IDLE;
                            end
                        end

                        8'ha1:
                        // Set Device Bits
                        begin
                            if (~ll_data_last_in)
                            begin
                                loc_inter       <= ll_data_in[14];
                                loc_notif       <= ll_data_in[15];
                                loc_status[2:0] <= ll_data_in[19:17];
                                loc_status[6:4] <= ll_data_in[23:21];
                                loc_err         <= ll_data_in[31:24];
                                state           <= STATE_IN_SDB_1;
                            end
                            else
                            // an error state, too little dwords transfered
                            begin
                                bad_fis_received    <= 1'b1;
                                state               <= STATE_IDLE;
                            end
                        end

                        default:
                        // no known FIS type matched
                        begin
                            dword_cnt   <= 14'h0;
                            state       <= STATE_IN_UNRECOG;
                        end
                    endcase
            end

            STATE_OUTCOMING:
            // enter state when we're issuing a FIS, leave when got an ack from ll (FIS started to transmit)
            // or if FIS won't start because of incoming transmission. In such case outcoming request parameter shall be latched TODO or not?
            begin
                dword_cnt   <= 14'h0;
                state       <= frame_rej ? STATE_INCOMING :
                               frame_ack & cmd_type_r == CMD_TYPE_REG_DEV   ? STATE_OUT_REG    :
                               frame_ack & cmd_type_r == CMD_TYPE_REG_CMD   ? STATE_OUT_REG    :
                               frame_ack & cmd_type_r == CMD_TYPE_DMA_SETUP ? STATE_OUT_DMAS   :
                               frame_ack & cmd_type_r == CMD_TYPE_DATA      ? STATE_OUT_DATA_H :
                               frame_ack & cmd_type_r == CMD_TYPE_BIST_ACT  ? STATE_OUT_BIST   :
                                                                              STATE_OUTCOMING;
            end

            STATE_IN_DATA:
            // receiving data from Data FIS, bypass it into buffer at upper level
            begin
                if (incom_done)
                // EOF received, CRC good
                begin
                    state   <= STATE_IDLE;
                end
                else 
                if (ll_data_val_in)
                begin
                    if (dword_cnt == 14'd2049)
                    // if too much data for a data FIS TODO handle this excpetion properly
                        state       <= STATE_IDLE; 
                    else
                    // continuing receiving data
                    begin
                        dword_cnt   <= dword_cnt + 1'b1;
                        state       <= STATE_IN_DATA;
                    end
                end
            end

            STATE_IN_REG_1:
            // receiving register FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // incorrect frame size
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    // going to the next dword, parse current one: {Device, LBA High, LBA Mid, LBA Low}
                    begin
                        loc_lba[7:0]    <= ll_data_in[7:0];
                        loc_lba[23:16]  <= ll_data_in[15:8];
                        loc_lba[39:32]  <= ll_data_in[23:16];
                        loc_dev[7:0]    <= ll_data_in[31:24];
                        state           <= STATE_IN_REG_2;
                    end
            end

            STATE_IN_REG_2:
            // receiving register FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // incorrect frame size
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    // going to the next dword, parse current one: {Reserved, LBA High (exp), LBA Mid (exp), LBA Low (exp)}
                    begin
                        loc_lba[15:8]   <= ll_data_in[7:0];
                        loc_lba[31:24]  <= ll_data_in[15:8];
                        loc_lba[47:40]  <= ll_data_in[23:16];
                        state           <= STATE_IN_REG_3;
                    end
            end

            STATE_IN_REG_3:
            // receiving register FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // incorrect frame size
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    // going to the next dword, parse current one: {Reserved, Reserved, Sector Count (exp), Sector Count}
                    begin
                        loc_count[15:0] <= ll_data_in[15:0];
                        state           <= STATE_IN_REG_4;
                    end
            end

            STATE_IN_REG_4:
            // receiving register FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // correct frame size, finishing
                    begin
                        state            <= STATE_IDLE;
                    end
                    else
                    // incorrect frame size
                    begin
                        state           <= STATE_IN_REG_ERR;
                        dword_cnt       <= 14'h4;
                    end
            end

            STATE_IN_REG_ERR:
            // FIS was started as REG, but for some reason it has a size more than needed
            // just wait until it's over and assert an error
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    begin
                        if (watchdog_dwords)
                        // if for some reason FIS continue transferring for too long, terminate it
                        begin
                            state                   <= STATE_IDLE;
                            incom_stop_req_timeout  <= 1'b1;
                        end
                        else
                            dword_cnt <= dword_cnt + 1'b1;
                    end
            end

            STATE_IN_DMAA_ERR:
            // FIS was started as DMA Activate, but for some reason it has a size more than needed
            // just wait until it's over and assert an error
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    begin
                        if (watchdog_dwords)
                        // if for some reason FIS continue transferring for too long, terminate it
                        begin
                            state                   <= STATE_IDLE;
                            incom_stop_req_timeout  <= 1'b1;
                        end
                        else
                            dword_cnt <= dword_cnt + 1'b1;
                    end
            end

            STATE_IN_DMAS_1:
            // receiving DMA Setup FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // incorrect frame size
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    // going to the next dword, parse current one: DMA Buffer Id Low
                    begin
                        loc_dma_id[31:0]    <= ll_data_in[31:0];
                        state               <= STATE_IN_DMAS_2;
                    end
            end

            STATE_IN_DMAS_2:
            // receiving DMA Setup FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // incorrect frame size
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    // going to the next dword, parse current one: DMA Buffer Id High
                    begin
                        loc_dma_id[63:32]   <= ll_data_in[31:0];
                        state               <= STATE_IN_DMAS_3;
                    end
            end

            STATE_IN_DMAS_3:
            // receiving DMA Setup FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // incorrect frame size
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    // going to the next dword, parse current one: Reserved
                    begin
                        state           <= STATE_IN_DMAS_4;
                    end
            end

            STATE_IN_DMAS_4:
            // receiving DMA Setup FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // incorrect frame size
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    // going to the next dword, parse current one: DMA Buffer Offset
                    begin
                        loc_dma_off[31:0]   <= ll_data_in[31:0];
                        state               <= STATE_IN_DMAS_5;
                    end
            end

            STATE_IN_DMAS_5:
            // receiving DMA Setup FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // incorrect frame size
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    // going to the next dword, parse current one: DMA Transfer Count
                    begin
                        loc_dma_cnt[31:0]   <= ll_data_in[31:0];
                        state               <= STATE_IN_DMAS_6;
                    end
            end

            STATE_IN_DMAS_6:
            // receiving DMA Setup FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // correct frame size, finishing, current dword: Reserved
                    begin
                        state            <= STATE_IDLE;
                    end
                    else
                    // incorrect frame size
                    begin
                        state           <= STATE_IN_DMAS_ERR;
                        dword_cnt       <= 14'h6;
                    end
            end

            STATE_IN_DMAS_ERR:
            // FIS was started as DMA Setup, but for some reason it has a size more than needed
            // just wait until it's over and assert an error
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    begin
                        if (watchdog_dwords)
                        // if for some reason FIS continue transferring for too long, terminate it
                        begin
                            state                   <= STATE_IDLE;
                            incom_stop_req_timeout  <= 1'b1;
                        end
                        else
                            dword_cnt <= dword_cnt + 1'b1;
                    end
            end

            STATE_IN_BIST_1:
            // receiving BIST FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // incorrect frame size
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    // going to the next dword, parse current one: TODO
                    begin
                        state               <= STATE_IN_BIST_2;
                    end
            end

            STATE_IN_BIST_2:
            // receiving BIST FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // correct frame size, finishing, current dword: Reserved
                    begin
                        state            <= STATE_IDLE;
                    end
                    else
                    // incorrect frame size
                    begin
                        state           <= STATE_IN_BIST_ERR;
                        dword_cnt       <= 14'h2;
                    end
            end

            STATE_IN_BIST_ERR:
            // FIS was started as BIST Activate, but for some reason it has a size more than needed
            // just wait until it's over and assert an error
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    begin
                        if (watchdog_dwords)
                        // if for some reason FIS continue transferring for too long, terminate it
                        begin
                            state                   <= STATE_IDLE;
                            incom_stop_req_timeout  <= 1'b1;
                        end
                        else
                            dword_cnt <= dword_cnt + 1'b1;
                    end
            end

            STATE_IN_PIOS_1:
            // receiving PIO Setup FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // incorrect frame size
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    // going to the next dword, parse current one: {Device, LBA High, LBA Mid, LBA Low}
                    begin
                        loc_lba[7:0]    <= ll_data_in[7:0];  
                        loc_lba[23:16]  <= ll_data_in[15:8];
                        loc_lba[39:32]  <= ll_data_in[23:16];
                        loc_dev         <= ll_data_in[31:24];
                        state           <= STATE_IN_PIOS_2;
                    end
            end

            STATE_IN_PIOS_2:
            // receiving PIO Setup FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // incorrect frame size
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    // going to the next dword, parse current one: {Reserved, LBA High (exp), LBA Mid (exp), LBA Low (exp)}
                    begin
                        loc_lba[15:8]   <= ll_data_in[7:0];
                        loc_lba[31:24]  <= ll_data_in[15:8];
                        loc_lba[47:40]  <= ll_data_in[23:16];
                        state           <= STATE_IN_PIOS_3;
                    end
            end

            STATE_IN_PIOS_3:
            // receiving PIOS FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // incorrect frame size
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    // going to the next dword, parse current one: {E_Status, Reserved, Sector Count (exp), Sector Count}
                    begin
                        loc_count[15:0] <= ll_data_in[15:0];
                        loc_estatus     <= ll_data_in[31:24];
                        state           <= STATE_IN_PIOS_4;
                    end
            end

            STATE_IN_PIOS_4:
            // receiving PIO Setup FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // correct frame size, finishing, current dword: {Reserved, Transfer Count}
                    begin
                        loc_tran_cnt    <= ll_data_in[15:0];
                        state           <= STATE_IDLE;
                    end
                    else
                    // incorrect frame size
                    begin
                        state           <= STATE_IN_BIST_ERR;
                        dword_cnt       <= 14'h4;
                    end
            end

            STATE_IN_PIOS_ERR:
            // FIS was started as PIO Setup Activate, but for some reason it has a size more than needed
            // just wait until it's over and assert an error
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    begin
                        bad_fis_received <= 1'b1;
                        state            <= STATE_IDLE;
                    end
                    else
                    begin
                        if (watchdog_dwords)
                        // if for some reason FIS continue transferring for too long, terminate it
                        begin
                            state                   <= STATE_IDLE;
                            incom_stop_req_timeout  <= 1'b1;
                        end
                        else
                            dword_cnt <= dword_cnt + 1'b1;
                    end
            end

            STATE_IN_SDB_1:
            // receiving Set Device Bits FIS, dword by dword
            begin
                if (ll_data_val_in)
                    if (ll_data_last_in)
                    // correct frame size, finishing, current dword: Reserved
                    begin
                        state           <= STATE_IDLE;
                    end
                    else
                    // incorrect frame size
                    begin
                        state           <= STATE_IN_SDB_ERR;
                        dword_cnt       <= 14'h1;
                    end
            end

            STATE_IN_SDB_ERR:
            // FIS was started as Set Device Bits FIS, but for some reason it has a size more than needed
            // just wait until it's over and assert an error
            begin
                if (ll_data_val_in)
                     if (ll_data_last_in)
                     begin
                         bad_fis_received <= 1'b1;
                         state            <= STATE_IDLE;
                     end
                     else
                     begin
                         if (watchdog_dwords)
                         // if for some reason FIS continue transferring for too long, terminate it
                         begin
                             state                   <= STATE_IDLE;
                             incom_stop_req_timeout  <= 1'b1;
                         end
                         else
                             dword_cnt <= dword_cnt + 1'b1;
                     end
            end

            STATE_OUT_DATA_H:
            // Send data FIS header
            begin
                if (ll_data_strobe_in)
                begin
                    state       <= STATE_OUT_DATA_D;
                    dword_cnt   <= 14'h1;
                end
            end

            STATE_OUT_DATA_D:
            // Send data FIS data payload
            begin
                if (ll_data_strobe_in)
                begin
                    if (cl_data_last_in)
                    begin
                    // All data is transmitted
                        dword_cnt   <= 14'h0;
                        state       <= STATE_OUT_WAIT_RESP;
                    end
                    else
                    if (dword_cnt == 2048)
                    // data_limit_exceed - wire assigned
                        state       <= STATE_IDLE;
                    else
                    begin
                        state       <= STATE_OUT_DATA_D;
                        dword_cnt   <= dword_cnt + 1'b1;
                    end
                end
            end

            STATE_OUT_REG:
            // Register Host 2 Device FIS
            begin
                if (ll_data_strobe_in)
                    // 5 header dwords, then wait for a reception on a device side
                    if (dword_cnt[2:0] == 3'h4)
                    begin
                        dword_cnt   <= 14'h0;
                        state       <= STATE_OUT_WAIT_RESP;
                    end
                    else
                    begin
                        state       <= STATE_OUT_REG;
                        dword_cnt   <= dword_cnt + 1'b1;
                    end
            end

            STATE_OUT_DMAS:
            // DMA Setup outcoming FIS
            begin
                if (ll_data_strobe_in)
                    // 7 header dwords, then wait for a reception on a device side
                    if (dword_cnt[2:0] == 3'h6)
                    begin
                        dword_cnt   <= 14'h0;
                        state       <= STATE_OUT_WAIT_RESP;
                    end
                    else
                    begin
                        state       <= STATE_OUT_DMAS;
                        dword_cnt   <= dword_cnt + 1'b1;
                    end
            end

            STATE_OUT_BIST:
            begin
                if (ll_data_strobe_in)
                    // 3 header dwords, then wait for a reception on a device side
                    if (dword_cnt[2:0] == 3'h2)
                    begin
                        dword_cnt   <= 14'h0;
                        state       <= STATE_OUT_WAIT_RESP;
                    end
                    else
                    begin
                        state       <= STATE_OUT_BIST;
                        dword_cnt   <= dword_cnt + 1'b1;
                    end
            end

            STATE_OUT_WAIT_RESP:
            begin
                if (frame_done_good)
                    // cmd_done_good wire assigned
                    state       <= STATE_IDLE;
                else 
                if (frame_done_bad)
                    // cmd_done_bad wire assigned
                    state       <= STATE_IDLE;
                else
                if (dword_cnt == WATCHDOG_EOF_LIMIT)
                // in here dword_cnt works as a watchdog timer
                begin
                    state       <= STATE_IDLE; 
                    // watchdog_eof wire assigned
                    // for now while debugging let it be indicated on higher level TODO Choose exception. May be send incom stop req. 
                    //      Be aware of no response for that. In such case go for rst for ll. Or better make link_reset -> 1. And dont forget for oob
                end
                else
                begin
                    dword_cnt   <= dword_cnt + 1'b1;
                    state       <= STATE_OUT_WAIT_RESP;
                end
            end

            STATE_IN_UNRECOG:
            begin
                if (incom_done | incom_invalidate)
                // transmission complete
                // incom_ack_bad wire assigned
                    state   <= STATE_IDLE;
                else
                if (watchdog_dwords)
                begin
                    state                   <= STATE_IDLE;
                    incom_stop_req_timeout  <= 1'b1;
                end
                else
                begin
                    dword_cnt   <= dword_cnt + 1'b1;
                    state       <= STATE_IN_UNRECOG;
                end
                    
            end

            default:
            begin
            end
        endcase

// buys circuit
assign  cmd_busy = |state | frame_busy;

// respond if received FIS had any meaning in terms of TL
// actual response shall come next tick after done signal to fit LL fsm
reg incom_done_r;
reg incom_done_bad_r;
always @ (posedge clk)
    incom_done_bad_r <= incom_done & state == STATE_IN_UNRECOG;
always @ (posedge clk)
    incom_done_r     <= incom_done;

assign  incom_ack_bad   = incom_done_bad_r | bad_fis_received;
assign  incom_ack_good  = incom_done_r & ~incom_ack_bad;

// after a device says it received the FIS, reveal the error code
assign  cmd_done_good = state == STATE_OUT_WAIT_RESP & frame_done_good;
assign  cmd_done_bad  = state == STATE_OUT_WAIT_RESP & frame_done_bad;

// Reg H2D FIS header
wire    [31:0] header_regfis;
assign  header_regfis   = dword_cnt[2:0] == 3'h0 ?  {sh_feature_in[7:0], sh_command_in, cmd_type_r == CMD_TYPE_REG_CMD, 3'h0, cmd_port_r, 8'h27} : //  features command C R R R PMPort FISType
                          dword_cnt[2:0] == 3'h1 ?  {sh_dev_in, sh_lba_in[39:32], sh_lba_in[23:16], sh_lba_in[7:0]} : // Device LBAHigh LBAMid LBALow
                          dword_cnt[2:0] == 3'h2 ?  {sh_feature_in[15:8], sh_lba_in[47:40], sh_lba_in[31:24], sh_lba_in[15:8]} : // Features (exp) LBAHigh (exp) LBAMid (exp) LBALow (exp)
                          dword_cnt[2:0] == 3'h3 ?  {sh_control_in[7:0], 8'h00, sh_count_in[15:0]} : // Control Reserved SectorCount (exp) SectorCount
                       /*dword_cnt[2:0] == 3'h4 ?*/ {32'h0000}; // Reserved
// DMA Setup FIS header
wire    [31:0] header_dmas;
assign  header_dmas     = dword_cnt[3:0] == 4'h0 ?  {8'h0, 8'h0, sh_autoact_in, sh_inter_in, sh_dir_in, 1'b0, cmd_port_r, 8'h41} : // Reserved, Reserved, A I D R PMPort, FIS Type
                          dword_cnt[3:0] == 4'h1 ?  {sh_dma_id_in[31:0]} : // DMA Buffer Identifier Low
                          dword_cnt[3:0] == 4'h2 ?  {sh_dma_id_in[63:32]} : // DMA Buffer Identifier High
                          dword_cnt[3:0] == 4'h4 ?  {sh_buf_off_in[31:0]} : // DMA Buffer Offset
                          dword_cnt[3:0] == 4'h5 ?  {sh_dma_cnt_in[31:0]} : // DMA Transfer Count
                                  /* 4'h3 | 4'h6 */ {32'h0000}; // Reserved
// BIST Activate FIS header
wire    [31:0] header_bist; // TODO
assign  header_bist     = dword_cnt[2:0] == 3'h0 ?  {8'h00, 8'h00, 4'h0, cmd_port_r, 8'h58} : // Reserved, T A S L F P R V, R R R R PMPort, FIS Type
                          dword_cnt[2:0] == 3'h1 ?  {32'h00000000} : // Data1
                          dword_cnt[2:0] == 3'h2 ?  {32'h00000000} : // Data2
                                                    {32'h00000000};
// Data FIS header
wire    [31:0] header_data;
assign  header_data     = {8'h00, 8'h00, 4'h0, cmd_port_r, 8'h46}; // Reserved, Reserved, R R R R PMPort, FIS Type


assign  ll_header_val   = state == STATE_OUT_REG | state == STATE_OUT_DMAS | state == STATE_OUT_BIST | state == STATE_OUT_DATA_H; 
assign  ll_header_last  = state == STATE_OUT_REG    & dword_cnt[2:0] == 3'h4 |
                          state == STATE_OUT_DMAS   & dword_cnt[2:0] == 3'h6 |
                          state == STATE_OUT_BIST   & dword_cnt[2:0] == 3'h2;
assign  ll_header_dword = {32{state == STATE_OUT_REG}}      & header_regfis | 
                          {32{state == STATE_OUT_DMAS}}     & header_dmas   | 
                          {32{state == STATE_OUT_BIST}}     & header_bist   |
                          {32{state == STATE_OUT_DATA_H}}   & header_data;

// bypass data from ll to cl if it's data stage in data FIS
assign  cl_data_val_out     = ll_data_val_in & state == STATE_IN_DATA;
assign  cl_data_last_out    = ll_data_val_in & ll_data_last_in & state == STATE_IN_DATA;
assign  cl_data_mask_out    = ll_data_mask_in;
assign  cl_data_out         = ll_data_in & {32{cl_data_val_out}};
assign  ll_data_busy_out    = cl_data_busy_in;

// set data to ll: bypass payload from cl or headers constructed in here
assign  ll_data_val_out     = ll_header_val | cl_data_val_in;
assign  ll_data_last_out    = ll_header_last & ll_header_val | cl_data_last_in & ~ll_header_val; 
assign  ll_data_out         = ll_header_dword & {32{ll_header_val}} | cl_data_in & {32{~ll_header_val}};
assign  ll_data_mask_out    = {2{ll_header_val}} | cl_data_mask_in & {2{~ll_header_val}};

// limit was 2048 words + 1 headers
assign  data_limit_exceeded = dword_cnt == 14'd2048 & ~cl_data_last_in;

// check if no data was obtained from buffer by ll when we're waiting for a response
wire    chk_strobe_while_waitresp;
assign  chk_strobe_while_waitresp = state == STATE_OUT_WAIT_RESP & ll_data_strobe_in;

// issue a FIS 
assign  frame_req = cmd_val & state == STATE_IDLE & ~frame_busy;

// update shadow registers as soon as transaction finishes TODO invalidate in case of errors
// TODO update only corresponding fields, which was updated during the transmission
assign  sh_lba_out      = loc_lba;
assign  sh_count_out    = loc_count;
assign  sh_command_out  = loc_command;
assign  sh_err_out      = loc_err;
assign  sh_status_out   = loc_status;
assign  sh_estatus_out  = loc_estatus;
assign  sh_dev_out      = loc_dev;
assign  sh_port_out     = loc_port;
assign  sh_inter_out    = loc_inter;
assign  sh_dir_out      = loc_dir;
assign  sh_dma_id_out   = loc_dma_id;
assign  sh_dma_off_out  = loc_dma_off;
assign  sh_dma_cnt_out  = loc_dma_cnt;
assign  sh_tran_cnt_out = loc_tran_cnt;
assign  sh_notif_out    = loc_notif;
assign  sh_autoact_out  = loc_autoact;

assign  sh_lba_val_out      = ll_data_last_in;
assign  sh_count_val_out    = ll_data_last_in;
assign  sh_command_val_out  = ll_data_last_in;
assign  sh_err_val_out      = ll_data_last_in;
assign  sh_status_val_out   = ll_data_last_in;
assign  sh_estatus_val_out  = ll_data_last_in;
assign  sh_dev_val_out      = ll_data_last_in;
assign  sh_port_val_out     = ll_data_last_in;
assign  sh_inter_val_out    = ll_data_last_in;
assign  sh_dir_val_out      = ll_data_last_in;
assign  sh_dma_id_val_out   = ll_data_last_in;
assign  sh_dma_off_val_out  = ll_data_last_in;
assign  sh_dma_cnt_val_out  = ll_data_last_in;
assign  sh_tran_cnt_val_out = ll_data_last_in;
assign  sh_notif_val_out    = ll_data_last_in;
assign  sh_autoact_val_out  = ll_data_last_in;

// dma activate is received when its type met and no errors occurs
assign  got_dma_activate        = state == STATE_INCOMING & cl_data_last_in & ll_data_val_in & ll_data_in[7:0] == 8'h39;
assign  got_dma_activate_port   = {4{got_dma_activate}} & ll_data_in[11:8];

`ifdef CHECKERS_ENABLED
always @ (posedge clk)
    if (~rst)
    if (chk_strobe_while_waitresp)
    begin
        $display("ERROR in %m: retrieving data while being in a STATE_OUT_WAIT_RESP state");
        $finish;
    end
`endif

// eof response watchdog
assign  watchdog_eof = dword_cnt == WATCHDOG_EOF_LIMIT & state == STATE_OUT_WAIT_RESP;
`ifdef CHECKERS_ENABLED
always @ (posedge clk)
    if (~rst)
    if (watchdog_eof)
    begin
        $display("WARNING in %m: watchdog_eof asserted");
        $stop;
    end
`endif
`ifdef CHECKERS_ENABLED
always @ (posedge clk)
    if (~rst)
    if (watchdog_dwords)
    begin
        $display("ERROR in %m: state %h - current FIS contains more than 2048 dwords", state);
        $finish;
    end
`endif
wire chk_inc_dword_limit_exceeded;
assign  chk_inc_dword_limit_exceeded = state == STATE_IN_DATA & dword_cnt == 14'd2049;
`ifdef CHECKERS_ENABLED
always @ (posedge clk)
    if (~rst)
    if (chk_inc_dword_limit_exceeded)
    begin
        $display("ERROR in %m: received more than 2048 words in one FIS");
        $finish;
    end
`endif

endmodule
