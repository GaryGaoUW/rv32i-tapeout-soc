`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/28 11:21:49
// Design Name: 
// Module Name: pipe_if_id
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


module pipe_if_id (
    input CLK,
    input RST_N,
    input FLUSH,
    input STALL,

    input [31:0] IF_PC_I,
    input [31:0] IF_INST_I,
    output reg [31:0] ID_PC_O,
    output [31:0] ID_INST_O
);

    always @(posedge CLK, negedge RST_N) begin
        if (!RST_N) begin
            ID_PC_O <= 32'h00000000;
        end else if (FLUSH) begin
            ID_PC_O <= 32'h00000000;
        end else if (!STALL) begin
            ID_PC_O <= IF_PC_I;
        end
    end

    // A taken branch/jump (resolved in EX) leaves TWO wrong-path instructions
    // in flight: one already in ID, and one still inside the synchronous BRAM
    // output register (fetch has 1 cycle of latency).
    // `FLUSH` kills the first one, `flush_d` (FLUSH delayed by one cycle)
    // kills the second one when it comes out of the BRAM.
    reg flush_d;
    always @(posedge CLK, negedge RST_N) begin
        if (!RST_N) begin
            flush_d <= 1'b0;
        end else begin
            flush_d <= FLUSH;
        end
    end

    // The BRAM output register inside inst_mem already acts as the IF/ID
    // instruction register, so the instruction is just passed through here.
    // Insert a NOP while flushing the two wrong-path slots.
    assign ID_INST_O = (FLUSH || flush_d) ? 32'h00000013 : IF_INST_I;

    // Note: on a stall both the PC and the BRAM output register are frozen
    // (see inst_mem), so the instruction sitting in ID is naturally held.

endmodule
