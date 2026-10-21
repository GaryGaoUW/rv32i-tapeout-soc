`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/03 12:57:40
// Design Name: 
// Module Name: hazard_detection_unit
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


module hazard_detection_unit (
    input EX_REG_WEN_I,
    input [1:0] EX_WB_SEL_I,
    input [4:0] EX_RD_I,
    input [4:0] ID_RADDR1_I,
    input [4:0] ID_RADDR2_I,
    input ID_MEM_RW_I,

    output STALL_O
);

    // Load-use hazard detection logic:
    // Stall when the instruction in EX is a load (reg_wen && wb_sel == 2'b00)
    // and the instruction in ID reads the load's destination register.
    //
    // Exception (store-after-load through rs2 only): if the ID instruction is a
    // store (ID_MEM_RW_I == 1) and the dependence is only through rs2 (the store
    // DATA, not the address in rs1), no stall is needed. The store data is
    // forwarded later in the MEM stage (mem_forward_wdata_sel in the forwarding
    // unit) when the store is in MEM and the load's data arrives in WB.
    assign STALL_O = (EX_REG_WEN_I == 1'b1) && 
                    ((EX_WB_SEL_I == 2'b00) && (EX_RD_I != 5'b0) && 
                    ((EX_RD_I == ID_RADDR1_I) || ((EX_RD_I == ID_RADDR2_I) && ~ID_MEM_RW_I)));
endmodule
