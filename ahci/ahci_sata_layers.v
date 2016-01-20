/*******************************************************************************
 * Module: ahci_sata_layers
 * Date:2016-01-19  
 * Author: andrey     
 * Description: Link and PHY SATA layers
 *
 * Copyright (c) 2016 Elphel, Inc .
 * ahci_sata_layers.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  ahci_sata_layers.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  ahci_sata_layers(
    input              exrst,   // master reset that resets PLL and GTX    
    output             rst,     // PHY-generated reset after PLL lock
    output             clk,     // PHY-generated clock, 75MHz for SATA2
// Data/type FIFO, host -> device   
    // Data System memory or FIS -> device
    input       [31:0] h2d_data,     // 32-bit data from the system memory to HBA (dma data)
    input       [ 1:0] h2d_type,     // 0 - data, 1 - FIS head, 2 - FIS LAST
    input              h2d_valid,    // input  register full
    output             h2d_ready,     // send FIFO has room for data (>= 8? dwords)
 
// Data/type FIFO, device -> host
    output      [31:0] d2h_data,         // FIFO input  data
    output      [ 1:0] d2h_type,    // 0 - data, 1 - FIS head, 2 - R_OK, 3 - R_ERR (last two - after data, so ignore data with R_OK/R_ERR)
    output             d2h_valid,  // Data available from the transport layer in FIFO                
    output             d2h_many,    // Multiple DWORDs available from the transport layer in FIFO           
    input              d2h_ready,   // This module or DMA consumes DWORD
    
   // communication with link/phys layers
    output      [ 1:0] phy_ready, // 0 - not ready, 1..3 - negotiated speed
    output             syncesc_recv, // These two **puts interrupt transmit
    output             xmit_err,     // Error during sending of a FIS
    input              syncesc_send,  // Send sync escape
    output             syncesc_send_done, // "SYNC escape until the interface is quiescent..."
    input              comreset_send,     // Not possible yet?
    output             cominit_got,
    input              set_offline, // electrically idle
    output             x_rdy_collision, // X_RDY/X_RDY collision on interface 
    
    input              send_R_OK,    // Should it be originated in this layer SM?
    input              send_R_ERR,
    
    // additional errors from SATA layers (single-clock pulses):
    output             serr_DT,   // RWC: Transport state transition error
    output             serr_DS,   // RWC: Link sequence error
    output             serr_DH,   // RWC: Handshake Error (i.e. Device got CRC error)
    output             serr_DC,   // RWC: CRC error in Link layer
    output             serr_DB,   // RWC: 10B to 8B decode error
    output             serr_DW,   // RWC: COMMWAKE signal was detected
    output             serr_DI,   // RWC: PHY Internal Error
                                  // sirq_PRC,
                                  // sirq_IF || // sirq_INF  
    output             serr_EP,   // RWC: Protocol Error - a violation of SATA protocol detected
    output             serr_EC,   // RWC: Persistent Communication or Data Integrity Error
    output             serr_ET,   // RWC: Transient Data Integrity Error (error not recovered by the interface)
    output             serr_EM,   // RWC: Communication between the device and host was lost but re-established
    output             serr_EI,   // RWC: Recovered Data integrity Error
    // additional control signals for SATA layers
    input        [3:0] sctl_ipm,          // Interface power management transitions allowed
    input        [3:0] sctl_spd          // Interface maximal speed
);

    link #(
        .DATA_BYTE_WIDTH(4)
    ) link_i (
        .rst              (), // input wire 
        .clk              (), // input wire 
    // data inputs from transport layer
        .data_in          (), // input[31:0] wire // input data stream (if any data during OOB setting => ignored)
    // in case of strange data aligments and size (1st mentioned @ doc, p.310, odd number of words case)
    // Actually, only last data bundle shall be masked, others are always valid.
    // Mask could be encoded into 3 bits instead of 4 for qword, but encoding+decoding aren't worth the bit
    // TODO, for now not supported, all mask bits are assumed to be set
        .data_mask_in     (), // input[1:0] wire 
        .data_strobe_out  (), // output wire  // buffer read strobe
        .data_last_in     (), // input wire // transaction's last data budle pulse
        .data_val_in      (), // input wire // read data is valid (if 0 while last pulse wasn't received => need to hold the line)
        .data_out         (), // output[31:0] wire  // read data, same as related inputs
        .data_mask_out    (), // output[1:0] wire // same thing - all 1s for now. TODO
        .data_val_out     (), // output wire // count every data bundle read by transport layer, even if busy flag is set // let the transport layer handle oveflows by himself
        .data_busy_in     (), // input wire  // transport layer tells if its inner buffer is almost full
        .data_last_out    (), // output wire 
        .frame_req        (), // input wire  // request for a new frame transition
        .frame_busy       (), // output wire // a little bit of overkill with the cound of response signals, think of throwing out 1 of them // LL tells back if it cant handle the request for now
        .frame_ack        (), // output wire // LL tells if the request is transmitting
        .frame_rej        (), // output wire // or if it was cancelled because of simultanious incoming transmission
        .frame_done_good  (), // output wire // TL tell if the outcoming transaction is done and how it was done
        .frame_done_bad   (), // output wire 
        .incom_start      (), // output wire // if started an incoming transaction
        .incom_done       (), // output wire // if incoming transition was completed
        .incom_invalidate (), // output wire // if incoming transition had errors
        .incom_ack_good   (), // input wire  // transport layer responds on a completion of a FIS
        .incom_ack_bad    (), // input wire  // oob sequence is reinitiated and link now is not established or rxelecidle
        .link_reset       (), // input wire  // oob sequence is reinitiated and link now is not established or rxelecidle
        .sync_escape_req  (), // input wire  // TL demands to brutally cancel current transaction
        .sync_escape_ack  (), // output wire // acknowlegement of a successful reception?
        .incom_stop_req   (), // input wire  // TL demands to stop current recieving session
        // inputs from phy
        .phy_ready        (), // input wire        // phy is ready - link is established
        // data-primitives stream from phy
        .phy_data_in      (), // input[31:0] wire  // phy_data_in
        .phy_isk_in       (), // input[3:0] wire   // charisk
        .phy_err_in       (), // input[3:0] wire   // disperr | notintable
        // to phy
        .phy_data_out     (), // output[31:0] wire 
        .phy_isk_out      () // output[3:0] wire   // charisk
    );
    reg        [8:0] h2d_raddr;
    reg        [8:0] h2d_waddr;
    reg        [8:0] d2h_raddr;
    reg        [8:0] d2h_waddr;
    wire       [1:0] dummy1;
    sata_phy #(
        .DATA_BYTE_WIDTH(4)
    ) sata_phy_i (
        .extrst          (), // input wire 
        .clk             (), // output wire 
        .rst             (), // output wire 
        .reliable_clk    (), // input wire 
        .phy_ready       (), // output wire 
        .gtx_ready       (), // output wire 
        .debug_cnt       (), // output[11:0] wire 
        .extclk_p        (), // input wire 
        .extclk_n        (), // input wire 
        .txp_out         (), // output wire 
        .txn_out         (), // output wire 
        .rxp_in          (), // input wire 
        .rxn_in          (), // input wire 
        .ll_data_out     (), // output[31:0] wire 
        .ll_charisk_out  (), // output[3:0] wire 
        .ll_err_out      (), // output[3:0] wire 
        .ll_data_in      (), // input[31:0] wire 
        .ll_charisk_in   () // input[3:0] wire 
    );
    
    ram18p_var_w_var_r #(
        .REGISTERS    (1),
        .LOG2WIDTH_WR (5),
        .LOG2WIDTH_RD (5)
    ) fifo_h2d_i (
        .rclk     (clk), // input
        .raddr    (h2d_raddr), // input[8:0] 
        .ren      (), // input
        .regen    (), // input
        .data_out (), // output[35:0] 
        .wclk     (clk), // input
        .waddr    (h2d_waddr), // input[8:0] 
        .we       (), // input
        .web      (4'hf), // input[3:0] 
        .data_in  ({2'b0,h2d_type,h2d_data}) // input[35:0] 
    );

    ram18p_var_w_var_r #(
        .REGISTERS    (1),
        .LOG2WIDTH_WR (5),
        .LOG2WIDTH_RD (5)
    ) fifo_d2h_i (
        .rclk     (clk), // input
        .raddr    (d2h_raddr), // input[8:0] 
        .ren      (), // input
        .regen    (), // input
        .data_out ({dummy1,d2h_type,d2h_data}), // output[35:0] 
        .wclk     (clk), // input
        .waddr    (d2h_waddr), // input[8:0] 
        .we       (), // input
        .web      (4'hf), // input[3:0] 
        .data_in  () // input[35:0] 
    );

endmodule

