`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/29 19:22:57
// Design Name: 
// Module Name: pipe_mem_wb
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


module pipe_mem_wb (
    input CLK,
    input RST_N,
    input FLUSH,
    input STALL,

    input [31:0] MEM_PC_I,
    input [31:0] MEM_ALU_RES_I,
    input [31:0] MEM_RDATA_I,
    input MEM_REG_WEN_I,
    input [4:0] MEM_RD_I,
    input [1:0] MEM_WB_SEL_I,
    input [2:0] MEM_FUNCT3_I,

    output reg [31:0] WB_PC_O,
    output reg [31:0] WB_ALU_RES_O,
    output [31:0] WB_RDATA_O,
    output reg WB_REG_WEN_O,
    output reg [4:0] WB_RD_O,
    output reg [1:0] WB_WB_SEL_O,
    output reg [2:0] WB_FUNCT3_O  // needed by the load data extraction in WB
);

    always @(posedge CLK, negedge RST_N) begin
        if (!RST_N) begin
            WB_PC_O <= 32'b0;
            WB_ALU_RES_O <= 32'b0;
            WB_REG_WEN_O <= 1'b0;
            WB_RD_O <= 5'b00000;
            WB_WB_SEL_O <= 2'b00;
            WB_FUNCT3_O <= 3'b000;
        end else if (FLUSH) begin
            WB_PC_O <= 32'b0;
            WB_ALU_RES_O <= 32'b0;
            WB_REG_WEN_O <= 1'b0;
            WB_RD_O <= 5'b00000;
            WB_WB_SEL_O <= 2'b00;
            WB_FUNCT3_O <= 3'b000;
        end else if (!STALL) begin
            WB_PC_O <= MEM_PC_I;
            WB_ALU_RES_O <= MEM_ALU_RES_I;
            WB_REG_WEN_O <= MEM_REG_WEN_I;
            WB_RD_O <= MEM_RD_I;
            WB_WB_SEL_O <= MEM_WB_SEL_I;
            WB_FUNCT3_O <= MEM_FUNCT3_I;
        end
    end

    // Directly pass the RAW read data to WB stage, no need to store in a register
    // because BRAM inherently delays rdata by 1 cycle, matching the MEM->WB transition perfectly.
    // The byte/half-word extraction is done in WB (core_top) with the load's own
    // registered controls (WB_FUNCT3_O / WB_ALU_RES_O), NOT with the controls of
    // whatever instruction currently sits in MEM.
    assign WB_RDATA_O = MEM_RDATA_I;
endmodule
