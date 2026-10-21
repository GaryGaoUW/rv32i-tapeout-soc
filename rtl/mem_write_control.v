`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/26 21:28:49
// Design Name: 
// Module Name: mem_write_control
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


module mem_write_control (
    input [31:0] ALU_RES,
    input IS_STORE,
    input [2:0] FUNCT3,
    output reg [3:0] WRITE_CTRL
);

    always @(*) begin
        if (IS_STORE) begin
            case (FUNCT3)
                3'b000:
                WRITE_CTRL = 4'b0001 << ALU_RES[1:0]; // only need the last 2 bits for offset within the word
                3'b001:
                WRITE_CTRL = 4'b0011 << ALU_RES[1:0]; // only need the last 2 bits for offset within the word
                3'b010: WRITE_CTRL = 4'b1111;
                default: WRITE_CTRL = 4'b0000;
            endcase
        end else WRITE_CTRL = 4'b0000;
    end
endmodule
