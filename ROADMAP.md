# 5 级流水线 RISC-V SoC、组相联 Cache 与流片工程路线图 (RV32I to Silicon)

> **项目定位**：面向计算机体系结构与数字前端/ASIC 设计的全栈工程落地项目。

**核心目标**：从零手写 5 级流水线 RV32I 核心，集成 AXI4 总线、2-Way 组相联 Cache、M-Mode 特权级 CSR 与外设，在 Xilinx Artix-7 50T FPGA 上跑通 FreeRTOS 抢占式多任务操作系统，并通过 OpenLane (SkyWater 130nm) 流程完成 ASIC 后端时序收敛、DRC/LVS 验证与 Tiny Tapeout 提交。

---

## 目录

- [0. 工具链与基础环境配置 (Phase 0)](#0-工具链与基础环境配置-phase-0)
- [Phase 1: 5 级流水线与差分验证 (RV32I + Verilator + Spike)](#phase-1-5-级流水线与差分验证-rv32i--verilator--spike)
- [Phase 2: 总线规范化与外设互连 (AXI4-Lite + UART + MMIO)](#phase-2-总线规范化与外设互连-axi4-lite--uart--mmio)
- [Phase 3: 特权级架构、CSR 与实时操作系统 (M-Mode + FreeRTOS)](#phase-3-特权级架构csr-与实时操作系统-m-mode--freertos)
- [Phase 4: 存储层次优化 (2-Way 组相联 Cache + AXI4 Burst)](#phase-4-存储层次优化-2-way-组相联-cache--axi4-burst)
- [Phase 5: FPGA 板级部署与物理后端收敛 (Artix-7 50T + Tiny Tapeout)](#phase-5-fpga-板级部署与物理后端收敛-artix-7-50t--tiny-tapeout)
- [附录 A: 总体时间与交付物检查清单](#附录-a-总体时间与交付物检查清单)
- [附录 B: 推荐仓库目录结构规范](#附录-b-推荐仓库目录结构规范)
- [附录 C: 简历项目量化描述模板](#附录-c-简历项目量化描述模板)

---

## 0. 工具链与基础环境配置 (Phase 0)

### 0.1 环境依赖清单

| 类别 | 工具 / 要求 |
| --- | --- |
| 操作系统 | Ubuntu 22.04 LTS (推荐原生 Linux 或 Windows WSL2) |
| RTL 仿真器 | `verilator`（周期精确的 SystemVerilog-to-C++ 编译型仿真器，$\ge$ v4.200，推荐 v5.x） |
| 参考模型 (Golden Model) | `spike`（`riscv-isa-sim`，RISC-V 官方 ISA 模拟器；本机经 `brew install riscv-software-src/riscv/riscv-isa-sim` 安装） |
| 波形查看器 | `surfer`（已安装）或 `gtkwave` |
| 交叉编译工具链 | xPack `riscv-none-elf-gcc`（本机 14.2.0，前缀为 `riscv-none-elf-`；支持 `-march=rv32i_zicsr -mabi=ilp32`。功能等价于 `riscv64-unknown-elf-gcc`，仅命名前缀不同） |
| Python 验证库 | `pytest`, `cocotb`, `cocotbext-axi` |
| FPGA 开发套件 | Xilinx Vivado（2022.2 或更新版本，Standard/WebPACK 免费授权即可覆盖 Artix-7 50T） |
| ASIC 后端套件 | `Docker`, `OpenLane 2`, `magic`, `netgen`, `klayout` |

> **原路线图基于 Ubuntu 22.04；本机为 macOS (Apple Silicon)，工具经 Homebrew 与 xPack 安装，具体路径见下方「本机环境」。macOS 上无法安装 Xilinx Vivado 与 OpenLane，Phase 5 的 FPGA 综合与 ASIC 后端需在 Linux 主机/虚拟机/WSL2 或云端完成。**

### 0.2 本机环境（macOS / Apple Silicon）

已安装并验证的工具链：

| 工具 | 路径 | 版本 |
| --- | --- | --- |
| Verilator | `/opt/homebrew/bin/verilator` | 5.050 |
| Spike | `/opt/homebrew/bin/spike` | 1.1.1-dev |
| Surfer | `/opt/homebrew/bin/surfer` | — |
| RISC-V GCC | `~/riscv-tools/xpack-riscv-none-elf-gcc-14.2.0-2/bin/` | 14.2.0（前缀 `riscv-none-elf-`） |
| Python venv (cocotb) | `.venv/`（项目根目录，Python 3.13.5） | cocotb 2.0.1 / pytest 9.1.1 |

> **注意**：cocotb 2.0.1 最高仅支持 Python 3.13，本机默认 `python3` 为 3.14，故 `.venv` 使用 `python3.13` 创建。

### 0.3 每次开发前的环境激活

新开终端后，在项目根目录执行：

```bash
# 激活 cocotb Python 虚拟环境
source .venv/bin/activate

# 自检：确认工具链均可用
verilator --version          # 期望 5.050
spike --help | head -1        # 期望 Spike RISC-V ISA Simulator
riscv-none-elf-gcc --version  # 期望 14.2.0（若提示 command not found，见下）
```

RISC-V GCC 的 PATH 已写入 `~/.zshrc`，**新开的终端会自动生效**。若在改动 `~/.zshrc` 之前就已打开的旧终端中报 `command not found`，执行一次 `source ~/.zshrc` 重新加载即可。

---

## Phase 1: 5 级流水线与差分验证 (RV32I + Verilator + Spike)

### 1. 阶段概述与解决的问题

构建处理器核心的执行底座。单周期 CPU 的时钟周期受限于最长组合逻辑通路延迟；本阶段通过在 5 个流水级（取指 IF、译码 ID、执行 EX、访存 MEM、写回 WB）之间插入流水线寄存器，切断过长的组合逻辑路径，从而缩短关键路径、提升工作主频。同时建立基于 Verilator（C++）与 Spike 的逐指令差分测试（DiffTest）机制，在开发早期即持续验证微架构的指令执行正确性，将功能缺陷尽早暴露。

### 2. 核心掌握知识点

**经典 5 级数据通路（Datapath）微架构：**

- **IF 阶段**：程序计数器（PC）更新逻辑（顺序 $+4$ 或分支跳转目标地址计算）、指令存储器接口。
- **ID 阶段**：指令译码器（提取 opcode, rd, funct3, rs1, rs2, funct7, 立即数生成扩展器）、32 个 32-bit 通用寄存器堆（Regfile，支持双异步读、单同步写，处理 $x0 \equiv 0$ 的硬编码逻辑）。
- **EX 阶段**：ALU 算术逻辑运算（ADD, SUB, SLT, SLTU, AND, OR, XOR, SLL, SRL, SRA）、分支跳转条件计算（BEQ, BNE, BLT, BGE, BLTU, BGEU）。
- **MEM 阶段**：数据存储器读写控制（支持按 Byte, Half-word, Word 进行符号/无符号扩展）。
- **WB 阶段**：写回多路选择器（选择 ALU 运算结果、内存读出数据或 PC+4 返回地址写回目标寄存器 rd）。

**流水线冒险（Hazards）与控制单元设计：**

- **数据冒险（RAW: Read-After-Write）**
  - **前递单元（Forwarding Unit）**：检查 EX/MEM 和 MEM/WB 阶段的目标寄存器 rd 是否与当前 ID/EX 阶段的 rs1/rs2 一致且具有写使能（`RegWrite == 1`），直接将最新运算结果旁路到 ALU 输入端口。必须优先采用 EX/MEM 阶段的数据以保证数据时效性。
- **Load-Use 结构延迟**
  - **暂停单元（Hazard Detection Unit）**：当 ID/EX 阶段为 `lw` 指令且其目标寄存器与 IF/ID 阶段的源寄存器重合时，强制冻结 PC 与 IF/ID 寄存器 1 拍，并向 ID/EX 注入气泡（Bubble/NOP）。
- **控制冒险（Control Hazard）**
  - 分支指令在 EX 阶段判定跳转时，冲刷（Flush）IF/ID 与 ID/EX 流水线寄存器，并将 PC 更新为跳转地址。

**差分测试（Co-simulation / DiffTest）原理：**

- 在 RTL 核心写回阶段（WB 阶段）暴露 Commit 探针信号（PC、rd_idx、rd_data、reg_write_en）。
- Verilator C++ 测试平台每检测到一次 Commit，驱动 Spike 步进一条指令，逐字段比对 32 个通用寄存器状态。

### 3. 技术栈

`SystemVerilog` | `Verilator` | `C++17` | `Spike` | `GTKWave` | `riscv-tests`

### 4. 验证指标与建议耗时

**预估耗时**：2 - 3 周

**可实现性验收标准：**

- 自动化测试脚本编译 Verilated C++ 模型。
- 跑通官方 `riscv-tests/isa/rv32ui-p-*` 全部基础指令测试用例（约 40 项，如 `rv32ui-p-add`、`rv32ui-p-bne`、`rv32ui-p-lw` 等；具体数量随 riscv-tests 版本略有出入）。
- 差分测试框架实时比对 Spike 内部状态，全程无 Mismatch，测试进程正常退出（退出码 0）。

---

## Phase 2: 总线规范化与外设互连 (AXI4-Lite + UART + MMIO)

### 1. 阶段概述与解决的问题

隔离处理器核心与外部慢速外设/存储器的直接耦合。引入行业标准 AXI4-Lite 总线协议，构建支持内存映射 I/O（MMIO）的总线互连开关（Crossbar），并建立裸机 C 语言编译环境与底层驱动，使 CPU 能够通过 C 代码与外部物理设备通信。

### 2. 核心掌握知识点

**Ready/Valid 握手协议基本法则：**

- 发送方置 `VALID = 1` 表示数据有效；接收方置 `READY = 1` 表示允许接收。
- 传输仅在 `VALID & READY == 1` 的时钟上升沿完成。
- **协议硬约束**：VALID 不得依赖 READY 的状态；VALID 一旦置 1，在握手成功前不得撤销；READY 允许在 VALID 之前或之后拉高。

**AXI4-Lite 协议通道微架构：**

- **读事务（Read Transaction）**：AR (Address Read) 通道与 R (Data Read) 通道。
- **写事务（Write Transaction）**：AW (Address Write) 通道、W (Data Write with Strobe WSTRB) 通道与 B (Write Response) 通道。
- **主从机有限状态机（FSM）**：设计 Master 端的读写状态机，将流水线访存阶段的单拍请求转换为符合 AXI 协议的多拍握手，并输出 stall 信号暂停流水线直到操作完成。

**内存映射 I/O（MMIO）与 Crossbar 互连：**

- **地址空间规划（Memory Map）**：

  | 外设 | 地址范围 | 大小 |
  | --- | --- | --- |
  | 片上 RAM | `0x8000_0000` - `0x8003_FFFF` | 256 KB |
  | UART 串口 | `0x1000_0000` - `0x1000_00FF` | — |
  | 定时器/中断控制器 | `0x0200_0000` - `0x0200_FFFF` | — |

- 编写 Crossbar 模块，根据访存地址的高位进行多路从机路由与片选。

**裸机软件运行环境构建：**

- 编写启动汇编代码 `crt0.S`：初始化栈指针寄存器（`sp = 0x8003FFF0`），清理 BSS 段，跳转到 `main()`。
- 编写链接脚本 `linker.ld`：定义 `.text`, `.rodata`, `.data`, `.bss` 段在物理内存中的布局。
- 编写底层 C 语言 UART 驱动：通过读写指针 `*(volatile uint32_t*)(0x10000000)` 实现字符与字符串发送函数。

### 3. 技术栈

`AXI4-Lite` | `Cocotb` | `cocotbext-axi` | `riscv-none-elf-gcc`（本机 xPack 工具链） | `GNU Make`

### 4. 验证指标与建议耗时

**预估耗时**：2 - 3 周

**可实现性验收标准：**

- 使用 Cocotb 对 AXI4-Lite Master/Slave 模块进行随机延迟反压测试（Random Backpressure），通过 10,000 次无死锁读写验证。
- 使用交叉编译工具链编译包含 `printf` 精简实现的 C 语言程序，生成 `.bin` / `.hex` 固件。
- 在 Verilator 仿真中加载固件，CPU 通过 MMIO 操作 UART 模块，在终端完整打印出 `[UART]: Hello World from RISC-V C Program!`。

---

## Phase 3: 特权级架构、CSR 与实时操作系统 (M-Mode + FreeRTOS)

### 1. 阶段概述与解决的问题

赋予处理器处理异步外部事件、定时中断以及异常调用的能力。实现 RISC-V 官方 Machine Mode (M-Mode) 控制状态寄存器（CSR）规范，构建硬件定时器（CLINT），并成功适配并移植 FreeRTOS，实现硬件级抢占式任务调度。

### 2. 核心掌握知识点

**M-Mode 控制状态寄存器（CSR）集合：**

| CSR | 说明 |
| --- | --- |
| `mstatus` | 机器模式状态寄存器（MIE 全局中断使能位、MPIE 异常前中断使能位、MPP 异常前特权级） |
| `mie` / `mip` | 中断使能与中断挂起寄存器（MTIE/MTIP 定时器中断、MEIE/MEIP 外部中断、MSIE/MSIP 软件中断） |
| `mtvec` | 中断向量表基地址寄存器（支持 Direct 模式与 Vector 模式） |
| `mepc` | 保存进入异常时的 PC 指针 |
| `mcause` | 保存导致异常或中断的具体原因编码（区分 Interrupt 与 Exception） |
| `mtval` | 保存发生异常时的附加信息（如非法访存地址） |

**CSR 读写原子指令与流水线交互：**

- 实现 `CSRRW`, `CSRRS`, `CSRRC`, `CSRRWI`, `CSRRSI`, `CSRRCI` 指令。
- 处理 CSR 读写的数据相关性与流水线刷新（Pipeline Flush）。

**精确异常处理（Precise Trap Handling）硬件流程：**

- **Trap 触发阶段**：硬件自动执行：
  1. 保存当前受影响的 PC 至 `mepc`。
  2. 将异常/中断编码写入 `mcause`。
  3. `mstatus.MPIE <= mstatus.MIE`，随后设置 `mstatus.MIE <= 0`（关全局中断）。
  4. 强制将下一拍取指 PC 设置为 `mtvec` 指定的地址。
- **Trap 返回阶段（`MRET` 指令）**：
  1. `mstatus.MIE <= mstatus.MPIE`，随后设置 `mstatus.MPIE <= 1`。
  2. 强制将下一拍取指 PC 恢复为 `mepc`。

**CLINT 定时器外设：**

- 实现 64-bit 硬件计数器 `mtime`（由固定时钟分频驱动自增）。
- 实现 64-bit 比较寄存器 `mtimecmp`。
- 当满足条件 $mtime \ge mtimecmp$ 时，硬件自动将 `mip.MTIP` 置 1；写 `mtimecmp` 后自动清除该中断。

**FreeRTOS 体系结构适配（Porting）：**

- 理解任务控制块（TCB）与任务栈初始化结构（模拟中断发生时将 32 个寄存器压栈）。
- 编写/修改 `portASM.S`：在定时器中断服务程序中完成任务上下文切换（Context Switch）。

### 3. 技术栈

`RISC-V Privileged Spec v1.12` | `FreeRTOS Kernel` | `CLINT` | `GDB / OpenOCD`

### 4. 验证指标与建议耗时

**预估耗时**：3 周

**可实现性验收标准：**

- 跑通自定义汇编测试，验证 `ECALL` 系统调用以及定时器中断触发与 `MRET` 返回流程。
- 成功编译 FreeRTOS 源代码并链接生成镜像。
- 在 Verilator 仿真中创建两个并发任务（Task A: 每隔 500ms 打印状态；Task B: 持续进行数学矩阵计算），验证抢占式任务调度无死锁、上下文寄存器无污染。

---

## Phase 4: 存储层次优化 (2-Way 组相联 Cache + AXI4 Burst)

### 1. 阶段概述与解决的问题

打破"内存墙"（Memory Wall）瓶颈。单次总线访问存在固有握手延迟；本阶段将总线升级为支持突发传输（Burst）的完整 AXI4 协议，并在 CPU 核心与总线之间构建 2-Way 组相联指令 Cache（I-Cache）和数据 Cache（D-Cache），通过局部性原理显著降低平均内存访问时间（AMAT）。

### 2. 核心掌握知识点

**AXI4 完整突发传输协议（Burst Protocol）：**

- 关键突发信号：`ARLEN`/`AWLEN`（传输拍数 - 1）、`ARSIZE`/`AWSIZE`（每拍传输字节数）、`ARBURST`/`AWBURST`（突发类型，固定采用 `2'b01` 即 INCR 递增模式）、`RLAST`/`WLAST`（最后一拍标志位）。

**Cache 组相联微架构参数设计（以 4KB, 2-Way, 16-Byte Line 为例）：**

参数计算公式：

- 块内偏移位宽（Offset）：$\log_2(16\text{ Bytes}) = 4\text{ bits}$（对应 $\text{Addr}[3:0]$）。
- 组数（Number of Sets）：$\dfrac{4\text{ KB}}{2\text{ Ways} \times 16\text{ B/Line}} = 128\text{ Sets}$。
- 组索引位宽（Index）：$\log_2(128) = 7\text{ bits}$（对应 $\text{Addr}[10:4]$）。
- 标签位宽（Tag）：$32 - 7 - 4 = 21\text{ bits}$（对应 $\text{Addr}[31:11]$）。

存储结构：

- **Tag RAM**：存储 $2 \times 128$ 个条目，每个条目包含 Valid 位（1-bit）、Dirty 位（1-bit）以及 Tag（21-bit）。
- **Data RAM**：存储 $2 \times 128 \times 16\text{ Bytes}$ 数据。

**Cache 控制状态机（FSM）与策略设计：**

- **写策略**：Write-Back（写回，仅在脏数据行被替换时回写主存）+ Write-Allocate（写缺失时先分配并加载整行）。
- **替换算法**：1-bit Pseudo-LRU（伪最近最少使用算法）。
- **状态机流转**：
  - `IDLE`：等待 CPU 请求。
  - `TAG_LOOKUP`：并行读取 Way 0 和 Way 1 的 Tag RAM。若某路 Tag 匹配且 Valid 为 1，判定为 Cache Hit，从对应 Data RAM 返回数据（采用同步 RAM 时命中路径延迟通常为 1~2 拍）；否则进入 Miss 流程。
  - `EVICT_WRITEBACK`：若选中的替换行 Valid 且 Dirty，向总线发起 AXI4 Write Burst，回写 16 字节脏数据。
  - `REFILL_READ`：向总线发起 AXI4 Read Burst（`ARLEN = 3`），连续读取 4 拍 32-bit 数据填入 Data RAM。

**Uncached MMIO 旁路通道：**

- 通过物理地址范围判断（若访问外设地址如 `0x1000_0000`），直接跳过 Cache 状态机，转换为单次 AXI4 传输，避免外设控制寄存器被错误缓存。

### 3. 技术栈

`AXI4 Full` | `Cache Design` | `Cocotb` | `CoreMark Benchmark`

### 4. 验证指标与建议耗时

**预估耗时**：3 - 4 周

**可实现性验收标准：**

- 使用 Cocotb 搭建 Cache 自动化测试平台，随机注入 100,000 次交替读写与从机延迟，验证数据一致性与替换逻辑无误。
- 硬件集成性能计数器（Performance Counter），实测典型 C 程序运行时 L1 Cache 命中率 $\ge 90\%$。
- 运行 CoreMark 跑分测试，量化对比开启 Cache 前后的 CPI（Cycles Per Instruction）指标，性能取得明显倍数级提升。

---

## Phase 5: FPGA 板级部署与物理后端收敛 (Artix-7 50T + Tiny Tapeout)

### 1. 阶段概述与解决的问题

打通从代码到实体硅片的最后两道屏障。首先在 Xilinx Artix-7 50T FPGA 上完成板级硬件部署与真实时钟域验证；随后采用开源数字后端流程（OpenLane），基于 SkyWater 130nm 工艺库，跑通从门级网表综合到 GDSII 物理版图的全流程，并封装适配 Tiny Tapeout 提交框架。

### 2. 核心掌握知识点

**FPGA 物理实现与约束（Vivado）：**

- **XDC 约束编写**：物理引脚绑定（`set_property LOC ...`）、I/O 电平标准配置（如 LVCMOS33）。
- **时钟约束与分频**：使用 Xilinx Clocking Wizard（MMCM/PLL）将板载晶振时钟分频至 CPU 工作频率（如 50MHz），并添加 `create_clock` 约束。
- **存储器映射**：使用 Vivado Block Memory Generator 或 SystemVerilog 数组推断（RAM Inference）例化片上 BRAM。

**静态时序分析（STA）与时序违例修复：**

理解建立时间裕量（Setup Slack）与保持时间裕量（Hold Slack）计算公式：

$$\text{Setup Slack} = T_{\text{clk}} - (T_{\text{cq}} + T_{\text{comb}} + T_{\text{setup}} + T_{\text{skew}}) \ge 0$$

查看 Vivado Timing Report，定位最长关键路径（Critical Path），在 RTL 中重构组合逻辑或增加流水线级数消除负裕量（Negative Slack）。

**ASIC 物理后端设计流程（RTL-to-GDSII via OpenLane）：**

- **Synthesis（逻辑综合）**：Yosys 将 SystemVerilog 转换为 Sky130 标准单元门级网表。
- **Floorplanning & Placement（布局规划）**：设定 Core 面积利用率（`FP_CORE_UTIL`）与引脚排布。
- **CTS（Clock Tree Synthesis 时钟树综合）**：构建平衡时钟树，抑制 Clock Skew。
- **Routing（全局与详细布线）**：FastRoute 与 TritonRoute 完成金属层连线并解决布线拥塞。

**Signoff 物理验证：**

- **DRC（Design Rule Checking）**：使用 Magic 检查制造几何规则（0 违例）。
- **LVS（Layout Versus Schematic）**：使用 Netgen 验证物理版图提取网表与原始逻辑网表的一致性（0 违例）。

**Tiny Tapeout 接口封装规范：**

- 将核心顶层封装至 Tiny Tapeout 标准模板：输入 `ui_in[7:0]`、输出 `uo_out[7:0]`、双向 `uio_in[7:0]` / `uio_out[7:0]` / `uio_oe[7:0]`（`uio_oe` 为逐位方向控制，1 表示输出）。
- 受限于单个 Tile 的面积（TT04–TT10 约 160×100 µm，约 1000 门），完整 SoC 通常需申请多个 Tile 或对设计做裁剪；提交前需确认目标 shuttle 的资源约束。

> **⚠️ 关于流片渠道的现实说明**：随着 eFabless 停止运营，原有的 SkyWater Sky130 shuttle 已暂停，未来的 Sky130 流片渠道尚在调整中；Tiny Tapeout 已在探索 IHP SG13G2（130nm，开源 PDK）等替代工艺。参见 [Tiny Tapeout 官方公告](https://tinytapeout.com/news/efabless-shutsdown/)。因此本阶段建议将「跑通 RTL-to-GDSII 全流程 + DRC/LVS 清零」作为核心可交付目标，实际提交的 shuttle 与工艺以届时开放的渠道为准。*（信息来源经改写以符合引用规范）*

### 3. 技术栈

`Xilinx Vivado` | `XDC` | `OpenLane 2` | `SkyWater 130nm PDK` | `Magic / Netgen` | `Tiny Tapeout / IHP SG13G2`

### 4. 验证指标与建议耗时

**预估耗时**：3 - 4 周

**可实现性验收标准：**

- Vivado 生成 `.bit` 固件并烧录至 Artix-7 50T 开发板。
- 使用电脑串口工具（115200 波特率），与板上运行的 FreeRTOS 串口命令行（CLI）进行交互输入，板载 LED 灯按预设多任务频率精准闪烁。
- OpenLane 自动化后端运行成功，静态时序报告无 Timing Violation（$\text{WNS} \ge 0$），DRC 与 LVS 全部清零，成功导出最终用于制造的 `.gds` 版图文件。

---

## 附录 A: 总体时间与交付物检查清单

| 阶段 | 核心主题 | 关键代码/技术交付物 | 验证与验收目标 | 预估周期 |
| --- | --- | --- | --- | --- |
| **P1** | 流水线与 DiffTest | `rv32_core.sv`, `forwarding.sv`, `tb_top.cpp` | riscv-tests 全绿，Spike 差分比对 0 差错 | 2 - 3 周 |
| **P2** | AXI4-Lite 与 C 裸机 | `axi_lite_master.sv`, `uart.sv`, `crt0.S`, `linker.ld` | 仿真终端成功打印 C 语言 Hello World | 2 - 3 周 |
| **P3** | CSR 与 FreeRTOS | `csr_file.sv`, `clint.sv`, `portASM.S`, `FreeRTOSConfig.h` | 板级/仿真稳定运行 FreeRTOS 多任务抢占调度 | 3 周 |
| **P4** | AXI4 Burst 与 Cache | `icache.sv`, `dcache.sv`, `axi_burst_master.sv` | Cache 命中率 $\ge 90\%$，CoreMark 跑分显著提升 | 3 - 4 周 |
| **P5** | 7A50T 上板与 Tapeout | `top_artix7.xdc`, `openlane/config.json`, `project.gds` | 真实硬件串口交互成功，GDSII DRC/LVS 清零 | 3 - 4 周 |

---

## 附录 B: 推荐仓库目录结构规范

```text
riscv_soc_workspace/
├── .github/
│   └── workflows/
│       └── regression.yml          # GitHub Actions: 自动拉起 Verilator 跑测试用例
├── rtl/
│   ├── core/                       # CPU 流水线模块
│   │   ├── rv32_core.sv            # CPU 核心顶层
│   │   ├── datapath/               # IF, ID, EX, MEM, WB 数据通路
│   │   ├── control/                # Hazard Unit, Forwarding Unit, Branch Control
│   │   └── csr/                    # CSR 寄存器文件与 Trap Controller
│   ├── cache/                      # 存储层次
│   │   ├── icache.sv               # 2-Way 指令 Cache 控制器
│   │   ├── dcache.sv               # 2-Way 数据 Cache 控制器
│   │   └── cache_ram.sv            # Tag RAM 与 Data RAM 例化
│   ├── bus/                        # AXI4 总线系统
│   │   ├── axi_crossbar.sv         # 总线互连与地址译码
│   │   └── axi_lite_bridge.sv      # AXI4 到 AXI4-Lite 协议转换桥
│   └── periph/                     # 外设模块
│       ├── clint.sv                # 硬件定时器 (mtime/mtimecmp)
│       └── uart16550.sv            # UART 控制器
├── tb/
│   ├── verilator/                  # C++ 仿真环境
│   │   ├── tb_top.cpp              # 仿真顶层主循环
│   │   └── spike_difftest.cpp      # Spike 差分比对驱动
│   └── cocotb/                     # Python 随机约束测试
│       ├── test_axi_bus.py         # 总线反压测试
│       └── test_cache.py           # Cache 一致性测试
├── sw/
│   ├── boot/                       # 启动与引导代码
│   │   ├── crt0.S                  # 汇编启动文件
│   │   └── linker.ld               # 链接脚本
│   ├── drivers/                    # 外设底层驱动 (UART, Timer, GPIO)
│   ├── benchmarks/                 # CoreMark 跑分源码
│   └── os/                         # FreeRTOS 移植代码与 Demo 任务
├── fpga/
│   ├── vivado/                     # Vivado 工程构建脚本 (build.tcl)
│   ├── constrs/                    # XDC 物理与时序约束文件
│   └── ip/                         # Clocking Wizard 等 Xilinx IP 配置
├── openlane/                       # ASIC 物理设计后端
│   ├── config.json                 # SkyWater 130nm 物理设计配置文件
│   └── pin_order.cfg               # 芯片引脚排布约束
└── docs/                           # 设计规范文档与波形时序图
```

---

## 附录 C: 简历项目量化描述模板

在完成本项目后，你可以直接将以下工业界标准、量化指标完备的英文 Bullet Points 复制到简历的技术项目经历中：

- Designed an in-order 5-stage pipelined RV32I processor in SystemVerilog, implementing the RISC-V M-mode privileged spec (CSRs), precise exception/trap handling, and timer interrupts via a CLINT.
- Integrated a 4 KB 2-way set-associative L1 I/D cache (write-back, write-allocate) over an AXI4 burst (INCR) interface, sustaining a >90% hit rate and a measurable CPI improvement on CoreMark.
- Built an automated Verilator co-simulation (DiffTest) framework against the Spike golden model, achieving a 100% pass rate on the riscv-tests rv32ui ISA suite.
- Ported FreeRTOS to the custom core, validating preemptive multitasking, context switching, and MMIO UART CLI interaction on a Xilinx Artix-7 50T FPGA.
- Executed a full RTL-to-GDSII flow with OpenLane (SkyWater 130 nm PDK), reaching clean DRC/LVS sign-off and timing closure at 50 MHz for a Tiny Tapeout submission.

> **提示**：以上量化数字（命中率、CPI、频率等）请在项目完成后替换为你实测得到的真实值，切勿在简历中填写未经验证的指标。
