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

    // CPU <-> instruction memory
    wire [31:0] imem_addr;
    wire        imem_stall;
    wire [31:0] imem_rdata;

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
        .imem_stall_o(imem_stall),
        .imem_rdata_i(imem_rdata),

        .dmem_we_o   (dmem_we),
        .dmem_addr_o (dmem_addr),
        .dmem_wdata_o(dmem_wdata),
        .dmem_rdata_i(dmem_rdata),

        .pc_wire       (pc_wire),
        .inst_wire     (inst_wire),
        .alu_res       (alu_res),
        .wb_data       (wb_data),
        .dbg_wb_pc     (dbg_wb_pc),
        .dbg_wb_rd     (dbg_wb_rd),
        .dbg_wb_reg_wen(dbg_wb_reg_wen)
    );

    inst_mem u_imem (
        .clk    (clk),
        .rst_n  (rst_n),
        .stall  (imem_stall),
        .pc_addr(imem_addr),
        .inst   (imem_rdata)
    );

    data_mem u_dmem (
        .clk  (clk),
        .we   (dmem_we),
        .addr (dmem_addr),
        .wdata(dmem_wdata),
        .rdata(dmem_rdata)
    );

endmodule
