`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/22 15:35:10
// Design Name: 
// Module Name: regfile
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


module regfile (
    input CLK,
    input RST_N,
    input [4:0] RADDR1,
    input [4:0] RADDR2,
    output [31:0] RDATA1,
    output [31:0] RDATA2,

    input WE,
    input [4:0] WADDR,
    input [31:0] WDATA
);

    // 32x32 register file with asynchronous (combinational) reads.
    // Note: because of the synchronous reset loop below, synthesis will map
    // this to flip-flops rather than distributed RAM, which is fine for a
    // register file this small. Can be read and written in the same cycle.
    reg [31:0] regs[0:31];

    // Internal Forwarding (Write-First): 
    // If reading the same register that is currently being written, 
    // bypass the operation to the register file array and directly forward the WDATA to read.
    assign RDATA1 = (RADDR1 == 5'b00000) ? 32'h00000000 : 
                    ((WE == 1'b1) && (WADDR == RADDR1)) ? WDATA : 
                    regs[RADDR1];

    assign RDATA2 = (RADDR2 == 5'b00000) ? 32'h00000000 : 
                    ((WE == 1'b1) && (WADDR == RADDR2)) ? WDATA : 
                    regs[RADDR2];

    integer i;
    always @(posedge CLK) begin
        if (!RST_N) begin
            // On reset, initialize all registers to 0. Good to have a known state for simulation and debugging.
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end else begin
            if (WE == 1'b1 && WADDR != 5'b00000) begin
                regs[WADDR] <= WDATA;
            end
        end
    end

endmodule
