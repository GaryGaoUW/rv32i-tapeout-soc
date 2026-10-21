`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/22 19:34:49
// Design Name: 
// Module Name: data_mem
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


module data_mem (
    input CLK,
    input [3:0] WE,
    input [31:0] ADDR,
    input [31:0] WDATA,
    output reg [31:0] RDATA
);

    // Use ram_syle = "block" to infer block RAM on FPGA
    (* ram_style = "block" *) reg [31:0] ram[0:1023];

    // Initialize memory to zero (To remove the 0xXXXXXXXX issue in simulation)
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            ram[i] = 32'h00000000;
        end
    end

    // Write logic with byte enables
    // WE[0] controls byte 0 (bits 7:0), WE[1] controls byte 1 (bits 15:8), etc.
    // This allows for byte, half-word, and word writes based on the write Enable(WE) signal.
    wire [9:0] ram_addr = ADDR[11:2];
    always @(posedge CLK) begin

        if (WE[0]) ram[ram_addr][7:0] <= WDATA[7:0];
        if (WE[1]) ram[ram_addr][15:8] <= WDATA[15:8];
        if (WE[2]) ram[ram_addr][23:16] <= WDATA[23:16];
        if (WE[3]) ram[ram_addr][31:24] <= WDATA[31:24];

        // Synchronous read (1 clock cycle latency)
        RDATA <= ram[ram_addr];

        // Note 1:
        // Chop the lowest 2 bits to get the word-aligned address index
        // Because ram is in integer index (like 1,2,3...), means number/index of the instructions
        // but ADDR is the word-addressable (32 bits = 4 bytes), means the actual byte address
        // so we have to divide ADDR by 4, same as ADDR[31:2].

        // Note 2:
        // With non-blocking assignments in the same always block, a same-cycle
        // read of a written address returns the OLD value (read-first behavior).
        // This never matters here: only one instruction occupies MEM per cycle,
        // and a store followed by a load to the same address commits its write
        // one full cycle before the load's read data is registered.

        // Note 3:
        // Because RDATA is registered (BRAM behavior), the read data belongs to
        // the address presented in the PREVIOUS cycle, i.e. the load instruction
        // that has meanwhile moved on to WB. That's why the load byte/half-word
        // extraction is done in the WB stage with the load's own registered
        // controls (see core_top / pipe_mem_wb).
    end
endmodule
