`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/23 23:49:02
// Design Name: 
// Module Name: branch_comp
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


module branch_comp (
    input [2:0] FUNCT3,
    input [31:0] RDATA1,
    input [31:0] RDATA2,
    output reg BR_EN
);

    always @(*) begin
        BR_EN = 1'b0;  // By default don't jump

        case (FUNCT3)
            3'b000: BR_EN = (RDATA1 == RDATA2);  // beq
            3'b001: BR_EN = (RDATA1 != RDATA2);  // bne
            3'b100: BR_EN = ($signed(RDATA1) < $signed(RDATA2));  // blt
            3'b101: BR_EN = ($signed(RDATA1) >= $signed(RDATA2));  // bge
            3'b110: BR_EN = (RDATA1 < RDATA2);  // bltu
            3'b111: BR_EN = (RDATA1 >= RDATA2);  // bgeu
        endcase
    end
endmodule
