import timescale
import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from driver_host import SataHostDriver

TIMESCALE = 1000 # in ps

@cocotb.coroutine
def issueReset(rst, length):
    rst <= 1
    yield Timer(length * TIMESCALE)
    rst <= 0

@cocotb.coroutine
def setClk(clk, halfperiod):
    while True:
        clk <= 0
        yield Timer(halfperiod * TIMESCALE)
        clk <= 1
        yield Timer(halfperiod * TIMESCALE)

@cocotb.coroutine
def setDiffClk(clkp, clkn, halfperiod):
    while True:
        clkp <= 0
        clkn <= 1
        yield Timer(halfperiod * TIMESCALE)
        clkp <= 1
        clkn <= 0
        yield Timer(halfperiod * TIMESCALE)


@cocotb.test()
def basic_test(dut):
    cocotb.fork(setDiffClk(dut.extclk_p, dut.extclk_n, 3.333))
    dut.rst = 0
    yield Timer(30 * TIMESCALE)
    yield issueReset(dut.extrst, 1050)

    shadow = SataHostDriver(dut, "", dut.clk)

    yield FallingEdge(dut.rst)

    # set random data to shadow registers
    yield RisingEdge(dut.clk)
    cocotb.fork(shadow.setReg(1,0xe))
    cocotb.fork(shadow.setReg(4,0xdead))
    cocotb.fork(shadow.setReg(5,0xbee1))
    yield Timer(100 * TIMESCALE)

    # write registers to a device
    yield RisingEdge(dut.clk)
#    cocotb.fork(shadow.setCmd(cmd_type = 1, cmd_port = 0, cmd_val = 1))
    yield Timer(40000 * TIMESCALE)

