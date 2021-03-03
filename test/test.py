import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, with_timeout, Timer
from cocotb.result import ReturnValue
from collections import namedtuple

PERIOD = 100

segments = {
    63  : 0,
    6   : 1,
    91  : 2,
    79  : 3,
    102 : 4,
    109 : 5,
    124 : 6,
    7   : 7,
    127 : 8,
    103 : 9,
    }

async def read_segment(dut):
    segment = 0
    for bit in range(9,16):
        value = int(dut.io_out[bit])
        shifted_value = value << (bit - 9)
        segment += shifted_value
    return segments[segment]

@cocotb.test()
async def test_seven_segment(dut):
    clock = Clock(dut.wb_clk_i, 10, units="us")
    cocotb.fork(clock.start())

    # reset but project is inactive
    dut.wb_rst_i <= 1
    await ClockCycles(dut.wb_clk_i, 5)
    dut.wb_rst_i <= 0
    dut.la_data_in <= 0

    # reset
    dut.la_data_in <= 1 << 0
    await ClockCycles(dut.wb_clk_i, 100)
    dut.la_data_in <= 0

    # pause
    await ClockCycles(dut.wb_clk_i, 100)

    # activate project
    dut.active <= 1
    await ClockCycles(dut.wb_clk_i, 100)
    
    dut.la_data_in <= (100 << 2) + (1 << 1)
    await ClockCycles(dut.wb_clk_i, 1)
    dut.la_data_in <= 0
    
    # reset
    for i in range(10):
        await ClockCycles(dut.wb_clk_i, PERIOD)
        assert dut.seven_segment_seconds.digit == i
        assert await read_segment(dut) == i

