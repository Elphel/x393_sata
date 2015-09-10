# clock, received via FCLK input from PS7
# barely used for now
create_clock -name axi_aclk0 -period 20.000 -waveform {0.000 10.000} {get_nets axi_aclk0}

# external clock 150Mhz
create_clock -name gtrefclk -period 6.666 -waveform {0.000 3.333} {get_nets sata_top.sata_host.sata_phy.gtrefclk}

# after plls inside of GTX:
create_clock -name txoutclk -period 13.333 -waveform {0.000 6.666} {get_nets sata_top.sata_host.sata_phy.txoutclk}

# txoutclk -> userpll, which gives us 2 clocks: userclk and userclk2. The second one is sata host clk
create_generate_clock -name usrclk  -source [get_clocks txoutclk] -multiply_by 2 [get_nets sata_top.sata_host.sata_phy.usrclk]
create_generate_clock -name sclk    -source [get_clocks txoutclk]                [get_nets sata_top.sata_host.sata_phy.usrclk2]

