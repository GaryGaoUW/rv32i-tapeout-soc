`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/24 22:48:05
// Design Name: 
// Module Name: control_logic
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

module control_logic (
    input [31:0] INST,
    output reg REG_WEN,
    output reg A_SEL,
    output reg B_SEL,
    output reg [3:0] ALU_SEL,
    output reg MEM_RW,
    output reg [1:0] WB_SEL,
    output reg IS_JUMP,
    output reg IS_BRANCH
);

    wire [6:0] opcode = INST[6:0];
    wire [2:0] funct3 = INST[14:12];
    wire [6:0] funct7 = INST[31:25];

    always @(*) begin
        REG_WEN = 1'b0;
        MEM_RW = 1'b0;
        A_SEL = 1'b0;
        B_SEL = 1'b0;
        ALU_SEL = 4'b0000;
        WB_SEL = 2'b00;
        IS_BRANCH = 1'b0;
        IS_JUMP = 1'b0;

        case (opcode)
            // R-Type
            7'b0110011: begin
                REG_WEN = 1'b1;
                A_SEL   = 1'b0;
                B_SEL   = 1'b0;
                WB_SEL  = 2'b01;

                case (funct3)
                    3'h0: ALU_SEL = (funct7[5]) ? 4'b1000 : 4'b0000;  // sub or add
                    3'h4: ALU_SEL = 4'b0100;  // xor
                    3'h6: ALU_SEL = 4'b0110;  // or
                    3'h7: ALU_SEL = 4'b0111;  //and
                    3'h1: ALU_SEL = 4'b0001;  // sll
                    3'h5: ALU_SEL = (funct7[5]) ? 4'b1101 : 4'b0101;  // sra or srl
                    3'h2: ALU_SEL = 4'b0010;  // slt
                    3'h3: ALU_SEL = 4'b0011;  // sltu
                endcase
            end

            // I-Type
            7'b0010011: begin
                REG_WEN = 1'b1;
                A_SEL   = 1'b0;
                B_SEL   = 1'b1;
                WB_SEL  = 2'b01;

                case (funct3)
                    3'h0: ALU_SEL = 4'b0000;  // add
                    3'h4: ALU_SEL = 4'b0100;  // xor
                    3'h6: ALU_SEL = 4'b0110;  // or
                    3'h7: ALU_SEL = 4'b0111;  //and
                    3'h1: ALU_SEL = 4'b0001;  // sll
                    3'h5: ALU_SEL = (funct7[5]) ? 4'b1101 : 4'b0101;  // sra or srl
                    3'h2: ALU_SEL = 4'b0010;  // slt
                    3'h3: ALU_SEL = 4'b0011;  // sltu
                endcase
            end

            // I-Type-Load
            7'b0000011: begin
                REG_WEN = 1'b1;
                A_SEL   = 1'b0;
                B_SEL   = 1'b1;
                ALU_SEL = 4'b0000;
                MEM_RW  = 1'b0;
                WB_SEL  = 2'b00;
            end

            // S-Type
            7'b0100011: begin
                REG_WEN = 1'b0;
                A_SEL   = 1'b0;
                B_SEL   = 1'b1;
                ALU_SEL = 4'b0000;
                MEM_RW  = 1'b1;
                WB_SEL  = 2'b00;  // don't care
            end

            // B-Type
            7'b1100011: begin
                REG_WEN = 1'b0;
                A_SEL = 1'b1;
                B_SEL = 1'b1;
                ALU_SEL = 4'b0000;
                MEM_RW = 1'b0;
                WB_SEL = 2'b01;  // don't care
                IS_BRANCH = 1'b1;
            end

            // U-Type-lui
            7'b0110111: begin
                REG_WEN = 1'b1;
                A_SEL   = 1'b1;  // don't care
                B_SEL   = 1'b1;
                WB_SEL  = 2'b01;
                ALU_SEL = 4'b1111;  // output shifted imm directly
            end

            // U-Type-auipc
            7'b0010111: begin
                REG_WEN = 1'b1;
                A_SEL   = 1'b1;  // care this time, choose pc
                B_SEL   = 1'b1;
                WB_SEL  = 2'b01;
                ALU_SEL = 4'b0000;  // output imm + pc 
            end

            // J-Type-jal (rd = PC+4; PC += imm)
            7'b1101111: begin
                REG_WEN = 1'b1;
                MEM_RW  = 1'b0;
                A_SEL   = 1'b1;
                B_SEL   = 1'b1;
                ALU_SEL = 4'b0000;
                WB_SEL  = 2'b10;
                IS_JUMP = 1'b1;
            end

            // I-Type-jalr
            7'b1100111: begin
                REG_WEN = 1'b1;
                MEM_RW  = 1'b0;
                A_SEL   = 1'b0;  // only change: choose the rs1 instead of the pc
                B_SEL   = 1'b1;
                ALU_SEL = 4'b0000;
                WB_SEL  = 2'b10;
                IS_JUMP = 1'b1;
            end

            default: begin
            end
        endcase
    end
endmodule
