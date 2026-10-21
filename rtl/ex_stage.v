`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/29 08:38:59
// Design Name: 
// Module Name: ex_stage
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


module ex_stage (
    // Inputs from the ID/EX pipeline register
    input [31:0] EX_PC_I,     // used for ALU op1 when pc_sel is 1
    input [31:0] EX_RDATA1_I, // used for ALU op1 and branch comp
    input [31:0] EX_RDATA2_I, // used for ALU op2 and branch comp
    input [31:0] EX_IMM_I,    // used for ALU op2

    input       EX_A_SEL_I,      // used for ALU op1 selection
    input       EX_B_SEL_I,      // used for ALU op2 selection
    input [3:0] EX_ALU_SEL_I,    // used for ALU operation selection
    input       EX_IS_JUMP_I,    // used to determine pc_sel in IF stage
    input       EX_IS_BRANCH_I,  // used to determine pc_sel in IF stage
    input [2:0] EX_FUNCT3_I,     // pass to M and used for branch comp

    // Outputs to MEM stage (New signals)
    output [31:0] EX_ALU_RES_O,
    output [31:0] EX_WDATA_O,    // New signal for data to be written to memory

    // For Branch and Jump in IF stage
    output IF_PC_SEL_O,
    output [31:0] IF_JUMP_ADDR_O,

    // forwarding signals
    input [ 1:0] EX_FORWARD_A_SEL_I,
    input [ 1:0] EX_FORWARD_B_SEL_I,
    input [31:0] MEM_ALU_RES_I,
    input [31:0] WB_DATA_I,
    input [ 1:0] EX_FORWARD_WDATA_SEL_I
);

    reg [31:0] ex_alu_op1;
    reg [31:0] ex_alu_op2;
    reg [31:0] ex_fresh_rdata1;
    reg [31:0] ex_fresh_rdata2;
    wire ex_br_en;

    always @(*) begin
        // Forwarding logic for ALU operand 1
        case (EX_FORWARD_A_SEL_I)
            2'b00: begin
                ex_alu_op1 = (EX_A_SEL_I) ? EX_PC_I : EX_RDATA1_I;  // No forwarding
                ex_fresh_rdata1 = EX_RDATA1_I;
            end
            2'b01: begin
                ex_alu_op1 = (EX_A_SEL_I) ? EX_PC_I : MEM_ALU_RES_I;  // Forward from MEM stage
                ex_fresh_rdata1 = MEM_ALU_RES_I;
            end
            2'b10: begin
                ex_alu_op1 = (EX_A_SEL_I) ? EX_PC_I : WB_DATA_I;  // Forward from WB stage
                ex_fresh_rdata1 = WB_DATA_I;
            end
            default: begin
                ex_alu_op1 = (EX_A_SEL_I) ? EX_PC_I : EX_RDATA1_I;  // Default case
                ex_fresh_rdata1 = EX_RDATA1_I;
            end
        endcase

        // Forwarding logic for ALU operand 2
        case (EX_FORWARD_B_SEL_I)
            2'b00: begin
                ex_alu_op2 = (EX_B_SEL_I) ? EX_IMM_I : EX_RDATA2_I;  // No forwarding
                ex_fresh_rdata2 = EX_RDATA2_I;
            end
            2'b01: begin
                ex_alu_op2 = (EX_B_SEL_I) ? EX_IMM_I : MEM_ALU_RES_I;  // Forward from MEM stage
                ex_fresh_rdata2 = MEM_ALU_RES_I;
            end
            2'b10: begin
                ex_alu_op2 = (EX_B_SEL_I) ? EX_IMM_I : WB_DATA_I;  // Forward from WB stage
                ex_fresh_rdata2 = WB_DATA_I;
            end
            default: begin
                ex_alu_op2 = (EX_B_SEL_I) ? EX_IMM_I : EX_RDATA2_I;  // Default case
                ex_fresh_rdata2 = EX_RDATA2_I;
            end
        endcase

        // Forwarding logic for data to be written to memory ex: ALU -> Store
        // Can be replaced with EX_WDATA_O = ex_fresh_rdata2, bc they got the same forwarding selection
        // case (EX_FORWARD_WDATA_SEL_I) 
        //     2'b00:   EX_WDATA_O = EX_RDATA2_I;
        //     2'b01:   EX_WDATA_O = MEM_ALU_RES_I;
        //     2'b10:   EX_WDATA_O = WB_DATA_I; 
        //     default: EX_WDATA_O = EX_RDATA2_I;  // Default case
        // endcase
    end

    branch_comp u_branch_comp (
        .FUNCT3(EX_FUNCT3_I),
        .RDATA1(ex_fresh_rdata1),  // must be the real data, not the EX_PC_I
        .RDATA2(ex_fresh_rdata2),  // must be the real data, not the EX_IMM_I
        .BR_EN (ex_br_en)
    );

    alu u_alu (
        .OP1    (ex_alu_op1),
        .OP2    (ex_alu_op2),
        .ALU_SEL(EX_ALU_SEL_I),
        .ALU_RES(EX_ALU_RES_O)
    );

    // Determine the next PC in IF stage
    // The if_pc_sel_flush will also be used as flush signal for IF/ID pipeline register, 
    // to flush the wrong path instruction when branch taken or jump
    assign IF_PC_SEL_O = (EX_IS_JUMP_I || (EX_IS_BRANCH_I && ex_br_en)) ? 1'b1 : 1'b0;
    assign IF_JUMP_ADDR_O = {
        EX_ALU_RES_O[31:1], 1'b0
    };  // Last bit is always 0 since instructions are 2 or 4 byte aligned

    // Continuous from top, assign for EX_WDATA_O, which is the data to be written to memory (for store instructions)
    assign EX_WDATA_O = ex_fresh_rdata2;

endmodule
