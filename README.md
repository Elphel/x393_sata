# x393_sata
SATA controller for x393 camera
Board: Zynq 7z30
FPGA: Kintex-7
# Current step:
Connecting Ashwin's core (slow interface to the system is almost done, have to completely rewrite phy-level). Feels like making the phy works is going to require a lot of effort
# Going to do afterwards:
Complete and test the 'current step'. Write host controller with ~same functionallity, check if it works with previously verified higher-level code.
And then to spin out the full-compatible functionallity (ideally somewhere to the level of ahci)
