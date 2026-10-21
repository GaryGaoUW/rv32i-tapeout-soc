`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/01 21:05:16
// Design Name: 
// Module Name: forwarding_unit
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


module forwarding_unit (
    input [4:0] EX_RADDR1_I,
    input [4:0] EX_RADDR2_I,

    input [4:0] MEM_RD_I,
    input MEM_REG_WEN_I,

    input [4:0] WB_RD_I,
    input WB_REG_WEN_I,

    output reg [1:0] EX_FORWARD_A_SEL_O,
    output reg [1:0] EX_FORWARD_B_SEL_O,

    input EX_MEM_RW_I,
    output reg [1:0] EX_WDATA_SEL_O,

    // for store after load hazard
    input [4:0] MEM_RADDR2_I,
    output reg MEM_FORWARD_WDATA_SEL_O

);

    always @(*) begin
        // Default: no forwarding, also use for cover all default cases
        EX_FORWARD_A_SEL_O = 2'b00;
        EX_FORWARD_B_SEL_O = 2'b00;
        EX_WDATA_SEL_O = 2'b00;
        MEM_FORWARD_WDATA_SEL_O = 1'b0;

        // Forwarding for ALU operand 1 (ex_rdata1)
        // Scenario: when next two inst used the same register as source in current ex stage, the data is not ready yet
        // By check if ex_raddr1 matches mem_rd and mem_reg_wen is enabled
        if (EX_RADDR1_I != 5'b0) begin
            if (EX_RADDR1_I == MEM_RD_I && MEM_REG_WEN_I) begin
                EX_FORWARD_A_SEL_O = 2'b01;
            end else if (EX_RADDR1_I == WB_RD_I && WB_REG_WEN_I) begin
                EX_FORWARD_A_SEL_O = 2'b10;
            end else begin
                EX_FORWARD_A_SEL_O = 2'b00;
            end
        end

        // Forwarding for ALU operand 2 (ex_rdata2) same as operand 1
        if (EX_RADDR2_I != 5'b0) begin
            if (EX_RADDR2_I == MEM_RD_I && MEM_REG_WEN_I) begin
                EX_FORWARD_B_SEL_O = 2'b01;
            end else if (EX_RADDR2_I == WB_RD_I && WB_REG_WEN_I) begin
                EX_FORWARD_B_SEL_O = 2'b10;
            end else begin
                EX_FORWARD_B_SEL_O = 2'b00;
            end

            // Forwarding for "Load after Store" or "Store after Use" hazards in EX stage
            // Senario: If the current instruction in the EX phase is a Store instruction (EX_MEM_RW_I == 1)
            //          and the preceding instruction in the MEM phase produces a register result (MEM_REG_WEN_I == 1)
            //          and the data register (rs2) that the Store is to write to memory is exactly the register (rd) 
            //          that the preceding instruction calculated to be written back
            if (EX_MEM_RW_I && MEM_REG_WEN_I && EX_RADDR2_I == MEM_RD_I) begin
                EX_WDATA_SEL_O = 2'b01;
            end else if (EX_MEM_RW_I && WB_REG_WEN_I && EX_RADDR2_I == WB_RD_I) begin
                EX_WDATA_SEL_O = 2'b10;
            end else begin
                EX_WDATA_SEL_O = 2'b00;
            end
        end

        // Forwarding for "Store after Load" hazard in MEM stage
        // Scenario: If the current instruction in the MEM phase is a Store instruction
        //           and the preceding instruction in the WB phase produces a register result (WB_REG_WEN_I == 1)
        //           and the data register (rs2) that the Store is to write to memory is exactly the register (rd) in written back
        if (MEM_RADDR2_I != 5'b0) begin
            if (WB_REG_WEN_I && MEM_RADDR2_I == WB_RD_I) begin
                MEM_FORWARD_WDATA_SEL_O = 1'b1;
            end else begin
                MEM_FORWARD_WDATA_SEL_O = 1'b0;
            end
        end

    end
endmodule
