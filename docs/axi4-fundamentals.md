# AXI4 Protocol — Complete Study Reference

> A personal recall reference covering AXI4-Lite, AXI4-Full, and AXI4-Stream —
> built from first principles with worked examples.
> All concepts with examples sufficient to re-derive anything from memory.

---

## Table of Contents

1. [What is AXI and Who Invented It](#1-what-is-axi-and-who-invented-it)
2. [Where AXI is Used in Real Chips](#2-where-axi-is-used-in-real-chips)
3. [Three AXI Variants](#3-three-axi-variants)
4. [The 5 Channels](#4-the-5-channels)
5. [The 3 Golden Handshake Rules](#5-the-3-golden-handshake-rules)
6. [Transactions — Read and Write](#6-transactions--read-and-write)
7. [Bursts — AXI4-Full Only](#7-bursts--axi4-full-only)
8. [Write Strobe — WSTRB](#8-write-strobe--wstrb)
9. [Addressing — How Many Bits, How it Works](#9-addressing--how-many-bits-how-it-works)
10. [Unaligned Data Transfers](#10-unaligned-data-transfers)
11. [AxCACHE — Cache Control Signals](#11-axcache--cache-control-signals)
12. [AXI4-Stream](#12-axi4-stream)
13. [Full Signal Reference — AXI4-Lite](#13-full-signal-reference--axi4-lite)
14. [Key Formulas Quick Reference](#14-key-formulas-quick-reference)
15. [ARM Official Specifications](#15-arm-official-specifications)

---

## 1. What is AXI and Who Invented It

**AXI = Advanced eXtensible Interface**

Invented by **ARM** as part of **AMBA (Advanced Microcontroller Bus Architecture)**.
Released as an **open standard** — any company uses it without paying ARM for the bus.
This is why it became the universal interconnect standard across the entire industry.

### AMBA Version History

```
AMBA 1 (1996) → APB   — simple slow peripheral bus
AMBA 2 (1999) → AHB   — faster, single channel, still in small MCUs today
AMBA 3 (2003) → AXI3  — first high-performance separate-channel bus
AMBA 4 (2010) → AXI4, AXI4-Lite, AXI4-Stream  ← current industry standard
AMBA 5 (2015) → AXI5, CHI — cache-coherent, multi-core server chips
```

---

## 2. Where AXI is Used in Real Chips

| Chip / Company | How AXI is Used |
|---|---|
| **NVIDIA RTX / H100 GPU** | Internal NoC connecting SM cores, HBM memory controller, video decoder — all via AXI fabric |
| **Apple M4 SoC** | CPU cores, Neural Engine, GPU connect to LPDDR5 memory via AMBA5/AXI |
| **AMD Ryzen / EPYC** | Infinity Fabric (AXI-based principles) links CPU cores, PCIe, memory controller |
| **Qualcomm Snapdragon** | Camera ISP uses AXI4-Stream for pixels; AI Engine uses AXI4-Full burst for weight loading |
| **AMD Xilinx FPGAs (Zynq/Versal)** | Native AXI4 fabric — ALL IP blocks use AXI to connect to ARM cores and FPGA fabric |

**Bottom line:** If you work at any chip company anywhere in the world, you will use AXI.

---

## 3. Three AXI Variants

| Feature | AXI4-Lite | AXI4-Full | AXI4-Stream |
|---|---|---|---|
| Has address channels | Yes | Yes | **NO** |
| Burst support | **NO** (always 1) | YES (up to 256) | N/A |
| Transaction IDs | **NO** | YES (ARID, AWID) | NO |
| Out-of-order responses | **NO** | YES | N/A |
| Unaligned transfers | **NOT supported** | YES (via WSTRB) | N/A |
| Write strobe | Yes (4-bit for 32b) | Yes | NO (uses TKEEP) |
| Response channel | BRESP, RRESP | BRESP, RRESP | **NO** |
| Max data width | 32 or 64 bit | 32 to 1024 bit | Any width |
| Typical use | **Control registers** | **Memory / DMA** | **Pixel / audio / network data** |

### One-line Mental Model

```
AXI4-Lite   = A single tap. One cup of water at a time. For control.
AXI4-Full   = A fire hose with a burst valve. 256 gallons in one go. For memory.
AXI4-Stream = A river. Continuous flow. You dam it (READY=0) to slow it down.
```

---

## 4. The 5 Channels

AXI4-Lite and AXI4-Full both have **exactly 5 independent channels**.
Each channel has its own VALID/READY handshake.
Because they are independent, operations can **overlap** for high performance.

```
MASTER side                                     SLAVE side
─────────                                       ──────────

Write Address Channel:
  AWADDR   ──────────────────────────────────►
  AWVALID  ──────────────────────────────────►
  AWREADY  ◄──────────────────────────────────

Write Data Channel:
  WDATA    ──────────────────────────────────►
  WSTRB    ──────────────────────────────────►
  WVALID   ──────────────────────────────────►
  WREADY   ◄──────────────────────────────────

Write Response Channel:
  BRESP    ◄──────────────────────────────────
  BVALID   ◄──────────────────────────────────
  BREADY   ──────────────────────────────────►

Read Address Channel:
  ARADDR   ──────────────────────────────────►
  ARVALID  ──────────────────────────────────►
  ARREADY  ◄──────────────────────────────────

Read Data Channel:
  RDATA    ◄──────────────────────────────────
  RRESP    ◄──────────────────────────────────
  RVALID   ◄──────────────────────────────────
  RREADY   ──────────────────────────────────►
```

**Master drives:** `AWADDR, AWVALID, WDATA, WSTRB, WVALID, BREADY, ARADDR, ARVALID, RREADY`

**Slave drives:** `AWREADY, WREADY, BRESP, BVALID, ARREADY, RDATA, RRESP, RVALID`

---

## 5. The 3 Golden Handshake Rules

> **A transfer happens on the rising clock edge where BOTH VALID and READY are HIGH.**

### Rule 1 — VALID must NOT wait for READY

```
WRONG (causes deadlock):
  Master: "I'll assert AWVALID only after AWREADY goes high."
  Slave:  "I'll assert AWREADY only after AWVALID goes high."
  Result: Both waiting forever. System hangs.

CORRECT:
  Master asserts AWVALID independently whenever it has data.
  Slave asserts AWREADY independently whenever it can accept.
```

### Rule 2 — Transfer only when VALID=1 AND READY=1 simultaneously

```
Clock    _|‾|_|‾|_|‾|_|‾|_|‾|

VALID    ─────‾‾‾‾‾‾‾‾‾‾‾‾‾‾─
READY    ──────────‾‾‾‾‾‾‾‾‾─
                   ↑
             Transfer here (both high)
```

### Rule 3 — Once VALID is high, it must stay HIGH until READY goes HIGH

The master cannot "change its mind" or de-assert VALID early.  
Data, address, and control signals must stay stable until the transfer completes.

---

## 6. Transactions — Read and Write

One transaction = one complete operation from start to finish.

### Write Transaction — 3 Phases

```
Phase 1 — Write Address:
  Master puts AWADDR on bus, asserts AWVALID.
  Slave asserts AWREADY when ready.
  → Transfer done on cycle where AWVALID=1 AND AWREADY=1.

Phase 2 — Write Data:
  Master puts WDATA and WSTRB on bus, asserts WVALID.
  Slave asserts WREADY when it can accept data.
  → Transfer done on cycle where WVALID=1 AND WREADY=1.

Phase 3 — Write Response:
  Slave puts BRESP and asserts BVALID.
  Master asserts BREADY when ready to accept response.
  → Transaction fully complete.

BRESP values:
  2'b00 = OKAY    (success)
  2'b10 = SLVERR  (slave error — e.g. address out of range, write to read-only register)
  2'b11 = DECERR  (decode error — address not mapped to any slave)
```

### Read Transaction — 2 Phases

```
Phase 1 — Read Address:
  Master puts ARADDR, asserts ARVALID.
  Slave asserts ARREADY when ready.

Phase 2 — Read Data:
  Slave puts RDATA and RRESP, asserts RVALID.
  Master asserts RREADY when it can accept the data.
  → Read transaction done.
```

> **KEY:** In AXI4, WDATA can arrive at the slave **before** AWADDR.
> The write address and write data channels are fully independent.
> Your slave state machine must handle both arrival orders correctly.

---

## 7. Bursts — AXI4-Full Only

### Why Bursts?

```
Without burst — write 16 words:
  16 separate transactions × 3 phases each = ~48+ clock cycles minimum
  Bus is idle between every transaction = wasted time

With burst — write 16 words:
  1 transaction: 1 address + 16 data beats back-to-back + 1 response
  = ~18 clock cycles  (2.7× faster, no idle gaps)
```

### Burst Control Signals

| Signal | Width | Meaning |
|---|---|---|
| `AWLEN` / `ARLEN` | 8 bits | Beats − 1. `AWLEN=0`→1 beat. `AWLEN=15`→16 beats. `AWLEN=255`→256 beats. |
| `AWSIZE` / `ARSIZE` | 3 bits | Bytes per beat = 2^AWSIZE. `2`→4B, `3`→8B |
| `AWBURST` / `ARBURST` | 2 bits | `INCR`(01): address increments. `FIXED`(00): same address. `WRAP`(10): wraps at boundary. |
| `WLAST` / `RLAST` | 1 bit | HIGH only on the **last beat** of a burst. |

### Complete Example — Writing 512 bits (16 words × 32 bits = 64 bytes)

**Using AXI4-Lite (no burst) — 16 separate transactions:**

```
Transaction 1:   AWADDR=0x00, WDATA=0xAAAAAAAA  → BRESP=OKAY
Transaction 2:   AWADDR=0x04, WDATA=0xBBBBBBBB  → BRESP=OKAY
Transaction 3:   AWADDR=0x08, WDATA=0xCCCCCCCC  → BRESP=OKAY
... × 13 more separate transactions ...
Transaction 16:  AWADDR=0x3C, WDATA=0xAAAABBBB  → BRESP=OKAY

Total: ~48+ clock cycles just for overhead.
```

**Using AXI4-Full burst — ONE transaction:**

```
Address Phase (sent ONCE):
  AWADDR  = 0x0000_0000   (start address)
  AWLEN   = 15            (16 beats: 15+1=16)
  AWSIZE  = 2             (4 bytes per beat: 2²=4)
  AWBURST = INCR          (auto-increment address by 4 each beat)

Data Phase (16 consecutive beats, no gaps):
  Beat 1:  WDATA=0xAAAAAAAA  WSTRB=4'b1111  WLAST=0  → slave writes to 0x0000_0000
  Beat 2:  WDATA=0xBBBBBBBB  WSTRB=4'b1111  WLAST=0  → slave writes to 0x0000_0004
  Beat 3:  WDATA=0xCCCCCCCC  WSTRB=4'b1111  WLAST=0  → slave writes to 0x0000_0008
  ...
  Beat 16: WDATA=0xAAAABBBB  WSTRB=4'b1111  WLAST=1  → slave writes to 0x0000_003C

Response Phase (ONCE):
  BRESP = OKAY

Total: ~18 clock cycles.
```

**How does the slave know each beat's address?**

The slave has an internal counter. It calculates:
```
Beat N address = AWADDR + (N−1) × 2^AWSIZE
Beat 1:  0x00 + 0×4 = 0x00
Beat 2:  0x00 + 1×4 = 0x04
Beat 3:  0x00 + 2×4 = 0x08
...
Beat 16: 0x00 + 15×4 = 0x3C
```

### Burst Types

| AWBURST | Name | Address Each Beat | Use Case |
|---|---|---|---|
| `2'b01` | INCR | Increments by 2^AWSIZE | RAM / DMA — **most common** |
| `2'b00` | FIXED | Same address every beat | FIFO — push/pop multiple items |
| `2'b10` | WRAP | Increments, wraps at power-of-2 boundary | CPU cache line fill |

---

## 8. Write Strobe — WSTRB

### The Problem WSTRB Solves

Your data bus is 32 bits = 4 bytes wide. But you might only want to write 1 byte.
Without WSTRB, all 4 bytes would be overwritten — corrupting adjacent data.

### How WSTRB Works

One bit per byte lane. `1` = write this byte. `0` = keep old value.

```
WSTRB bit:  [3]        [2]        [1]        [0]
            │          │          │          │
WDATA byte: [31:24]   [23:16]   [15:8]    [7:0]
Address:    Byte+3    Byte+2    Byte+1    Byte+0
```

### Example

```
Memory: [AA] [BB] [CC] [DD]  at addresses 0x00–0x03
Goal:   Change ONLY byte at 0x02 from CC to FF.

WDATA  = 0x00FF0000   (FF placed in bits [23:16])
WSTRB  = 4'b0100     (bit[2]=1 → write only byte 2)

Slave writes only byte 2:
Before:  [AA] [BB] [CC] [DD]
After:   [AA] [BB] [FF] [DD]  ← only 0x02 changed ✅
```

### WSTRB for Common RISC-V Instructions

| WSTRB | Bytes Written | RISC-V Instruction |
|---|---|---|
| `4'b1111` | All 4 bytes | SW (Store Word) |
| `4'b0011` | Bytes 0 and 1 | SH at offset +0 |
| `4'b1100` | Bytes 2 and 3 | SH at offset +2 |
| `4'b0001` | Byte 0 only | SB at offset +0 |
| `4'b0010` | Byte 1 only | SB at offset +1 |
| `4'b0100` | Byte 2 only | SB at offset +2 |
| `4'b1000` | Byte 3 only | SB at offset +3 |

### WSTRB Width Rule

```
WSTRB width = Data bus bits ÷ 8

32-bit bus  → WSTRB = 4 bits
64-bit bus  → WSTRB = 8 bits
128-bit bus → WSTRB = 16 bits
512-bit bus → WSTRB = 64 bits  (HBM GPU memory)
```

> **Note:** In your RV32I SoC, `i_wb_sel` in the Wishbone bus is **the same concept** as AXI WSTRB.
> You already built this. AXI just formalises it.

---

## 9. Addressing — How Many Bits, How it Works

### Fundamental Rule

Memory is **byte-addressable** — every address points to **exactly 1 byte**.

```
Address bits needed = log₂(memory size in bytes)
Addressable locations = 2^(address bits)

Examples:
  1 KB   = 1,024 bytes     → log₂(1024)      = 10 bits  → 0x000 to 0x3FF
  64 KB  = 65,536 bytes    → log₂(65536)      = 16 bits  → 0x0000 to 0xFFFF
  80 KB  = 81,920 bytes    → log₂(81920) ≈ 17 bits  → 0x00000 to 0x13FFF  (your SoC!)
  4 GB   = 4,294,967,296   → log₂(4G)         = 32 bits  → 0x00000000 to 0xFFFFFFFF
```

### Reading Hex Addresses

```
0x prefix = hexadecimal. 1 hex digit = 4 bits. 8 hex digits = 32-bit address.

0x8000_0050 broken down:
  Bit 31 = 1  (the '8' in MSB)
  ← this is why your SoC uses bit 31 to separate peripherals from RAM:
       0x0000_0000 → bit 31 = 0 → RAM
       0x8000_0050 → bit 31 = 1 → UART TX register
```

### Word Addresses (32-bit words)

```
Each 32-bit word = 4 bytes. Consecutive word addresses differ by 4.

Word 0: 0x00  →  bytes at 0x00, 0x01, 0x02, 0x03
Word 1: 0x04  →  bytes at 0x04, 0x05, 0x06, 0x07
Word 2: 0x08  →  bytes at 0x08, 0x09, 0x0A, 0x0B

The BOTTOM 2 BITS of a 32-bit-aligned address are ALWAYS 00.
In slave RTL, decode bits [4:2] for 8 registers (bits [1:0] always ignored):
  wire [2:0] reg_index = AWADDR[4:2];
```

### Memory Size Reference

| Memory Size | Bytes | Address Bits | Address Range |
|---|---|---|---|
| 1 KB | 1,024 | 10 | `0x000` to `0x3FF` |
| 4 KB | 4,096 | 12 | `0x000` to `0xFFF` |
| 64 KB | 65,536 | 16 | `0x0000` to `0xFFFF` |
| 80 KB | 81,920 | 17 | `0x00000` to `0x13FFF` |
| 1 MB | 1,048,576 | 20 | `0x00000` to `0xFFFFF` |
| 4 GB | 4,294,967,296 | 32 | `0x00000000` to `0xFFFFFFFF` |

---

## 10. Unaligned Data Transfers

### What is Alignment?

A 4-byte aligned address is any **multiple of 4** (bottom 2 bits = `00`).

```
Aligned:     0x00 ✅  0x04 ✅  0x08 ✅
Not aligned: 0x01 ❌  0x02 ❌  0x06 ❌  0x09 ❌
```

- **AXI4-Lite**: Unaligned NOT supported. Address must be aligned. Slave can return SLVERR.
- **AXI4-Full**: Supported using WSTRB masking.

### Complete Example — Write 6 bytes starting at 0x02

```
Memory before:
  Address: 0x00  0x01  0x02  0x03  0x04  0x05  0x06  0x07
  Data:    [11]  [22]  [33]  [44]  [55]  [66]  [77]  [88]

Goal (write AA BB CC DD EE FF starting at 0x02):
  Address: 0x00  0x01  0x02  0x03  0x04  0x05  0x06  0x07
  Target:  [11]  [22]  [AA]  [BB]  [CC]  [DD]  [EE]  [FF]
                        ^-- keep 0x00 and 0x01 unchanged
```

Data crosses two 4-byte groups → need **2 beats** with careful WSTRB masking.

**Address Phase:**
```
AWADDR  = 0x0000_0000   (round DOWN to nearest aligned address)
AWLEN   = 1             (2 beats)
AWSIZE  = 2             (4 bytes per beat)
AWBURST = INCR
```

**Beat 1 — writing AA (0x02) and BB (0x03):**
```
WDATA bit layout for address 0x00:
  [31:24]=[0x03]  [23:16]=[0x02]  [15:8]=[0x01]  [7:0]=[0x00]

AA→0x02 → WDATA[23:16]
BB→0x03 → WDATA[31:24]
0x00 and 0x01 must NOT be touched

WDATA  = 0xBBAA????    (BB at [31:24], AA at [23:16], don't-care for rest)
WSTRB  = 4'b1100       (bit3=1→write 0x03, bit2=1→write 0x02,
                          bit1=0→skip 0x01, bit0=0→skip 0x00)
WLAST  = 0

Memory after Beat 1:
  [11]  [22]  [AA]  [BB]  [55]  [66]  [77]  [88]   ← only 0x02, 0x03 changed ✅
```

**Beat 2 — writing CC DD EE FF (0x04–0x07):**
```
Slave auto-increments address to 0x0000_0004

CC→0x04  DD→0x05  EE→0x06  FF→0x07
WDATA  = 0xFFEEDDCC
WSTRB  = 4'b1111    (all 4 bytes valid)
WLAST  = 1

Memory after Beat 2:
  [11]  [22]  [AA]  [BB]  [CC]  [DD]  [EE]  [FF]   ✅
```

**Who does the work?**

```
Master:  1. Detect unaligned start (0x02 not multiple of 4)
         2. Round DOWN to aligned address for AWADDR (0x00)
         3. Shift data into correct WDATA byte lanes per beat
         4. Set WSTRB to mask bytes before the actual start

Slave:   1. Check each WSTRB bit
         2. Write ONLY bytes where WSTRB = 1
         3. Leave all other bytes untouched
```

---

## 11. AxCACHE — Cache Control Signals

`AWCACHE[3:0]` (for writes) and `ARCACHE[3:0]` (for reads).  
Tell every cache/component on the path how to handle the transaction.

### The 4 Bits

| Bit | Name | = 0 | = 1 |
|---|---|---|---|
| `[0]` | **Bufferable** | Response MUST come from final RAM. Wait for it. | Intermediate (L2 cache) can buffer & respond OKAY immediately. |
| `[1]` | **Modifiable** | Transaction must arrive at slave exactly as sent. No merging, no prefetch. | Caches CAN merge writes, split writes, prefetch reads, reuse fetches. |
| `[2]` | **RA** (Read-Allocate) | On read miss: fetch and deliver. Don't store in cache. | On read miss: SHOULD allocate cache line and store for future use. |
| `[3]` | **WA** (Write-Allocate) | On write miss: write directly to RAM. | On write miss: SHOULD fetch cache line first, modify in cache, write-back later. |

> **Rule:** If `Bit[1]=0` (Not Modifiable), then `Bit[2]` (RA) and `Bit[3]` (WA) **MUST** be 0.
> Caching requires modification. Can't cache what you can't modify.

### Applying to the 512-bit Write Example

```
━━━ Writing to your AXI4-Lite PWM peripheral ━━━━━━━━━━━━━━━━━━━━━━
AWADDR  = 0x8000_0004   (PERIOD register)
AWLEN   = 0             (1 beat — AXI4-Lite style)
AWCACHE = 4'b0000       ← Non-cacheable, Non-modifiable, Non-bufferable

Why 0x0000:
  Hardware register. Write MUST reach hardware — no buffering.
  No caching/merging/prefetch — always exactly 4 bytes to exactly this address.
  The cache on the path passes this straight through.

━━━ Writing 512 bits to normal RAM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AWADDR  = 0x0000_0000   (RAM)
AWLEN   = 15            (16 beats)
AWSIZE  = 2
AWBURST = INCR
AWCACHE = 4'b1111       ← Write-Back, Write-Allocate, Read-Allocate, Bufferable

What L2 cache does:
  Step 1: Cache lookup — is 0x00–0x3F in L2?
  HIT:    Modify cache lines, mark dirty, return BRESP=OKAY immediately (~8 cycles)
  MISS:   WA=1 → fetch 64-byte cache line from RAM, write new data in cache,
          return BRESP=OKAY. RAM gets updated later (write-back).

CPU sees: 512-bit write done in ~8 cycles instead of ~200 cycles to DDR.

━━━ DMA streaming write (video frame, never re-read) ━━━━━━━━━━━━━━
AWCACHE = 4'b0010       ← Modifiable=1, WA=0, RA=0, Bufferable=0

Why: Large video buffer written once, read once by display controller.
     No point caching — would waste L2 space (cache pollution).
     WA=0, RA=0 = bypass cache, write straight to RAM.
```

### Common AxCACHE Values

| AxCACHE | Name | Used For |
|---|---|---|
| `0b0000` | Device Non-Bufferable | Memory-mapped I/O — UART, GPIO, AXI-Lite peripherals |
| `0b0001` | Device Bufferable | Peripheral with write buffer allowed |
| `0b0110` | Write-Through, Read-Allocate | Cache writes through to RAM immediately |
| `0b1110` | Write-Back, Read-Allocate | High-performance cache |
| `0b1111` | Write-Back, Read+Write Allocate | Most aggressive — highest performance RAM access |

> **For ALL AXI4-Lite peripherals (UART, GPIO, PWM, etc.): always `AWCACHE = 4'b0000`**

---

## 12. AXI4-Stream

No address channels. Pure continuous data flow. Used for: camera pixels, audio samples, network packets, DMA output, video processing pipelines.

### Signals

| Signal | Direction | Purpose |
|---|---|---|
| `TDATA` | M→S | Actual data payload |
| `TVALID` | M→S | Master has valid data right now |
| `TREADY` | S→M | Slave can accept data right now |
| `TLAST` | M→S | Last beat of the current packet/frame |
| `TKEEP` | M→S | Which byte lanes contain valid data (same idea as WSTRB) |

### Handshake — Same VALID/READY rule

```
Transfer happens when TVALID=1 AND TREADY=1 simultaneously.

When TREADY=0 (slave busy): master holds TVALID=1 and TDATA stable.
This is BACKPRESSURE — slave signalling master to slow down.
```

### TLAST and TKEEP Example (10-byte packet on 32-bit bus)

```
Packet: [B0 B1 B2 B3 B4 B5 B6 B7 B8 B9]  — 10 bytes total

Beat 1: TDATA=[B3|B2|B1|B0]  TKEEP=4'b1111  TLAST=0  → 4 valid bytes
Beat 2: TDATA=[B7|B6|B5|B4]  TKEEP=4'b1111  TLAST=0  → 4 valid bytes
Beat 3: TDATA=[??|??|B9|B8]  TKEEP=4'b0011  TLAST=1  → 2 valid bytes, end of packet

TKEEP=0011: ignore [31:16], only [15:0] are valid data.
```

> **TKEEP vs WSTRB:** Same concept, different context.
> WSTRB = which bytes to write to memory.
> TKEEP = which byte lanes in TDATA carry valid packet data.

---

## 13. Full Signal Reference — AXI4-Lite (32-bit)

| Signal | Width | Direction | Description |
|---|---|---|---|
| `AWADDR` | 32 | M→S | Write address |
| `AWPROT` | 3 | M→S | Protection level (privilege, security, instruction vs data) |
| `AWVALID` | 1 | M→S | Write address valid |
| `AWREADY` | 1 | S→M | Write address accepted |
| `WDATA` | 32 | M→S | Write data |
| `WSTRB` | 4 | M→S | Byte enables (1 bit per byte lane) |
| `WVALID` | 1 | M→S | Write data valid |
| `WREADY` | 1 | S→M | Write data accepted |
| `BRESP` | 2 | S→M | Write response: `00`=OKAY, `10`=SLVERR, `11`=DECERR |
| `BVALID` | 1 | S→M | Write response valid |
| `BREADY` | 1 | M→S | Master ready to accept response |
| `ARADDR` | 32 | M→S | Read address |
| `ARPROT` | 3 | M→S | Protection level |
| `ARVALID` | 1 | M→S | Read address valid |
| `ARREADY` | 1 | S→M | Read address accepted |
| `RDATA` | 32 | S→M | Read data |
| `RRESP` | 2 | S→M | Read response: `00`=OKAY, `10`=SLVERR |
| `RVALID` | 1 | S→M | Read data valid |
| `RREADY` | 1 | M→S | Master ready to accept read data |

---

## 14. Key Formulas Quick Reference

```
Address bits needed       = log₂(memory size in bytes)
Addressable bytes         = 2^(address bits)

Bytes per burst beat      = 2^AWSIZE
   AWSIZE=0 → 1 byte
   AWSIZE=1 → 2 bytes
   AWSIZE=2 → 4 bytes   ← most common for 32-bit bus
   AWSIZE=3 → 8 bytes   ← for 64-bit bus

Number of beats in burst  = AWLEN + 1
Total bytes in burst      = (AWLEN+1) × 2^AWSIZE

WSTRB width               = Data bus bits ÷ 8

INCR burst beat N address = AWADDR + (N−1) × 2^AWSIZE

32-bit aligned addresses  = multiples of 4  (bottom 2 bits = 00)
64-bit aligned addresses  = multiples of 8  (bottom 3 bits = 000)

For AXI4-Lite slave RTL — register index from address:
  reg_index = AWADDR[ADDR_MSB:2]   (ignore bottom 2 bits)
```

---

## 15. ARM Official Specifications

| Document ID | Title | What It Covers |
|---|---|---|
| **IHI0022** | AMBA AXI and ACE Protocol Specification | AXI4-Lite + AXI4-Full — complete signal list, handshake rules, bursts, unaligned, IDs |
| **IHI0051** | AMBA AXI4-Stream Protocol Specification | AXI4-Stream — TDATA, TVALID, TREADY, TLAST, TKEEP |
| **IHI0033** | AMBA AHB Protocol Specification | AHB — older/smaller MCU bus (STM32 AHB) |
| **IHI0024** | AMBA APB Protocol Specification | APB — simple slow peripheral bus, no burst |

**Download:** [developer.arm.com/documentation](https://developer.arm.com/documentation) (free account required)

### Reading Priority

```
1. IHI0022 Chapter A1  — Introduction (what AXI is, motivation)
2. IHI0022 Chapter A3  — Single Interface Requirements (the 3 handshake rules)
3. IHI0022 Chapter A4  — Transaction Attributes (burst, size, type, cache)
4. IHI0022 Appendix A  — Signal descriptions (every signal with direction)
5. IHI0051             — After fully understanding AXI4-Lite and AXI4-Full
```

---

## Project Status

| Module | Status | Description |
|---|---|---|
| AXI4-Lite Slave (PWM IP) | 🔄 In Progress | Register bank + PWM engine with interrupt |
| AXI4-Lite Master (TB) | 🔄 Planning | Hand-written master testbench |
| AXI4-Full Burst Controller | ⏳ Next | Memory burst read/write slave |
| AXI4-Stream FIFO | ⏳ Future | Stream FIFO with backpressure |
| Image Processing Pipeline | ⏳ Future | AXI4-Stream pixel pipeline |

---

*Reference: ARM IHI0022 (AXI4 Protocol Spec) · ARM IHI0051 (AXI4-Stream Spec)*

