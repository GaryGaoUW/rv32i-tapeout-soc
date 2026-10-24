`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/22 19:45:02
// Design Name: 
// Module Name: axi_i_bus
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

module axi_i_bus (
    // Interface with CPU. Aka IF
    input [31:0] cpu_pc_i,
    input cpu_fetch_en_i,

    // Interface with AXI4-Lite
    input a_clk,
    input a_reset_n,

    // AXI4-Lite Adress Read Address Channel
    output [31:0] m_axi_araddr_o,
    output [2:0] m_axi_arprot_o,
    output m_axi_arvalid_o,
    input m_axi_arready_i,

    // AXI4-Lite Read Data Channel
    input [31:0] m_axi_rdata_i,
    input [1:0] m_axi_rresp_i, // Will ignore for now, as I am goint to implement Hardware Exception later
    input m_axi_rvalid_i,
    output m_axi_rready_o,

    // Interface with CPU. Aka ID (instruction register ready)
    output reg [31:0] cpu_instr_o,
    output reg cpu_instr_valid_o,
    output cpu_bus_stop_o
);

    // All states for FSM
    localparam s_idle = 2'b00;
    localparam s_wait_data = 2'b01;
    reg [1:0] state;
    reg [1:0] next_state;

    // Practice 3-stages coding habit for FSM
    // Stage 1: Combinational logic to determine next state
    wire r_done = m_axi_rvalid_i && m_axi_rready_o;
    wire ar_done = m_axi_arvalid_o && m_axi_arready_i;

    always @(*) begin
        // Good convention: proset default values
        next_state = state;
        case(state)
            s_idle: begin
                if(cpu_fetch_en_i && ar_done) begin            
                    next_state = s_wait_data;
                end 
            end
            s_wait_data: begin
                if(r_done) begin
                    next_state = s_idle;
                end
            end
            default: begin
                next_state = s_idle;
            end
        endcase
    end

    // Stage 2: Sequential logic to update state
    always @(posedge a_clk or negedge a_reset_n) begin
        if(!a_reset_n) begin
            state <= s_idle;
        end else begin
            state <= next_state;
            
        end
    end

    // Stage 3: Combinational logic to determine outputs
    assign m_axi_arvalid_o = (state == s_idle) && cpu_fetch_en_i;
    assign m_axi_araddr_o = cpu_pc_i;
    assign m_axi_arprot_o = 3'b100; // For sample I fetch, set protected to 1
    assign m_axi_rready_o = (state == s_wait_data);
    assign cpu_bus_stop_o = !r_done && cpu_fetch_en_i;

    always @(*) begin
        case(state) 
            s_idle: begin
                cpu_instr_o = 32'h00000013;
                cpu_instr_valid_o = 1'b0;
            end
            s_wait_data : begin
                if(r_done) begin
                    cpu_instr_o = m_axi_rdata_i;
                    cpu_instr_valid_o = 1'b1;
                end
                else begin
                    cpu_instr_o = 32'h00000013;
                    cpu_instr_valid_o = 1'b0;
                end
            end
            default: begin
                cpu_instr_o = 32'h00000013;
                cpu_instr_valid_o = 1'b0;
            end
        endcase
    end

endmodule