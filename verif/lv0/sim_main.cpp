#include "Vcore_top.h"        // Verilator 生成的头文件,类名 = V + 顶层模块名
#include "verilated.h"
#include "verilated_vcd_c.h"  // 波形 dump 支持
#include <cstdio>

#define MAX_CYCLES 200

int main(int argc, char** argv) {
    // 1. 初始化 Verilator 上下文
    
    // 2. new 一个 Vcore_top 实例(用 unique_ptr)
    auto p_top = std::make_unique<Vcore_top>();

    // 3. 打开波形 dump(trace)
    // 4. 复位:rst_n = 0 拉几个周期,再 = 1 放开
    for(int i = 0; i<10; i++){
        p_top->rst_n = 0;
        p_top->clk = 0; p_top->eval(); 
        p_top->clk = 1; p_top->eval(); 
    }
    p_top->rst_n = 1;

    uint32_t prev_pc = 0xFFFFFFFF;

    for(int i=0; i<MAX_CYCLES; i++){
        p_top->clk = 0; p_top->eval(); 
        p_top->clk = 1; p_top->eval(); 

        if(prev_pc == p_top->pc_wire){
            printf(">>> HALT detected at pc=%08x (cycle %d)\n", p_top->pc_wire, i);
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
    }
        
    
    // 6. 关闭 trace、清理

    return 0;
}
