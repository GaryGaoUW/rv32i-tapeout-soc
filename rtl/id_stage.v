`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/22 15:22:10
// Design Name: Gary Gao
// Module Name: id_stage
// Project Name: RV32I
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - Finaled sigle cycle RV32I cpu, all the control signals are generated in ID stage
// Revision 0.03 - Impoved to pipelined version
//               - Moved the branch_comp to EX stage, and output is_jump, is_branch and funct3 to EX stage for branch comp
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module id_stage (
    input CLK,
    input RST_N,
    input [31:0] ID_INST_I,

    // From WriteBack Stage: 
    input WB_WEN_I,
    input [4:0] WB_WADDR_I,
    input [31:0] WB_WDATA_I,

    // Outputs for internal wireing and forwarding in top
    output [ 6:0] ID_OPCODE_O,
    output [ 4:0] ID_RD_O,
    output [31:0] ID_RDATA1_O,
    output [31:0] ID_RDATA2_O,
    output [31:0] ID_IMM_O,

    // To Control Logic and ID/EX Pipeline Register
    output       ID_REG_WEN_O,
    output       ID_A_SEL_O,
    output       ID_B_SEL_O,
    output [3:0] ID_ALU_SEL_O,
    output       ID_MEM_RW_O,
    output [1:0] ID_WB_SEL_O,

    // For Branch and Jump in AlU/ EX Stage
    output ID_IS_JUMP_O,
    output ID_IS_BRANCH_O,
    output [2:0] ID_FUNCT3_O,

    // forwarding signals
    output [4:0] ID_RADDR1_O,
    output [4:0] ID_RADDR2_O

);
    // Decoding logic by bits on the ece222 slides
    assign ID_OPCODE_O = ID_INST_I[6:0];
    assign ID_FUNCT3_O = ID_INST_I[14:12];
    assign ID_RD_O = ID_INST_I[11:7];
    assign ID_RADDR1_O = ID_INST_I[19:15];
    assign ID_RADDR2_O = ID_INST_I[24:20];

    regfile u_regfile (
        .CLK   (CLK),
        .RST_N (RST_N),
        .RADDR1(ID_RADDR1_O),
        .RADDR2(ID_RADDR2_O),
        .RDATA1(ID_RDATA1_O),
        .RDATA2(ID_RDATA2_O),

        .WE   (WB_WEN_I),
        .WADDR(WB_WADDR_I),
        .WDATA(WB_WDATA_I)
    );

    imm_gen u_imm_gen (
        .INST   (ID_INST_I),
        .IMM_SEL(ID_OPCODE_O),
        .IMM    (ID_IMM_O)
    );

    control_logic u_control_logic (
        .INST     (ID_INST_I),
        .REG_WEN  (ID_REG_WEN_O),
        .A_SEL    (ID_A_SEL_O),
        .B_SEL    (ID_B_SEL_O),
        .ALU_SEL  (ID_ALU_SEL_O),
        .MEM_RW   (ID_MEM_RW_O),
        .WB_SEL   (ID_WB_SEL_O),
        .IS_JUMP  (ID_IS_JUMP_O),
        .IS_BRANCH(ID_IS_BRANCH_O)
    );

endmodule
