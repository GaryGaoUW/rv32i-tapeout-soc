# 5-Stage Pipelined RISC-V SoC & Tapeout Roadmap (RV32I to Silicon)

> **Scope**: Full-stack computer architecture, digital frontend, and ASIC tapeout flow.

**Primary Goal**: Build an in-order 5-stage pipelined RV32I core from scratch with AXI4 bus, 2-way set-associative Cache, M-mode CSRs, and peripherals. Deploy FreeRTOS on a Xilinx Artix-7 50T FPGA, and achieve timing closure and clean DRC/LVS via OpenLane (SkyWater 130nm) for Tiny Tapeout.

---

## Table of Contents

- [Phase 0: Toolchain & Environment Setup](#phase-0-toolchain--environment-setup)
- [Phase 1: 5-Stage Pipeline & DiffTest (RV32I + Verilator + Spike)](#phase-1-5-stage-pipeline--difftest-rv32i--verilator--spike)
- [Phase 2: Bus Standard & Peripherals (AXI4-Lite + UART + MMIO)](#phase-2-bus-standard--peripherals-axi4-lite--uart--mmio)
- [Phase 3: Privileged Spec, CSRs & RTOS (M-Mode + FreeRTOS)](#phase-3-privileged-spec-csrs--rtos-m-mode--freertos)
- [Phase 4: Memory Hierarchy Optimization (2-Way Cache + AXI4 Burst)](#phase-4-memory-hierarchy-optimization-2-way-cache--axi4-burst)
- [Phase 5: FPGA Deployment & Physical Backend Closure (Artix-7 + Tiny Tapeout)](#phase-5-fpga-deployment--physical-backend-closure-artix-7--tiny-tapeout)
- [Appendix A: Milestone & Deliverable Checklist](#appendix-a-milestone--deliverable-checklist)
- [Appendix B: Repository Structure](#appendix-b-repository-structure)
- [Appendix C: Resume Bullet Points Template](#appendix-c-resume-bullet-points-template)

---

## Phase 0: Toolchain & Environment Setup

### 0.1 Tool Dependencies

| Category | Tool / Requirement |
| --- | --- |
| OS | Ubuntu 22.04 LTS (Native Linux / WSL2) or macOS (Apple Silicon) |
| RTL Simulator | `verilator` ($\ge$ v5.0) |
| Reference Model | `spike` (`riscv-isa-sim`) |
| Waveform Viewer | `surfer` or `gtkwave` |
| Cross-Compiler | `riscv-none-elf-gcc` (14.2.0, `-march=rv32i_zicsr -mabi=ilp32`) |
| Python Verif | `pytest`, `cocotb`, `cocotbext-axi` |
| FPGA Suite | Xilinx Vivado (2022.2+) |
| ASIC Flow | `Docker`, `OpenLane 2`, `magic`, `netgen`, `klayout` |

### 0.2 Local Environment (macOS / Apple Silicon)

| Tool | Path | Version |
| --- | --- | --- |
| Verilator | `/opt/homebrew/bin/verilator` | 5.050 |
| Spike | `/opt/homebrew/bin/spike` | 1.1.1-dev |
| Surfer | `/opt/homebrew/bin/surfer` | Latest |
| RISC-V GCC | `~/riscv-tools/xpack-riscv-none-elf-gcc-14.2.0-2/bin/` | 14.2.0 (`riscv-none-elf-`) |
| Python (venv) | `.venv/` (Python 3.13.5) | cocotb 2.0.1 / pytest 9.1.1 |

> **Note**: Vivado and OpenLane do not run natively on macOS; run Phase 5 synthesis and physical design on Linux or cloud VMs.

### 0.3 Daily Environment Activation

```bash
source .venv/bin/activate
verilator --version
spike --help | head -1
riscv-none-elf-gcc --version
```

---

## Phase 1: 5-Stage Pipeline & DiffTest (RV32I + Verilator + Spike)

### 1. Objectives
Eliminate long single-cycle combination paths by inserting pipeline registers across IF, ID, EX, MEM, and WB. Implement Hazard Detection, Forwarding, and co-simulation DiffTest against Spike.

### 2. Core Concepts
- **5-Stage Datapath**:
  - **IF**: PC update logic, instruction memory interface.
  - **ID**: Instruction decoder, 32x 32-bit register file (dual async read, single sync write, hardwired $x0 \equiv 0$).
  - **EX**: ALU (arithmetic, logic, shifts, comparisons), branch condition evaluation.
  - **MEM**: Byte/halfword/word load-store with sign/zero extension.
  - **WB**: Writeback multiplexer (ALU result, memory read data, PC+4).
- **Hazard Handling**:
  - **RAW Hazards**: Forwarding Unit (bypass from EX/MEM and MEM/WB to ALU inputs; prioritize EX/MEM).
  - **Load-Use Latency**: Hazard Detection Unit stalls IF/ID and PC for 1 cycle and injects a bubble into ID/EX.
  - **Control Hazards**: Flush IF/ID and ID/EX on taken branch in EX; redirect PC to target.
- **DiffTest Framework**:
  - Expose WB commit probes (`commit_valid`, `pc`, `rd`, `wb_data`).
  - Lock-step compare against golden model (Spike / C++ emulator).

### 3. Tech Stack
`SystemVerilog` | `Verilator` | `C++17` | `Spike` | `riscv-tests`

### 4. Acceptance Criteria
- Pass all 38+ `riscv-tests/isa/rv32ui-p-*` tests with 0 mismatches.
- DiffTest matches Spike register state on every retired instruction.

---

## Phase 2: Bus Standard & Peripherals (AXI4-Lite + UART + MMIO)

### 1. Objectives
Decouple the core from slow memories and peripherals using standard AXI4-Lite bus with MMIO Crossbar. Build bare-metal C runtime.

### 2. Core Concepts
- **Ready/Valid Handshake**:
  - Transfer occurs on `VALID & READY == 1` at clock rising edge.
  - VALID must not depend on READY; once asserted, VALID must remain stable until handshake.
- **AXI4-Lite Channels**:
  - Read: AR (Address Read), R (Data Read).
  - Write: AW (Address Write), W (Data Write + WSTRB), B (Response).
  - Master FSM: Convert core single-cycle memory requests into multi-cycle handshakes; stall core until completion.
- **Memory Map**:
  | Peripheral | Address Range | Size |
  | --- | --- | --- |
  | On-chip RAM | `0x8000_0000` - `0x8003_FFFF` | 256 KB |
  | UART | `0x1000_0000` - `0x1000_00FF` | — |
  | CLINT / Timer | `0x0200_0000` - `0x0200_FFFF` | — |
- **Bare-Metal Runtime**:
  - `crt0.S`: Initialize stack pointer (`sp = 0x8003FFF0`), clear `.bss`, jump to `main()`.
  - `linker.ld`: Map `.text`, `.rodata`, `.data`, `.bss`.
  - UART driver: Byte-level transmit via MMIO `*(volatile uint32_t*)(0x10000000)`.

### 3. Tech Stack
`AXI4-Lite` | `Cocotb` | `cocotbext-axi` | `riscv-none-elf-gcc`

### 4. Acceptance Criteria
- Pass 10,000 randomized backpressure transactions in Cocotb with zero deadlocks.
- Load C firmware in Verilator and print `[UART]: Hello World from RISC-V C Program!`.

---

## Phase 3: Privileged Spec, CSRs & RTOS (M-Mode + FreeRTOS)

### 1. Objectives
Support asynchronous interrupts and synchronous exceptions per RISC-V M-Mode spec. Add CLINT timer and port FreeRTOS preemptive multitasking.

### 2. Core Concepts
- **M-Mode CSRs**: `mstatus`, `mie`, `mip`, `mtvec`, `mepc`, `mcause`, `mtval`.
- **CSR Instructions**: `csrrw`, `csrrs`, `csrrc`, `csrrwi`, `csrrsi`, `csrrci` with pipeline flush.
- **Precise Trap Flow**:
  - Entry: Save PC $\rightarrow$ `mepc`, cause $\rightarrow$ `mcause`, `MPIE <= MIE`, `MIE <= 0`, jump to `mtvec`.
  - Return (`mret`): `MIE <= MPIE`, `MPIE <= 1`, PC $\leftarrow$ `mepc`.
- **CLINT**:
  - 64-bit `mtime` counter and `mtimecmp` comparator.
  - Trigger `mip.MTIP` when $mtime \ge mtimecmp$.
- **FreeRTOS Porting**:
  - Context save/restore of 32 registers in timer ISR (`portASM.S`).

### 3. Tech Stack
`RISC-V Privileged Spec v1.12` | `FreeRTOS Kernel` | `CLINT`

### 4. Acceptance Criteria
- Verify `ecall`, timer interrupt handling, and `mret` flow.
- Run two concurrent FreeRTOS tasks in simulation (Task A: periodic print; Task B: matrix computation) without context corruption.

---

## Phase 4: Memory Hierarchy Optimization (2-Way Cache + AXI4 Burst)

### 1. Objectives
Bridge the memory wall with 2-way set-associative I-Cache and D-Cache backed by full AXI4 INCR burst transfers.

### 2. Core Concepts
- **AXI4 Full Burst Protocol**:
  - `ARLEN`/`AWLEN`, `ARSIZE`/`AWSIZE`, `ARBURST` (INCR `2'b01`), `RLAST`/`WLAST`.
- **Cache Architecture (4 KB, 2-Way, 16-Byte Line)**:
  - Offset: 4 bits (`Addr[3:0]`).
  - Sets: $4\text{ KB} / (2 \times 16\text{ B}) = 128$ sets $\rightarrow$ Index: 7 bits (`Addr[10:4]`).
  - Tag: $32 - 7 - 4 = 21$ bits (`Addr[31:11]`).
  - Policy: Write-Back + Write-Allocate, 1-bit Pseudo-LRU replacement.
- **Cache Controller FSM**:
  - `IDLE` $\rightarrow$ `TAG_LOOKUP` $\rightarrow$ `EVICT_WRITEBACK` (if dirty) $\rightarrow$ `REFILL_READ` (4-beat burst) $\rightarrow$ `IDLE`.
- **Uncached MMIO Bypass**:
  - Route peripheral addresses (`0x1000_0000`) directly to bus as single transfers.

### 3. Tech Stack
`AXI4 Full` | `Cache Design` | `Cocotb` | `CoreMark Benchmark`

### 4. Acceptance Criteria
- 100,000 randomized read/write operations pass in Cocotb with strict data consistency.
- L1 cache hit rate $\ge 90\%$ on benchmark workloads.
- Measure significant CoreMark score and CPI improvement.

---

## Phase 5: FPGA Deployment & Physical Backend Closure (Artix-7 + Tiny Tapeout)

### 1. Objectives
Validate design on physical FPGA silicon and complete full RTL-to-GDSII flow via OpenLane (SkyWater 130nm / IHP SG13G2) for Tiny Tapeout.

### 2. Core Concepts
- **FPGA Implementation (Vivado)**:
  - Pin assignments and I/O standards in XDC.
  - Clocking Wizard PLL/MMCM generating 50 MHz core clock with timing constraints.
  - BRAM inference for on-chip memory.
- **Timing Closure**:
  - $\text{Setup Slack} = T_{\text{clk}} - (T_{\text{cq}} + T_{\text{comb}} + T_{\text{setup}} + T_{\text{skew}}) \ge 0$.
- **ASIC Backend (OpenLane 2)**:
  - Synthesis (Yosys) $\rightarrow$ Floorplanning $\rightarrow$ CTS $\rightarrow$ Routing $\rightarrow$ GDSII.
  - Signoff: DRC clean (Magic), LVS clean (Netgen).
- **Tiny Tapeout Interface**:
  - Standard wrapper: `ui_in[7:0]`, `uo_out[7:0]`, `uio_in[7:0]`, `uio_out[7:0]`, `uio_oe[7:0]`.

### 3. Tech Stack
`Vivado` | `OpenLane 2` | `SkyWater 130nm / IHP SG13G2` | `Magic / Netgen`

### 4. Acceptance Criteria
- FreeRTOS CLI responsive over UART at 115200 baud on Artix-7 50T hardware.
- OpenLane flow achieves timing closure at 50 MHz with 0 DRC and 0 LVS violations.

---

## Appendix A: Milestone & Deliverable Checklist

| Phase | Theme | Deliverables | Target | Duration |
| --- | --- | --- | --- | --- |
| **P1** | Pipeline & DiffTest | `rv32_core.sv`, `forwarding.sv`, `tb_top.cpp` | `riscv-tests` 100% pass, Spike diff clean | 2 - 3 wks |
| **P2** | AXI4-Lite & C Bare-metal | `axi_lite_master.sv`, `uart.sv`, `crt0.S`, `linker.ld` | UART prints "Hello World" in simulation | 2 - 3 wks |
| **P3** | CSRs & FreeRTOS | `csr_file.sv`, `clint.sv`, `portASM.S`, `FreeRTOSConfig.h` | Preemptive FreeRTOS multitasking stable | 3 wks |
| **P4** | AXI4 Burst & Cache | `icache.sv`, `dcache.sv`, `axi_burst_master.sv` | Hit rate $\ge 90\%$, CoreMark score improved | 3 - 4 wks |
| **P5** | FPGA & Tapeout Signoff | `top_artix7.xdc`, `config.json`, `project.gds` | Hardware UART active, DRC/LVS zero-defect | 3 - 4 wks |

---

## Appendix B: Repository Structure

```text
rv32i-tapeout-soc/
├── .github/workflows/regression.yml  # Automated CI regression
├── rtl/                              # SystemVerilog RTL modules
│   ├── core/                         # Pipeline datapath, hazard unit, CSRs
│   ├── mem/                          # On-chip instruction / data RAMs
│   ├── cache/                        # 2-Way I/D caches & RAMs
│   ├── bus/                          # AXI4 interconnect & bridges (axi_i_bus, axi_d_bus)
│   └── periph/                       # CLINT, UART
├── verif/
│   ├── lv0/                          # Verilator C++ testbench & Makefile
│   ├── isa/                          # rv32ui ISA suite (Makefile, link.ld, bin/)
│   ├── cocotb/                       # Python constrained-random tests
│   │   └── <module>/                 # One folder per DUT: tb wrapper + test_<module>.py
│   └── run_all.py                    # Regression runner
├── sw/
│   ├── boot/                         # crt0.S, linker.ld
│   ├── drivers/                      # UART, timer drivers
│   ├── benchmarks/                   # CoreMark, Dhrystone
│   └── os/                           # FreeRTOS port
├── fpga/                             # Board top (fpga_top.v), Vivado scripts, constraints (XDC)
└── openlane/                         # ASIC config.json & pin layout
```

---

## Appendix C: Resume Bullet Points Template

- Designed an in-order 5-stage pipelined RV32I processor in SystemVerilog, implementing the RISC-V M-mode privileged spec (CSRs), precise trap handling, and timer interrupts via a CLINT.
- Integrated a 4 KB 2-way set-associative L1 I/D cache (write-back, write-allocate) over an AXI4 burst interface, sustaining a >90% hit rate and measurable CPI improvement on CoreMark.
- Built an automated Verilator co-simulation (DiffTest) framework against the Spike golden model, achieving a 100% pass rate on the riscv-tests rv32ui ISA suite.
- Ported FreeRTOS to the custom core, validating preemptive multitasking, context switching, and MMIO UART CLI interaction on a Xilinx Artix-7 50T FPGA.
- Executed a full RTL-to-GDSII flow with OpenLane (SkyWater 130 nm PDK), reaching clean DRC/LVS sign-off and timing closure at 50 MHz for a Tiny Tapeout submission.
