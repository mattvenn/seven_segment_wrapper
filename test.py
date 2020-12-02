import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, with_timeout, Timer
from cocotb.result import ReturnValue
from collections import namedtuple

ADDR_BASE    = 0x30000000
ADDR_COMPARE = 0x30000004

# in ADDR_BASE, this is the bit configuration
ACTIVATE        = 1 << 0    # set high to enable project
RESET           = 1 << 1    # set high to reset project

async def wishbone_write(dut, address, data):
    assert dut.wbs_ack_o == 0
    await RisingEdge(dut.wb_clk_i)
    dut.wbs_stb_i   <= 1
    dut.wbs_cyc_i   <= 1
    dut.wbs_we_i    <= 1        # write
    dut.wbs_sel_i   <= 0b1111   # select all bytes,      // which byte to read/write
    dut.wbs_dat_i   <= data
    dut.wbs_adr_i   <= address

    await with_timeout (RisingEdge(dut.wbs_ack_o), 100, 'us')
    await RisingEdge(dut.wb_clk_i)

    dut.wbs_cyc_i   <= 0
    dut.wbs_stb_i   <= 0
    dut.wbs_sel_i   <= 0
    dut.wbs_dat_i   <= 0
    dut.wbs_adr_i   <= 0

    await with_timeout (FallingEdge(dut.wbs_ack_o), 100, 'us')

async def wishbone_read(dut, address):
    assert dut.wbs_ack_o == 0
    await RisingEdge(dut.wb_clk_i)
    dut.wbs_stb_i   <= 1
    dut.wbs_cyc_i   <= 1
    dut.wbs_we_i    <= 0        # read
    dut.wbs_sel_i   <= 0b1111   # select all bytes,      // which byte to read/write
    dut.wbs_adr_i   <= address

    await with_timeout (RisingEdge(dut.wbs_ack_o), 100, 'us')
    await RisingEdge(dut.wb_clk_i)

    # grab data
    data = dut.wbs_dat_o

    dut.wbs_cyc_i   <= 0
    dut.wbs_stb_i   <= 0
    dut.wbs_sel_i   <= 0
    dut.wbs_dat_i   <= 0
    dut.wbs_adr_i   <= 0

    await with_timeout (FallingEdge(dut.wbs_ack_o), 100, 'us')

    return data

# reset
async def reset(dut):
    dut.wbs_cyc_i   <= 0
    dut.wbs_stb_i   <= 0
    dut.wbs_sel_i   <= 0
    dut.wbs_dat_i   <= 0
    dut.wbs_adr_i   <= 0

    dut.wb_rst_i <= 1;
    await ClockCycles(dut.wb_clk_i, 5)
    dut.wb_rst_i <= 0;
    await ClockCycles(dut.wb_clk_i, 5)

def get_oeb_value():
    oeb_value = 0 # all outputs
    outputs = [8, 9, 10, 11, 12, 13, 14]
    for pin in range(38):
        if pin not in outputs:
            oeb_value += 1 << pin
        
    print(bin(oeb_value))  
    return oeb_value

@cocotb.test()
# 7 segment
async def test_project_0(dut):
    clock = Clock(dut.wb_clk_i, 10, units="us")
    cocotb.fork(clock.start())

    await reset(dut)

    assert dut.io_out == 0

    # activate design
    await wishbone_write(dut, ADDR_BASE, RESET + ACTIVATE)
    assert dut.active == 1

    # check oeb is set correctly
    assert dut.io_oeb == get_oeb_value()

    # take out of reset
    await wishbone_write(dut, ADDR_BASE, ACTIVATE)

    # update compare to 10 - will also reset the counter
    await wishbone_write(dut, ADDR_COMPARE, 10)

    # wait some cycles
    await ClockCycles(dut.wb_clk_i, 10)
    assert dut.project.digit == 1
    await ClockCycles(dut.wb_clk_i, 10)
    assert dut.project.digit == 2

