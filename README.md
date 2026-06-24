# AMBA AXI4 Protocol Mastery

A hands-on, from-scratch implementation and study repository for the AMBA AXI4 protocol family: **AXI4-Lite, AXI4-Full, and AXI4-Stream**. 

> **Goal:** Build industry-standard AXI IPs, understand the handshakes and transaction rules deeply, and verify them in simulation and on a physical FPGA (Cmod-S7) alongside a custom RISC-V SoC.

## Repository Structure & Study Path

### 📚 1. Fundamentals (Completed)
- [`docs/axi4_protocol_fundamentals.md`](docs/axi4_protocol_fundamentals.md): Comprehensive reference for all AXI4 rules, bursts, WSTRB, cache signals, and formulas.
- [`docs/verilog_rtl_coding_style.md`](docs/verilog_rtl_coding_style.md): Professional RTL coding guide covering FSM encoding, non-blocking/blocking rules, and registered outputs for AXI.

### 🔌 2. AXI4-Lite (Completed)
- **Status:** Master and Slave RTL developed and verified in hardware.
- [`axi4_lite/rtl/axi_lite_slave.v`](axi4_lite/rtl/axi_lite_slave.v): A robust AXI4-Lite slave with a 4-register bank.
- [`axi4_lite/rtl/axi_lite_master.v`](axi4_lite/rtl/axi_lite_master.v): A custom AXI4-Lite master wrapper connecting Wishbone to AXI.
- [`axi4_lite/rtl/axi_pwm_slave.v`](axi4_lite/rtl/axi_pwm_slave.v): A dual-register AXI4-Lite hardware PWM controller.
- [`axi4_lite/firmware/axi_pwm/main.c`](axi4_lite/firmware/axi_pwm/main.c): C firmware controlling the AXI PWM hardware to create a breathing LED effect.
- **Hardware Integration:** The complete system was successfully deployed on the Cmod-S7 FPGA. The custom RISC-V SoC controls the AXI hardware via firmware. See the **[RV32i-soc Repository](https://github.com/vignesh-rtl/RV32i-soc)** for the closed-loop system implementation.

### 🚀 3. AXI4-Full (Planned)
- Implement a burst-capable memory controller.
- Understand unaligned transfers, multi-beat bursts, and out-of-order execution concepts.

### 🌊 4. AXI4-Stream (Planned)
- Implement continuous flow streaming (FIFO/DMA).
- Handle `TLAST`, `TKEEP`, and backpressure (`TREADY`).

## Verification Strategy
- **Simulation:** Icarus Verilog + GTKWave / Xilinx Vivado AXI VIP.
- **Hardware Integration:** Add the custom IPs to the RISC-V SoC via a Wishbone-to-AXI bridge or direct AXI Interconnect on the Cmod-S7 FPGA.
