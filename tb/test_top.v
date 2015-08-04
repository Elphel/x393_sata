/*******************************************************************************
 * Module: tb
 * Date: 2015-07-11  
 * Author: Alexey     
 * Description: dut inputs control for for tb_top.v
 *
 * Copyright (c) 2015 Elphel, Inc.
 * test_top.v is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * test_top.v file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/> .
 *******************************************************************************/
/*
 * this file is included into tb_top.v due to the compatibility with x393 design testbench
 */

// external clock to gtx

always #3.333
begin
    EXT_REF_CLK_P = ~EXT_REF_CLK_P;
    EXT_REF_CLK_N = ~EXT_REF_CLK_N;
end

// write registers
initial
begin
    CLK =1'b0;
    RST = 1'bx;
    AR_SET_CMD_r = 1'b0;
    AW_SET_CMD_r = 1'b0;
    W_SET_CMD_r = 1'b0;
    #500;
//    $display ("x393_i.ddrc_sequencer_i.phy_cmd_i.phy_top_i.rst=%d",x393_i.ddrc_sequencer_i.phy_cmd_i.phy_top_i.rst);
    #500;
    RST = 1'b1;
    NUM_WORDS_EXPECTED =0;
//    #99000; // same as glbl
    #900; // same as glbl
    repeat (20) @(posedge CLK) ;
    RST =1'b0;

    repeat (20) 
        @ (posedge CLK);
// test MAXI1 inface
    axi_set_rd_lag(0);
    axi_write_single(32'h4, 32'hdeadbeef);
    axi_read_addr(12'h777, 32'h4, 4'h3, 2'b01);
    repeat (7) 
        @ (posedge CLK);
    axi_write_single(32'h8, 32'hd34db33f);
    axi_read_addr(12'h555, 32'h0, 4'h3, 2'b01);

// test SAXI3 iface
    afi_setup(3);
    axi_write_single(32'h10, 32'h0add9e55); // addr
    axi_write_single(32'h14, 32'h12345678); // lba
    axi_write_single(32'h18, 32'h00000020); // sector count
    axi_write_single(32'h20, 32'h00100000); // dma type
    axi_write_single(32'h24, 32'h00010000); // start
/*    axi_write_single(32'h28, 32'hdeadbee2); // data
    axi_write_single(32'h2c, 32'hdeadbee3); // data
    axi_write_single(32'h1c, 32'hffffffff); // start */
end

initial
    #10000 $finish;
