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
    // Interface with IF
    input [31:0] if_pc_i,
    input if_fetch_en_i,
    input if_flush_i,

    // Interface with AXI4-Lite
    input aclk,
    input aresetn,

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

    // Interface with IF/ID (instruction register ready)
    output reg [31:0] instr_o,
    output reg instr_valid_o,
    output reg bus_stop_o
);

    // All states for FSM
    localparam s_idle = 2'b00;
    localparam s_wait_data = 2'b01;
    reg state;


    assign m_axi_arprot_o = 3'b100; // For sample I fetch, set protected to 1

    always @(posedge aclk) begin
        if(state == s_idle) begin
            if(if_fetch_en_i) begin
                state <= s_wait_data;
            end
        end else if(state == s_wait_data) begin
            if(m_axi_rvalid_i && m_axi_rready_o) begin
                state <= s_idle;
            end
        end
    end
endmodule
