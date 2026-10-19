#include "Vcore_top.h"        // Verilator generated header (V + top module)
#include "verilated.h"
#include "verilated_vcd_c.h"  // Waveform tracing support
#include <cstdio>
#include "Vcore_top___024root.h"  // Direct access to internal rom / ram / regs

#define MAX_CYCLES 10000

bool load_bin(Vcore_top* top, const char* filename){
    FILE* fp = fopen(filename, "rb");
    if(!fp){
        printf("Failed to open %s\n", filename);
        return false;
    }

    // Initialize ROM (fill NOP: 0x00000013) and RAM (fill 0)
    for (int i = 0; i < 1024; i++) {
        top->rootp->core_top__DOT__u_mem__DOT__rom[i]  = 0x00000013;
        top->rootp->core_top__DOT__u_dmem__DOT__ram[i] = 0x00000000;
    }

    // Load binary into ROM and RAM
    uint32_t word = 0;
    int idx = 0;
    while(fread(&word, sizeof(uint32_t), 1, fp) == 1 && idx < 1024){
        top->rootp->core_top__DOT__u_mem__DOT__rom[idx]  = word;
        top->rootp->core_top__DOT__u_dmem__DOT__ram[idx] = word;
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
    
    // 2. Instantiate Vcore_top
    auto p_top = std::make_unique<Vcore_top>();

    // 3. Setup waveform dump
    auto tfp = std::make_unique<VerilatedVcdC>();
    p_top->trace(tfp.get(), 99);  // Trace depth
    tfp->open("wave.vcd");
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

    uint32_t prev_pc = 0xFFFFFFFF;

    bool halted = false;
    for(int i=0; i<MAX_CYCLES; i++){
        p_top->clk = 0; p_top->eval(); 
        tfp->dump(sim_time++);

        bool is_halt = (prev_pc == p_top->pc_wire) || (p_top->inst_wire == 0x00000073);
        if(is_halt){
            printf(">>> Simulation finished at pc=%08x (cycle %d)\n", p_top->pc_wire, i);
            halted = true;
            break;
        }

        if(p_top->reg_wen && p_top->rd != 0){
            printf("cyc %3d | pc=%08x | inst=%08x | x%-2d <= %08x\n",
                i+1, 
                p_top->pc_wire, 
                p_top->inst_wire, 
                p_top->rd, 
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
    uint32_t a0 = p_top->rootp->core_top__DOT__u_id__DOT__u_regfile__DOT__regs[10];
    uint32_t gp = p_top->rootp->core_top__DOT__u_id__DOT__u_regfile__DOT__regs[3];
    int test_result = 0;
    if (!halted) {
        printf("\033[1;31m[TEST TIMEOUT]\033[0m Simulation exceeded MAX_CYCLES (%d)\n", MAX_CYCLES);
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
