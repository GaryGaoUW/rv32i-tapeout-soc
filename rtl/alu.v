`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/22 17:28:19
// Design Name: 
// Module Name: alu
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


module alu (
    input [31:0] OP1,
    input [31:0] OP2,
    input [3:0] ALU_SEL,
    output reg [31:0] ALU_RES
);

    always @(*) begin
        case (ALU_SEL)
            4'b0000: ALU_RES = OP1 + OP2;  // add, addi (lw, sw, auipc, jal, jalr)
            4'b1000: ALU_RES = OP1 - OP2;  // sub

            4'b0001: ALU_RES = OP1 << OP2[4:0];  // sll, slli
            4'b0101: ALU_RES = OP1 >> OP2[4:0];  // srl, srli
            4'b1101: ALU_RES = $signed(OP1) >>> OP2[4:0];  // sra, srai

            4'b0010: ALU_RES = $signed(OP1) < $signed(OP2) ? 32'b1 : 32'b0;  // slt, slti
            4'b0011: ALU_RES = OP1 < OP2 ? 32'b1 : 32'b0;  // sltu, sltiu

            4'b0111: ALU_RES = OP1 & OP2;  // and, andi
            4'b0110: ALU_RES = OP1 | OP2;  // or, ori
            4'b0100: ALU_RES = OP1 ^ OP2;  // xor, xori

            4'b1111: ALU_RES = OP2;  // Pass B for lui
            default: ALU_RES = 32'h00000000;
        endcase
    end
endmodule
