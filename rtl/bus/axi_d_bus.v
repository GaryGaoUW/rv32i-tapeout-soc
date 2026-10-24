`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/23 19:59:00
// Design Name: 
// Module Name: axi_d_bus
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


module axi_d_bus (
    // Interface with AXI4-Lite
    input a_clk,
    input a_reset_n,

    // Interface with CPU. Aka Ex, addr or data coming in, maybe write data
    input [31:0] cpu_addr_i,
    input [31:0] cpu_wdata_i,
    input [3:0] cpu_write_en_i,
    input cpu_r_req_i,
    input cpu_w_req_i,

    // AR
    output [31:0] m_axi_araddr_o,
    output [2:0] m_axi_arprot_o,
    output m_axi_arvalid_o,
    input  m_axi_arready_i,

    // R
    input [31:0] m_axi_rdata_i,
    input [1:0] m_axi_rresp_i, // Ignore for now
    input m_axi_rvalid_i,
    output m_axi_rready_o,

    // AW
    output [31:0] m_axi_awaddr_o,
    output [2:0] m_axi_awprot_o,
    output m_axi_awvalid_o,
    input m_axi_awready_i,

    // W
    output [31:0] m_axi_wdata_o,
    output [3:0] m_axi_wstrb_o,
    output m_axi_wvalid_o,
    input m_axi_wready_i,

    // B
    input [1:0] m_axi_bresp_i, // Ignore for now
    input m_axi_bvalid_i,
    output m_axi_bready_o,


    // Interface with CPU. Aka WB, outputs read
    output reg [31:0] cpu_rdata_o,
    output reg cpu_read_valid_o,
    output reg cpu_write_valid_o,
    output cpu_bus_stop_o


);
    // All states for FSM
    localparam s_idle = 3'b000;
    localparam s_read_data = 3'b001;
    localparam s_write_waiting_aw = 3'b010;
    localparam s_write_waiting_w = 3'b011;
    localparam s_write_resp = 3'b100;
    reg [2:0] state;
    reg [2:0] next_state;


    // Practice 3-stages coding habit for FSM
    // Stage 1: Combinational logic to determine next state
    wire ar_done = m_axi_arvalid_o && m_axi_arready_i;
    wire r_done = m_axi_rvalid_i && m_axi_rready_o;
    wire aw_done = m_axi_awvalid_o && m_axi_awready_i;
    wire w_done  = m_axi_wvalid_o  && m_axi_wready_i;
    wire b_done  = m_axi_bvalid_i  && m_axi_bready_o;

    always @(*) begin
        // Good convention: proset default values
        next_state = state;
        case(state)
            s_idle: begin
                // Assume only one if read or write can request at once
                if(cpu_r_req_i && ar_done) begin            
                    next_state = s_read_data;
                end else if(cpu_w_req_i && aw_done && w_done) begin
                    next_state = s_write_resp;
                end else if(cpu_w_req_i && aw_done && !w_done) begin
                    next_state = s_write_waiting_w;
                end else if(cpu_w_req_i && !aw_done && w_done) begin
                    next_state = s_write_waiting_aw;
                end
            end
            s_read_data: begin
                if(r_done) begin
                    next_state = s_idle;
                end
            end
            s_write_waiting_aw: begin
                if(aw_done) begin
                    next_state = s_write_resp;
                end
            end
            s_write_waiting_w: begin
                if(w_done) begin
                    next_state = s_write_resp;
                end
            end
            s_write_resp: begin
                if(b_done) begin
                    next_state = s_idle;
                end
            end
            default: begin
                next_state = s_idle;
            end
        endcase
    end

    // Stage 2: Sequential logic to update state (Usually dont change)
    always @(posedge a_clk or negedge a_reset_n) begin
        if(!a_reset_n) begin
            state <= s_idle;
        end else begin
            state <= next_state;
            
        end
    end

    // Stage 3: Combinational logic to determine outputs
    // For read: 
    assign m_axi_araddr_o = cpu_addr_i;
    assign m_axi_arvalid_o = cpu_r_req_i && (state == s_idle);
    assign m_axi_arprot_o = 3'b000; // 3rd bit: 1(instr) 0(data)
    assign m_axi_rready_o = (state == s_read_data);

    // For write: 
    assign m_axi_awaddr_o = cpu_addr_i;
    assign m_axi_awvalid_o = ((state == s_idle) && cpu_w_req_i) || (state == s_write_waiting_aw); // 2 scenarios, w_req at beginning, or w channel finished, both cases we have to keep aw_vaild HIGH
    assign m_axi_awprot_o = 3'b000; // 3rd bit: 1(instr) 0(data)
    assign m_axi_wdata_o = cpu_wdata_i; // Or cpu_w_req_i ? cpu_wdata_i : 32'b0; But id wvalid = 0, the slave dont care wdata, so saving 32 2-to-1 MUXs
    assign m_axi_wstrb_o = cpu_write_en_i;
    assign m_axi_wvalid_o = ((state == s_idle) && cpu_w_req_i) || (state == s_write_waiting_w); // Same as above, 2 scenarios: one at start, one keep vaild HIGH waiting for another vaild!
    assign m_axi_bready_o = (state == s_write_resp);

    // For bus stall
    assign cpu_bus_stop_o = (cpu_r_req_i && !r_done) || (cpu_w_req_i && !b_done);

    always @(*) begin
        cpu_rdata_o = 32'h00000000;
        cpu_read_valid_o = 1'b0;
        cpu_write_valid_o = 1'b0;   

        if(r_done) begin
            cpu_rdata_o = m_axi_rdata_i;
            cpu_read_valid_o = 1'b1;
            cpu_write_valid_o = 1'b0;
        end

        if(b_done) begin
            cpu_rdata_o = 32'h00000000;
            cpu_read_valid_o = 1'b0;
            cpu_write_valid_o = 1'b1;
        end
    end

endmodule
