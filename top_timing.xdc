# clock, received via FCLK input from PS7
# barely used for now
create_clock -name axi_aclk0 -period 20.000 -waveform {0.000 10.000} [get_nets axi_aclk0]

# external clock 150Mhz
create_clock -name gtrefclk -period 6.666 -waveform {0.000 3.333} [get_nets sata_top/sata_host/phy/gtrefclk]

# after plls inside of GTX:
create_clock -name txoutclk -period 6.666 -waveform {0.000 3.333} [get_nets sata_top/sata_host/phy/txoutclk]

# recovered sata parallel clock
create_clock -name xclk -period 6.666 -waveform {0.000 3.333} [get_nets sata_top/sata_host/phy/gtx_wrap/xclk]

# txoutclk -> userpll, which gives us 2 clocks: userclk and userclk2. The second one is sata host clk
###create_generated_clock -name usrclk [get_nets sata_top/sata_host/phy/CLK]
create_generated_clock -name usrclk [get_nets sata_top/sata_host/phy/usrclk2]
#create_generated_clock -name sclk   [get_nets sata_top/sata_host/phy/clk]
create_generated_clock -name sclk   [get_nets sata_top_n_173]

set_clock_groups -name async_clocks -asynchronous \
-group {gtrefclk} \
-group {axi_aclk0} \
-group {xclk} \
-group {usrclk} \
-group {sclk} \
-group {clk_axihp_pre} \
-group {txoutclk}
