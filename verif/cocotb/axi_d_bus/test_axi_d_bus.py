"""
cocotb testbench for rtl/bus/axi_d_bus.v

Structure:

    Python fake CPU  --cpu_*-->  axi_d_bus (DUT)  <--AXI-Lite-->  AxiLiteRam
         ^                          |
         +------ cpu_bus_stop_o ----+

Run from repo root:
    make -C verif/cocotb/axi_d_bus
"""

from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge
from cocotbext.axi import AxiLiteBus, AxiLiteRam

# Max cycles one CPU request may take before we call it a deadlock.
TIMEOUT_CYCLES = 1000


# =============================================================================
# Testbench infrastructure (boilerplate)
# =============================================================================
class TB:
    def __init__(self, dut):
        self.dut = dut

        # 100 MHz clock
        cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

        # AXI-Lite slave model. 64 KB of memory is plenty for unit tests.
        # reset_active_level=False because rst_n is active-low.
        self.ram = AxiLiteRam(
            AxiLiteBus.from_prefix(dut, "m_axil"),
            dut.clk,
            dut.rst_n,
            reset_active_level=False,
            size=2**16,
        )

        # Idle values for every CPU-side input
        dut.cpu_addr_i.value = 0
        dut.cpu_wdata_i.value = 0
        dut.cpu_write_en_i.value = 0
        dut.cpu_r_req_i.value = 0
        dut.cpu_w_req_i.value = 0

    async def reset(self, cycles=5):
        """Hold rst_n low for a few cycles, then release on a clock edge."""
        self.dut.rst_n.value = 0
        for _ in range(cycles):
            await RisingEdge(self.dut.clk)
        self.dut.rst_n.value = 1
        await RisingEdge(self.dut.clk)

    def set_pause(self, channel, generator):
        """
        Make the slave drop READY according to a generator.
        channel: "aw" | "w" | "b" | "ar" | "r"
        generator yields True (= pause this cycle) or False.
        Pass generator=None to clear.
        """
        ports = {
            "aw": self.ram.write_if.aw_channel,
            "w": self.ram.write_if.w_channel,
            "b": self.ram.write_if.b_channel,
            "ar": self.ram.read_if.ar_channel,
            "r": self.ram.read_if.r_channel,
        }
        ports[channel].set_pause_generator(generator)

    # -------------------------------------------------------------------------
    # Fake CPU
    #
    # Mimics the real pipeline: the MEM stage raises a request and holds it
    # (address, data, strobe unchanged) while cpu_bus_stop_o is 1. In the cycle
    # where cpu_bus_stop_o drops to 0, the pipeline advances on the next edge.
    #
    # Must be called right after a RisingEdge. Returns right after a RisingEdge.
    # -------------------------------------------------------------------------
    async def _wait_until_not_stalled(self):
        """Wait for the cycle where cpu_bus_stop_o == 0, then step past its edge."""
        for _ in range(TIMEOUT_CYCLES):
            await ReadOnly()  # let combinational logic settle this cycle
            if int(self.dut.cpu_bus_stop_o.value) == 0:
                snapshot = {
                    "rdata": int(self.dut.cpu_rdata_o.value),
                    "read_valid": int(self.dut.cpu_read_valid_o.value),
                    "write_valid": int(self.dut.cpu_write_valid_o.value),
                }
                await RisingEdge(self.dut.clk)
                return snapshot
            await RisingEdge(self.dut.clk)
        raise TimeoutError(f"cpu_bus_stop_o stuck at 1 for {TIMEOUT_CYCLES} cycles (deadlock?)")

    async def cpu_write(self, addr, data, strb=0xF):
        """Issue one store and block until the bus finishes it."""
        dut = self.dut
        dut.cpu_addr_i.value = addr
        dut.cpu_wdata_i.value = data
        dut.cpu_write_en_i.value = strb
        dut.cpu_w_req_i.value = 1

        snap = await self._wait_until_not_stalled()
        assert snap["write_valid"] == 1, "bus released the CPU but cpu_write_valid_o was 0"

        dut.cpu_w_req_i.value = 0
        dut.cpu_write_en_i.value = 0

    async def cpu_read(self, addr):
        """Issue one load, block until the bus returns data, and return it."""
        dut = self.dut
        dut.cpu_addr_i.value = addr
        dut.cpu_r_req_i.value = 1

        snap = await self._wait_until_not_stalled()
        assert snap["read_valid"] == 1, "bus released the CPU but cpu_read_valid_o was 0"

        dut.cpu_r_req_i.value = 0
        return snap["rdata"]


# =============================================================================
# Tests
# =============================================================================
@cocotb.test()
async def test_reset_idle(dut):
    """Smoke test: after reset the master must not drive any VALID/READY."""
    tb = TB(dut)
    await tb.reset()
    await ReadOnly()

    for sig in ["arvalid", "rready", "awvalid", "wvalid", "bready"]:
        value = int(getattr(dut, f"m_axil_{sig}").value)
        assert value == 0, f"m_axil_{sig} should be 0 in idle, got {value}"

    assert int(dut.cpu_bus_stop_o.value) == 0, "no request -> CPU must not be stalled"


@cocotb.test()
async def test_write_then_read(dut):
    """Scenario 1: write one word, read it back, compare."""
    tb = TB(dut)
    await tb.reset()

    addr = 0x00001000
    value = 0x12345678

    await tb.cpu_write(addr, value)
    got = await tb.cpu_read(addr)

    assert got == value, f"Expected {value:#010x} got value = {got:#010x}"


# =============================================================================
# pytest entry point: builds the RTL with Verilator and runs the tests above
# =============================================================================
def test_axi_d_bus_runner():
    from cocotb_tools.runner import get_runner

    here = Path(__file__).resolve().parent
    repo = here.parents[2]

    runner = get_runner("verilator")
    runner.build(
        sources=[
            repo / "rtl/bus/axi_d_bus.v",
            here / "tb_axi_d_bus.v",
        ],
        hdl_toplevel="tb_axi_d_bus",
        build_dir=here / "sim_build",
        waves=True,
        always=True,
    )
    runner.test(
        hdl_toplevel="tb_axi_d_bus",
        test_module="test_axi_d_bus",
        test_dir=here,
        waves=True,
    )
