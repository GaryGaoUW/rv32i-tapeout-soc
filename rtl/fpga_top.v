`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/26 16:13:51
// Design Name: 
// Module Name: fpga_top
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


module fpga_top (
    input I_CLK_25M,
    input I_RST_N,
    output [3:0] DEBUG_PC
);

    wire [31:0] alu_res;

    core_top u_cpu (
        .CLK    (I_CLK_25M),
        .RST_N  (I_RST_N),
        .ALU_RES(alu_res)
    );

    // Route four spread-out ALU-result bits to output pins for quick debug
    // visibility (and to keep the core from being optimized away in synthesis).
    assign DEBUG_PC = {alu_res[31], alu_res[21], alu_res[11], alu_res[1]};

endmodule
