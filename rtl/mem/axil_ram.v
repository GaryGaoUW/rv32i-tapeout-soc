`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/24 16:38:00
// Design Name: 
// Module Name: axil_ram
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: AXI4-Lite slave RAM ("axil" = AXI4-Lite)
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module axil_ram #(
    parameter ADDR_W = 10,
    parameter DBG_DELAY = 0
) (
    // Interface with AXI4-Lite
    input a_clk,
    input a_reset_n,

    // AR
    input  [31:0] s_axil_araddr_i,
    input  [ 2:0] s_axil_arprot_i,   // Ignore for now
    input         s_axil_arvalid_i,
    output        s_axil_arready_o,

    // R
    output reg [31:0] s_axil_rdata_o,
    output     [ 1:0] s_axil_rresp_o,
    output            s_axil_rvalid_o,
    input             s_axil_rready_i,

    // AW
    input  [31:0] s_axil_awaddr_i,
    input  [ 2:0] s_axil_awprot_i,   // Ignore for now
    input         s_axil_awvalid_i,
    output        s_axil_awready_o,

    // W
    input  [31:0] s_axil_wdata_i,
    input  [ 3:0] s_axil_wstrb_i,
    input         s_axil_wvalid_i,
    output        s_axil_wready_o,

    // B
    output [1:0] s_axil_bresp_o,
    output       s_axil_bvalid_o,
    input        s_axil_bready_i
);
    // Debugging counter for delay
    integer _dbg_delay;

    // All states for FSM
    localparam s_idle = 2'b00;
    localparam s_write_resp = 2'b01;
    localparam s_read_resp = 2'b10;
    reg [1:0] state;
    reg [1:0] next_state;


    // Practice 3-stages coding habit for FSM
    // Stage 1: Combinational logic to determine next state
    wire ar_done = s_axil_arvalid_i && s_axil_arready_o;
    wire r_done = s_axil_rvalid_o && s_axil_rready_i;
    wire aw_done = s_axil_awvalid_i && s_axil_awready_o;
    wire w_done = s_axil_wvalid_i && s_axil_wready_o;
    wire b_done = s_axil_bvalid_o && s_axil_bready_i;

    always @(*) begin
        // Good convention: proset default values
        next_state = state;
        case (state)
            s_idle: begin
                // Write has priority over read
                if (aw_done && w_done) begin
                    next_state = s_write_resp;
                end else if (ar_done) begin
                    next_state = s_read_resp;
                end
            end
            s_read_resp: begin
                if (r_done) begin
                    next_state = s_idle;
                end
            end
            s_write_resp: begin
                if (b_done) begin
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
        if (!a_reset_n) begin
            state <= s_idle;
        end else begin
            state <= next_state;
        end
    end

    // Stage 3: Combinational logic to determine outputs
    // TODO: arready / awready / wready / rvalid / bvalid / rresp / bresp
    assign s_axil_awready_o = (state == s_idle) && s_axil_awvalid_i && s_axil_wvalid_i;
    assign s_axil_wready_o = (state == s_idle) && s_axil_wvalid_i && s_axil_awvalid_i;
    // We assume write has higher priority
    assign s_axil_arready_o = (state == s_idle) && s_axil_arvalid_i && !(s_axil_wvalid_i || s_axil_awvalid_i);
    assign s_axil_rvalid_o = (state == s_read_resp) && (_dbg_delay == 0);
    assign s_axil_bvalid_o = (state == s_write_resp);

    assign s_axil_rresp_o = 2'b00;  // Assume read and write allways succeed for BRAM! 
    // TO DO: When switching to SDRAM, the response values have to change to their actual meanings
    assign s_axil_bresp_o = 2'b00;

    // Allocate 2^10 words (4KB) of BRAM space
    reg [31:0] mem[0:(1<<ADDR_W)-1];


    // Chop the last two bits off, since all addresses in RISC-V are word-aligned
    wire [ADDR_W-1:0] aw_addr_word = s_axil_awaddr_i[ADDR_W+1:2];
    wire [ADDR_W-1:0] ar_addr_word = s_axil_araddr_i[ADDR_W+1:2];
    always @(posedge a_clk) begin
        if (aw_done && w_done) begin
            if (s_axil_wstrb_i[0]) mem[aw_addr_word][7:0] <= s_axil_wdata_i[7:0];
            if (s_axil_wstrb_i[1]) mem[aw_addr_word][15:8] <= s_axil_wdata_i[15:8];
            if (s_axil_wstrb_i[2]) mem[aw_addr_word][23:16] <= s_axil_wdata_i[23:16];
            if (s_axil_wstrb_i[3]) mem[aw_addr_word][31:24] <= s_axil_wdata_i[31:24];
        end else if (ar_done) begin
            s_axil_rdata_o <= mem[ar_addr_word];
        end
    end

    // For debugging!
    // Simulate when read resp take more then 1 cycle
    always @(posedge a_clk or negedge a_reset_n) begin
        if (!a_reset_n) begin
            _dbg_delay <= 0;
        end else if (ar_done) begin
            _dbg_delay <= DBG_DELAY;
        end else begin
            if (_dbg_delay > 0) begin
                _dbg_delay <= _dbg_delay - 1'b1;
            end
        end
    end

endmodule
