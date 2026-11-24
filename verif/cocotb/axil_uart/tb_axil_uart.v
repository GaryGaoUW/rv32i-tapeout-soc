`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_axil_uart: test wrapper for cocotb
//
// Why this file exists:
//   cocotbext-axi finds AXI signals by name: <prefix>_awaddr, <prefix>_awvalid...
//   Our RTL uses direction suffixes (s_axil_awaddr_i, s_axil_awready_o), which
//   the library cannot match. This wrapper only renames ports - no logic.
//
//   AXI side    : s_axil_*            (driven by cocotbext-axi AxiLiteMaster)
//   Serial side : uart_tx, uart_rx    (watched / driven by Python)
//   Interrupt   : irq
// -----------------------------------------------------------------------------
module tb_axil_uart #(
    parameter TX_DEPTH    = 16,
    parameter RX_DEPTH    = 8,
    parameter DEFAULT_DIV = 8
) (
    input clk,
    input rst_n,

    // AR
    input  [31:0] s_axil_araddr,
    input  [ 2:0] s_axil_arprot,
    input         s_axil_arvalid,
    output        s_axil_arready,

    // R
    output [31:0] s_axil_rdata,
    output [ 1:0] s_axil_rresp,
    output        s_axil_rvalid,
    input         s_axil_rready,

    // AW
    input  [31:0] s_axil_awaddr,
    input  [ 2:0] s_axil_awprot,
    input         s_axil_awvalid,
    output        s_axil_awready,

    // W
    input  [31:0] s_axil_wdata,
    input  [ 3:0] s_axil_wstrb,
    input         s_axil_wvalid,
    output        s_axil_wready,

    // B
    output [1:0] s_axil_bresp,
    output       s_axil_bvalid,
    input        s_axil_bready,

    // Serial and interrupt
    output uart_tx,
    input  uart_rx,
    output irq
);

    axil_uart #(
        .TX_DEPTH   (TX_DEPTH),
        .RX_DEPTH   (RX_DEPTH),
        .DEFAULT_DIV(DEFAULT_DIV)
    ) u_dut (
        .a_clk    (clk),
        .a_reset_n(rst_n),

        .s_axil_araddr_i (s_axil_araddr),
        .s_axil_arprot_i (s_axil_arprot),
        .s_axil_arvalid_i(s_axil_arvalid),
        .s_axil_arready_o(s_axil_arready),

        .s_axil_rdata_o (s_axil_rdata),
        .s_axil_rresp_o (s_axil_rresp),
        .s_axil_rvalid_o(s_axil_rvalid),
        .s_axil_rready_i(s_axil_rready),

        .s_axil_awaddr_i (s_axil_awaddr),
        .s_axil_awprot_i (s_axil_awprot),
        .s_axil_awvalid_i(s_axil_awvalid),
        .s_axil_awready_o(s_axil_awready),

        .s_axil_wdata_i (s_axil_wdata),
        .s_axil_wstrb_i (s_axil_wstrb),
        .s_axil_wvalid_i(s_axil_wvalid),
        .s_axil_wready_o(s_axil_wready),

        .s_axil_bresp_o (s_axil_bresp),
        .s_axil_bvalid_o(s_axil_bvalid),
        .s_axil_bready_i(s_axil_bready),

        .uart_tx_o(uart_tx),
        .uart_rx_i(uart_rx),
        .irq_o    (irq)
    );

endmodule
