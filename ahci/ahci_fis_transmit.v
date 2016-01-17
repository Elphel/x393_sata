/*******************************************************************************
 * Module: ahci_fis_transmit
 * Date:2016-01-07  
 * Author: andrey     
 * Description: Fetches commands, command tables, creates/sends FIS
 *
 * Copyright (c) 2016 Elphel, Inc .
 * ahci_fis_transmit.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  ahci_fis_transmit.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  ahci_fis_transmit #(
    parameter PREFETCH_ALWAYS =   0,
    parameter READ_REG_LATENCY =  2, // 0 if  reg_rdata is available with reg_re/reg_addr, 2 with re/regen
    parameter READ_CT_LATENCY =   1, // 0 if  reg_rdata is available with reg_re/reg_addr, 2 with re/regen
    parameter ADDRESS_BITS =     10 // number of memory address bits - now fixed. Low half - RO/RW/RWC,RW1 (2-cycle write), 2-nd just RW (single-cycle)

)(
    input                         hba_rst, // @posedge mclk - when port is reset (even COMINIT)?
    input                         mclk, // for command/status
    // Command pulses to execute states
    input                         fetch_cmd,   // Enter p:FetchCmd, fetch command header (from the register memory, prefetch command FIS)
                                               // wait for either fetch_cmd_busy == 0 or pCmdToIssue ==1 after fetch_cmd
    input                         cfis_xmit,    // transmit command (wait for dma_ct_busy == 0)
    input                         dx_transmit,  // send FIS header DWORD, (just 0x46), then forward DMA data
                                                // transmit until error, 2048DWords or pDmaXferCnt 
    input                         atapi_xmit,   // trasmit ATAPI command FIS
    
    
    output reg                    done,
    output reg                    busy,

    input                         clearCmdToIssue, // From CFIS:SUCCESS 
    output                        pCmdToIssue, // AHCI port variable
//    output                        dmaCntrZero, // DMA counter is zero - would be a duplicate to the one in receive module and dwords_sent output
//    output reg                    fetch_cmd_busy, // does not include prefetching CT - now just use busy/done
    input                         syncesc_recv, // These two inputs interrupt transmit
    input                         xmit_err,     // 
    output                 [ 1:0] dx_err,       // bit 0 - syncesc_recv, 1 - xmit_err  (valid @ xmit_err and later, reset by new command)
    
    output                 [15:0] ch_prdtl,    // Physical region descriptor table length (in entries, 0 is 0)
    output                        ch_c,        // Clear busy upon R_OK for this FIS
    output                        ch_b,        // Built-in self test command
    output                        ch_r,        // reset - may need to send SYNC escape before this command
    output                        ch_p,        // prefetchable - only used with non-zero PRDTL or ATAPI bit set
    output                        ch_w,        // Write: system memory -> device
    output                        ch_a,        // ATAPI: 1 means device should send PIO setup FIS for ATAPI command
    output                  [4:0] ch_cfl,      // length of the command FIS in DW, 0 means none. 0 and 1 - illegal,
                                               // maximal is 16 (0x10)
    output reg             [11:0] dwords_sent, // number of DWORDs transmitted (up to 2048)                                 
    
    // register memory interface
    output reg [ADDRESS_BITS-1:0] reg_addr,      
    output                 [ 1:0] reg_re,
    input                  [31:0] reg_rdata,

    // ahci_fis_receive interface
    input                  [31:2] xfer_cntr,     // transfer counter in words for both DMA (31 bit) and PIO (lower 15 bits), updated after decr_dwc


    output                        dma_ctba_ld,   // load command table address from 
    output                        dma_start,     // start processing command table, reset prdbc (next cycle after dma_ctba_ld, bits prdtl valid)
    output                        dma_dev_wr,    // write to device (valid at start)
    input                         dma_ct_busy,   // dma module is busy reading command table from the system memory
    // issue dma_prd_start same time as dma_start if prefetch enabled, otherwise with cfis_xmit
    output reg                    dma_prd_start, // at or after cmd_start - enable reading PRD/data (if any) ch_prdtl should be valid, twice - OK
    output reg                    dma_cmd_abort,   // try to abort a command TODO: Implement
    
    // reading out command table data from DMA module
    output reg             [ 4:0] ct_addr,     // DWORD address
    output                 [ 1:0] ct_re,       // [0] - re, [1] - regen 
    input                  [31:0] ct_data,     // 
    
    // DMA (memory -> device) interface
    input                  [31:0] dma_out,      // 32-bit data from the DMA module, HBA -> device port
    input                         dma_dav,      // at least one dword is ready to be read from DMA module
    output                        dma_re,       // read dword from DMA module to the output register
    
    // Data System memory or FIS -> device
    output reg             [31:0] todev_data,     // 32-bit data from the system memory to HBA (dma data)
    output reg             [ 1:0] todev_type,     // 0 - data, 1 - FIS head, 2 - FIS END (make FIS_Last?)
    output                        todev_valid,    // output register full
    input                         todev_ready     // send FIFO has room for data (>= 8? dwords)
    
    // Add a possiblity to flush any data to FIFO if error was detected after data went there?
);
    localparam CLB_OFFS32 = 'h200; //  # In the second half of the register space (0x800..0xbff - 1KB)
    localparam DATA_FIS =   32'h46;
    reg                 todev_full_r;
    reg                 dma_en_r;
    wire                fis_data_valid;
    wire          [1:0] fis_data_type;
    wire         [31:0] fis_data_out;
    
    wire                write_or_w = (dma_en_r?(dma_dav && todev_ready):fis_data_valid); // do not fill the buffer if FIFO is not ready for DMA,
                                                                                         // for fis_data_valid - longer latency
//    wire                fis_out_w =  !dma_en_r && fis_data_valid && todev_ready;
    wire                dma_re_w =    dma_en_r && dma_dav && todev_ready;

    reg               [15:0] ch_prdtl_r;
    reg                      ch_c_r;
    reg                      ch_b_r;
    reg                      ch_r_r;
    reg                      ch_p_r;
    reg                      ch_w_r;
    reg                      ch_a_r;
    reg                [4:0] ch_cmd_len_r;
    reg                [4:0] cfis_acmd_left_r; // number of DWORDS in CFIS or ACMD area of the command table left to be fetched from ahci_dma module BRAM
                                               // For CFIS this register is set from ch_cmd_len_r, for ACMD - from the xfer_cntr input
                                               // (stored in the ahci_fis_receive module)
    reg                [4:0] cfis_acmd_left_out_r; // Same, just with latency of the data available from the ahci_dma module
    
//    reg               [31:7] ch_ctba_r;                                       
    reg [READ_REG_LATENCY:0] reg_re_r;
    wire                     reg_re_w; // combined conditions to read register memory
///    wire                     reg_stb =     reg_re_r[READ_REG_LATENCY];
    wire                     pre_reg_stb = reg_re_r[READ_REG_LATENCY-1];
    reg                [3:0] fetch_chead_r; 
    reg                [3:0] fetch_chead_stb_r;
    wire                     chead_done_w = fetch_chead_stb_r[2]; // done fetching command header
    reg                      chead_bsy;    // busy reading command header
    reg                      chead_bsy_re; // busy sending read command header
    reg                      pCmdToIssue_r;
//    reg                      fetch_ct_r;
    reg                      acfis_xmit_pend_r; //
    reg                      acfis_xmit_start_r; 
    reg                      acfis_xmit_busy_r; //
//    reg                      anc_fis_r; // This is ATAPI FIS, not Command FIS

    wire                     acfis_xmit_start_w = (cfis_xmit || atapi_xmit || acfis_xmit_pend_r) && !dma_ct_busy && !fetch_cmd_busy_r; // dma_ct_busy no gaps with fetch_cmd_busy
    wire                     acfis_xmit_end = ct_stb && fis_dw_last;
    
    wire                     ct_re_w; // next cycle will be ct_re;
    reg  [READ_CT_LATENCY:0] ct_re_r;
    wire                     ct_stb = ct_re_r[READ_CT_LATENCY];
    
    reg                      fis_dw_first;
    wire                     fis_dw_last;
    
    reg               [11:2] dx_dwords_left;
    reg                      dx_fis_pend_r; // waiting to send first DWORD of the  H2D data transfer
    wire                     dx_dma_last_w; // sending last adat word
    reg                      dx_busy_r;
    reg               [ 1:0] dx_err_r;
    wire                     any_cmd_start = fetch_cmd || cfis_xmit || dx_transmit || atapi_xmit;
    wire                     done_w = dx_dma_last_w || ((|dx_err_r) && dx_busy_r) || chead_done_w || acfis_xmit_end || dma_start; // done on last transmit or error
                             // dma_start ends 'fetch_cmd'
    
    reg                      fetch_cmd_busy_r;
    
    assign todev_valid = todev_full_r;
    assign dma_re =   dma_re_w;
    assign reg_re =   reg_re_r[1:0]; 
    
    assign ch_prdtl = ch_prdtl_r;
    assign ch_c =     ch_c_r;
    assign ch_b =     ch_b_r;
    assign ch_r =     ch_r_r;
    assign ch_p =     ch_p_r;
    assign ch_w =     ch_w_r;
    assign ch_a =     ch_a_r;
    assign ch_cfl =   cfis_acmd_left_r;
    assign reg_re_w = fetch_cmd || chead_bsy_re;
    assign dma_ctba_ld = fetch_chead_stb_r[2];
    assign dma_start =   fetch_chead_stb_r[3]; // next cycle after dma_ctba_ld 
    assign pCmdToIssue = pCmdToIssue_r;
//    assign dmaCntrZero = dmaCntrZero_r;
    assign ct_re =       ct_re_r[1:0];
    assign fis_data_valid = ct_stb; // no wait write to output register 'todev_data', ct_re_r[0] is throttled according to FIFO room availability
    assign ct_re_w = todev_ready && ((cfis_acmd_left_r[4:1] != 0) || (cfis_acmd_left_r[0] && !ct_re_r[0]));  // Later add more sources
    assign fis_dw_last = (cfis_acmd_left_out_r == 1);
    assign fis_data_type = {fis_dw_last, (write_or_w && dx_fis_pend_r) | (fis_dw_first && ct_stb)};
    
    assign fis_data_out = ({32{dx_fis_pend_r}} & DATA_FIS) | ({32{ct_stb}} & ct_data) ;
    assign dx_dma_last_w = dma_en_r && dma_re_w && (dx_dwords_left[11:2] == 1);

    assign dx_err = dx_err_r;
    assign dma_dev_wr = ch_w_r;
    
    always @ (posedge mclk) begin
        // Mutliplex between DMA and FIS output to the output routed to transmit FIFO
        // Count bypassing DMA dwords to generate FIS_last condition?
        if      (hba_rst)                  todev_full_r <= 0;
        else if (write_or_w)               todev_full_r <= 1; // do not fill the buffer if FIFO is not ready
        else if (todev_ready)              todev_full_r <= 0;
        
        if (write_or_w)                    todev_data <= dma_en_r? dma_out: fis_data_out;
        
        if      (hba_rst)                  todev_type <= 3; // invalid? - no, now first and last word in command FIS (impossible?)
        else if (write_or_w)               todev_type <= dma_en_r? {dx_dma_last_w, 1'b0} : fis_data_type;
        
        // Read 3 DWORDs from the command header
        
        if (hba_rst)                       fetch_chead_r <= 0; // running 1 
        else if (fetch_cmd)                fetch_chead_r <= 1;
        else                               fetch_chead_r <= fetch_chead_r << 1;
        
        if      (hba_rst)                  fetch_chead_stb_r <= 0;
        else if (pre_reg_stb && chead_bsy) fetch_chead_stb_r <= 1;
        else                               fetch_chead_stb_r <= fetch_chead_stb_r << 1;
        
        if      (hba_rst)                  chead_bsy <= 0;
        else if (fetch_cmd)                chead_bsy <= 1;
        else if (chead_done_w)             chead_bsy <= 0;

        if      (hba_rst)                  chead_bsy_re <= 0;
        else if (fetch_cmd)                chead_bsy_re <= 1;
        else if (fetch_chead_r[1])         chead_bsy_re <= 0; // read 3 dwords
        
        if      (hba_rst)                  reg_re_r <= 0; // [0] -> reg_re output
        else if (reg_re_w)                 reg_re_r <= 1;
        else                               reg_re_r <= reg_re_r << 1;
        
        if      (fetch_cmd)                reg_addr <= CLB_OFFS32;   // there will be more conditions
        else if (reg_re_r[0])              reg_addr <= reg_addr + 1;
        
        // save command header data to registers
        if (fetch_chead_stb_r[0]) begin
            ch_prdtl_r <=   reg_rdata[31:16];
            ch_c_r <=       reg_rdata[   10];
            ch_b_r <=       reg_rdata[    9];
            ch_r_r <=       reg_rdata[    8];
            ch_p_r <=       reg_rdata[    7];
            ch_w_r <=       reg_rdata[    6];
//            ch_a_r <=       reg_rdata[    5];
            ch_cmd_len_r<=  reg_rdata[ 4: 0];
        end
//ch_a
       if (hba_rst || atapi_xmit)     ch_a_r <= 0;
       else if (fetch_chead_stb_r[0]) ch_a_r <= reg_rdata[    5];

       if      (hba_rst)         pCmdToIssue_r <= 0;
       else if (chead_done_w)    pCmdToIssue_r <= 1;
       else if (clearCmdToIssue) pCmdToIssue_r <= 0;
       
       if      (hba_rst)         fetch_cmd_busy_r <= 0;
       else if (fetch_cmd)       fetch_cmd_busy_r <= 1;
       else if (dma_start)       fetch_cmd_busy_r <= 0;
       
       //CFIS/ATAPI common
       
//       if (hba_rst || cfis_xmit)  anc_fis_r <= 0;
//       else if (atapi_xmit)       anc_fis_r <= 1;

       // fetch and send command/atapi FIS
       if (hba_rst || acfis_xmit_start_w) acfis_xmit_pend_r <= 0;
       else if (cfis_xmit || atapi_xmit)  acfis_xmit_pend_r <= 1;
        
       acfis_xmit_start_r <= !hba_rst && acfis_xmit_start_w;

       if      (hba_rst)            acfis_xmit_busy_r <= 0;
       else if (acfis_xmit_start_r) acfis_xmit_busy_r <= 1;
       else if (acfis_xmit_end)     acfis_xmit_busy_r <= 0;
       
       if      (cfis_xmit)                        cfis_acmd_left_r <=   ch_cmd_len_r[ 4: 0];   // Will assume that there is room for ...
       else if (atapi_xmit)                       cfis_acmd_left_r <=  (|xfer_cntr[31:4]) ? 5'h4 : {3'b0,xfer_cntr[3:2]};
       else if (acfis_xmit_busy_r && ct_re_r[0])  cfis_acmd_left_r <=   cfis_acmd_left_r - 1;
       
       // Counting CFIS/ATAPI FIS dwords sent to TL
       if      (acfis_xmit_start_r) cfis_acmd_left_out_r <= cfis_acmd_left_r;
       else if (ct_stb)             cfis_acmd_left_out_r <= cfis_acmd_left_out_r - 1;
       
       ct_re_r <= {ct_re_r[READ_CT_LATENCY-1:0],ct_re_w};
       
       if      (cfis_xmit)   ct_addr <= 0;
       else if (atapi_xmit)  ct_addr <= 'h10; // start of ATAPI area
       else if (cfis_acmd_left_r[0]) ct_addr <= ct_addr + 1;

       // first/last dword in FIS
       if (!acfis_xmit_busy_r) fis_dw_first <= 1;
       else if (ct_stb)        fis_dw_first <= 0;
       
       //TODO: update xfer length, prdtl (only after R_OK) - yes, do it outside
       
       if   (dx_transmit) dx_dwords_left[11:2] <= (|xfer_cntr[31:11])?10'h200:{1'b0,xfer_cntr[10:2]};
       else if (dma_re_w) dx_dwords_left[11:2] <= dx_dwords_left[11:2] - 1;
       
       if   (dx_transmit) dwords_sent <= 0;
       else if (dma_re_w) dwords_sent <= dwords_sent + 1;

       // send FIS header
       if (hba_rst || write_or_w) dx_fis_pend_r <= 0;
       else if (dx_transmit)      dx_fis_pend_r <= 1;
       
       if (hba_rst || dx_dma_last_w || (|dx_err_r)) dma_en_r  <= 0;
       else if (dx_fis_pend_r &&  write_or_w)       dma_en_r  <= 1;
       
       // Abort on transmit errors
       if (hba_rst || any_cmd_start) dx_err_r[0] <= 0;
       else if (syncesc_recv)        dx_err_r[0] <= 1;

       if (hba_rst || any_cmd_start) dx_err_r[1] <= 0;
       else if (xmit_err)            dx_err_r[1] <= 1;
       
       if      (hba_rst)                      dx_busy_r <= 0;
       else if (dx_transmit)                  dx_busy_r <= 1;
       else if (dx_dma_last_w || (|dx_err_r)) dx_busy_r <= 0;

       dma_prd_start <= (dma_start && (PREFETCH_ALWAYS || ch_p_r || !ch_w_r)) ||  // device read may prefetch just prd addresses
                        (dx_fis_pend_r &&  write_or_w); // enable PRD read now (if it was not already done)
        
       if      (hba_rst)                      done <= 0;
       else                                   done <= done_w;
       
       if      (hba_rst)                      busy <= 0;
       else if (any_cmd_start)                busy <= 1;
       else if (done_w)                       busy <= 0;

       dma_cmd_abort <= done_w && (|dx_err_r);


    end 

endmodule

