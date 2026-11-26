# SoC Pipeline Capstone

Experimental FPGA SoC with a custom pipelined RISC-V CPU, Wishbone instruction ROM and AHB peripheral subsystem. CNN accelerators and geometry remain separate projects and are not yet integrated.

```text
 Instruction ROM <-- Wishbone Classic --> CPU pipeline
                                              |
                                        AHB data master
                                              |
                                      AHB peripheral fabric
                                  RAM | UART | SPI | I2C | PMU
```

The PMU controls UART, SPI and I2C core clocks. `POWER` and `CLOCK` are logical requests, not physical power switches. The design uses LUT-based AND clock gating; clock distribution, glitch behavior and timing need review for the target board.

## Repository

| Path | Contents |
| --- | --- |
| `SoC_Pipeline_Capstone.xpr` | Vivado 2018.3 project; top `soc_peripheral_top` |
| `rtl/` | CPU, bus, memory, peripherals and PMU Verilog |
| `sim/` | Testbenches and `soc_demo.mem` instruction image |
| `constraints/soc_pmu_clock.xdc` | 10 ns clock constraint; no board pin assignments |
| `soc_rtl.svg` | Existing RTL schematic export |

## Simulation

1. Open `SoC_Pipeline_Capstone.xpr` in Vivado 2018.3.
2. Under **Simulation Sources**, right-click a testbench and select **Set as Top**. The project currently selects `tb_soc_pmu`.
3. Select **Run Simulation → Run Behavioral Simulation**. Enter `run all` in the Tcl Console if needed. Relaunch after changing sources or the simulation top.

`tb_soc_wishbone` tests instruction fetch with wait states and CPU access to RAM and peripherals. Additional testbenches include `tb_soc_pmu`, `tb_pmu_uart_i2c`, `tb_pmu_reset_disabled`, `tb_ahb_pmu`, `tb_pmu_and`, `tb_ahb_ram_reset` and `tb_soc_rom`. The ROM uses `$readmemh("soc_demo.mem", ...)`; the memory image is included in the project and must remain available to simulation and synthesis.

## Synthesis and board use

The configured part is `xc7a200tffv1156-2`; the `clk` constraint is 100 MHz. Use **Run Synthesis** and **Run Implementation** to generate fresh reports. The clock constraint is not a board pin assignment: clock, reset and peripheral pins and I/O standards must be assigned for the actual board. A timing result for a different part or constraints set does not validate this project.

## AHB address map

| Window | Base address |
| --- | --- |
| Data RAM | `0x00000000` |
| UART | `0x40000000` |
| SPI | `0x40001000` |
| I2C | `0x40002000` |
| PMU | `0x60000000` |

Each window is 4 KiB. PMU offsets are `POWER=0x00`, `CLOCK=0x04` and `STATUS=0x08`; bits 0, 1 and 2 refer to UART, SPI and I2C. Disable requests are deferred while the corresponding core or transfer is busy. Access to a disabled peripheral returns an AHB error; this prototype CPU latches a bus fault and halts.

## Current limits

- The CPU implements an incomplete RV32I subset; exceptions, interrupts and CSRs are not implemented. This project does not claim RV32IMC compliance.
- Instruction fetch is a single-master/single-slave Wishbone connection with wait states. The data bus is a single-master AHB subsystem; RETRY/SPLIT replay is not implemented.
- Data RAM is 4 KiB and word-only. Reset coincident with a RAM write edge has limited guarantees.
- The PMU gates clocks, not physical power. UART RX cannot wake a clock-disabled UART.
- AXI, CNN accelerators, geometry, multi-master arbitration and a complete board-level system are future integration work.
- Testbench PASS results cover the tested scenarios; they do not establish complete protocol compliance or board readiness.
