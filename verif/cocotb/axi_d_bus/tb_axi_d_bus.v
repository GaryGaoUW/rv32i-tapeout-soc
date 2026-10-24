`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_axi_d_bus: test wrapper for cocotb
//
// Why this file exists:
//   cocotbext-axi finds AXI signals by name: <prefix>_awaddr, <prefix>_awvalid...
//   Our RTL uses direction suffixes (m_axi_awaddr_o, m_axi_awready_i), which
//   the library cannot match. This wrapper only renames ports - no logic.
//
//   CPU side  : cpu_*        (driven by the Python "fake CPU")
//   AXI side  : m_axil_*     (connected to cocotbext-axi AxiLiteRam)
// -----------------------------------------------------------------------------
module tb_axi_d_bus (
    input         clk,
    input         rst_n,

    // CPU side
    input  [31:0] cpu_addr_i,
    input  [31:0] cpu_wdata_i,
    input  [3:0]  cpu_write_en_i,
    input         cpu_r_req_i,
    input         cpu_w_req_i,
    output [31:0] cpu_rdata_o,
    output        cpu_read_valid_o,
    output        cpu_write_valid_o,
    output        cpu_bus_stop_o,

    // AR
    output [31:0] m_axil_araddr,
    output [2:0]  m_axil_arprot,
    output        m_axil_arvalid,
    input         m_axil_arready,
    // R
    input  [31:0] m_axil_rdata,
    input  [1:0]  m_axil_rresp,
    input         m_axil_rvalid,
    output        m_axil_rready,
    // AW
    output [31:0] m_axil_awaddr,
    output [2:0]  m_axil_awprot,
    output        m_axil_awvalid,
    input         m_axil_awready,
    // W
    output [31:0] m_axil_wdata,
    output [3:0]  m_axil_wstrb,
    output        m_axil_wvalid,
    input         m_axil_wready,
    // B
    input  [1:0]  m_axil_bresp,
    input         m_axil_bvalid,
    output        m_axil_bready
);

    axi_d_bus u_dut (
        .a_clk             (clk),
        .a_reset_n         (rst_n),

        .cpu_addr_i        (cpu_addr_i),
        .cpu_wdata_i       (cpu_wdata_i),
        .cpu_write_en_i    (cpu_write_en_i),
        .cpu_r_req_i       (cpu_r_req_i),
        .cpu_w_req_i       (cpu_w_req_i),

        .m_axi_araddr_o    (m_axil_araddr),
        .m_axi_arprot_o    (m_axil_arprot),
        .m_axi_arvalid_o   (m_axil_arvalid),
        .m_axi_arready_i   (m_axil_arready),

        .m_axi_rdata_i     (m_axil_rdata),
        .m_axi_rresp_i     (m_axil_rresp),
        .m_axi_rvalid_i    (m_axil_rvalid),
        .m_axi_rready_o    (m_axil_rready),

        .m_axi_awaddr_o    (m_axil_awaddr),
        .m_axi_awprot_o    (m_axil_awprot),
        .m_axi_awvalid_o   (m_axil_awvalid),
        .m_axi_awready_i   (m_axil_awready),

        .m_axi_wdata_o     (m_axil_wdata),
        .m_axi_wstrb_o     (m_axil_wstrb),
        .m_axi_wvalid_o    (m_axil_wvalid),
        .m_axi_wready_i    (m_axil_wready),

        .m_axi_bresp_i     (m_axil_bresp),
        .m_axi_bvalid_i    (m_axil_bvalid),
        .m_axi_bready_o    (m_axil_bready),

        .cpu_rdata_o       (cpu_rdata_o),
        .cpu_read_valid_o  (cpu_read_valid_o),
        .cpu_write_valid_o (cpu_write_valid_o),
        .cpu_bus_stop_o    (cpu_bus_stop_o)
    );

endmodule
