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
    parameter READ_REG_LATENCY =  2 // 0 if  reg_rdata is available with reg_re/reg_addr

)(
    input                         hba_rst, // @posedge mclk - sync reset
    input                         mclk, // for command/status
    
    
    input                         fetch_chead, // fetch command header (from the register memory
    output                 [15:0] ch_prdtl,    // Physical region descriptor table length (in entries, 0 is 0)
    output                        ch_c,        // Clear busy upon R_OK for this FIS
    output                        ch_b,        // Built-in self test command
    output                        ch_r,        // reset - may need to send SYNC escape before this command
    output                        ch_p,        // prefetchable - only used with non-zero PRDTL or ATAPI bit set
    output                        ch_w,        // Write: system memory -> device
    output                        ch_a,        // ATAPI: 1 means device should send PIO setup FIS for ATAPI command
    output                  [4:0] ch_cfl,      // length of the command FIS in DW, 0 means none. 0 and 1 - illegal,
                                               // maximal is 16 (0x10)
    output                 [31:7] ch_ctba,     // command table base address                                       
    

    // register memory interface
    output reg [ADDRESS_BITS-1:0] reg_addr,      
    output                        reg_re,
    output reg             [31:0] reg_rdata,
    
    // DMA (memory -> device) interface
    input                  [31:0] dma_out,      // 32-bit data from the DMA module, HBA -> device port
    input                         dma_dav,      // at least one dword is ready to be read from DMA module
    input                         dma_re,       // read dword from DMA module to the outpu register
    
    // Data System memory or FIS -> device
    output reg             [31:0] todev_data,     // 32-bit data from the system memory to HBA (dma data)
    output reg             [ 1:0] todev_type,     // 0 - data, 1 - FIS head, 2 - FIS END (make FIS_Last?)
    output                        todev_valid,    // output register full
    input                         todev_ready     // send FIFO has room for data (>= ? dwords)
    
    // Add a possiblity to flush any data to FIFO if error was detected after data went there?
);
    localparam CLB_OFFS32 = 'h200; //  # In the second half of the register space (0x800..0xbff - 1KB)
 
    reg                 todev_full_r;
    reg                 dma_en_r;
    wire                fis_data_valid;
    wire          [1:0] fis_data_type;
    wire         [31:0] fis_data_out;
    
    wire                write_or_w = (dma_en_r?dma_dav:fis_data_valid) && todev_ready; // do not fill the buffer if FIFO is not ready
    wire                fis_out_w =  !dma_en_r && fis_data_valid && todev_ready;
    wire                dma_re_w =    dma_en_r && dma_dav && todev_ready;

    reg               [15:0] ch_prdtl_r;
    reg                      ch_c_r;
    reg                      ch_b_r;
    reg                      ch_r_r;
    reg                      ch_p_r;
    reg                      ch_w_r;
    reg                      ch_a_r;
    reg                [4:0] ch_cfl_r;
    reg               [31:7] ch_ctba_r;                                       
    reg [READ_REG_LATENCY:0] reg_re_r;
    wire                     reg_re_w; // combined conditions to read register memory
    wire                     reg_stb =     reg_re_r[READ_REG_LATENCY];
    wire                     pre_reg_stb = reg_re_r[READ_REG_LATENCY-1];
    reg                [3:0] fetch_chead_r;
    reg                [2:0] fetch_chead_stb_r;
    reg                      chead_bsy;    // busy reading command header
    reg                      chead_bsy_re; // busy sending read command header
    
    assign todev_valid = todev_full_r;
    assign dma_re =   dma_re_w;
    assign reg_re =   reg_re_r[0]; 
    
    assign ch_prdtl = ch_prdtl_r;
    assign ch_c =     ch_c_r;
    assign ch_b =     ch_b_r;
    assign ch_r =     ch_r_r;
    assign ch_p =     ch_p_r;
    assign ch_w =     ch_w_r;
    assign ch_a =     ch_a_r;
    assign ch_cfl =   ch_cfl_r;
    assign ch_ctba =  ch_ctba_r[31:7];

    assign reg_re_w = fetch_chead || chead_bsy_re;

    
    always @ (posedge mclk) begin
        // Mutliplex between DMA and FIS output to the output routed to transmit FIFO
        // Count bypassing DMA dwords to generate FIS_last condition?
        if      (hba_rst)     todev_full_r <= 0;
        else if (write_or_w)  todev_full_r <= 1; // do not fill the buffer if FIFO is not ready
        else if (todev_ready) todev_full_r <= 0;
        
        if (write_or_w)       todev_data <= dma_en_r? dma_out: fis_data_out;
        
        if      (hba_rst)     todev_type <= 3; // invalid?
        else if (write_or_w)  todev_type <= dma_en_r? 2'h0 : fis_data_type;
        
        if (hba_rst)          fetch_chead_r <= 0;
        else if (fetch_chead) fetch_chead_r <= 1;
        else                  fetch_chead_r <= fetch_chead_r << 1;
        
        if      (hba_rst)                  fetch_chead_stb_r <= 0;
        else if (pre_reg_stb && chead_bsy) fetch_chead_stb_r <= 1;
        else                               fetch_chead_stb_r <= fetch_chead_stb_r << 1;
        
        if      (hba_rst)              chead_bsy <= 0;
        else if (fetch_chead)          chead_bsy <= 1;
        else if (fetch_chead_stb_r[2]) chead_bsy <= 0;

        if      (hba_rst)              chead_bsy_re <= 0;
        else if (fetch_chead)          chead_bsy_re <= 1;
        else if (fetch_chead_r[1])     chead_bsy_re <= 0; // read 3 dwords
        
        if      (hba_rst)              reg_re_r <= 0;
        else if (reg_re_w)             reg_re_r <= 1;
        else                           reg_re_r <= reg_re_r << 1;
        
        if      (fetch_chead)          reg_addr <= CLB_OFFS32;   // there will be more conditions
        else if (reg_re_r[0])          reg_addr <= reg_addr + 1;
        
        // save command header data to registers
        if (fetch_chead_stb_r[0]) begin
            ch_prdtl_r <= reg_rdata[31:16];
            ch_c_r <=     reg_rdata[   10];
            ch_b_r <=     reg_rdata[    9];
            ch_r_r <=     reg_rdata[    8];
            ch_p_r <=     reg_rdata[    7];
            ch_w_r <=     reg_rdata[    6];
            ch_a_r <=     reg_rdata[    5];
            ch_cfl_r <=   reg_rdata[ 4: 0];
        end

        if (fetch_chead_stb_r[2]) ch_ctba_r[31:7] <= reg_rdata[31:7];
        
        
/*
    reg                [3:0] fetch_chead_r;
    reg                [3:0] fetch_chead_stb_r;
    reg                      chead_bsy; // busy reading command header

*/        
        
    end 
    


endmodule

