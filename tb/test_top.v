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
    EXTCLK_P = ~EXTCLK_P;
    EXTCLK_N = ~EXTCLK_N;
end

integer i;
integer status;
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

    @ (negedge dut.sata_top.sata_rst);
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


    for (i = 0; i < 2048; i = i + 1) begin
        dev.receive_data_pause[i] = 32'h0;
    end
    dev.receive_wait_fifo = 0;

// issue Identify Device command
    // ATAPI command id = EC
    axi_write_single({30'h5, 2'b00}, 32'hEC);
    // start!
    axi_write_single({30'hf, 2'b00}, 32'h0108);
    $display("[Test] H2D Reg with pio cmd issued");
    // wait until reception
    while (dev.receive_id != 1) begin
        repeat (100)
            @ (posedge dev.clk);
    end

    if (dev.receive_status != 0) begin
        $display("[Test] Failed step");
        $finish;
    end

    $display("[Test] H2D Reg with pio cmd received by dev");
    // send dev2host reg fis with BSY flag
    repeat (100)
        @ (posedge dev.clk);
    for (i = 0; i < 2048; i = i + 1) begin
        dev.transmit_data_pause[i] = 32'h0;
    end
    dev.transmit_data[0] = 32'h00800034; // BSY -> 1, type = dev2host reg
    dev.transmit_data[1] = 32'hdeadbeef; // whatever
    dev.transmit_data[2] = 32'hdeadbeef; // whatever
    dev.transmit_data[3] = 32'hdeadbeef; // whatever
    dev.transmit_data[4] = 32'hdeadbeef; // whatever

    dev.linkTransmitFIS(66, 4, 0, status);
    $display("[Test] Dev sent BSY flag");

    // checks if BSY is set up // only on waves TODO
    axi_read_addr(12'h555, {30'h11, 2'b00}, 4'h3, 2'b01);
    repeat (50)
        @ (posedge dev.clk);

    




    


    repeat (1000) 
        @ (posedge dev.clk);

    for (i = 0; i < 32; i = i + 1) begin
        $display("data received : %h", dev.receive_data[i]);
    end
    $display("============= DONE =============");
    $finish;
    
// test SAXI3 iface
/*    afi_setup(3);
    axi_write_single(32'h10, 32'h0add9e55); // addr
    axi_write_single(32'h14, 32'h12345678); // lba
    axi_write_single(32'h18, 32'h00000020); // sector count
    axi_write_single(32'h20, 32'h00100000); // dma type
    axi_write_single(32'h24, 32'h00010000); // start
    axi_write_single(32'h28, 32'hdeadbee2); // data
    axi_write_single(32'h2c, 32'hdeadbee3); // data
    axi_write_single(32'h1c, 32'hffffffff); // start */
end
/*
// control the device
reg [112:0] rprim;
integer status;
initial
begin
    @ (posedge dev.phy_ready);
    repeat (30)
        @ (posedge dev.clk);
    dev.linkSendPrim("XRDY");
    rprim = dev.linkGetPrim(0);
    while (rprim != "RRDY") begin
        if (rprim != "SYNC") begin
            $display("Expected SYNC primitive, got %8s", rprim);
            $finish;
        end
        @ (posedge dev.clk)
            rprim = dev.linkGetPrim(0);
    end
    dev.linkSendPrim("SYNC");
    repeat (30)
        @ (posedge dev.clk);
    for (i = 0; i < 2048; i = i + 1) begin
        dev.transmit_data[i] = 32'hdeadbeef;
        dev.transmit_data_pause[i] = 32'h0;
    end
//    dev.transmit_crc = 32'hfd60f8a6;
    dev.transmit_crc = 32'hfd60f8a5;
    dev.linkTransmitFIS(66, 12, status);
    $display("Fis %d transmitted, status %d", 66, status);


    repeat (1000) 
        @ (posedge dev.clk);
    $display("============= DONE =============");
    $finish;
end
*/
initial begin
    #100000;
    $display("============= TIMELIMIT =============");
    $finish;
end
