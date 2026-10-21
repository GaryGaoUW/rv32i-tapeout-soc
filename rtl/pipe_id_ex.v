`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/28 19:02:48
// Design Name: 
// Module Name: pipe_id_ex
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


module pipe_id_ex (
    // Every pipeline register needs CLK, RST_N, FLUSH and STALL
    input CLK,
    input RST_N,
    input FLUSH,
    input STALL,

    // Information from ID stage for ALU to use in EX stage
    input [31:0] ID_PC_I,
    input [31:0] ID_RDATA1_I,
    input [31:0] ID_RDATA2_I,
    input [31:0] ID_IMM_I,

    output reg [31:0] EX_PC_O,
    output reg [31:0] EX_RDATA1_O,
    output reg [31:0] EX_RDATA2_O,
    output reg [31:0] EX_IMM_O,

    // Control signals from ID stage to EX stage
    input       ID_A_SEL_I,
    input       ID_B_SEL_I,
    input [3:0] ID_ALU_SEL_I,
    input       ID_MEM_RW_I,
    input       ID_REG_WEN_I,
    input [4:0] ID_RD_I,
    input [1:0] ID_WB_SEL_I,
    input       ID_IS_JUMP_I,
    input       ID_IS_BRANCH_I,
    input [2:0] ID_FUNCT3_I,

    output reg       EX_A_SEL_O,
    output reg       EX_B_SEL_O,
    output reg [3:0] EX_ALU_SEL_O,
    output reg       EX_MEM_RW_O,
    output reg       EX_REG_WEN_O,
    output reg [4:0] EX_RD_O,
    output reg [1:0] EX_WB_SEL_O,
    output reg       EX_IS_JUMP_O,
    output reg       EX_IS_BRANCH_O,
    output reg [2:0] EX_FUNCT3_O,

    // forwarding signals
    input [4:0] ID_RADDR1_I,
    input [4:0] ID_RADDR2_I,
    output reg [4:0] EX_RADDR1_O,
    output reg [4:0] EX_RADDR2_O
);

    always @(posedge CLK, negedge RST_N) begin
        if (!RST_N) begin
            EX_PC_O <= 32'b0;
            EX_RDATA1_O <= 32'b0;
            EX_RDATA2_O <= 32'b0;
            EX_IMM_O <= 32'b0;
            EX_A_SEL_O <= 1'b0;
            EX_B_SEL_O <= 1'b0;
            EX_ALU_SEL_O <= 4'b0000;
            EX_MEM_RW_O <= 1'b0;
            EX_REG_WEN_O <= 1'b0;
            EX_RD_O <= 5'b00000;
            EX_WB_SEL_O <= 2'b01;
            EX_IS_JUMP_O <= 1'b0;
            EX_IS_BRANCH_O <= 1'b0;
            EX_FUNCT3_O <= 3'b000;
            EX_RADDR1_O <= 5'b00000;
            EX_RADDR2_O <= 5'b00000;
        end else if (FLUSH) begin
            EX_PC_O <= 32'b0;
            EX_RDATA1_O <= 32'b0;
            EX_RDATA2_O <= 32'b0;
            EX_IMM_O <= 32'b0;
            EX_A_SEL_O <= 1'b0;
            EX_B_SEL_O <= 1'b0;
            EX_ALU_SEL_O <= 4'b0000;
            EX_MEM_RW_O <= 1'b0;
            EX_REG_WEN_O <= 1'b0;
            EX_RD_O <= 5'b00000;
            EX_WB_SEL_O <= 2'b01;
            EX_IS_JUMP_O <= 1'b0;
            EX_IS_BRANCH_O <= 1'b0;
            EX_FUNCT3_O <= 3'b000;
            EX_RADDR1_O <= 5'b00000;
            EX_RADDR2_O <= 5'b00000;
        end else if (!STALL) begin
            EX_PC_O <= ID_PC_I;
            EX_RDATA1_O <= ID_RDATA1_I;
            EX_RDATA2_O <= ID_RDATA2_I;
            EX_IMM_O <= ID_IMM_I;
            EX_A_SEL_O <= ID_A_SEL_I;
            EX_B_SEL_O <= ID_B_SEL_I;
            EX_ALU_SEL_O <= ID_ALU_SEL_I;
            EX_MEM_RW_O <= ID_MEM_RW_I;
            EX_REG_WEN_O <= ID_REG_WEN_I;
            EX_RD_O <= ID_RD_I;
            EX_WB_SEL_O <= ID_WB_SEL_I;
            EX_IS_JUMP_O <= ID_IS_JUMP_I;
            EX_IS_BRANCH_O <= ID_IS_BRANCH_I;
            EX_FUNCT3_O <= ID_FUNCT3_I;
            EX_RADDR1_O <= ID_RADDR1_I;
            EX_RADDR2_O <= ID_RADDR2_I;
        end
    end

endmodule
