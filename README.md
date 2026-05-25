# AMBA AXI4 Protocol Mastery

A hands-on, from-scratch implementation and study repository for the AMBA AXI4 protocol family: **AXI4-Lite, AXI4-Full, and AXI4-Stream**. 

> **Goal:** Build industry-standard AXI IPs, understand the handshakes and transaction rules deeply, and verify them in simulation and on a physical FPGA (Cmod-S7) alongside a custom RISC-V SoC.

## Repository Structure & Study Path

### 📚 1. Fundamentals (Completed)
- [`docs/axi4_protocol_fundamentals.md`](docs/axi4_protocol_fundamentals.md): Comprehensive reference for all AXI4 rules, bursts, WSTRB, cache signals, and formulas.
- [`docs/verilog_rtl_coding_style.md`](docs/verilog_rtl_coding_style.md): Professional RTL coding guide covering FSM encoding, non-blocking/blocking rules, and registered outputs for AXI.

### 🔌 2. AXI4-Lite (In Progress)
- **Status:** Slave RTL developed. Verification next.
- [`axi4_lite/rtl/axi_lite_slave.v`](axi4_lite/rtl/axi_lite_slave.v): A robust, fully-commented AXI4-Lite slave with a 4-register bank. It implements a single-always FSM, one-hot encoding, proper WSTRB handling, and SLVERR responses.
- **Next steps:** 
  1. Add AXI4-Lite Master testbench or use Vivado AXI VIP for verification.
  2. Expand to include a PWM controller and interrupt logic.

### 🚀 3. AXI4-Full (Planned)
- Implement a burst-capable memory controller.
- Understand unaligned transfers, multi-beat bursts, and out-of-order execution concepts.

### 🌊 4. AXI4-Stream (Planned)
- Implement continuous flow streaming (FIFO/DMA).
- Handle `TLAST`, `TKEEP`, and backpressure (`TREADY`).

## Verification Strategy
- **Simulation:** Icarus Verilog + GTKWave / Xilinx Vivado AXI VIP.
- **Hardware Integration:** Add the custom IPs to the RISC-V SoC via a Wishbone-to-AXI bridge or direct AXI Interconnect on the Cmod-S7 FPGA.
