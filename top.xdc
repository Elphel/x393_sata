# bind gtx reference clock
set_property PACKAGE_PIN U6 [get_ports EXTCLK_P]
set_property PACKAGE_PIN U5 [get_ports EXTCLK_N]

# bind sata inputs/outputs
set_property PACKAGE_PIN AA5 [get_ports RXN]
set_property PACKAGE_PIN AA6 [get_ports RXP]
set_property PACKAGE_PIN AB3 [get_ports TXN]
set_property PACKAGE_PIN AB4 [get_ports TXP]

# manually placing usrpll in the same region where gtx is located : x0y0
startgroup
place_cell sata_top/sata_host/phy/usrclk_pll PLLE2_ADV_X0Y0/PLLE2_ADV
endgroup