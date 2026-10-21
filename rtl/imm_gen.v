`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/23 23:02:17
// Design Name: 
// Module Name: imm_gen
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


module imm_gen (
    input [31:0] INST,
    input [6:0] IMM_SEL,
    output reg [31:0] IMM
);

    always @(*) begin
        IMM = 32'b0;  //Dafault value to avoid latches

        case (IMM_SEL)
            //I type
            7'b0010011, 7'b0000011, 7'b1100111: begin
                IMM = {{20{INST[31]}}, INST[31:20]};
            end

            // S type
            7'b0100011: begin
                IMM = {{20{INST[31]}}, INST[31:25], INST[11:7]};
            end

            // B type
            7'b1100011: begin
                IMM = {{19{INST[31]}}, INST[31], INST[7], INST[30:25], INST[11:8], 1'b0};
            end

            // U type
            7'b0110111, 7'b0010111: begin
                IMM = {INST[31:12], 12'b0};
            end

            // J type
            7'b1101111: begin
                IMM = {{12{INST[31]}}, INST[19:12], INST[20], INST[30:21], 1'b0};
            end
        endcase
    end
endmodule
