# Verilog RTL Coding Style — Complete Reference

> A personal reference for professional RTL coding style.
> Covers: blocking vs non-blocking, always blocks, assign, parameter vs localparam,
> FSM encoding, and how each applies to AXI4 and RISC-V design.

---

## Table of Contents

1. [Blocking vs Non-Blocking Assignment](#1-blocking-vs-non-blocking-assignment)
2. [always @(posedge clk) vs always @(*)](#2-always-posedge-clk-vs-always-)
3. [assign Statement](#3-assign-statement)
4. [parameter vs localparam](#4-parameter-vs-localparam)
5. [FSM Encoding Styles](#5-fsm-encoding-styles)
6. [Two-Always vs Three-Always FSM Style](#6-two-always-vs-three-always-fsm-style)
7. [Registered vs Combinational Outputs](#7-registered-vs-combinational-outputs)
8. [Where Each Applies — AXI and RISC-V Context](#8-where-each-applies--axi-and-risc-v-context)
9. [Complete Style Guide Template](#9-complete-style-guide-template)
10. [Golden Rules — Quick Reference](#10-golden-rules--quick-reference)

---

## 1. Blocking vs Non-Blocking Assignment

This is the most important rule in Verilog.
Getting this wrong causes simulation mismatches and synthesis bugs that are extremely hard to find.

### Non-Blocking `<=` — Sequential Logic

```verilog
always @(posedge clk) begin
    a <= b;   // non-blocking
    b <= a;   // non-blocking
end
```

**How it works:**
All right-hand sides are read using **OLD values** first.
All left-hand sides are written with **NEW values simultaneously** at the end of the time step.

```
Before clock edge:  a = 0,  b = 1
After clock edge:   a = 1,  b = 0   ← SWAP happens correctly
```

This is exactly how a flip-flop works in real hardware —
it captures the input and updates the output at the same clock edge.

> **Rule: Always use `<=` inside `always @(posedge clk)`. No exceptions.**

---

### Blocking `=` — Combinational Logic

```verilog
always @(*) begin
    a = b;   // blocking
    b = a;   // blocking
end
```

**How it works:**
Assignments execute **one by one, in order**, like software.
Each line reads the value updated by the previous line.

```
Start:   a = 0,  b = 1
Line 1:  a = b  →  a becomes 1  (immediate)
Line 2:  b = a  →  b becomes 1  (reads new a = 1)
Result:  a = 1,  b = 1   ← NOT a swap
```

This correctly models combinational logic — a MUX, decoder, or priority encoder
evaluates its logic immediately, in priority order.

> **Rule: Always use `=` inside `always @(*)`. No exceptions.**

---

### The Core Rule

```
always @(posedge clk)  →  NON-BLOCKING  <=   models flip-flops
always @(*)            →  BLOCKING       =    models gates / wires
assign                 →  BLOCKING       =    continuous assignment

NEVER mix = and <= in the same always block.
NEVER use <= in an always @(*) block.
NEVER use = in an always @(posedge clk) block for state/data registers.
```

---

### AXI Example — Correct Style

```verilog
// ─── Sequential: registers update on clock edge ───────────────────
always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        write_state    <= W_IDLE;    // <= non-blocking ✅
        s_axi_bvalid   <= 1'b0;      // <= non-blocking ✅
        awaddr_latched <= 32'b0;     // <= non-blocking ✅
    end else begin
        write_state    <= next_write_state;   // <= ✅
        s_axi_bvalid   <= next_bvalid;        // <= ✅
        if (s_axi_awvalid && s_axi_awready)
            awaddr_latched <= s_axi_awaddr;   // <= ✅ latch on handshake
    end
end

// ─── Combinational: next-state decode ─────────────────────────────
always @(*) begin
    next_write_state = write_state;    // = blocking ✅ (default: hold)
    next_bvalid      = 1'b0;           // = blocking ✅ (default: 0)

    case (write_state)
        W_IDLE: begin
            if (s_axi_awvalid && s_axi_wvalid)
                next_write_state = W_WRITE_REG;   // = ✅
        end
        W_RESPOND: begin
            next_bvalid = 1'b1;                   // = ✅
            if (s_axi_bready)
                next_write_state = W_IDLE;         // = ✅
        end
    endcase
end
```

---

## 2. always @(posedge clk) vs always @(*)

| Block Type | Use For | Models | Synthesizes To |
|---|---|---|---|
| `always @(posedge clk)` | State registers, output FFs, data latches | Sequential logic | D flip-flops |
| `always @(*)` | Next-state decode, MUX, decoders | Combinational logic | Gates (AND/OR/MUX) |
| `assign` | Simple 1-line combinational | Continuous assignment | Gates |

---

### When to Use `always @(posedge clk)`

```verilog
// ── State register — must be clocked ──────────────────────────────
always @(posedge clk) begin
    state <= next_state;
end

// ── Registered output — glitch-free ───────────────────────────────
always @(posedge clk) begin
    s_axi_bvalid <= next_bvalid;
end

// ── Data latch on handshake ────────────────────────────────────────
always @(posedge clk) begin
    if (s_axi_awvalid && s_axi_awready)
        awaddr_latched <= s_axi_awaddr;
end

// ── Counter (PWM, timer, watchdog) ────────────────────────────────
always @(posedge clk) begin
    if (!resetn || !enable)
        counter <= 32'b0;
    else if (counter == period_reg - 1)
        counter <= 32'b0;    // wrap
    else
        counter <= counter + 1;
end
```

---

### When to Use `always @(*)`

```verilog
// ── Next-state logic — pure combinational decode ───────────────────
always @(*) begin
    next_state = state;          // default: hold current state
    case (state)
        IDLE:    if (start) next_state = BUSY;
        BUSY:    if (done)  next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// ── Address decoder ────────────────────────────────────────────────
always @(*) begin
    reg_sel = REG_INVALID;      // default
    case (awaddr_latched[4:2])
        3'd0:    reg_sel = REG_CTRL;
        3'd1:    reg_sel = REG_PERIOD;
        3'd2:    reg_sel = REG_DUTY;
        3'd3:    reg_sel = REG_STATUS;
        default: reg_sel = REG_INVALID;
    endcase
end

// ── Priority encoder / MUX ────────────────────────────────────────
always @(*) begin
    if      (req[3]) grant = 4'b1000;
    else if (req[2]) grant = 4'b0100;
    else if (req[1]) grant = 4'b0010;
    else if (req[0]) grant = 4'b0001;
    else             grant = 4'b0000;
end
```

---

## 3. assign Statement

Use `assign` for **simple, one-line continuous combinational logic**.

```verilog
// ── PWM output from counter ────────────────────────────────────────
assign pwm_out = (counter < duty_reg) ? 1'b1 : 1'b0;

// ── Interrupt line: only fires if enabled ─────────────────────────
assign irq = |(isr_reg & ier_reg);    // any pending + enabled interrupt

// ── Address range check ────────────────────────────────────────────
assign addr_valid = (awaddr_latched[4:2] <= 3'd5);

// ── Active-high reset from active-low ─────────────────────────────
assign rst = ~resetn;

// ── Bus concatentation ────────────────────────────────────────────
assign full_addr = {upper_addr, lower_addr};

// ── Bit extraction ────────────────────────────────────────────────
assign pwm_enable = ctrl_reg[0];
assign pwm_reset  = ctrl_reg[1];
assign pwm_mode   = ctrl_reg[2];
```

**Decision guide:**
```
Logic fits in 1 line and is purely combinational?  →  use assign
Needs case/if-else or multiple lines?              →  use always @(*)
Must hold value between clock edges?               →  use always @(posedge clk)
```

---

## 4. parameter vs localparam

### `parameter` — Configurable from Outside

Can be **overridden by the parent module** when instantiating.
Use for anything the user of your IP might want to change.

```verilog
module axi4_lite_slave #(
    parameter DATA_WIDTH    = 32,    // 32-bit or 64-bit AXI data bus
    parameter ADDR_WIDTH    = 32,    // address bus width
    parameter CLK_FREQ_HZ   = 12_000_000,  // board clock frequency
    parameter NUM_REGS      = 6      // number of registers in the bank
)(
    input wire [DATA_WIDTH-1:0]   WDATA,
    input wire [ADDR_WIDTH-1:0]   AWADDR,
    input wire [DATA_WIDTH/8-1:0] WSTRB,
    ...
);
```

Instantiating with different values:

```verilog
// Default 32-bit
axi4_lite_slave u_slave_32 (...);

// Override to 64-bit
axi4_lite_slave #(
    .DATA_WIDTH(64),
    .ADDR_WIDTH(64)
) u_slave_64 (...);
```

---

### `localparam` — Fixed Internal Constants

**Cannot be overridden** by parent. Use for anything internal to the module.

```verilog
// ── FSM state encoding ─────────────────────────────────────────────
localparam [4:0] W_IDLE      = 5'b00001;
localparam [4:0] W_WAIT_DATA = 5'b00010;
localparam [4:0] W_WAIT_ADDR = 5'b00100;
localparam [4:0] W_WRITE_REG = 5'b01000;
localparam [4:0] W_RESPOND   = 5'b10000;

localparam [1:0] R_IDLE      = 2'b01;
localparam [1:0] R_DECODE    = 2'b10;

// ── AXI Response codes ────────────────────────────────────────────
localparam RESP_OKAY   = 2'b00;
localparam RESP_SLVERR = 2'b10;

// ── Register address map (decoded from AWADDR[4:2]) ───────────────
localparam REG_CTRL    = 3'd0;   // 0x00
localparam REG_PERIOD  = 3'd1;   // 0x04
localparam REG_DUTY    = 3'd2;   // 0x08
localparam REG_STATUS  = 3'd3;   // 0x0C  (read-only)
localparam REG_IER     = 3'd4;   // 0x10
localparam REG_ISR     = 3'd5;   // 0x14  (write-1-to-clear)

// ── Bit positions inside CTRL register ────────────────────────────
localparam CTRL_ENABLE = 0;   // CTRL[0]
localparam CTRL_RESET  = 1;   // CTRL[1]
localparam CTRL_MODE   = 2;   // CTRL[2]
```

**Decision guide:**

```
Can the user of your module need to change this?   →  parameter
Is this purely internal to the module?             →  localparam
Is this a magic number (address, bit mask, code)?  →  localparam (never hardcode)
```

---

## 5. FSM Encoding Styles

### Binary Encoding — Most Compact

```verilog
localparam IDLE      = 3'd0;   // 000
localparam WAIT_DATA = 3'd1;   // 001
localparam WAIT_ADDR = 3'd2;   // 010
localparam WRITE_REG = 3'd3;   // 011
localparam RESPOND   = 3'd4;   // 100

reg [2:0] state;   // only 3 flip-flops for 5 states
```

**Decoding:** needs multi-bit comparison → more logic gates.

```
To check if state == WRITE_REG:
   (state == 3'b011) → need 3-input AND gate
```

**Use when:** Area critical, many states (> 16), ASIC design.

---

### One-Hot Encoding — Fastest on FPGA ✅ (recommended for AXI)

```verilog
localparam [4:0] W_IDLE      = 5'b00001;   // bit 0
localparam [4:0] W_WAIT_DATA = 5'b00010;   // bit 1
localparam [4:0] W_WAIT_ADDR = 5'b00100;   // bit 2
localparam [4:0] W_WRITE_REG = 5'b01000;   // bit 3
localparam [4:0] W_RESPOND   = 5'b10000;   // bit 4

reg [4:0] state;   // 5 flip-flops, 1 per state
```

**Decoding:** check only ONE bit → single wire, no gate needed.

```
To check if state == W_WRITE_REG:
   state[3]   ← just a single wire! Fastest possible decode.
```

**In case statement (one-hot style):**

```verilog
case (1'b1)    // check which bit is set
    state[0]: ...    // W_IDLE
    state[1]: ...    // W_WAIT_DATA
    state[2]: ...    // W_WAIT_ADDR
    state[3]: ...    // W_WRITE_REG
    state[4]: ...    // W_RESPOND
endcase
```

**Use when:** Speed is priority, moderate states (< 32), FPGA design (Xilinx/Intel).

| | Binary | One-Hot |
|---|---|---|
| Flip-flops used | log₂(N) | N |
| Decode logic | Multi-gate (slower) | Single wire (fastest) |
| Best for | ASIC, many states | FPGA, timing-critical |

---

### Gray Encoding — Low Power

```verilog
localparam IDLE    = 3'b000;
localparam STATE_A = 3'b001;
localparam STATE_B = 3'b011;   // only 1 bit changes per transition
localparam STATE_C = 3'b010;
localparam STATE_D = 3'b110;
```

Only 1 bit changes between adjacent states → fewer switching transitions → less dynamic power and EMI.

**Use when:** Battery-powered or RF-sensitive designs. Rarely used for AXI or RISC-V.

---

### Letting the Tool Choose (with attributes)

```verilog
(* fsm_encoding = "one_hot" *)    reg [4:0] write_state;   // Vivado attribute
(* fsm_encoding = "binary"  *)    reg [2:0] read_state;
(* fsm_encoding = "gray"    *)    reg [2:0] power_state;
```

Vivado automatically extracts FSMs and applies the encoding you specify.
Default in Vivado: `auto` (tool decides based on state count and timing).

---

## 6. Two-Always vs Three-Always FSM Style

### Two Always Blocks — Recommended ✅

Clean separation between sequential (FF update) and combinational (logic decode).

```verilog
// ─── Block 1: Sequential — ONLY updates the state register ────────
always @(posedge clk or negedge resetn) begin
    if (!resetn) state <= W_IDLE;
    else         state <= next_state;
end

// ─── Block 2: Combinational — next state + output logic ───────────
always @(*) begin
    // Set safe defaults first (prevents latches)
    next_state  = state;           // default: hold
    s_axi_bvalid = 1'b0;          // default: 0
    s_axi_bresp  = RESP_OKAY;

    case (1'b1)   // one-hot style
        state[0]: begin   // W_IDLE
            if (awvalid_i && wvalid_i)
                next_state = W_WRITE_REG;
        end

        state[3]: begin   // W_WRITE_REG
            // decode address, compute response
            next_state = W_RESPOND;
        end

        state[4]: begin   // W_RESPOND
            s_axi_bvalid = 1'b1;
            if (s_axi_bready)
                next_state = W_IDLE;
        end
    endcase
end
```

**Pro:** Clean, readable. Standard in Xilinx templates. Easy to lint and synthesize.

---

### Three Always Blocks — More Explicit

```verilog
// Block 1: Sequential — state register only
always @(posedge clk) begin
    state <= next_state;
end

// Block 2: Combinational — next state ONLY
always @(*) begin
    next_state = state;
    case (1'b1)
        state[0]: if (both_valid) next_state = W_WRITE_REG;
        state[3]: next_state = W_RESPOND;
        state[4]: if (s_axi_bready) next_state = W_IDLE;
    endcase
end

// Block 3: Combinational — OUTPUT logic ONLY
always @(*) begin
    s_axi_bvalid = state[4];   // BVALID only in RESPOND state
    s_axi_bresp  = bresp_reg;
end
```

**Pro:** Maximum clarity — you can instantly see what drives each output.
**Con:** More blocks, more code. Sometimes outputs need to be registered separately anyway.

**Recommendation for AXI4-Lite:** Use Two Always style. Outputs should be **registered** (see Section 7) so the third block becomes a sequential block anyway.

---

## 7. Registered vs Combinational Outputs

### Combinational Output — Can Glitch ❌

```verilog
// BAD for AXI — output can briefly glitch during state transitions
always @(*) begin
    case (state)
        W_RESPOND: s_axi_bvalid = 1'b1;
        default:   s_axi_bvalid = 1'b0;
    endcase
end
```

**Problem:** At high clock frequencies, if the state register has any setup/hold timing variation, `bvalid` can briefly pulse incorrectly between clock edges. AXI master might capture a false BVALID. Timing analysis tools flag this as a critical path.

---

### Registered Output — Clean, Glitch-Free ✅

```verilog
// GOOD for AXI — output only changes on clock edge, guaranteed clean
always @(posedge clk or negedge resetn) begin
    if (!resetn)
        s_axi_bvalid <= 1'b0;
    else
        case (1'b1)
            state[4]: s_axi_bvalid <= 1'b1;   // W_RESPOND
            default:  s_axi_bvalid <= 1'b0;
        endcase
end
```

**Output is now a flip-flop** — it only changes on the rising clock edge.
No glitches possible. Clean transitions. Timing analyzers are happy.

**Tradeoff:** Registered output adds 1 cycle of latency (output appears 1 cycle after state enters).
For AXI: this is expected and correct — the AXI spec allows 1-cycle latency on VALID signals.

---

### Rule for AXI Signals

```
MUST be registered (use always @posedge clk):
  AWREADY, WREADY, ARREADY   (handshake ready signals)
  BVALID, RVALID              (response valid signals)
  BRESP, RRESP                (response data)
  RDATA                       (read data)

CAN be combinational (use assign) if simple:
  pwm_out                     (single compare from counter)
  irq                         (AND of ISR and IER bits)
  addr_valid                  (address range check)
```

---

## 8. Where Each Applies — AXI and RISC-V Context

| Signal / Block | Style | Assignment | Why |
|---|---|---|---|
| AXI state register | `always @(posedge clk)` | `<=` | Sequential |
| AXI next-state decode | `always @(*)` | `=` | Combinational |
| AXI VALID/READY outputs | `always @(posedge clk)` | `<=` | Must be registered |
| AXI RDATA, BRESP | `always @(posedge clk)` | `<=` | Registered, glitch-free |
| Address decoder | `always @(*)` | `=` | Pure combinational |
| Simple 1-line logic | `assign` | `=` | Continuous |
| RISC-V pipeline registers | `always @(posedge clk)` | `<=` | Pipeline FFs |
| RISC-V control signals | `always @(*)` | `=` | Combinational decode |
| RISC-V ALU | `always @(*)` | `=` | Pure combinational |
| RISC-V register file read | `assign` or `always @(*)` | — | Combinational read |
| RISC-V register file write | `always @(posedge clk)` | `<=` | Clocked write |
| PWM counter | `always @(posedge clk)` | `<=` | Must count on clock |
| PWM output | `assign` | `=` | 1-line compare |
| Interrupt line | `assign` | `=` | AND of ISR & IER |
| FSM encoding (FPGA) | One-Hot | — | Fastest decode |
| FSM encoding (ASIC) | Binary | — | Fewest FFs |
| Module config | `parameter` | — | Overridable |
| Internal constants | `localparam` | — | Fixed |

---

## 9. Complete Style Guide Template

```verilog
`timescale 1ns / 1ps
//==============================================================================
// Module:      axi4_lite_pwm_slave
// Engineer:    Vignesh D
// Description: AXI4-Lite slave — configurable PWM with interrupt support
//==============================================================================

module axi4_lite_pwm_slave #(
    //── Configurable Parameters (can be overridden by parent) ──────────────
    parameter DATA_WIDTH  = 32,          // AXI data bus: 32 or 64 only
    parameter ADDR_WIDTH  = 32,          // AXI address bus width
    parameter CLK_FREQ_HZ = 12_000_000   // Board clock frequency in Hz
)(
    input  wire                    ACLK,
    input  wire                    ARESETn,
    // ... full port list
);

    //── Internal Constants (not overridable) ─────────────────────────────
    // Write FSM states — One-Hot encoding for FPGA speed
    localparam [4:0] W_IDLE      = 5'b00001;
    localparam [4:0] W_WAIT_DATA = 5'b00010;
    localparam [4:0] W_WAIT_ADDR = 5'b00100;
    localparam [4:0] W_WRITE_REG = 5'b01000;
    localparam [4:0] W_RESPOND   = 5'b10000;

    // Read FSM states — One-Hot
    localparam [2:0] R_IDLE      = 3'b001;
    localparam [2:0] R_DECODE    = 3'b010;
    localparam [2:0] R_SEND_DATA = 3'b100;

    // AXI Response codes
    localparam RESP_OKAY   = 2'b00;
    localparam RESP_SLVERR = 2'b10;

    // Register map — decoded from AWADDR[4:2]
    localparam REG_CTRL    = 3'd0;   // 0x00 — R/W
    localparam REG_PERIOD  = 3'd1;   // 0x04 — R/W
    localparam REG_DUTY    = 3'd2;   // 0x08 — R/W
    localparam REG_STATUS  = 3'd3;   // 0x0C — Read-Only
    localparam REG_IER     = 3'd4;   // 0x10 — R/W
    localparam REG_ISR     = 3'd5;   // 0x14 — Write-1-to-Clear

    //── Internal Registers ───────────────────────────────────────────────
    reg [4:0] write_state;           // write FSM state (one-hot)
    reg [2:0] read_state;            // read FSM state  (one-hot)

    reg [ADDR_WIDTH-1:0] awaddr_latched;
    reg [DATA_WIDTH-1:0] wdata_latched;
    reg [DATA_WIDTH/8-1:0] wstrb_latched;
    reg [ADDR_WIDTH-1:0] araddr_latched;

    reg [31:0] ctrl_reg;
    reg [31:0] period_reg;
    reg [31:0] duty_reg;
    reg [31:0] ier_reg;
    reg [31:0] isr_reg;

    //── Combinational Wires (assign) ─────────────────────────────────────
    wire addr_in_range;
    wire pwm_enable;

    assign addr_in_range = (awaddr_latched[4:2] <= REG_ISR);
    assign pwm_enable    = ctrl_reg[0];

    //── Sequential Block — Write FSM ─────────────────────────────────────
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            write_state    <= W_IDLE;    // <= non-blocking ✅
            s_axi_awready  <= 1'b0;      // <= non-blocking ✅
            s_axi_wready   <= 1'b0;      // <= non-blocking ✅
            s_axi_bvalid   <= 1'b0;      // <= non-blocking ✅
            s_axi_bresp    <= RESP_OKAY; // <= non-blocking ✅
        end else begin
            // (state machine transitions here)
        end
    end

    //── Sequential Block — Read FSM ───────────────────────────────────────
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            read_state    <= R_IDLE;     // <= non-blocking ✅
            s_axi_arready <= 1'b0;       // <= non-blocking ✅
            s_axi_rvalid  <= 1'b0;       // <= non-blocking ✅
            s_axi_rdata   <= 32'b0;      // <= non-blocking ✅
            s_axi_rresp   <= RESP_OKAY;  // <= non-blocking ✅
        end else begin
            // (state machine transitions here)
        end
    end

    //── Combinational — PWM output and interrupt ─────────────────────────
    assign pwm_out = (counter < duty_reg) ? 1'b1 : 1'b0;  // assign ✅
    assign irq     = |(isr_reg & ier_reg);                 // assign ✅

endmodule
```

---

## 10. Golden Rules — Quick Reference

```
ASSIGNMENT:
  always @(posedge clk) → use <=   (non-blocking, flip-flops)
  always @(*)           → use  =   (blocking, gates)
  assign                → use  =   (continuous, gates)
  NEVER mix = and <= in the same always block

ALWAYS BLOCK CHOICE:
  Must hold value between clocks?      → always @(posedge clk)
  Must react instantly to inputs?      → always @(*) or assign
  1 line, purely combinational?        → assign
  Multiple lines or case/if-else?      → always @(*)

PARAMETER vs LOCALPARAM:
  Can parent module change this?       → parameter
  Internal to this module only?        → localparam
  Magic numbers (address, mask, code)? → localparam (never hardcode)

FSM ENCODING:
  FPGA, timing priority, < 32 states? → One-Hot
  ASIC, area priority, many states?   → Binary
  Low power, battery device?          → Gray
  Let Vivado decide?                  → (* fsm_encoding = "auto" *)

OUTPUT STYLE for AXI:
  AXI VALID/READY signals             → MUST be registered (clocked FF)
  AXI RDATA, BRESP, RRESP             → MUST be registered (clocked FF)
  Simple combinational (pwm, irq)     → assign is fine

RESET STYLE:
  Synchronous reset:   always @(posedge clk)          if (!rst)
  Asynchronous reset:  always @(posedge clk or negedge resetn)
  AXI spec uses:       ARESETn — ASYNCHRONOUS active-LOW reset ✅
  Preferred in FPGA:   Synchronous (cleaner timing)
  Preferred in ASIC:   Asynchronous (guaranteed initialization)

DEFAULTS IN always @(*):
  Always set a default value at the TOP of the block before the case:
    next_state = state;     ← prevents unintentional latches
    output_x   = 1'b0;     ← prevents unintentional latches
  A missing default = latch inferred = timing issue in synthesis

LATCH vs FLIP-FLOP:
  Latch:     level-sensitive, inferred from incomplete if/case in always@(*)
             AVOID in synchronous design — causes timing closure problems
  Flip-flop: edge-sensitive, from always @(posedge clk)
             ALWAYS prefer this in synchronous RTL
```

---

*Reference: IEEE Std 1364-2001 (Verilog), Vivado Design Suite User Guide UG901, ARM IHI0022 (AXI4 Spec)*
