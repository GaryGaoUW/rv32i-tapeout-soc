`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/25 15:21:00
// Design Name: 
// Module Name: soc_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Chip-level top. Connects the CPU core to memories (and later
//              the AXI-Lite buses and peripherals). Shared by every shell:
//              simulation (verif/lv0), FPGA (fpga/fpga_top), Tiny Tapeout.
// 
// Dependencies: core_top, inst_mem, data_mem
// 
// Revision:
// Revision 0.01 - File Created (Step A: memories moved out of core_top, no AXI)
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module soc_top (
    input clk,
    input rst_n,

    // Debug outputs used by sim_main.cpp and fpga_top
    output [31:0] pc_wire,
    output [31:0] inst_wire,
    output [31:0] alu_res,
    output [31:0] wb_data,
    output [31:0] dbg_wb_pc,
    output [ 4:0] dbg_wb_rd,
    output        dbg_wb_reg_wen
);

    // CPU <-> instruction bus
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;

    // Any bus still busy -> freeze the whole pipeline
    wire        bus_stall;

    // Instruction bus <-> I-RAM (AXI-Lite read channels only)
    wire [31:0] i_axil_araddr;
    wire [ 2:0] i_axil_arprot;
    wire        i_axil_arvalid;
    wire        i_axil_arready;
    wire [31:0] i_axil_rdata;
    wire [ 1:0] i_axil_rresp;
    wire        i_axil_rvalid;
    wire        i_axil_rready;

    // CPU <-> data memory
    wire [ 3:0] dmem_we;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;

    // The other dbg_* ports of core_top are left unconnected on purpose:
    // they are still visible in the waveform under u_core.
    core_top u_core (
        .clk  (clk),
        .rst_n(rst_n),

        .imem_addr_o (imem_addr),
        .imem_rdata_i(imem_rdata),

        .dmem_we_o   (dmem_we),
        .dmem_addr_o (dmem_addr),
        .dmem_wdata_o(dmem_wdata),
        .dmem_rdata_i(dmem_rdata),

        .bus_stall_i(bus_stall),

        .pc_wire       (pc_wire),
        .inst_wire     (inst_wire),
        .alu_res       (alu_res),
        .wb_data       (wb_data),
        .dbg_wb_pc     (dbg_wb_pc),
        .dbg_wb_rd     (dbg_wb_rd),
        .dbg_wb_reg_wen(dbg_wb_reg_wen)
    );

    // Instruction fetch over AXI-Lite. The bus only releases the pipeline
    // (bus_stop = 0) in the cycle where the instruction is valid, so
    // cpu_instr_valid_o is not needed here.
    axil_i_bus u_i_bus (
        .a_clk    (clk),
        .a_reset_n(rst_n),

        .cpu_pc_i         (imem_addr),
        .cpu_fetch_en_i   (1'b1),
        .cpu_instr_o      (imem_rdata),
        .cpu_instr_valid_o(),
        .cpu_bus_stop_o   (bus_stall),

        .m_axil_araddr_o (i_axil_araddr),
        .m_axil_arprot_o (i_axil_arprot),
        .m_axil_arvalid_o(i_axil_arvalid),
        .m_axil_arready_i(i_axil_arready),

        .m_axil_rdata_i (i_axil_rdata),
        .m_axil_rresp_i (i_axil_rresp),
        .m_axil_rvalid_i(i_axil_rvalid),
        .m_axil_rready_o(i_axil_rready)
    );

    // I-RAM: 2^10 words = 4 KB. Read-only from the CPU side, so the write
    // channel inputs are tied to 0 (never leave inputs floating) and the
    // write channel outputs are left open. Synthesis removes the write logic.
    axil_ram #(
        .ADDR_W(10)
    ) u_iram (
        .a_clk    (clk),
        .a_reset_n(rst_n),

        .s_axil_araddr_i (i_axil_araddr),
        .s_axil_arprot_i (i_axil_arprot),
        .s_axil_arvalid_i(i_axil_arvalid),
        .s_axil_arready_o(i_axil_arready),

        .s_axil_rdata_o (i_axil_rdata),
        .s_axil_rresp_o (i_axil_rresp),
        .s_axil_rvalid_o(i_axil_rvalid),
        .s_axil_rready_i(i_axil_rready),

        .s_axil_awaddr_i (32'b0),
        .s_axil_awprot_i (3'b0),
        .s_axil_awvalid_i(1'b0),
        .s_axil_awready_o(),

        .s_axil_wdata_i (32'b0),
        .s_axil_wstrb_i (4'b0),
        .s_axil_wvalid_i(1'b0),
        .s_axil_wready_o(),

        .s_axil_bresp_o (),
        .s_axil_bvalid_o(),
        .s_axil_bready_i(1'b0)
    );

    data_mem u_dmem (
        .clk  (clk),
        .we   (dmem_we),
        .addr (dmem_addr),
        .wdata(dmem_wdata),
        .rdata(dmem_rdata)
    );

endmodule
