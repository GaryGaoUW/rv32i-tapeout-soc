"""
cocotb testbench for rtl/periph/axil_uart.v

Structure:

    AxiLiteMaster (Python)  <--AXI-Lite-->  axil_uart (DUT)  --uart_tx-->  Python
                                                              <--uart_rx--  Python

Run from repo root:
    make -C verif/cocotb/axil_uart
"""

from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

# Must match the parameters used in the build below.
# A small DIV keeps serial tests fast (8 clocks per bit instead of 217).
TX_DEPTH = 16
RX_DEPTH = 8
DEFAULT_DIV = 8

# Register offsets
RX_DATA = 0x00
TX_DATA = 0x04
STAT = 0x08
CTRL = 0x0C
DIV = 0x10

# STAT bits
STAT_RX_VALID = 1 << 0
STAT_RX_FULL = 1 << 1
STAT_TX_EMPTY = 1 << 2
STAT_TX_FULL = 1 << 3
STAT_IRQ_EN = 1 << 4
STAT_RX_OVERRUN = 1 << 5
STAT_FRAME_ERR = 1 << 6
STAT_PARITY_ERR = 1 << 7
STAT_TX_DROP = 1 << 8
STAT_BREAK = 1 << 9

# CTRL bits
CTRL_CLR_TX = 1 << 0
CTRL_CLR_RX = 1 << 1
CTRL_IRQ_EN = 1 << 4


# =============================================================================
# Testbench infrastructure (boilerplate)
# =============================================================================
class TB:
    def __init__(self, dut):
        self.dut = dut

        # 100 MHz clock
        cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

        # Serial input idles high
        dut.uart_rx.value = 1

        # AXI-Lite master model. It drives AW/W/AR valid and R/B ready.
        # reset_active_level=False because rst_n is active-low.
        self.axil = AxiLiteMaster(
            AxiLiteBus.from_prefix(dut, "s_axil"),
            dut.clk,
            dut.rst_n,
            reset_active_level=False,
        )

    async def reset(self, cycles=5):
        """Hold rst_n low for a few cycles, then release on a clock edge."""
        self.dut.rst_n.value = 0
        for _ in range(cycles):
            await RisingEdge(self.dut.clk)
        self.dut.rst_n.value = 1
        await RisingEdge(self.dut.clk)

    def set_pause(self, channel, generator):
        """
        Make the master stall a channel according to a generator.
          "aw" / "w" / "ar" : master delays raising VALID
          "b"  / "r"        : master delays raising READY
        generator yields True (= pause this cycle) or False.
        Pass generator=None to clear.
        """
        ports = {
            "aw": self.axil.write_if.aw_channel,
            "w": self.axil.write_if.w_channel,
            "b": self.axil.write_if.b_channel,
            "ar": self.axil.read_if.ar_channel,
            "r": self.axil.read_if.r_channel,
        }
        ports[channel].set_pause_generator(generator)

    # -------------------------------------------------------------------------
    # Bus helpers. Each call is one full AXI-Lite transaction.
    # -------------------------------------------------------------------------
    async def write32(self, addr, value):
        """Write one 32-bit word (wstrb = 4'b1111)."""
        await self.axil.write_dword(addr, value)

    async def read32(self, addr):
        """Read one 32-bit word and return it as an int."""
        return await self.axil.read_dword(addr)

    async def write8(self, addr, value):
        """Write one byte, like a RISC-V sb. wstrb follows addr[1:0]."""
        await self.axil.write(addr, bytes([value & 0xFF]))

    # -------------------------------------------------------------------------
    # Serial helpers
    # -------------------------------------------------------------------------
    async def wait_clocks(self, n):
        for _ in range(n):
            await RisingEdge(self.dut.clk)


# =============================================================================
# Tests
# =============================================================================
@cocotb.test()
async def test_reset_idle(dut):
    """Smoke test: after reset, no READY/VALID is raised and uart_tx idles high."""
    tb = TB(dut)
    await tb.reset()
    await ReadOnly()

    for sig in ["awready", "wready", "arready", "rvalid", "bvalid"]:
        value = int(getattr(dut, f"s_axil_{sig}").value)
        assert value == 0, f"s_axil_{sig} should be 0 in idle, got {value}"


@cocotb.test()
async def test_stat_after_reset(dut):
    """Block A: read STAT right after reset; STAT_TX_EMPTY must be 1."""
    tb = TB(dut)
    await tb.reset()
    val = await tb.read32(STAT)
    assert val & STAT_TX_EMPTY, f"TX_empty should be 1, STAT={val:#x}"


@cocotb.test()
async def test_div_rw(dut):
    """
    Block A: DIV reads DEFAULT_DIV after reset; a full-word write reads back;
    a byte write (write8) only changes the addressed byte.
    """
    tb = TB(dut)
    await tb.reset()
    div = await tb.read32(DIV)
    assert div == DEFAULT_DIV, f"DIV should be DEFAULT_DIV, got {div}"

    await tb.write32(DIV, 0x1234)
    val = await tb.read32(DIV)
    assert val == 0x1234, f"DIV should be 0x1234, got {val}"

    await tb.write8(DIV+1, 0xAB)
    val = await tb.read32(DIV)
    assert val == 0xAB34, f"DIV high byte should be 0xAB, got {val:#x}"


# =============================================================================
# pytest entry point: builds the RTL with Verilator and runs the tests above
# =============================================================================
def test_axil_uart_runner():
    from cocotb_tools.runner import get_runner

    here = Path(__file__).resolve().parent
    repo = here.parents[2]

    runner = get_runner("verilator")
    runner.build(
        sources=[
            repo / "rtl/periph/axil_uart.v",
            here / "tb_axil_uart.v",
        ],
        hdl_toplevel="tb_axil_uart",
        parameters={
            "TX_DEPTH": TX_DEPTH,
            "RX_DEPTH": RX_DEPTH,
            "DEFAULT_DIV": DEFAULT_DIV,
        },
        build_dir=here / "sim_build",
        waves=True,
        always=True,
    )
    runner.test(
        hdl_toplevel="tb_axil_uart",
        test_module="test_axil_uart",
        test_dir=here,
        waves=True,
    )
