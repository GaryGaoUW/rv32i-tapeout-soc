`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/11/7 15:09:00
// Design Name: 
// Module Name: axil_uart
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: AXI4-Lite slave UART ("axil" = AXI4-Lite)
//              Registers table:  0x00: tx_data  R
//                                0x04: rx_data  R
//                                0x08: stat     R
//                                0x0C: ctrl     W
//                                0x10: div      W
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module axil_uart #(
    parameter TX_DEPTH = 16,
    parameter RX_DEPTH = 8,
    parameter DEFAULT_DIV = 217
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
    input        s_axil_bready_i,

    // Uart serial ports
    output uart_tx_o,
    input  uart_rx_i,
    output irq_o

);
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
        // Good convention: preset default values
        next_state = state;
        case (state)
            s_idle: begin
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

    // Read priority over write, to prevent miss read data (FIFO is full)
    assign s_axil_awready_o = (state == s_idle) && s_axil_awvalid_i && s_axil_wvalid_i && !s_axil_arready_o;
    assign s_axil_wready_o = (state == s_idle) && s_axil_wvalid_i && s_axil_awvalid_i && !s_axil_arready_o;

    assign s_axil_bvalid_o = (state == s_write_resp);
    assign s_axil_arready_o = (state == s_idle) && s_axil_arvalid_i;
    assign s_axil_rvalid_o = (state == s_read_resp);

    assign s_axil_rresp_o = 2'b00;
    assign s_axil_bresp_o = 2'b00;

    wire [7:0] wr_offset = {
        s_axil_awaddr_i[7:2], 2'b00  // word aligned, last 2 bits handled by wstrb
    };
    wire [7:0] rd_offset = {
        s_axil_araddr_i[7:2], 2'b00  // word aligned, last 2 bits handled by wstrb
    };
    wire wr_fire = aw_done && w_done;

    // Registers
    reg [7:0] tx_data;
    wire [7:0] rx_data;
    wire [9:0] stat;
    reg [7:0] ctrl;
    reg [15:0] div;

    // Debug
    assign rx_data = 8'h0;

    always @(posedge a_clk or negedge a_reset_n) begin
        if (!a_reset_n) begin
            tx_data <= 8'h00;
            ctrl <= 8'h00;
            div <= DEFAULT_DIV[15:0];
        end else if (wr_fire) begin
            case (wr_offset)
                // Separate the sb over here instead in the else if
                8'h04: begin
                    if (s_axil_wstrb_i[0]) tx_data <= s_axil_wdata_i[7:0];
                end
                8'h0C: begin
                    if (s_axil_wstrb_i[0]) ctrl <= s_axil_wdata_i[7:0];
                end
                8'h10: begin
                    // the div write is depends on wstrb, user might use sb instead of sw if the num is small
                    if (s_axil_wstrb_i[0]) div[7:0] <= s_axil_wdata_i[7:0];
                    if (s_axil_wstrb_i[1]) div[15:8] <= s_axil_wdata_i[15:8];
                end
                default: ;
            endcase
        end
    end

    reg [31:0] rd_mux;

    always @(*) begin
        rd_mux = 32'h0;
        case (rd_offset)
            8'h00:   rd_mux = {24'h0, rx_data};
            8'h08:   rd_mux = {22'h0, stat};
            8'h10:   rd_mux = {16'h0, div};
            default: rd_mux = 32'h0;
        endcase
    end

    always @(posedge a_clk) begin
        if (ar_done) s_axil_rdata_o <= rd_mux;
    end

    assign stat[0] = 1'b0;  // TO DO
    assign stat[1] = 1'b0;
    assign stat[2] = 1'b1;
    assign stat[3] = 1'b0;
    assign stat[4] = ctrl[4];  // Interrupt enable
    assign stat[5] = 1'b0;
    assign stat[6] = 1'b0;
    assign stat[7] = 1'b0;
    assign stat[8] = 1'b0;
    assign stat[9] = 1'b0;


endmodule
