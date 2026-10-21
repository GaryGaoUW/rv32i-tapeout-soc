`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/26 21:28:49
// Design Name: 
// Module Name: mem_load_control
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


module mem_load_control (
    input [31:0] ALU_RES,
    input [31:0] RDATA,
    input IS_LOAD,
    input [2:0] FUNCT3,
    output reg [31:0] RDATA_FILTERED
);

    reg  [31:0] shifted_data;
    wire [ 1:0] offset = ALU_RES[1:0];

    always @(*) begin
        shifted_data   = 32'b0;
        RDATA_FILTERED = 32'b0;

        if (IS_LOAD) begin
            shifted_data = RDATA >> {offset, 3'b000};

            case (FUNCT3)
                3'b000:  RDATA_FILTERED = {{24{shifted_data[7]}}, shifted_data[7:0]};  // lb
                3'b001:  RDATA_FILTERED = {{16{shifted_data[15]}}, shifted_data[15:0]};  // lh
                3'b010:  RDATA_FILTERED = RDATA;  // lw
                3'b100:  RDATA_FILTERED = {24'b0, shifted_data[7:0]};  // lbu
                3'b101:  RDATA_FILTERED = {16'b0, shifted_data[15:0]};  // lhu
                default: RDATA_FILTERED = 32'b0;
            endcase
        end
    end
endmodule
