`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/29 19:06:25
// Design Name: 
// Module Name: mem_stage
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


module mem_stage (
    input CLK,
    input RST_N,

    input [31:0] MEM_WDATA_I,
    input MEM_MEM_RW_I,
    input [31:0] MEM_ALU_RES_I,
    input [2:0] MEM_FUNCT3_I,

    // Raw BRAM read data. Because of the 1-cycle BRAM latency it becomes valid
    // when the load instruction is already in WB, so the byte/half-word
    // extraction (mem_load_control) is done in the WB stage (see core_top),
    // using the load's own registered controls (funct3 / address offset).
    output [31:0] MEM_RDATA_O,

    // forwading signals
    input [31:0] WB_DATA_I,
    input MEM_FORWARD_WDATA_SEL_I
);

    wire [3:0] mem_write_ctrl;  // 4-bit control signal for byte/half/word write enables

    mem_write_control u_mem_write_control (
        .ALU_RES   (MEM_ALU_RES_I),
        .IS_STORE  (MEM_MEM_RW_I),
        .FUNCT3    (MEM_FUNCT3_I),
        .WRITE_CTRL(mem_write_ctrl)
    );

    // forwarding logic for store after load hazard
    wire [31:0] mem_wdata_final = (MEM_FORWARD_WDATA_SEL_I) ? WB_DATA_I : MEM_WDATA_I;

    // Shift the store data into the byte lane selected by the address offset,
    // so it lines up with the shifted byte-enable pattern from mem_write_control.
    // e.g. "sb" to ADDR%4 == 1 -> WE = 4'b0010, and data_mem writes WDATA[15:8],
    // so the store byte must be moved from WDATA[7:0] up to WDATA[15:8].
    wire [31:0] mem_wdata_aligned = mem_wdata_final << {MEM_ALU_RES_I[1:0], 3'b000};

    data_mem u_data_mem (
        .CLK  (CLK),
        .WE   (mem_write_ctrl),
        .ADDR (MEM_ALU_RES_I),
        .WDATA(mem_wdata_aligned),
        .RDATA(MEM_RDATA_O)
    );

endmodule
