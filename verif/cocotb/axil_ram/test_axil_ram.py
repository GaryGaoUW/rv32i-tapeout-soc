"""
cocotb testbench for rtl/mem/axil_ram.v

Structure (mirror of the axil_d_bus test):

    AxiLiteMaster (Python)  <--AXI-Lite-->  axil_ram (DUT)

Run from repo root:
    make -C verif/cocotb/axil_ram
"""

from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

# Must match the ADDR_W parameter used in the build below.
ADDR_W = 10
RAM_BYTES = 4 << ADDR_W  # 1024 words * 4 bytes = 4 KB


# =============================================================================
# Testbench infrastructure (boilerplate)
# =============================================================================
class TB:
    def __init__(self, dut):
        self.dut = dut

        # 100 MHz clock
        cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

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

    async def write_bytes(self, addr, data: bytes):
        """
        Write 1..4 bytes inside one word. The master derives wstrb from the
        address offset and length, e.g. write_bytes(0x101, b"\\xAB") -> wstrb 4'b0010.
        """
        await self.axil.write(addr, data)


# =============================================================================
# Tests
# =============================================================================
@cocotb.test()
async def test_reset_idle(dut):
    """Smoke test: with no request, the slave must not raise any READY/VALID."""
    tb = TB(dut)
    await tb.reset()
    await ReadOnly()

    for sig in ["awready", "wready", "arready", "rvalid", "bvalid"]:
        value = int(getattr(dut, f"s_axil_{sig}").value)
        assert value == 0, f"s_axil_{sig} should be 0 in idle, got {value}"


@cocotb.test()
async def test_multi_addr(dut):
    """Write several different addresses, then read every one back."""
    tb = TB(dut)
    await tb.reset()

    pairs = [(0x000, 0x11111111), (0x004, 0x22222222), (0x008, 0x12345678), (0xFFC, 0x11223344)]
    
    for addr, value in pairs:
        await tb.write32(addr,value)

    for addr, expected in pairs:
        got = await tb.read32(addr)
        assert expected == got, f"Expected: {expected:#010x}, got: {got:#010x}"


# =============================================================================
# pytest entry point: builds the RTL with Verilator and runs the tests above
# =============================================================================
def test_axil_ram_runner():
    from cocotb_tools.runner import get_runner

    here = Path(__file__).resolve().parent
    repo = here.parents[2]

    runner = get_runner("verilator")
    runner.build(
        sources=[
            repo / "rtl/mem/axil_ram.v",
            here / "tb_axil_ram.v",
        ],
        hdl_toplevel="tb_axil_ram",
        parameters={"ADDR_W": ADDR_W},
        build_dir=here / "sim_build",
        waves=True,
        always=True,
    )
    runner.test(
        hdl_toplevel="tb_axil_ram",
        test_module="test_axil_ram",
        test_dir=here,
        waves=True,
    )
