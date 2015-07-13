# x393_sata
SATA controller for x393 camera
# Current step:
Creating simple testbench structure, placing some register @ axi iface (+axi slave onto maxigp1), simulate them.
To syntesize, try to access these registers (read+write)
# Going to do afterwards:
Connect Ashwin's core and make it work at least somehow (write system level tests and application level rtl). Write host controller with ~same functionallity, check if it works with previously verified higher-level code.
And then to spin out the full-compatible functionallity (ideally somewhere to the level of ahci)
