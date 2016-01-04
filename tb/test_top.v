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
/*
 * this file is included into tb_top.v due to the compatibility with x393 design testbench
 */
    reg [639:0] TEST_TITLE; // to show human-readable state in the GTKWave

// external clock to gtx

always #3.333
begin
    EXTCLK_P = ~EXTCLK_P;
    EXTCLK_N = ~EXTCLK_N;
end

// MAXI clock
always #10
begin
    CLK = ~CLK;
end

integer i;
integer status;
integer id;
reg [31:0] data;
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
    repeat (20) @(posedge EXTCLK_P) ;
    RST =1'b0;

    @ (negedge dut.sata_top.sata_rst);
    repeat (20) 
        @ (posedge dev.clk);
// test MAXI1 inface
    axi_set_rd_lag(0);
    axi_write_single(32'h4, 32'hdeadbeef);
//    axi_read_addr(12'h777, 32'h4, 4'h3, 2'b01);
    repeat (7) 
        @ (posedge dev.clk);
    axi_write_single(32'h8, 32'hd34db33f);
//    axi_read_addr(12'h555, 32'h0, 4'h3, 2'b01);


    for (i = 0; i < 2048; i = i + 1) begin
        dev.receive_data_pause[i] = 32'h0;
    end
    dev.receive_wait_fifo = 0;

// issue Identify Device command
    // ATAPI command id = EC
    axi_write_single({30'h5, 2'b00}, 32'hEC);
    // start!
    axi_write_single({30'hf, 2'b00}, 32'h0108);
//    $display("[Test]:            H2D Reg with pio cmd issued");
    TEST_TITLE = "H2D Reg with pio cmd issued";
    $display("[Test]:            %s @%t", TEST_TITLE, $time);
    
    // wait until reception
    while (dev.receive_id != 1) begin
        repeat (100)
            @ (posedge dev.clk);
    end

    if (dev.receive_status != 0) begin
//        $display("[Test]:            Failed 1");
        TEST_TITLE = "Failed #1";
        $display("[Test]:            %s @%t", TEST_TITLE, $time);
        $finish;
    end

//    $display("[Test]:            H2D Reg with pio cmd received by dev");
    TEST_TITLE = "H2D Reg with pio cmd received by dev";
    $display("[Test]:            %s @%t", TEST_TITLE, $time);
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

    dev.linkTransmitFIS(66, 5, 0, status);
    if (status != 0) begin
//        $display("[Test]:            Failed 2");
        TEST_TITLE = "Failed #2";
        $display("[Test]:            %s @%t", TEST_TITLE, $time);
        $finish;
    end
//    $display("[Test]:            Dev sent BSY flag");
    TEST_TITLE = "Dev sent BSY flag";
    $display("[Test]:            %s @%t", TEST_TITLE, $time);

    // checks if BSY is set up // only on waves TODO
    axi_read_addr(12'h555, {30'h11, 2'b00}, 4'h3, 2'b01);
    repeat (50)
        @ (posedge dev.clk);

//    $display("[Test]:            Device sends PIO Setup");
    TEST_TITLE = "Device sends PIO Setup";
    $display("[Test]:            %s @%t", TEST_TITLE, $time);
    dev.transmit_data[0] = 32'h0080205f; // direction d2h, type = 5f
    dev.transmit_data[1] = 32'hdeadbeef; // whatever
    dev.transmit_data[2] = 32'hdeadbeef; // whatever
    dev.transmit_data[3] = 32'h00adbeef; // whatever
    dev.transmit_data[4] = 32'h00000014; // let it be 20 bytes to be transfered
    dev.linkTransmitFIS(11, 5, 0, status);
    if (status != 0) begin
//        $display("[Test]:            Failed 3");
        TEST_TITLE = "Failed #3";
        $display("[Test]:            %s @%t", TEST_TITLE, $time);
        $finish;
    end

//    $display("[Test]:            Device sends data FIS");
    TEST_TITLE = "Device sends data FIS";
    $display("[Test]:            %s @%t", TEST_TITLE, $time);
    dev.transmit_data[0] = 32'h00000046; // type = 46
    dev.transmit_data[1] = 32'hfeeddeaf;
    dev.transmit_data[2] = 32'ha114bea7;
    dev.transmit_data[3] = 32'hca110911;
    dev.transmit_data[4] = 32'hCA715F1E;
    dev.transmit_data[5] = 32'hdeadbeef;
    dev.linkTransmitFIS(22, 6, 0, status);
    if (status != 0) begin
//        $display("[Test]:            Failed 4");
        TEST_TITLE = "Failed #4";
        $display("[Test]:            %s @%t", TEST_TITLE, $time);
        
        $finish;
    end

    repeat (20)
        @ (posedge dev.clk);

    // prepare monitor - clean it before actual usage
    while (~maxiMonitorIsEmpty(0)) begin
        maxiMonitorPop(data, id);
    end
    
    // imitating PIO reads
//    $display("[Test]:            Read data word 0");
    TEST_TITLE = "Read data word 0";
    $display("[Test]:            %s @%t", TEST_TITLE, $time);
    axi_read_addr(12'h660, {30'h00, 2'b00}, 4'h0, 2'b01);

//    $display("[Test]:            Read data word 1");
    TEST_TITLE = "Read data word 1";
    $display("[Test]:            %s @%t", TEST_TITLE, $time);
    axi_read_addr(12'h661, {30'h00, 2'b00}, 4'h0, 2'b01);

//    $display("[Test]:            Read data word 2");
    TEST_TITLE = "Read data word 2";
    $display("[Test]:            %s @%t", TEST_TITLE, $time);
    axi_read_addr(12'h662, {30'h00, 2'b00}, 4'h0, 2'b01);

//    $display("[Test]:            Read data word 3");
    TEST_TITLE = "Read data word 3";
    $display("[Test]:            %s @%t", TEST_TITLE, $time);
    axi_read_addr(12'h663, {30'h00, 2'b00}, 4'h0, 2'b01);
    

//    $display("[Test]:            Read data word 4");
    TEST_TITLE = "Read data word 4";
    $display("[Test]:            %s @%t", TEST_TITLE, $time);
    axi_read_addr(12'h664, {30'h00, 2'b00}, 4'h0, 2'b01);

    // check if all ok
    i = 0;
    while (~maxiMonitorIsEmpty(0)) begin
        maxiMonitorPop(data, id);
        if (dev.transmit_data[i] != data) begin
//            $display("[Test]:            Data check failed");
            TEST_TITLE = "Data check failed";
            $display("[Test]:            %s @%t", TEST_TITLE, $time);
            
            $finish;
        end
        i = i + 1;
    end
//    $display("[Test]:            Data check OK");
    TEST_TITLE = "Data check OK";
    $display("[Test]:            %s @%t", TEST_TITLE, $time);
    
    


    repeat (30) 
        @ (posedge dev.clk);

/*    for (i = 0; i < 32; i = i + 1) begin
        $display("data received : %h", dev.receive_data[i]);
    end*/
    $display("============= DONE =============");
    TEST_TITLE = "DONE";
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
    #150000;
//    $display("[Test]:            Failed");
    TEST_TITLE = "Failed (timelimit)";
    $display("[Test]:            %s @%t", TEST_TITLE, $time);
    
    $display("============= TIMELIMIT =============");
    $finish;
end
