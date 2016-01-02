/*******************************************************************************
 * Module: ahci_dma_rd_fifo
 * Date:2016-01-01  
 * Author: andrey     
 * Description: cross clocks,  word-realign, 64->32
 * Convertion from x64 QWORD-aligned AXI data @hclk to
 * 32-bit word-aligned data at mclk
 *
 * Copyright (c) 2016 Elphel, Inc .
 * ahci_dma_rd_fifo.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  ahci_dma_rd_fifo.v is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
`timescale 1ns/1ps

module  ahci_dma_rd_fifo#(
    parameter WCNT_BITS = 21
)(
    input                 mrst,
    input                 hrst,
    input                 mclk,
    input                 hclk,
    input [WCNT_BITS-1:0] wcnt,
    input          [63:0] din,
    input                 din_av,
    input                 din_av_many,
    output                din_re,
    
    output         [31:0] dout,
    output                dout_av,
    output                dout_av_many,
    input                 dout_re
);


endmodule

