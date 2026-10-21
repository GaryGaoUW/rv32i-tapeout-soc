`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/22 11:41:17
// Design Name: 
// Module Name: core_top
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


module core_top (
    input CLK,
    input RST_N,

    // Basic outputs for simulation
    output [31:0] PC_WIRE,
    output [31:0] INST_WIRE,
    output [31:0] ALU_RES,
    output [31:0] MEM_RDATA,
    output [31:0] WB_DATA,

    // Stage-level debug outputs for pipeline tracing
    output DBG_FLUSH,
    output DBG_STALL,

    output        DBG_IF_PC_SEL,
    output [31:0] DBG_IF_JUMP_ADDR,

    output [31:0] DBG_ID_PC,
    output [31:0] DBG_ID_INST,
    output [ 6:0] DBG_ID_OPCODE,
    output [ 4:0] DBG_ID_RD,
    output [ 2:0] DBG_ID_FUNCT3,
    output        DBG_ID_REG_WEN,
    output [31:0] DBG_ID_RDATA1,
    output [31:0] DBG_ID_RDATA2,
    output [31:0] DBG_ID_IMM,

    output [31:0] DBG_EX_PC,
    output [31:0] DBG_EX_ALU_RES,
    output [ 4:0] DBG_EX_RD,
    output        DBG_EX_REG_WEN,
    output [ 1:0] DBG_EX_WB_SEL,

    output [31:0] DBG_MEM_PC,
    output [31:0] DBG_MEM_ALU_RES,
    output [ 4:0] DBG_MEM_RD,
    output        DBG_MEM_REG_WEN,
    output [ 1:0] DBG_MEM_WB_SEL,
    output        DBG_MEM_RW,

    output [31:0] DBG_WB_PC,
    output [ 4:0] DBG_WB_RD,
    output        DBG_WB_REG_WEN,
    output [ 1:0] DBG_WB_WB_SEL
);

    wire        if_pc_sel;
    wire [31:0] if_jump_addr;
    wire        wb_reg_wen;
    wire [ 4:0] wb_rd;


    wire [31:0] if_pc;
    wire [31:0] if_inst;
    wire [31:0] id_pc;
    wire [31:0] id_inst;

    // forwarding signals
    wire        flush = if_pc_sel;  // flush the pipeline when there's a branch taken or jump
    wire        stall;

    if_stage u_if_stage (
        .CLK           (CLK),
        .RST_N         (RST_N),
        .IF_PC_SEL_I   (if_pc_sel),
        .IF_JUMP_ADDR_I(if_jump_addr),
        .IF_STALL_I    (stall),
        .IF_PC_O       (if_pc),
        .IF_INST_O     (if_inst)
    );
    pipe_if_id u_pipe_if_id (
        .CLK  (CLK),
        .RST_N(RST_N),
        .FLUSH(flush),
        .STALL(stall),

        .IF_PC_I  (if_pc),
        .IF_INST_I(if_inst),
        .ID_PC_O  (id_pc),
        .ID_INST_O(id_inst)
    );

    wire [ 6:0] id_opcode;
    wire [ 4:0] id_rd;
    wire [31:0] id_rdata1;
    wire [31:0] id_rdata2;
    wire [31:0] id_imm;
    wire        id_reg_wen;
    wire        id_a_sel;
    wire        id_b_sel;
    wire [ 3:0] id_alu_sel;
    wire        id_mem_rw;
    wire [ 1:0] id_wb_sel;
    wire        id_is_jump;
    wire        id_is_branch;
    wire [ 2:0] id_funct3;

    wire [31:0] ex_pc;
    wire [31:0] ex_rdata1;
    wire [31:0] ex_rdata2;
    wire [31:0] ex_imm;
    wire        ex_a_sel;
    wire        ex_b_sel;
    wire [ 3:0] ex_alu_sel;
    wire        ex_mem_rw;
    wire        ex_reg_wen;
    wire [ 4:0] ex_rd;
    wire [ 1:0] ex_wb_sel;
    wire        ex_is_jump;
    wire        ex_is_branch;
    wire [ 2:0] ex_funct3;

    wire [ 4:0] id_raddr1;
    wire [ 4:0] id_raddr2;
    wire [ 4:0] ex_raddr1;
    wire [ 4:0] ex_raddr2;

    id_stage u_id_stage (
        .CLK      (CLK),
        .RST_N    (RST_N),
        .ID_INST_I(id_inst),

        // From WriteBack Stage: 
        .WB_WEN_I  (wb_reg_wen),
        .WB_WADDR_I(wb_rd),
        .WB_WDATA_I(WB_DATA),

        // Outputs for internal wireing and forwarding in top
        .ID_OPCODE_O(id_opcode),
        .ID_RD_O    (id_rd),
        .ID_RDATA1_O(id_rdata1),
        .ID_RDATA2_O(id_rdata2),
        .ID_IMM_O   (id_imm),

        // To Control Logic and ID/EX Pipeline Register
        .ID_REG_WEN_O(id_reg_wen),
        .ID_A_SEL_O  (id_a_sel),
        .ID_B_SEL_O  (id_b_sel),
        .ID_ALU_SEL_O(id_alu_sel),
        .ID_MEM_RW_O (id_mem_rw),
        .ID_WB_SEL_O (id_wb_sel),

        // For Branch and Jump in AlU/ EX Stage
        .ID_IS_JUMP_O  (id_is_jump),
        .ID_IS_BRANCH_O(id_is_branch),
        .ID_FUNCT3_O   (id_funct3),

        // forwarding signals
        .ID_RADDR1_O(id_raddr1),
        .ID_RADDR2_O(id_raddr2)
    );

    pipe_id_ex u_pipe_id_ex (
        // Every pipeline register needs CLK, RST_N, FLUSH and STALL
        .CLK(CLK),
        .RST_N(RST_N),
        .FLUSH(flush || stall),   // Flush the pipeline when there's a branch taken or jump, also flush when stalling to avoid executing wrong instructions
        .STALL(1'b0),  // No stall for ID/EX, stalling happens in IF and EX stage

        // Information from ID stage for ALU to use in EX stage
        .ID_PC_I    (id_pc),
        .ID_RDATA1_I(id_rdata1),
        .ID_RDATA2_I(id_rdata2),
        .ID_IMM_I   (id_imm),

        .EX_PC_O    (ex_pc),
        .EX_RDATA1_O(ex_rdata1),
        .EX_RDATA2_O(ex_rdata2),
        .EX_IMM_O   (ex_imm),

        // Control signals from ID stage to EX stage
        .ID_A_SEL_I    (id_a_sel),
        .ID_B_SEL_I    (id_b_sel),
        .ID_ALU_SEL_I  (id_alu_sel),
        .ID_MEM_RW_I   (id_mem_rw),
        .ID_REG_WEN_I  (id_reg_wen),
        .ID_RD_I       (id_rd),
        .ID_WB_SEL_I   (id_wb_sel),
        .ID_IS_JUMP_I  (id_is_jump),
        .ID_IS_BRANCH_I(id_is_branch),
        .ID_FUNCT3_I   (id_funct3),

        .EX_A_SEL_O    (ex_a_sel),
        .EX_B_SEL_O    (ex_b_sel),
        .EX_ALU_SEL_O  (ex_alu_sel),
        .EX_MEM_RW_O   (ex_mem_rw),
        .EX_REG_WEN_O  (ex_reg_wen),
        .EX_RD_O       (ex_rd),
        .EX_WB_SEL_O   (ex_wb_sel),
        .EX_IS_JUMP_O  (ex_is_jump),
        .EX_IS_BRANCH_O(ex_is_branch),
        .EX_FUNCT3_O   (ex_funct3),

        // forwarding signals
        .ID_RADDR1_I(id_raddr1),
        .ID_RADDR2_I(id_raddr2),
        .EX_RADDR1_O(ex_raddr1),
        .EX_RADDR2_O(ex_raddr2)
    );



    wire [31:0] mem_pc;
    wire [31:0] mem_wdata;
    wire        mem_mem_rw;
    wire        mem_reg_wen;
    wire [ 4:0] mem_rd;
    wire [ 1:0] mem_wb_sel;
    wire [31:0] mem_alu_res;
    wire [ 2:0] mem_funct3;
    wire [31:0] ex_wdata;
    wire [31:0] ex_alu_res;
    wire [ 1:0] ex_forward_a_sel;
    wire [ 1:0] ex_forward_b_sel;
    wire [ 1:0] ex_forward_wdata_sel;

    // forwarding signals
    wire [ 4:0] mem_raddr2;
    wire        mem_forward_wdata_sel;


    ex_stage u_ex_stage (
        // Inputs from the ID/EX pipeline register
        .EX_PC_I    (ex_pc),      // pass to WB
        .EX_RDATA1_I(ex_rdata1),  // used for ALU op1 and branch comp
        .EX_RDATA2_I(ex_rdata2),  // used for ALU op2 and branch comp
        .EX_IMM_I   (ex_imm),     // used for ALU op2

        .EX_A_SEL_I    (ex_a_sel),      // used for ALU op1 selection
        .EX_B_SEL_I    (ex_b_sel),      // used for ALU op2 selection
        .EX_ALU_SEL_I  (ex_alu_sel),    // used for ALU operation selection
        .EX_IS_JUMP_I  (ex_is_jump),    // used to determine pc_sel in IF stage
        .EX_IS_BRANCH_I(ex_is_branch),  // used to determine pc_sel in IF stage
        .EX_FUNCT3_I   (ex_funct3),     // pass to M and used for branch comp

        // Outputs to MEM stage (New signals)
        .EX_ALU_RES_O(ex_alu_res),
        .EX_WDATA_O  (ex_wdata),

        // For Branch and Jump in IF stage
        .IF_PC_SEL_O   (if_pc_sel),
        .IF_JUMP_ADDR_O(if_jump_addr),

        // forwarding signals
        .EX_FORWARD_A_SEL_I    (ex_forward_a_sel),
        .EX_FORWARD_B_SEL_I    (ex_forward_b_sel),
        .MEM_ALU_RES_I         (mem_alu_res),
        .WB_DATA_I             (WB_DATA),
        .EX_FORWARD_WDATA_SEL_I(ex_forward_wdata_sel)
    );

    pipe_ex_mem u_pipe_ex_mem (
        .CLK  (CLK),
        .RST_N(RST_N),
        .FLUSH(1'b0),   // No flush for EX/MEM
        .STALL(1'b0),   // No stall for EX/MEM, stalling happens in IF and EX stage

        .EX_PC_I     (ex_pc),
        .EX_WDATA_I  (ex_wdata),
        .EX_MEM_RW_I (ex_mem_rw),
        .EX_REG_WEN_I(ex_reg_wen),
        .EX_RD_I     (ex_rd),
        .EX_WB_SEL_I (ex_wb_sel),
        .EX_ALU_RES_I(ex_alu_res),
        .EX_FUNCT3_I (ex_funct3),

        .MEM_PC_O     (mem_pc),
        .MEM_WDATA_O  (mem_wdata),
        .MEM_MEM_RW_O (mem_mem_rw),
        .MEM_REG_WEN_O(mem_reg_wen),
        .MEM_RD_O     (mem_rd),
        .MEM_WB_SEL_O (mem_wb_sel),
        .MEM_ALU_RES_O(mem_alu_res),
        .MEM_FUNCT3_O (mem_funct3),

        // forwarding signals
        .EX_RADDR2_I (ex_raddr2),
        .MEM_RADDR2_O(mem_raddr2)
    );


    wire [31:0] wb_pc;
    wire [31:0] wb_alu_res;
    wire [31:0] wb_rdata;
    wire [ 1:0] wb_wb_sel;
    wire [ 2:0] wb_funct3;

    mem_stage u_mem_stage (
        .CLK  (CLK),
        .RST_N(RST_N),

        .MEM_WDATA_I  (mem_wdata),
        .MEM_MEM_RW_I (mem_mem_rw),
        .MEM_ALU_RES_I(mem_alu_res),
        .MEM_FUNCT3_I (mem_funct3),

        // Raw BRAM read data (valid one cycle later, when the load is in WB)
        .MEM_RDATA_O(MEM_RDATA),

        // forwarding signals
        .WB_DATA_I              (WB_DATA),
        .MEM_FORWARD_WDATA_SEL_I(mem_forward_wdata_sel)
    );

    pipe_mem_wb u_pipe_mem_wb (
        .CLK  (CLK),
        .RST_N(RST_N),
        .FLUSH(1'b0),   // No flush for MEM/WB
        .STALL(1'b0),   // No stall for EX/MEM, stalling happens in IF and EX stage

        .MEM_PC_I     (mem_pc),
        .MEM_ALU_RES_I(mem_alu_res),
        .MEM_RDATA_I  (MEM_RDATA),
        .MEM_REG_WEN_I(mem_reg_wen),
        .MEM_RD_I     (mem_rd),
        .MEM_WB_SEL_I (mem_wb_sel),
        .MEM_FUNCT3_I (mem_funct3),

        .WB_PC_O     (wb_pc),
        .WB_ALU_RES_O(wb_alu_res),
        .WB_RDATA_O  (wb_rdata),
        .WB_REG_WEN_O(wb_reg_wen),
        .WB_RD_O     (wb_rd),
        .WB_WB_SEL_O (wb_wb_sel),
        .WB_FUNCT3_O (wb_funct3)
    );

    // Load data extraction (byte/half-word slice + sign/zero extension) is done
    // HERE in the WB stage, not in MEM: the BRAM read data arrives one cycle
    // after the address was presented, i.e. when the load itself is already in
    // WB. So it must be sliced with the load's own registered controls
    // (wb_funct3 / wb_alu_res), not with those of the instruction now in MEM.
    wire        wb_is_load = wb_reg_wen && (wb_wb_sel == 2'b00);
    wire [31:0] wb_rdata_filtered;

    mem_load_control u_mem_load_control (
        .ALU_RES       (wb_alu_res),
        .RDATA         (wb_rdata),
        .IS_LOAD       (wb_is_load),
        .FUNCT3        (wb_funct3),
        .RDATA_FILTERED(wb_rdata_filtered)
    );

    assign WB_DATA = (wb_wb_sel == 2'b00) ? wb_rdata_filtered : 
                     (wb_wb_sel == 2'b01) ? wb_alu_res   :
                     (wb_wb_sel == 2'b10) ? (wb_pc + 4) : wb_alu_res;

    forwarding_unit u_forwarding_unit (
        .EX_RADDR1_I  (ex_raddr1),   // ID/EX.rs1
        .EX_RADDR2_I  (ex_raddr2),   // ID/EX.rs2
        .MEM_RD_I     (mem_rd),      // EX/MEM.rd
        .MEM_REG_WEN_I(mem_reg_wen), // EX/MEM.reg_wen

        .WB_RD_I     (wb_rd),      // MEM/WB.rd
        .WB_REG_WEN_I(wb_reg_wen), // MEM/WB.reg_wen

        .EX_FORWARD_A_SEL_O(ex_forward_a_sel),
        .EX_FORWARD_B_SEL_O(ex_forward_b_sel),

        .EX_MEM_RW_I   (ex_mem_rw),
        .EX_WDATA_SEL_O(ex_forward_wdata_sel),

        .MEM_RADDR2_I           (mem_raddr2),
        .MEM_FORWARD_WDATA_SEL_O(mem_forward_wdata_sel)
    );

    hazard_detection_unit u_hazard_detection_unit (
        .EX_REG_WEN_I(ex_reg_wen),
        .EX_WB_SEL_I (ex_wb_sel),
        .EX_RD_I     (ex_rd),
        .ID_RADDR1_I (id_raddr1),
        .ID_RADDR2_I (id_raddr2),
        .ID_MEM_RW_I (id_mem_rw),

        .STALL_O(stall)
    );


    assign PC_WIRE = if_pc;
    assign INST_WIRE = if_inst;

    assign ALU_RES = ex_alu_res;

    assign DBG_FLUSH = flush;
    assign DBG_STALL = stall;
    assign DBG_IF_PC_SEL = if_pc_sel;
    assign DBG_IF_JUMP_ADDR = if_jump_addr;

    assign DBG_ID_PC = id_pc;
    assign DBG_ID_INST = id_inst;
    assign DBG_ID_OPCODE = id_opcode;
    assign DBG_ID_RD = id_rd;
    assign DBG_ID_FUNCT3 = id_funct3;
    assign DBG_ID_REG_WEN = id_reg_wen;
    assign DBG_ID_RDATA1 = id_rdata1;
    assign DBG_ID_RDATA2 = id_rdata2;
    assign DBG_ID_IMM = id_imm;

    assign DBG_EX_PC = ex_pc;
    assign DBG_EX_ALU_RES = ex_alu_res;
    assign DBG_EX_RD = ex_rd;
    assign DBG_EX_REG_WEN = ex_reg_wen;
    assign DBG_EX_WB_SEL = ex_wb_sel;

    assign DBG_MEM_PC = mem_pc;
    assign DBG_MEM_ALU_RES = mem_alu_res;
    assign DBG_MEM_RD = mem_rd;
    assign DBG_MEM_REG_WEN = mem_reg_wen;
    assign DBG_MEM_WB_SEL = mem_wb_sel;
    assign DBG_MEM_RW = mem_mem_rw;

    assign DBG_WB_PC = wb_pc;
    assign DBG_WB_RD = wb_rd;
    assign DBG_WB_REG_WEN = wb_reg_wen;
    assign DBG_WB_WB_SEL = wb_wb_sel;

endmodule
