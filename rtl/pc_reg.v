`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/22 11:06:42
// Design Name: 
// Module Name: pc_reg
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


module pc_reg (
    input CLK,
    input RST_N,
    input STALL,
    input [31:0] PC_IN,
    output reg [31:0] PC_OUT
);

    always @(posedge CLK) begin
        if (!RST_N) begin
            // Reset the pc to 0, aka standard RISCV starting address
            // Also help the simulation to start with a known value instead of x's
            PC_OUT <= 32'h00000000;
        end else if (!STALL) begin
            // When staling, freeze the PC address
            // In another word, only update the PC when we are not stalling
            PC_OUT <= PC_IN;
        end
    end
endmodule
