#include "Vsoc_top.h"        // Verilator generated header (V + top module)
#include "verilated.h"
#include "verilated_vcd_c.h"  // Waveform tracing support
#include <cstdio>
#include <string>
#include "Vsoc_top___024root.h"  // Direct access to internal rom / ram / regs

#define MAX_CYCLES 10000

bool load_bin(Vsoc_top* top, const char* filename){
    FILE* fp = fopen(filename, "rb");
    if(!fp){
        printf("Failed to open %s\n", filename);
        return false;
    }

    // Initialize ROM (fill NOP: 0x00000013) and RAM (fill 0)
    for (int i = 0; i < 1024; i++) {
        top->rootp->soc_top__DOT__u_iram__DOT__mem[i]  = 0x00000013;
        top->rootp->soc_top__DOT__u_dram__DOT__mem[i] = 0x00000000;
    }

    // Load binary into ROM and RAM
    uint32_t word = 0;
    int idx = 0;
    while(fread(&word, sizeof(uint32_t), 1, fp) == 1 && idx < 1024){
        top->rootp->soc_top__DOT__u_iram__DOT__mem[idx]  = word;
        top->rootp->soc_top__DOT__u_dram__DOT__mem[idx] = word;
        idx++;
    }

    fclose(fp);
    printf(">>> Loaded %d words (%d bytes) from %s\n", idx, idx * 4, filename);
    return true;
}

int main(int argc, char** argv) {
    // 1. Initialize Verilator context
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);  // Enable wave tracing
    
    // 2. Instantiate Vsoc_top
    auto p_top = std::make_unique<Vsoc_top>();

    // 3. Setup waveform dump
    auto tfp = std::make_unique<VerilatedVcdC>();
    p_top->trace(tfp.get(), 99);  // Trace depth
    // Write the waveform next to this testbench (verif/lv0/wave.vcd), no matter
    // which directory the binary is launched from. argv[0] = ".../obj_dir/Vsoc_top"
    std::string exe_path = argv[0];
    std::string obj_dir  = exe_path.substr(0, exe_path.find_last_of('/'));
    tfp->open((obj_dir + "/../wave.vcd").c_str());
    uint64_t sim_time = 0;

    // 4. Reset: hold rst_n = 0 for 10 cycles, then release
    for(int i = 0; i<10; i++){
        p_top->rst_n = 0;
        p_top->clk = 0; p_top->eval(); 
        tfp->dump(sim_time++);
        p_top->clk = 1; p_top->eval(); 
        tfp->dump(sim_time++);
    }
    p_top->rst_n = 1;

    if (argc > 1) {
        if (!load_bin(p_top.get(), argv[1])) {
            return 1;
        }
        // Pulse reset for 1 cycle so PC=0 samples freshly loaded rom[0]
        p_top->rst_n = 0;
        p_top->clk = 0; p_top->eval();
        p_top->clk = 1; p_top->eval();
        p_top->rst_n = 1;
    }

    // Poison a0 (x10). The regfile resets to 0, and a0 == 0 means PASS, so a
    // simulation that stops before the test writes a0 would look like a PASS.
    // With a non-zero start value, only a real "li a0, 0" can produce a PASS.
    p_top->rootp->soc_top__DOT__u_core__DOT__u_id_stage__DOT__u_regfile__DOT__regs[10] = 0xDEADBEEF;

    // Hang watchdog: the PC may legally stay unchanged for several cycles while
    // a bus is busy (fetch alone is >= 2 cycles, more with DBG_DELAY). Only a
    // much longer freeze means the pipeline is stuck.
    const int HANG_CYCLES = 1000;

    uint32_t prev_pc = 0xFFFFFFFF;
    int same_pc_count = 0;
    int drain_cycles = -1;
    bool halted = false;
    bool hung = false;

    // Scoreboard: each load/store instruction must cause exactly ONE D-bus
    // transaction. Compare what the bus did with what the pipeline executed.
    auto* r = p_top->rootp;
    int dbus_reads = 0, dbus_writes = 0;   // D-RAM handshakes: R done / B done
    int mem_loads  = 0, mem_stores  = 0;   // load/store leaving MEM (pipeline advances)

    for(int i=0; i<MAX_CYCLES; i++){
        p_top->clk = 0; p_top->eval(); 
        tfp->dump(sim_time++);

        // Scoreboard sampling (combinational values of this cycle)
        dbus_reads  += r->soc_top__DOT__u_dram__DOT__r_done;
        dbus_writes += r->soc_top__DOT__u_dram__DOT__b_done;
        if (!r->soc_top__DOT__bus_stall) {   // the instruction in MEM moves on this edge
            if (r->soc_top__DOT__u_core__DOT__mem_mem_rw) mem_stores++;
            if (r->soc_top__DOT__u_core__DOT__mem_reg_wen &&
                r->soc_top__DOT__u_core__DOT__mem_wb_sel == 0) mem_loads++;
        }

        // Normal end of test: ecall (0x00000073) is fetched.
        bool is_ecall = (p_top->inst_wire == 0x00000073);

        // Abnormal end: PC frozen for HANG_CYCLES -> the pipeline is stuck.
        if (p_top->pc_wire == prev_pc) {
            same_pc_count++;
        } else {
            same_pc_count = 0;
        }
        if (same_pc_count >= HANG_CYCLES) {
            printf(">>> PC stuck at %08x for %d cycles (cycle %d)\n", p_top->pc_wire, HANG_CYCLES, i);
            hung = true;
            break;
        }

        if (drain_cycles < 0 && is_ecall) {
            // Let the instructions ahead of ecall (e.g. "li a0, 0") reach WB.
            // Each pipeline step takes >= 2 cycles over AXI-Lite and more with
            // DBG_DELAY, so leave plenty of headroom.
            drain_cycles = 100;
        }

        if (drain_cycles > 0) {
            drain_cycles--;
            if (drain_cycles == 0) {
                printf(">>> Simulation finished at pc=%08x (cycle %d)\n", p_top->pc_wire, i);
                halted = true;
                break;
            }
        }

        if(p_top->dbg_wb_reg_wen && p_top->dbg_wb_rd != 0){
            printf("cyc %3d | wb_pc=%08x | inst=%08x | x%-2d <= %08x\n",
                i+1, 
                p_top->dbg_wb_pc, 
                p_top->inst_wire, 
                p_top->dbg_wb_rd, 
                p_top->wb_data
            );
        }
        else{
            printf("cyc %3d | pc=%08x | inst=%08x | (no regfile write)\n",
                i+1, 
                p_top->pc_wire, 
                p_top->inst_wire
            );
        }

        prev_pc = p_top->pc_wire;
        p_top->clk = 1; p_top->eval(); 
        tfp->dump(sim_time++);
    }

    // Check x10 (a0) and x3 (gp) for test result
    uint32_t a0 = p_top->rootp->soc_top__DOT__u_core__DOT__u_id_stage__DOT__u_regfile__DOT__regs[10];
    uint32_t gp = p_top->rootp->soc_top__DOT__u_core__DOT__u_id_stage__DOT__u_regfile__DOT__regs[3];
    // One line, parsed by verif/run_all.py
    printf(">>> DBUS reads=%d writes=%d | MEM loads=%d stores=%d\n",
           dbus_reads, dbus_writes, mem_loads, mem_stores);

    int test_result = 0;
    if (hung) {
        printf("\033[1;31m[TEST HANG]\033[0m Pipeline stuck (no PC change for %d cycles)\n", HANG_CYCLES);
        test_result = 1;
    } else if (!halted) {
        printf("\033[1;31m[TEST TIMEOUT]\033[0m Simulation exceeded MAX_CYCLES (%d)\n", MAX_CYCLES);
        test_result = 1;
    } else if (a0 == 0xDEADBEEF) {
        printf("\033[1;31m[TEST FAILED]\033[0m Ended before the test wrote a0 (a0 still 0xDEADBEEF)\n");
        test_result = 1;
    } else if (a0 == 0) {
        printf("\033[1;32m[TEST PASSED]\033[0m All tests passed successfully!\n");
        test_result = 0;
    } else {
        printf("\033[1;31m[TEST FAILED]\033[0m Failed at test case #%d (a0=%d, gp=%d)\n", gp, a0, gp);
        test_result = 1;
    }
    tfp->close();
    return test_result;
}
