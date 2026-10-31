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
    wire        i_bus_stop;
    wire        d_bus_stop;
    wire        bus_stall = i_bus_stop || d_bus_stop;

    // Instruction bus <-> I-RAM (AXI-Lite read channels only)
    wire [31:0] i_axil_araddr;
    wire [ 2:0] i_axil_arprot;
    wire        i_axil_arvalid;
    wire        i_axil_arready;
    wire [31:0] i_axil_rdata;
    wire [ 1:0] i_axil_rresp;
    wire        i_axil_rvalid;
    wire        i_axil_rready;

    // Data bus <-> D-RAM (full AXI-Lite: read + write)
    wire [31:0] d_axil_araddr;
    wire [ 2:0] d_axil_arprot;
    wire        d_axil_arvalid;
    wire        d_axil_arready;
    wire [31:0] d_axil_rdata;
    wire [ 1:0] d_axil_rresp;
    wire        d_axil_rvalid;
    wire        d_axil_rready;
    wire [31:0] d_axil_awaddr;
    wire [ 2:0] d_axil_awprot;
    wire        d_axil_awvalid;
    wire        d_axil_awready;
    wire [31:0] d_axil_wdata;
    wire [ 3:0] d_axil_wstrb;
    wire        d_axil_wvalid;
    wire        d_axil_wready;
    wire [ 1:0] d_axil_bresp;
    wire        d_axil_bvalid;
    wire        d_axil_bready;

    // CPU <-> data bus
    wire [ 3:0] dmem_we;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_rd_en;
    wire        dmem_wr_en;

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

        .bus_stall_i (bus_stall),
        .dmem_rd_en_o(dmem_rd_en),
        .dmem_wr_en_o(dmem_wr_en),

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
        .cpu_bus_stop_o   (i_bus_stop),

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
    // channel inputs are tied to 0 (never leave inputs floating)
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

        .s_axil_wdata_i(32'b0),
        .s_axil_wstrb_i(4'b0),
        .s_axil_wvalid_i(1'b0),
        .s_axil_wready_o(), // Write channel outputs are left open. Synthesis will remove the write logic :)

        .s_axil_bresp_o (),
        .s_axil_bvalid_o(),
        .s_axil_bready_i(1'b0)
    );

    // Data bus master. CPU side: addr/wdata/we from MEM stage, rdata back to WB.
    axil_d_bus u_d_bus (
        .a_clk    (clk),
        .a_reset_n(rst_n),

        .cpu_addr_i       (dmem_addr),
        .cpu_wdata_i      (dmem_wdata),
        .cpu_write_en_i   (dmem_we),
        .cpu_r_req_i      (dmem_rd_en),
        .cpu_w_req_i      (dmem_wr_en),
        .cpu_rdata_o      (dmem_rdata),
        .cpu_read_valid_o (),
        .cpu_write_valid_o(),
        .cpu_bus_stop_o   (d_bus_stop),

        .m_axil_araddr_o (d_axil_araddr),
        .m_axil_arprot_o (d_axil_arprot),
        .m_axil_arvalid_o(d_axil_arvalid),
        .m_axil_arready_i(d_axil_arready),

        .m_axil_rdata_i (d_axil_rdata),
        .m_axil_rresp_i (d_axil_rresp),
        .m_axil_rvalid_i(d_axil_rvalid),
        .m_axil_rready_o(d_axil_rready),

        .m_axil_awaddr_o (d_axil_awaddr),
        .m_axil_awprot_o (d_axil_awprot),
        .m_axil_awvalid_o(d_axil_awvalid),
        .m_axil_awready_i(d_axil_awready),

        .m_axil_wdata_o (d_axil_wdata),
        .m_axil_wstrb_o (d_axil_wstrb),
        .m_axil_wvalid_o(d_axil_wvalid),
        .m_axil_wready_i(d_axil_wready),

        .m_axil_bresp_i (d_axil_bresp),
        .m_axil_bvalid_i(d_axil_bvalid),
        .m_axil_bready_o(d_axil_bready)
    );

    // D-RAM: 2^10 words = 4 KB. Both read and write channels are used here
    axil_ram #(
        .ADDR_W(10)
    ) u_dram (
        .a_clk    (clk),
        .a_reset_n(rst_n),

        .s_axil_araddr_i (d_axil_araddr),
        .s_axil_arprot_i (d_axil_arprot),
        .s_axil_arvalid_i(d_axil_arvalid),
        .s_axil_arready_o(d_axil_arready),

        .s_axil_rdata_o (d_axil_rdata),
        .s_axil_rresp_o (d_axil_rresp),
        .s_axil_rvalid_o(d_axil_rvalid),
        .s_axil_rready_i(d_axil_rready),

        .s_axil_awaddr_i (d_axil_awaddr),
        .s_axil_awprot_i (d_axil_awprot),
        .s_axil_awvalid_i(d_axil_awvalid),
        .s_axil_awready_o(d_axil_awready),

        .s_axil_wdata_i (d_axil_wdata),
        .s_axil_wstrb_i (d_axil_wstrb),
        .s_axil_wvalid_i(d_axil_wvalid),
        .s_axil_wready_o(d_axil_wready),

        .s_axil_bresp_o (d_axil_bresp),
        .s_axil_bvalid_o(d_axil_bvalid),
        .s_axil_bready_i(d_axil_bready)
    );

endmodule
