`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/29 18:23:26
// Design Name: 
// Module Name: pipe_ex_mem
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


module pipe_ex_mem (
    input CLK,
    input RST_N,
    input FLUSH,
    input STALL,

    input [31:0] EX_PC_I,
    input [31:0] EX_WDATA_I,
    input EX_MEM_RW_I,
    input EX_REG_WEN_I,
    input [4:0] EX_RD_I,
    input [1:0] EX_WB_SEL_I,
    input [31:0] EX_ALU_RES_I,
    input [2:0] EX_FUNCT3_I,

    output reg [31:0] MEM_PC_O,
    output reg [31:0] MEM_WDATA_O,
    output reg MEM_MEM_RW_O,
    output reg MEM_REG_WEN_O,
    output reg [4:0] MEM_RD_O,
    output reg [1:0] MEM_WB_SEL_O,
    output reg [31:0] MEM_ALU_RES_O,
    output reg [2:0] MEM_FUNCT3_O,

    // frwarding signals
    input [4:0] EX_RADDR2_I,
    output reg [4:0] MEM_RADDR2_O
);

    always @(posedge CLK, negedge RST_N) begin
        if (!RST_N) begin
            MEM_PC_O <= 32'b0;
            MEM_WDATA_O <= 32'b0;
            MEM_MEM_RW_O <= 1'b0;
            MEM_REG_WEN_O <= 1'b0;
            MEM_RD_O <= 5'b00000;
            MEM_WB_SEL_O <= 2'b00;
            MEM_ALU_RES_O <= 32'b0;
            MEM_FUNCT3_O <= 3'b000;
            MEM_RADDR2_O <= 5'b00000;
        end else if (FLUSH) begin
            MEM_PC_O <= 32'b0;
            MEM_WDATA_O <= 32'b0;
            MEM_MEM_RW_O <= 1'b0;
            MEM_REG_WEN_O <= 1'b0;
            MEM_RD_O <= 5'b00000;
            MEM_WB_SEL_O <= 2'b00;
            MEM_ALU_RES_O <= 32'b0;
            MEM_FUNCT3_O <= 3'b000;
            MEM_RADDR2_O <= 5'b00000;
        end else if (!STALL) begin
            MEM_PC_O <= EX_PC_I;
            MEM_WDATA_O <= EX_WDATA_I;
            MEM_MEM_RW_O <= EX_MEM_RW_I;
            MEM_REG_WEN_O <= EX_REG_WEN_I;
            MEM_RD_O <= EX_RD_I;
            MEM_WB_SEL_O <= EX_WB_SEL_I;
            MEM_ALU_RES_O <= EX_ALU_RES_I;
            MEM_FUNCT3_O <= EX_FUNCT3_I;
            MEM_RADDR2_O <= EX_RADDR2_I;
        end
    end
endmodule
