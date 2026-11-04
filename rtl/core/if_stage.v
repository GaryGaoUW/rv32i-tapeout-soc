`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/29 19:35:20
// Design Name: 
// Module Name: if_stage
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module if_stage (
    input clk,
    input rst_n,

    input         if_pc_sel_i,
    input  [31:0] if_jump_addr_i,
    input         if_stall_i,
    output [31:0] if_pc_o
);
    // Calculate the next PC value based on whether we are taking a jump/branch or just incrementing by 4.
    wire [31:0] if_next_pc = (if_pc_sel_i) ? if_jump_addr_i : (if_pc_o + 4);

    pc_reg u_pc_reg (
        .clk   (clk),
        .rst_n (rst_n),
        .stall (if_stall_i),
        .pc_in (if_next_pc),
        .pc_out(if_pc_o)
    );

    // The instruction memory now lives outside the core (see soc_top).
    // if_pc_o is the fetch address; the instruction comes back into core_top
    // through imem_rdata_i.
endmodule
