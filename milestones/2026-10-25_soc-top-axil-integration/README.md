**Status: ✅ DONE (2026-10-31)**

**2026-10-25** — Integrate the AXI4-Lite buses and RAMs into the 5-stage RV32I core through a new chip-level `soc_top`, keeping all 38/38 `rv32ui` ISA tests passing (`wave.vcd`: final design, `rv32ui-p-sw`, every fetch, load and store over AXI-Lite).

```mermaid
flowchart LR
    subgraph FPGA["fpga_top (board shell)"]
        subgraph SOC["soc_top (chip)"]
            subgraph CORE["core_top (CPU)"]
                IF["IF"] --> ID["ID"] --> EX["EX"] --> MEM["MEM"] --> WB["WB"]
            end
            IF -->|"imem_*"| IBUS["axil_i_bus (AXI-Lite master)"]
            MEM -->|"dmem_*"| DBUS["axil_d_bus (AXI-Lite master)"]
            IBUS -->|"AR / R"| IRAM["axil_ram (I-RAM)"]
            DBUS -->|"AR / R / AW / W / B"| DRAM["axil_ram (D-RAM)"]
            IBUS -.->|"bus_stop"| STALL(("global stall"))
            DBUS -.->|"bus_stop"| STALL
            STALL -.-> CORE
        end
    end
```

## Why this architecture

The CPU core contains no memory. It only exposes two ports: `imem_*` (fetch) and `dmem_*` (load/store). Everything else lives one level up, in `soc_top`.

- **Swap memories without touching the CPU.** BRAM today, AXI-Lite RAM in Stage 2, caches in Phase 4: only `soc_top` changes.
- **One chip, many shells.** Simulation, `fpga_top` (Artix-7) and a future Tiny Tapeout wrapper all instantiate the same `soc_top`, so what passes in simulation is what goes on the board.
- **Add peripherals the same way.** A UART or timer is just another AXI-Lite slave behind the bus; the core never knows it exists.
- **Same shape as real cores.** Ibex and PicoRV32 also keep memory outside the core and expose a simple fetch/data interface.

## Stages

| Stage | Goal | Status |
| --- | --- | --- |
| 1 | Move `inst_mem` / `data_mem` out of `core_top` into `soc_top` (no AXI yet) | ✅ Done |
| 2 | Replace them with `axil_i_bus` / `axil_d_bus` + two `axil_ram`, add global bus stall | ✅ Done |
| 3 | 38/38 ISA tests pass over AXI-Lite | ✅ Done |

## Movements

### 2026-10-25 15:21 — Stage 1: memories moved out of the core

Added `rtl/soc_top.v`; `core_top` now exposes `imem_*` / `dmem_*` ports; `fpga_top` and the Verilator testbench use `soc_top` as top. ISA regression 38/38 (commit `e98a8be`).

```mermaid
flowchart LR
    subgraph SOC["soc_top"]
        CORE["core_top"] -->|"imem_*"| IM["inst_mem (BRAM)"]
        CORE -->|"dmem_*"| DM["data_mem (BRAM)"]
    end
```

### 2026-10-25 16:40 — Stage 2a: bus stall wired into the pipeline

Added `bus_stall_i` to `core_top`; it freezes every pipeline register and masks flush (flush has priority over stall inside the pipe registers). Tied to 0 for now; ISA regression still 38/38.

```mermaid
flowchart LR
    BS["bus_stall_i (tied 0)"] -->|"stall"| P["PC / IF-ID / ID-EX / EX-MEM / MEM-WB"]
    BS -->|"mask"| F["flush"]
    HDU["hazard_detection_unit"] -->|"load-use stall"| P
```

### 2026-10-25 18:01 — Stage 2b-1: instruction fetch over AXI-Lite

Fetch now runs over `axil_i_bus` + `axil_ram` (I-RAM); IF/ID and MEM/WB became real registers (the hidden BRAM output register and `flush_d` are gone). ISA regression 38/38, cycle count ×2 as expected (`rv32ui-p-add`: 466 → 932; commit `9471711`).

```mermaid
flowchart LR
    subgraph SOC["soc_top"]
        CORE["core_top"] -->|"imem_*"| IBUS["axil_i_bus"] -->|"AR / R"| IRAM["axil_ram (I-RAM)"]
        CORE -->|"dmem_*"| DM["data_mem (BRAM)"]
        IBUS -.->|"bus_stall"| CORE
    end
```

### 2026-10-31 17:20 — Stage 2b-2 (wiring): loads/stores over AXI-Lite

Loads/stores now run over `axil_d_bus` + `axil_ram` (D-RAM); `core_top` exposes `dmem_rd_en_o` / `dmem_wr_en_o`; `bus_stall = i_bus_stop || d_bus_stop`. ISA regression 38/38 with no extra cycles (I- and D-bus both take 2 cycles and overlap). The one-request-per-instruction `done` flag is still to do (commit `af91146`).

```mermaid
flowchart LR
    subgraph SOC["soc_top"]
        CORE["core_top"] -->|"imem_*"| IBUS["axil_i_bus"] -->|"AR / R"| IRAM["axil_ram (I-RAM)"]
        CORE -->|"dmem_* + rd_en / wr_en"| DBUS["axil_d_bus"] -->|"AR / R / AW / W / B"| DRAM["axil_ram (D-RAM)"]
        IBUS -.->|"i_bus_stop"| OR(("OR"))
        DBUS -.->|"d_bus_stop"| OR
        OR -.->|"bus_stall"| CORE
    end
```

### 2026-10-31 19:55 — Stage 2b-2: one bus transaction per load/store

Added `DBG_DELAY` to `axil_ram` to make the two buses finish at different times, and a scoreboard in the Verilator testbench (bus handshakes vs. executed loads/stores). With a slow I-RAM every load/store hit the bus twice while ISA still showed 38/38, because RAM accesses are idempotent. A small adapter in `soc_top` (`dmem_done` flag that gates the request, `dmem_rdata_hold` register, and a selector) fixes it: 38/38 with zero extra transactions for I/D delays 0/0, 2/0, 0/3 and 3/1. Removing the selector fails 8 tests in the same-cycle case.

```mermaid
flowchart LR
    CORE["core_top (MEM stage)"] -->|"dmem_rd_en / wr_en"| GATE["AND !dmem_done"]
    GATE -->|"d_bus_r_req / w_req"| DBUS["axil_d_bus"]
    DBUS -->|"r_valid / w_valid (set)"| DONE["dmem_done"]
    STALL["bus_stall = 0 (clear, wins)"] --> DONE
    DONE --> GATE
    DBUS -->|"d_bus_rdata"| HOLD["dmem_rdata_hold"]
    DBUS -->|"d_bus_rdata"| MUX{"dmem_done ?"}
    HOLD --> MUX
    MUX -->|"dmem_rdata"| CORE
```

### 2026-10-31 19:58 — Stage 3: milestone done

Debug delays removed (both RAMs at `DBG_DELAY = 0`). The final design fetches every instruction and runs every load/store over AXI-Lite: ISA regression 38/38, scoreboard shows one bus transaction per load/store in every test (`rv32ui-p-sw`: 34 reads / 34 loads, 34 writes / 34 stores, 1060 cycles). `wave.vcd` replaced with this run.

```mermaid
flowchart LR
    subgraph SOC["soc_top"]
        CORE["core_top"] -->|"imem_*"| IBUS["axil_i_bus"] -->|"AR / R"| IRAM["axil_ram (I-RAM)"]
        CORE -->|"dmem_*"| ADP["one-request adapter"] -->|"d_bus_*"| DBUS["axil_d_bus"] -->|"AR / R / AW / W / B"| DRAM["axil_ram (D-RAM)"]
        IBUS -.->|"i_bus_stop"| OR(("OR"))
        DBUS -.->|"d_bus_stop"| OR
        OR -.->|"bus_stall"| CORE
        OR -.->|"clear done"| ADP
    end
```
