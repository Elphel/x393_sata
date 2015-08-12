/*******************************************************************************
 * Module: sata_host
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: is a wrapper for command + transport + link + phy levels
 *
 * Copyright (c) 2015 Elphel, Inc.
 * sata_host.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * sata_host.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
/*
 * For now assuming the actual rtl would be Ashwin's
 */
module sata_host(
// TODO trim these old interfaces
    // command, control and status
    output  wire            ready_for_cmd,
    input   wire            new_cmd,
    input   wire    [1:0]   cmd_type,
    input   wire    [31:0]  sector_count,
    input   wire    [31:0]  sector_addr,

    // data and user clock
    input   wire    [31:0]  sata_din,
    input   wire            sata_din_we,
    output  wire            sata_core_full,
    output  wire    [31:0]  sata_dout,
    input   wire            sata_dout_re,
    output  wire            sata_core_empty,
    input   wire            data_clk_in,
    input   wire            data_clk_out,

    // timer
    output  wire    [31:0]  sata_timer,
    
    // phy
    input   wire            clkin_150,
    input   wire            reset,

    output  wire            linkup,
    output  wire            txp_out,
    output  wire            txn_out,
    input   wire            rxp_in,
    input   wire            rxn_in,

    output  wire            plllkdet,
    output  wire            dcmlocked
// end of old ifaces

// temporary
    input   wire    [31:0]  al_cmd_in; // == {cmd_type, cmd_port, cmd_val, cmd_done_bad, cmd_done_good; cmd_busy}
    input   wire            al_cmd_val_in;
    input   wire    [31:0]  al_cmd_out; // same

// tmp inputs directly from registers for each and every shadow register and control bit
// from al
    input   wire    [31:0]  al_sh_data_in, // write data
    input   wire            al_sh_data_val_in, // write strobe
    input   wire            al_sh_data_strobe_in, // read strobe
    input   wire    [15:0]  al_sh_feature_in,
    input   wire            al_sh_feature_val_in,
    input   wire    [23:0]  al_sh_lba_lo_in,
    input   wire            al_sh_lba_lo_val_in,
    input   wire    [23:0]  al_sh_lba_hi_in,
    input   wire            al_sh_lba_hi_val_in,
    input   wire    [15:0]  al_sh_count_in,
    input   wire            al_sh_count_val_in,
    input   wire    [7:0]   al_sh_command_in,
    input   wire            al_sh_command_val_in,
    input   wire    [7:0]   al_sh_dev_in,
    input   wire            al_sh_dev_val_in,
    input   wire    [7:0]   al_sh_control_in,
    input   wire            al_sh_control_val_in,
    input   wire    [31:0]  al_sh_dma_id_lo_in
    input   wire            al_sh_dma_id_lo_val_in,
    input   wire    [31:0]  al_sh_dma_id_hi_in,
    input   wire            al_sh_dma_id_hi_val_in,
    input   wire    [31:0]  al_sh_buf_off_in,
    input   wire            al_sh_buf_off_val_in,
    input   wire    [31:0]  al_sh_tran_cnt_in,
    input   wire            al_sh_tran_cnt_val_in,
    input   wire            al_sh_autoact_in,
    input   wire            al_sh_autoact_val_in,
    input   wire            al_sh_inter_in,
    input   wire            al_sh_inter_val_in,
    input   wire            al_sh_dir_in,
    input   wire            al_sh_dir_val_in,
    input   wire    [31:0]  al_sh_dma_cnt_in,
    input   wire            al_sh_dma_cnt_val_in,
    input   wire            al_sh_notif_in,
    input   wire            al_sh_notif_val_in,
    input   wire    [3:0]   al_sh_port_in,
    input   wire            al_sh_port_val_in,



);
  
wire    rst;
// sata clk
wire    clk;

// tl cmd iface
wire    [2:0]   cl2tl_cmd_type;
wire            cl2tl_cmd_val;
wire    [3:0]   cl2tl_cmd_port;
wire            cl2tl_cmd_busy;
wire            cl2tl_cmd_done_good;
wire            cl2tl_cmd_done_bad;


// data from tl
wire    [31:0]  tl2cl_data;
wire            tl2cl_data_val;
wire            tl2cl_data_last;
wire            tl2cl_data_busy;
// to tl
wire    [31:0]  cl2tl_data;
wire            cl2tl_data_last;
wire            cl2tl_data_val;
wire            cl2tl_data_strobe;


// from tl
wire    [47:0]  tl2cl_sh_lba_in;
wire    [15:0]  tl2cl_sh_count_in;
wire    [7:0]   tl2cl_sh_command_in;
wire    [7:0]   tl2cl_sh_err_in;
wire    [7:0]   tl2cl_sh_status_in;
wire    [7:0]   tl2cl_sh_estatus_in; // E_Status
wire    [7:0]   tl2cl_sh_dev_in;
wire    [3:0]   tl2cl_sh_port_in;
wire            tl2cl_sh_inter_in;
wire            tl2cl_sh_dir_in;
wire    [63:0]  tl2cl_sh_dma_id_in;
wire    [31:0]  tl2cl_sh_dma_off_in;
wire    [31:0]  tl2cl_sh_dma_cnt_in;
wire    [15:0]  tl2cl_sh_tran_cnt_in; // Transfer Count
wire            tl2cl_sh_notif_in;
wire            tl2cl_sh_autoact_in;
wire            tl2cl_sh_lba_val_in;
wire            tl2cl_sh_count_val_in;
wire            tl2cl_sh_command_val_in;
wire            tl2cl_sh_err_val_in;
wire            tl2cl_sh_status_val_in;
wire            tl2cl_sh_estatus_val_in; // E_Status
wire            tl2cl_sh_dev_val_in;
wire            tl2cl_sh_port_val_in;
wire            tl2cl_sh_inter_val_in;
wire            tl2cl_sh_dir_val_in;
wire            tl2cl_sh_dma_id_val_in;
wire            tl2cl_sh_dma_off_val_in;
wire            tl2cl_sh_dma_cnt_val_in;
wire            tl2cl_sh_tran_cnt_val_in; // Transfer Count
wire            tl2cl_sh_notif_val_in;
wire            tl2cl_sh_autoact_val_in;

// all regs to output
wire            sh_data_val;
wire    [31:0]  sh_data;
wire    [7:0]   sh_control;
wire    [15:0]  sh_feature;
wire    [47:0]  sh_lba;
wire    [15:0]  sh_count;
wire    [7:0]   sh_command;
wire    [7:0]   sh_err;
wire    [7:0]   sh_status;
wire    [7:0]   sh_estatus; // E_Status
wire    [7:0]   sh_dev;
wire    [3:0]   sh_port;
wire            sh_inter;
wire            sh_dir;
wire    [63:0]  sh_dma_id;
wire    [31:0]  sh_dma_off;
wire    [31:0]  sh_dma_cnt;
wire    [15:0]  sh_tran_cnt; // Transfer Count
wire            sh_notif;
wire            sh_autoact;

command command(
    .rst                                (rst),
    .clk                                (clk),

// tl cmd iface
    .cmd_type                           (cl2tl_cmd_type),
    .cmd_val                            (cl2tl_cmd_val),
    .cmd_port                           (cl2tl_cmd_port),
    .cmd_busy                           (cl2tl_cmd_busy),
    .cmd_done_good                      (cl2tl_cmd_done_good),
    .cmd_done_bad                       (cl2tl_cmd_done_bad),

// temporary TODO
    .al_cmd_in                          (al_cmd_in), // == {cmd_type, cmd_port, cmd_val, cmd_done_bad, cmd_done_good, cmd_busy}
    .al_cmd_val_in                      (al_cmd_val_in),
    .al_cmd_out                         (al_cmd_out), // same

// data from tl
    .tl_data_in                         (tl2cl_data),
    .tl_data_val_in                     (tl2tl_data_val),
    .tl_data_last_in                    (tl2tl_data_last),
    .tl_data_busy_out                   (tl2tl_data_busy),
// to tl
    .tl_data_out                        (cl2tl_data),
    .tl_data_last_out                   (cl2tl_data_last),
    .tl_data_val_out                    (cl2tl_data_val),
    .tl_data_strobe_in                  (cl2tl_data_strobe),

// tmp inputs directly from registers for each and every shadow register and control bit
// from al
    .al_sh_data_in                      (al_sh_data_in), // write data
    .al_sh_data_val_in                  (al_sh_data_val_in), // write strobe
    .al_sh_data_strobe_in               (al_sh_data_strobe_in), // read strobe
    .al_sh_feature_in                   (al_sh_feature_in),
    .al_sh_feature_val_in               (al_sh_feature_val_in),
    .al_sh_lba_lo_in                    (al_sh_lba_lo_in),
    .al_sh_lba_lo_val_in                (al_sh_lba_lo_val_in),
    .al_sh_lba_hi_in                    (al_sh_lba_hi_in),
    .al_sh_lba_hi_val_in                (al_sh_lba_hi_val_in),
    .al_sh_count_in                     (al_sh_count_in),
    .al_sh_count_val_in                 (al_sh_count_val_in),
    .al_sh_command_in                   (al_sh_command_in),
    .al_sh_command_val_in               (al_sh_command_val_in),
    .al_sh_dev_in                       (al_sh_dev_in),
    .al_sh_dev_val_in                   (al_sh_dev_val_in),
    .al_sh_control_in                   (al_sh_control_in),
    .al_sh_control_val_in               (al_sh_control_val_in),
    .al_sh_dma_id_lo_in                 (al_sh_dma_id_lo_in),
    .al_sh_dma_id_lo_val_in             (al_sh_dma_id_lo_val_in),
    .al_sh_dma_id_hi_in                 (al_sh_dma_id_hi_in),
    .al_sh_dma_id_hi_val_in             (al_sh_dma_id_hi_val_in),
    .al_sh_buf_off_in                   (al_sh_buf_off_in),
    .al_sh_buf_off_val_in               (al_sh_buf_off_val_in),
    .al_sh_tran_cnt_in                  (al_sh_tran_cnt_in),
    .al_sh_tran_cnt_val_in              (al_sh_tran_cnt_val_in),
    .al_sh_autoact_in                   (al_sh_autoact_in),
    .al_sh_autoact_val_in               (al_sh_autoact_val_in),
    .al_sh_inter_in                     (al_sh_inter_in),
    .al_sh_inter_val_in                 (al_sh_inter_val_in),
    .al_sh_dir_in                       (al_sh_dir_in),
    .al_sh_dir_val_in                   (al_sh_dir_val_in),
    .al_sh_dma_cnt_in                   (al_sh_dma_cnt_in),
    .al_sh_dma_cnt_val_in               (al_sh_dma_cnt_val_in),
    .al_sh_notif_in                     (al_sh_notif_in),
    .al_sh_notif_val_in                 (al_sh_notif_val_in),
    .al_sh_port_in                      (al_sh_port_in),
    .al_sh_port_val_in                  (al_sh_port_val_in),

// from tl
    .tl_sh_lba_in                       (tl_sh_lba_in),
    .tl_sh_count_in                     (tl_sh_count_in),
    .tl_sh_command_in                   (tl_sh_command_in),
    .tl_sh_err_in                       (tl_sh_err_in),
    .tl_sh_status_in                    (tl_sh_status_in),
    .tl_sh_estatus_in                   (tl_sh_estatus_in), // E_Status
    .tl_sh_dev_in                       (tl_sh_dev_in),
    .tl_sh_port_in                      (tl_sh_port_in),
    .tl_sh_inter_in                     (tl_sh_inter_in),
    .tl_sh_dir_in                       (tl_sh_dir_in),
    .tl_sh_dma_id_in                    (tl_sh_dma_id_in),
    .tl_sh_dma_off_in                   (tl_sh_dma_off_in),
    .tl_sh_dma_cnt_in                   (tl_sh_dma_cnt_in),
    .tl_sh_tran_cnt_in                  (tl_sh_tran_cnt_in), // Transfer Count
    .tl_sh_notif_in                     (tl_sh_notif_in),
    .tl_sh_autoact_in                   (tl_sh_autoact_in),
    .tl_sh_lba_val_in                   (tl_sh_lba_val_in),
    .tl_sh_count_val_in                 (tl_sh_count_val_in),
    .tl_sh_command_val_in               (tl_sh_command_val_in),
    .tl_sh_err_val_in                   (tl_sh_err_val_in),
    .tl_sh_status_val_in                (tl_sh_status_val_in),
    .tl_sh_estatus_val_in               (tl_sh_estatus_val_in), // E_Status
    .tl_sh_dev_val_in                   (tl_sh_dev_val_in),
    .tl_sh_port_val_in                  (tl_sh_port_val_in),
    .tl_sh_inter_val_in                 (tl_sh_inter_val_in),
    .tl_sh_dir_val_in                   (tl_sh_dir_val_in),
    .tl_sh_dma_id_val_in                (tl_sh_dma_id_val_in),
    .tl_sh_dma_off_val_in               (tl_sh_dma_off_val_in),
    .tl_sh_dma_cnt_val_in               (tl_sh_dma_cnt_val_in),
    .tl_sh_tran_cnt_val_in              (tl_sh_tran_cnt_val_in), // Transfer Count
    .tl_sh_notif_val_in                 (tl_sh_notif_val_in),
    .tl_sh_autoact_val_in               (tl_sh_autoact_val_in),

// all regs to output
    .sh_data_val_out                    (sh_data_val_out),
    .sh_data_out                        (sh_data_out),
    .sh_control_out                     (sh_control_out),
    .sh_feature_out                     (sh_feature_out),
    .sh_lba_out                         (sh_lba_out),
    .sh_count_out                       (sh_count_out),
    .sh_command_out                     (sh_command_out),
    .sh_err_out                         (sh_err_out),
    .sh_status_out                      (sh_status_out),
    .sh_estatus_out                     (sh_estatus_out), // E_Status
    .sh_dev_out                         (sh_dev_out),
    .sh_port_out                        (sh_port_out),
    .sh_inter_out                       (sh_inter_out),
    .sh_dir_out                         (sh_dir_out),
    .sh_dma_id_out                      (sh_dma_id_out),
    .sh_dma_off_out                     (sh_dma_off_out),
    .sh_dma_cnt_out                     (sh_dma_cnt_out),
    .sh_tran_cnt_out                    (sh_tran_cnt_out), // Transfer Count
    .sh_notif_out                       (sh_notif_out),
    .sh_autoact_out                     (sh_autoact_out)
);

// issue a frame
wire    frame_req;
// frame started to be transmitted
wire    frame_ack;
// frame issue was rejected because of incoming frame with higher priority
wire    frame_rej;
// LL is not ready to receive a frame request. frame_req shall be low if busy is asserted
wire    frame_busy;
// frame was transmitted w/o probles and successfully received @ a device side
wire    frame_done_good;
// frame was transmitted, but device messages of problems with receiving
wire    frame_done_bad;

// LL reports of an incoming frame transmission. They're always allowed and have the highest priority
wire    incom_start;
// LL reports of a completion of an incoming frame transmission.
wire    incom_done;
// LL reports of errors in current FIS
wire    incom_invalidate; // TODO
// TL analyzes FIS and returnes if FIS makes sense.
wire    incom_ack_good;
// ... and if it doesn't
wire    incom_ack_bad;

// transmission interrupts
// TL demands to brutally cancel current transaction TODO
wire    sync_escape_req;
// acknowlegement of a successful reception TODO
wire    sync_escape_ack;
// TL demands to stop current recieving session TODO
wire    incom_stop_req;

// shows if dma activate was received (a pulse)
wire            got_dma_activate;
wire    [3:0]   got_dma_activate_port;
// if CL made a mistake in controlling data FIS length
wire            data_limit_exceeded;

// LL data
// data inputs from LL
wire    [DATA_BYTE_WIDTH*8 - 1:0]   ll_data_in;
wire    [DATA_BYTE_WIDTH/2 - 1:0]   ll_data_mask_in;
wire                                ll_data_val_in;
wire                                ll_data_last_in;
// transport layer tells if its inner buffer is almost full
wire                                ll_data_busy_out;

// data outputs to LL
wire    [DATA_BYTE_WIDTH*8 - 1:0]   ll_data_out;
// not implemented yet TODO
wire    [DATA_BYTE_WIDTH*8 - 1:0]   ll_data_mask_out;
wire                                ll_data_last_out;
wire                                ll_data_val_out;
wire                                ll_data_strobe_in;

// watchdog timers calls. They shall be handled in TL, but for debug purposes are wired to the upper level
// when eof acknowledgement is not received after sent FIS
wire    watchdog_eof;
// when too many dwords is in current FIS
wire    watchdog_dwords;

transport transport(
    .clk                                (clk),
    .rst                                (rst),

    // link layer (LL) control

    // issue a frame
    .frame_req                          (frame_req),
    // frame started to be transmitted
    .frame_ack                          (frame_ack),
    // frame issue was rejected because of incoming frame with higher priority
    .frame_rej                          (frame_rej),
    // LL is not ready to receive a frame request. frame_req shall be low if busy is asserted
    .frame_busy                         (frame_busy),
    // frame was transmitted w/o probles and successfully received @ a device side
    .frame_done_good                    (frame_done_good),
    // frame was transmitted, but device messages of problems with receiving
    .frame_done_bad                     (frame_done_bad),

    // LL reports of an incoming frame transmission. They're always allowed and have the highest priority
    .incom_start                        (incom_start),
    // LL reports of a completion of an incoming frame transmission.
    .incom_done                         (incom_done),
    // LL reports of errors in current FIS
    .incom_invalidate                   (incom_invalidate), // TODO
    // TL analyzes FIS and returnes if FIS makes sense.
    .incom_ack_good                     (incom_ack_good),
    // ... and if it doesn't
    .incom_ack_bad                      (incom_ack_bad),

    // transmission interrupts
    // TL demands to brutally cancel current transaction TODO
    .sync_escape_req                    (sync_escape_req),
    // acknowlegement of a successful reception TODO
    .sync_escape_ack                    (sync_escape_ack),
    // TL demands to stop current recieving session TODO
    .incom_stop_req                     (incom_stop_req),

    // controls from a command layer (CL)
    // FIS type, ordered by CL
    .cmd_type                           (cl2tl_cmd_type),
    // request itself
    .cmd_val                            (cl2tl_cmd_val),
    // destination port
    .cmd_port                           (cl2tl_cmd_port),
    // if cmd got into processing, busy asserts, when TL is ready to receive a new cmd, busy deasserts
    .cmd_busy                           (cl2tl_cmd_busy),
    // indicates completion of a request
    .cmd_done_good                      (cl2tl_cmd_done_good),
    // request is completed, but device wasn't able to receive
    .cmd_done_bad                       (cl2tl_cmd_done_bad),

    // shadow registers TODO reduce outputs/inputs count. or not
    // actual registers are stored in CL
    .sh_data_in                         (sh_data),
    .sh_feature_in                      (sh_feature),
    .sh_lba_in                          (sh_lba),
    .sh_count_in                        (sh_count),
    .sh_command_in                      (sh_command),
    .sh_dev_in                          (sh_dev),
    .sh_control_in                      (sh_control),
    .sh_autoact_in                      (sh_autoact),
    .sh_inter_in                        (sh_inter),
    .sh_dir_in                          (sh_dir),
    .sh_dma_id_in                       (sh_dma_id),
    .sh_buf_off_in                      (sh_buf_off),
    .sh_dma_cnt_in                      (sh_dma_cnt),
    .sh_notif_in                        (sh_notif),
    .sh_tran_cnt_in                     (sh_tran_cnt),
    .sh_port_in                         (sh_port),
    // TL decodes register writes and sends corresponding issues to CL
    .sh_lba_out                         (tl2cl_sh_lba_out),
    .sh_count_out                       (tl2cl_sh_count_out),
    .sh_command_out                     (tl2cl_sh_command_out),
    .sh_err_out                         (tl2cl_sh_err_out),
    .sh_status_out                      (tl2cl_sh_status_out),
    .sh_estatus_out                     (tl2cl_sh_estatus_out), // E_Status
    .sh_dev_out                         (tl2cl_sh_dev_out),
    .sh_port_out                        (tl2cl_sh_port_out),
    .sh_inter_out                       (tl2cl_sh_inter_out),
    .sh_dir_out                         (tl2cl_sh_dir_out),
    .sh_dma_id_out                      (tl2cl_sh_dma_id_out),
    .sh_dma_off_out                     (tl2cl_sh_dma_off_out),
    .sh_dma_cnt_out                     (tl2cl_sh_dma_cnt_out),
    .sh_tran_cnt_out                    (tl2cl_sh_tran_cnt_out), // Transfer Count
    .sh_notif_out                       (tl2cl_sh_notif_out),
    .sh_autoact_out                     (tl2cl_sh_autoact_out),
    .sh_lba_val_out                     (tl2cl_sh_lba_val_out),
    .sh_count_val_out                   (tl2cl_sh_count_val_out),
    .sh_command_val_out                 (tl2cl_sh_command_val_out),
    .sh_err_val_out                     (tl2cl_sh_err_val_out),
    .sh_status_val_out                  (tl2cl_sh_status_val_out),
    .sh_estatus_val_out                 (tl2cl_sh_estatus_val_out), // E_Status
    .sh_dev_val_out                     (tl2cl_sh_dev_val_out),
    .sh_port_val_out                    (tl2cl_sh_port_val_out),
    .sh_inter_val_out                   (tl2cl_sh_inter_val_out),
    .sh_dir_val_out                     (tl2cl_sh_dir_val_out),
    .sh_dma_id_val_out                  (tl2cl_sh_dma_id_val_out),
    .sh_dma_off_val_out                 (tl2cl_sh_dma_off_val_out),
    .sh_dma_cnt_val_out                 (tl2cl_sh_dma_cnt_val_out),
    .sh_tran_cnt_val_out                (tl2cl_sh_tran_cnt_val_out), // Transfer Count
    .sh_notif_val_out                   (tl2cl_sh_notif_val_out),
    .sh_autoact_val_out                 (tl2cl_sh_autoact_val_out),


    // shows if dma activate was received (a pulse)
    .got_dma_activate                   (got_dma_activate),
    .got_dma_activate_port              (got_dma_activate_port),
    // if CL made a mistake in controlling data FIS length
    .data_limit_exceeded                (data_limit_exceeded),

    // LL data
    // data inputs from LL
    .ll_data_in                         (ll_data_in),
    .ll_data_mask_in                    (ll_data_mask_in),
    .ll_data_val_in                     (ll_data_val_in),
    .ll_data_last_in                    (ll_data_last_in),
    // transport layer tells if its inner buffer is almost full
    .ll_data_busy_out                   (ll_data_busy_out),

    // data outputs to LL
    .ll_data_out                        (ll_data_out),
    // not implemented yet TODO
    .ll_data_mask_out                   (ll_data_mask_out),
    .ll_data_last_out                   (ll_data_last_out),
    .ll_data_val_out                    (ll_data_val_out),
    .ll_data_strobe_in                  (ll_data_strobe_in),

    // CL data
    // required content is bypassed from ll, other is trimmed
    // only content of data FIS, starting from 1st dword. Max burst = 2048 dwords
    // data outputs to CL
    .cl_data_out                        (tl2cl_data),
    .cl_data_mask_out                   (),
    .cl_data_val_out                    (tl2cl_data_val),
    .cl_data_last_out                   (tl2cl_data_last),
    // transport layer tells if its inner buffer is almost full
    .cl_data_busy_in                    (tl2cl_data_busy),

    // data inputs from CL
    .cl_data_in                         (cl2tl_data),
    // not implemented yet TODO
    .cl_data_mask_in                    (cl2tl_data_mask),
    .cl_data_last_in                    (cl2tl_data_last),
    .cl_data_val_in                     (cl2tl_data_val),
    .cl_data_strobe_out                 (cl2tl_data_strobe),


    // watchdog timers calls. They shall be handled in TL, but for debug purposes are wired to the upper level
    // when eof acknowledgement is not received after sent FIS
    .watchdog_eof                       (watchdog_eof),
    // when too many dwords is in current FIS
    .watchdog_dwords                    (watchdog_dwords)
);


// data s from transport layer
// data stream (if any data during OOB setting => ignored)
wire    [DATA_BYTE_WIDTH*8 - 1:0] data_in,
// in case of strange data aligments and size (1st mentioned @ doc, p.310, odd number of words case)
// Actually, only last data bundle shall be masked, others are always valid.
// Mask could be encoded into 3 bits instead of 4 for qword, but encoding+decoding aren't worth the bit
// TODO, for now not supported, all mask bits are assumed to be set
wire    [DATA_BYTE_WIDTH/2 - 1:0] data_mask_in,
// buffer read strobe
wire    data_strobe_out,
// transaction's last data budle pulse
wire    data_last_in,
// read data is valid (if 0 while last pulse wasn't received => need to hold the line)
wire    data_val_in,

// data s to transport layer
// read data, same as related s
wire    [DATA_BYTE_WIDTH*8 - 1:0] data_out,
// same thing - all 1s for now. TODO
wire    [DATA_BYTE_WIDTH/2 - 1:0] data_mask_out,
// count every data bundle read by transport layer, even if busy flag is set
// let the transport layer handle oveflows by himself
wire    data_val_out,
// transport layer tells if its inner buffer is almost full
wire    data_busy_in,
wire    data_last_out,

// request for a new frame transition
wire    frame_req,
// a little bit of overkill with the cound of response signals, think of throwing out 1 of them
// LL tells back if it cant handle the request for now
wire    frame_busy,
// LL tells if the request is transmitting
wire    frame_ack,
// or if it was cancelled because of simultanious incoming transmission
wire    frame_rej,
// TL tell if the outcoming transaction is done and how it was done
wire    frame_done_good,
wire    frame_done_bad,

// if started an incoming transaction
wire    incom_start,
// if incoming transition was completed
wire    incom_done,
// if incoming transition had errors
wire    incom_invalidate,
// transport layer responds on a completion of a FIS
wire    incom_ack_good,
wire    incom_ack_bad,

// oob sequence is reinitiated and link now is not established or rxelecidle
wire    link_reset,
// TL demands to brutally cancel current transaction
wire    sync_escape_req,
// acknowlegement of a successful reception
wire    sync_escape_ack,
// TL demands to stop current recieving session
wire    incom_stop_req,

// s from phy
// phy is ready - link is established
wire    phy_ready,

// data-primitives stream from phy
wire    [DATA_BYTE_WIDTH*8 - 1:0] phy_data_in,
wire    [DATA_BYTE_WIDTH/2 - 1:0] phy_isk_in, // charisk
wire    [DATA_BYTE_WIDTH/2 - 1:0] phy_err_in, // disperr | notintable
// to phy
wire    [DATA_BYTE_WIDTH*8 - 1:0] phy_data_out,
wire    [DATA_BYTE_WIDTH/2 - 1:0] phy_isk_out // charisk


link link(
    // TODO insert watchdogs
    .rst                                (rst),
    .clk                                (clk),

    // data inputs from transport layer
    // input data stream (if any data during OOB setting => ignored)
    .data_in                            (data_in),
    // in case of strange data aligments and size (1st mentioned @ doc, p.310, odd number of words case)
    // Actually, only last data bundle shall be masked, others are always valid.
    // Mask could be encoded into 3 bits instead of 4 for qword, but encoding+decoding aren't worth the bit
    // TODO, for now not supported, all mask bits are assumed to be set
    .data_mask_in                       (data_mask_in),
    // buffer read strobe
    .data_strobe_out                    (data_strobe_out),
    // transaction's last data budle pulse
    .data_last_in                       (data_last_in),
    // read data is valid (if 0 while last pulse wasn't received => need to hold the line)
    .data_val_in                        (data_val_in),

    // data outputs to transport layer
    // read data, same as related inputs
    .data_out                           (data_out),
    // same thing - all 1s for now. TODO
    .data_mask_out                      (data_mask_out),
    // count every data bundle read by transport layer, even if busy flag is set
    // let the transport layer handle oveflows by himself
    .data_val_out                       (data_val_out),
    // transport layer tells if its inner buffer is almost full
    .data_busy_in                       (data_busy_in),
    .data_last_out                      (data_last_out),

    // request for a new frame transition
    .frame_req                          (frame_req),
    // a little bit of overkill with the cound of response signals, think of throwing out 1 of them
    // LL tells back if it cant handle the request for now
    .frame_busy                         (frame_busy),
    // LL tells if the request is transmitting
    .frame_ack                          (frame_ack),
    // or if it was cancelled because of simultanious incoming transmission
    .frame_rej                          (frame_rej),
    // TL tell if the outcoming transaction is done and how it was done
    .frame_done_good                    (frame_done_good),
    .frame_done_bad                     (frame_done_bad),

    // if started an incoming transaction
    .incom_start                        (incom_start),
    // if incoming transition was completed
    .incom_done                         (incom_done),
    // if incoming transition had errors
    .incom_invalidate                   (incom_invalidate),
    // transport layer responds on a completion of a FIS
    .incom_ack_good                     (incom_ack_good),
    .incom_ack_bad                      (incom_ack_bad),

    // oob sequence is reinitiated and link now is not established or rxelecidle
    .link_reset                         (link_reset),
    // TL demands to brutally cancel current transaction
    .sync_escape_req                    (sync_escape_req),
    // acknowlegement of a successful reception
    .sync_escape_ack                    (sync_escape_ack),
    // TL demands to stop current recieving session
    .incom_stop_req                     (incom_stop_req),

    // inputs from phy
    // phy is ready - link is established
    .phy_ready                          (phy_ready),

    // data-primitives stream from phy
    .phy_data_in                        (phy_data_in),
    .phy_isk_in                         (phy_isk_in), // charisk
    .phy_err_in                         (phy_err_in), // disperr | notintable
    // to phy
    .phy_data_out                       (phy_data_out),
    .phy_isk_out // charis
);
endmodule
