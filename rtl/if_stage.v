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
    input CLK,
    input RST_N,
    input IF_PC_SEL_I,
    input [31:0] IF_JUMP_ADDR_I,
    input IF_STALL_I,

    output [31:0] IF_PC_O,
    output [31:0] IF_INST_O
);
    // Calculate the next PC value based on whether we are taking a jump/branch or just incrementing by 4.
    wire [31:0] if_next_pc = (IF_PC_SEL_I) ? IF_JUMP_ADDR_I : (IF_PC_O + 4);

    pc_reg u_pc_reg (
        .CLK   (CLK),
        .RST_N (RST_N),
        .STALL (IF_STALL_I),
        .PC_IN (if_next_pc),
        .PC_OUT(IF_PC_O)
    );

    // The BRAM output register inside inst_mem is the de-facto IF/ID instruction
    // register, so it must be frozen on stall together with the PC (see inst_mem).
    inst_mem u_inst_mem (
        .CLK    (CLK),
        .RST_N  (RST_N),
        .STALL  (IF_STALL_I),
        .PC_ADDR(IF_PC_O),
        .INST   (IF_INST_O)
    );
endmodule
