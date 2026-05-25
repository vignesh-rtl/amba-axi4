`timescale 1ns / 1ps
//==============================================================================
// Module:      axi_lite_slave
// Engineer:    Vignesh D
// Create Date: 2026-05-25
// Description: AXI4-Lite Slave with 4-register bank.
//              Designed for learning AXI4-Lite protocol handshake.
//              Uses single-always FSM style — all outputs are registered.
//
// Register Map:
//   Offset 0x00  REG_0   R/W   General purpose scratch register
//   Offset 0x04  REG_1   R/W   General purpose scratch register
//   Offset 0x08  REG_2   R/W   General purpose scratch register
//   Offset 0x0C  REG_3   R/O   Read-only status (returns 0xDEADBEEF)
//
// Design Decisions:
//   - Single-always FSM: safer for beginners, all outputs registered
//   - One-hot FSM encoding: fastest decode on FPGA
//   - Separate write and read FSMs: they are independent in AXI
//   - SLVERR returned for: write to read-only REG_3, out-of-range address
//
// AXI4-Lite Compliance:
//   - Handles AWVALID before WVALID, WVALID before AWVALID, and both together
//   - All VALID/READY outputs are registered (no combinational glitches)
//   - WSTRB byte-enable supported on all R/W registers
//   - BRESP: OKAY (2'b00) or SLVERR (2'b10) only — no EXOKAY per spec
//==============================================================================

module axi_lite_slave #(
    // ── Configurable Parameters ─────────────────────────────────────────
    // These can be overridden when instantiating the module.
    // Use 'parameter' because a parent module might need different values.
    parameter ADDR_WIDTH = 24,       // Address bus width (interconnect sets this)
    parameter DATA_WIDTH = 32        // AXI4-Lite: only 32 or 64 allowed by spec
)(
    // ── Global Signals ──────────────────────────────────────────────────
    input  wire                        s_axi_aclk,
    input  wire                        s_axi_aresetn,   // Active-LOW async reset

    // ── Write Address Channel (AW) ──────────────────────────────────────
    // Master drives: AWADDR, AWPROT, AWVALID
    // Slave drives:  AWREADY
    input  wire [ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  wire [2:0]                  s_axi_awprot,    // Accept but don't use
    input  wire                        s_axi_awvalid,
    output reg                         s_axi_awready,

    // ── Write Data Channel (W) ──────────────────────────────────────────
    // Master drives: WDATA, WSTRB, WVALID
    // Slave drives:  WREADY
    input  wire [DATA_WIDTH-1:0]       s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]     s_axi_wstrb,     // Byte enables
    input  wire                        s_axi_wvalid,
    output reg                         s_axi_wready,

    // ── Write Response Channel (B) ──────────────────────────────────────
    // Slave drives:  BRESP, BVALID
    // Master drives: BREADY
    output reg  [1:0]                  s_axi_bresp,
    output reg                         s_axi_bvalid,
    input  wire                        s_axi_bready,

    // ── Read Address Channel (AR) ───────────────────────────────────────
    // Master drives: ARADDR, ARPROT, ARVALID
    // Slave drives:  ARREADY
    input  wire [ADDR_WIDTH-1:0]       s_axi_araddr,
    input  wire [2:0]                  s_axi_arprot,    // Accept but don't use
    input  wire                        s_axi_arvalid,
    output reg                         s_axi_arready,

    // ── Read Data Channel (R) ───────────────────────────────────────────
    // Slave drives:  RDATA, RRESP, RVALID
    // Master drives: RREADY
    output reg  [DATA_WIDTH-1:0]       s_axi_rdata,
    output reg  [1:0]                  s_axi_rresp,
    output reg                         s_axi_rvalid,
    input  wire                        s_axi_rready
);

    // ════════════════════════════════════════════════════════════════════
    // LOCAL PARAMETERS — Internal constants, NOT overridable
    // ════════════════════════════════════════════════════════════════════

    // ── Write FSM States (One-Hot for FPGA speed) ───────────────────────
    // Each state is 1 bit. Only ONE bit is HIGH at any time.
    // Decode = check single bit. No multi-input AND gate needed.
    localparam [4:0] W_IDLE      = 5'b00001;  // Ready for new transaction
    localparam [4:0] W_WAIT_DATA = 5'b00010;  // Got addr, waiting for data
    localparam [4:0] W_WAIT_ADDR = 5'b00100;  // Got data, waiting for addr
    localparam [4:0] W_WRITE     = 5'b01000;  // Both received, do the write
    localparam [4:0] W_RESPOND   = 5'b10000;  // Send BRESP back to master

    // ── Read FSM States (One-Hot) ───────────────────────────────────────
    localparam [2:0] R_IDLE      = 3'b001;    // Ready for read address
    localparam [2:0] R_READ      = 3'b010;    // Decode addr, fetch reg data
    localparam [2:0] R_RESPOND   = 3'b100;    // Send RDATA + RRESP to master

    // ── AXI Response Codes ──────────────────────────────────────────────
    // Only OKAY and SLVERR are valid in AXI4-Lite (no EXOKAY).
    localparam RESP_OKAY   = 2'b00;
    localparam RESP_SLVERR = 2'b10;

    // ── Register Address Decode ─────────────────────────────────────────
    // Bits [1:0] are always 00 for 32-bit aligned access.
    // Bits [3:2] select which register (2 bits = 4 registers).
    // Bits [ADDR_WIDTH-1:4] are used by interconnect for slave selection.
    localparam REG_0_ADDR = 2'd0;   // Offset 0x00
    localparam REG_1_ADDR = 2'd1;   // Offset 0x04
    localparam REG_2_ADDR = 2'd2;   // Offset 0x08
    localparam REG_3_ADDR = 2'd3;   // Offset 0x0C (Read-Only)

    // ── Read-Only Register Value ────────────────────────────────────────
    localparam REG_3_HARDWIRED = 32'hDEAD_BEEF;  // Debug marker value

    // ════════════════════════════════════════════════════════════════════
    // INTERNAL REGISTERS AND WIRES
    // ════════════════════════════════════════════════════════════════════

    // ── FSM State Registers ─────────────────────────────────────────────
    reg [4:0] w_state;               // Write FSM current state (one-hot)
    reg [2:0] r_state;               // Read FSM current state (one-hot)

    // ── Latched AXI Signals ─────────────────────────────────────────────
    // WHY: After the VALID/READY handshake completes, the master is
    //       allowed to change AWADDR/WDATA on the very next cycle.
    //       We must capture them into internal registers at the moment
    //       the handshake completes, so we have stable copies to use
    //       in the WRITE/READ states.
    reg [ADDR_WIDTH-1:0]   aw_addr_latched;
    reg [DATA_WIDTH-1:0]   w_data_latched;
    reg [DATA_WIDTH/8-1:0] w_strb_latched;
    reg [ADDR_WIDTH-1:0]   ar_addr_latched;

    // ── User Registers (the actual register bank) ───────────────────────
    reg [DATA_WIDTH-1:0]   reg_0;    // R/W — scratch register
    reg [DATA_WIDTH-1:0]   reg_1;    // R/W — scratch register
    reg [DATA_WIDTH-1:0]   reg_2;    // R/W — scratch register
    // reg_3 is read-only — no storage needed, it's a localparam constant

    // ── Address Decode Helpers ──────────────────────────────────────────
    // Extract the register select bits from latched addresses.
    // Using wires with assign keeps these as simple combinational.
    wire [1:0] aw_reg_sel;
    wire [1:0] ar_reg_sel;
    wire       aw_addr_valid;
    wire       ar_addr_valid;

    assign aw_reg_sel    = aw_addr_latched[3:2];
    assign ar_reg_sel    = ar_addr_latched[3:2];
    assign aw_addr_valid = (aw_addr_latched[ADDR_WIDTH-1:4] == {(ADDR_WIDTH-4){1'b0}});
    assign ar_addr_valid = (ar_addr_latched[ADDR_WIDTH-1:4] == {(ADDR_WIDTH-4){1'b0}});

    // ════════════════════════════════════════════════════════════════════
    // WRITE PATH FSM — Single-Always Style
    // ════════════════════════════════════════════════════════════════════
    //
    // All outputs (AWREADY, WREADY, BVALID, BRESP) are driven from
    // a clocked always block → they are flip-flop outputs → glitch-free.
    //
    // State flow:
    //   IDLE ──┬── both valid ──► WRITE ──► RESPOND ──► IDLE
    //          ├── aw only   ──► WAIT_DATA ──► WRITE ...
    //          └── w only    ──► WAIT_ADDR ──► WRITE ...
    //
    // ════════════════════════════════════════════════════════════════════

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            // ── RESET: Set all outputs to safe defaults ─────────────
            // WHY active-low async reset: AXI spec defines ARESETn as
            //     asynchronous active-low. All VALID signals must be 0
            //     during reset. READY signals should also be 0 during
            //     reset to prevent accidental handshakes.
            w_state         <= W_IDLE;
            s_axi_awready   <= 1'b0;
            s_axi_wready    <= 1'b0;
            s_axi_bvalid    <= 1'b0;
            s_axi_bresp     <= RESP_OKAY;
            aw_addr_latched <= {ADDR_WIDTH{1'b0}};
            w_data_latched  <= {DATA_WIDTH{1'b0}};
            w_strb_latched  <= {(DATA_WIDTH/8){1'b0}};
            reg_0           <= 32'h0;
            reg_1           <= 32'h0;
            reg_2           <= 32'h0;

        end else begin
            case (w_state)

                // ────────────────────────────────────────────────────
                // W_IDLE: Ready to accept new write transaction
                // ────────────────────────────────────────────────────
                W_IDLE: begin
                    // Assert READY on both channels — we can accept
                    s_axi_awready <= 1'b1;
                    s_axi_wready  <= 1'b1;
                    s_axi_bvalid  <= 1'b0;   // No response pending

                    // Case 1: BOTH address and data arrive on same cycle
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        aw_addr_latched <= s_axi_awaddr;   // Sample address
                        w_data_latched  <= s_axi_wdata;    // Sample data
                        w_strb_latched  <= s_axi_wstrb;    // Sample strobes
                        s_axi_awready   <= 1'b0;           // Handshake done
                        s_axi_wready    <= 1'b0;           // Handshake done
                        w_state         <= W_WRITE;        // Go write
                    end

                    // Case 2: Only ADDRESS arrives first
                    else if (s_axi_awvalid && !s_axi_wvalid) begin
                        aw_addr_latched <= s_axi_awaddr;   // Sample address
                        s_axi_awready   <= 1'b0;           // AW handshake done
                        // WREADY stays 1 — still waiting for data
                        w_state         <= W_WAIT_DATA;
                    end

                    // Case 3: Only DATA arrives first
                    else if (s_axi_wvalid && !s_axi_awvalid) begin
                        w_data_latched  <= s_axi_wdata;    // Sample data
                        w_strb_latched  <= s_axi_wstrb;    // Sample strobes
                        s_axi_wready    <= 1'b0;           // W handshake done
                        // AWREADY stays 1 — still waiting for address
                        w_state         <= W_WAIT_ADDR;
                    end
                end

                // ────────────────────────────────────────────────────
                // W_WAIT_DATA: Address received, waiting for data
                // ────────────────────────────────────────────────────
                W_WAIT_DATA: begin
                    if (s_axi_wvalid) begin
                        w_data_latched <= s_axi_wdata;     // Sample data
                        w_strb_latched <= s_axi_wstrb;     // Sample strobes
                        s_axi_wready   <= 1'b0;            // W handshake done
                        w_state        <= W_WRITE;         // Both ready → write
                    end
                    // else: stay here, WREADY is still 1
                end

                // ────────────────────────────────────────────────────
                // W_WAIT_ADDR: Data received, waiting for address
                // ────────────────────────────────────────────────────
                W_WAIT_ADDR: begin
                    if (s_axi_awvalid) begin
                        aw_addr_latched <= s_axi_awaddr;   // Sample address
                        s_axi_awready   <= 1'b0;           // AW handshake done
                        w_state         <= W_WRITE;        // Both ready → write
                    end
                    // else: stay here, AWREADY is still 1
                end

                // ────────────────────────────────────────────────────
                // W_WRITE: Both address and data are latched. Do the
                //          register write and determine BRESP.
                // ────────────────────────────────────────────────────
                W_WRITE: begin
                    // Default: assume error until proven otherwise
                    s_axi_bresp <= RESP_SLVERR;

                    if (aw_addr_valid) begin
                        case (aw_reg_sel)
                            // ── REG_0 at 0x00: R/W ─────────────────
                            REG_0_ADDR: begin
                                // Apply WSTRB byte enables:
                                // Only write bytes where strobe bit = 1
                                if (w_strb_latched[0]) reg_0[ 7: 0] <= w_data_latched[ 7: 0];
                                if (w_strb_latched[1]) reg_0[15: 8] <= w_data_latched[15: 8];
                                if (w_strb_latched[2]) reg_0[23:16] <= w_data_latched[23:16];
                                if (w_strb_latched[3]) reg_0[31:24] <= w_data_latched[31:24];
                                s_axi_bresp <= RESP_OKAY;
                            end

                            // ── REG_1 at 0x04: R/W ─────────────────
                            REG_1_ADDR: begin
                                if (w_strb_latched[0]) reg_1[ 7: 0] <= w_data_latched[ 7: 0];
                                if (w_strb_latched[1]) reg_1[15: 8] <= w_data_latched[15: 8];
                                if (w_strb_latched[2]) reg_1[23:16] <= w_data_latched[23:16];
                                if (w_strb_latched[3]) reg_1[31:24] <= w_data_latched[31:24];
                                s_axi_bresp <= RESP_OKAY;
                            end

                            // ── REG_2 at 0x08: R/W ─────────────────
                            REG_2_ADDR: begin
                                if (w_strb_latched[0]) reg_2[ 7: 0] <= w_data_latched[ 7: 0];
                                if (w_strb_latched[1]) reg_2[15: 8] <= w_data_latched[15: 8];
                                if (w_strb_latched[2]) reg_2[23:16] <= w_data_latched[23:16];
                                if (w_strb_latched[3]) reg_2[31:24] <= w_data_latched[31:24];
                                s_axi_bresp <= RESP_OKAY;
                            end

                            // ── REG_3 at 0x0C: READ-ONLY ───────────
                            // Writing to a read-only register = error
                            // Don't modify anything, return SLVERR
                            REG_3_ADDR: begin
                                s_axi_bresp <= RESP_SLVERR;
                            end

                            // ── Default: address decoded but unknown
                            default: begin
                                s_axi_bresp <= RESP_SLVERR;
                            end
                        endcase
                    end
                    // else: aw_addr_valid is false → SLVERR (default set above)

                    // Always move to RESPOND regardless of error
                    s_axi_bvalid <= 1'b1;
                    w_state      <= W_RESPOND;
                end

                // ────────────────────────────────────────────────────
                // W_RESPOND: BVALID is asserted. Wait for master to
                //            acknowledge with BREADY.
                // ────────────────────────────────────────────────────
                W_RESPOND: begin
                    if (s_axi_bready) begin
                        // Master accepted the response
                        s_axi_bvalid <= 1'b0;   // De-assert BVALID
                        w_state      <= W_IDLE;  // Ready for next transaction
                    end
                    // else: hold BVALID=1 and BRESP stable until BREADY
                    // AXI Rule 3: VALID must stay high until READY goes high
                end

                // ── Safety: go to IDLE on unknown state ─────────────
                default: begin
                    w_state       <= W_IDLE;
                    s_axi_awready <= 1'b0;
                    s_axi_wready  <= 1'b0;
                    s_axi_bvalid  <= 1'b0;
                end

            endcase
        end
    end

    // ════════════════════════════════════════════════════════════════════
    // READ PATH FSM — Single-Always Style
    // ════════════════════════════════════════════════════════════════════
    //
    // The read path is independent of the write path.
    // Both FSMs run in parallel on the same clock.
    //
    // State flow:
    //   IDLE ──► (ARVALID) ──► READ (decode + fetch) ──► RESPOND ──► IDLE
    //
    // ════════════════════════════════════════════════════════════════════

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            r_state         <= R_IDLE;
            s_axi_arready   <= 1'b0;
            s_axi_rvalid    <= 1'b0;
            s_axi_rdata     <= {DATA_WIDTH{1'b0}};
            s_axi_rresp     <= RESP_OKAY;
            ar_addr_latched <= {ADDR_WIDTH{1'b0}};

        end else begin
            case (r_state)

                // ────────────────────────────────────────────────────
                // R_IDLE: Ready to accept read address
                // ────────────────────────────────────────────────────
                R_IDLE: begin
                    s_axi_arready <= 1'b1;   // Ready for address
                    s_axi_rvalid  <= 1'b0;   // No data yet

                    if (s_axi_arvalid) begin
                        ar_addr_latched <= s_axi_araddr;   // Sample address
                        s_axi_arready   <= 1'b0;           // Handshake done
                        r_state         <= R_READ;
                    end
                end

                // ────────────────────────────────────────────────────
                // R_READ: Decode address and load register value
                // ────────────────────────────────────────────────────
                R_READ: begin
                    // Default: error response with debug marker
                    s_axi_rdata <= 32'hBAD_ACCE5;
                    s_axi_rresp <= RESP_SLVERR;

                    if (ar_addr_valid) begin
                        case (ar_reg_sel)
                            REG_0_ADDR: begin
                                s_axi_rdata <= reg_0;
                                s_axi_rresp <= RESP_OKAY;
                            end
                            REG_1_ADDR: begin
                                s_axi_rdata <= reg_1;
                                s_axi_rresp <= RESP_OKAY;
                            end
                            REG_2_ADDR: begin
                                s_axi_rdata <= reg_2;
                                s_axi_rresp <= RESP_OKAY;
                            end
                            REG_3_ADDR: begin
                                s_axi_rdata <= REG_3_HARDWIRED;  // 0xDEADBEEF
                                s_axi_rresp <= RESP_OKAY;
                            end
                            default: begin
                                s_axi_rdata <= 32'hBAD_ACCE5;
                                s_axi_rresp <= RESP_SLVERR;
                            end
                        endcase
                    end
                    // else: ar_addr_valid false → SLVERR (default set above)

                    s_axi_rvalid <= 1'b1;    // Data is ready
                    r_state      <= R_RESPOND;
                end

                // ────────────────────────────────────────────────────
                // R_RESPOND: RVALID asserted. Wait for master RREADY.
                // ────────────────────────────────────────────────────
                R_RESPOND: begin
                    if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;    // De-assert RVALID
                        r_state      <= R_IDLE;   // Ready for next
                    end
                    // else: hold RVALID=1, RDATA, RRESP stable until RREADY
                end

                // ── Safety default ──────────────────────────────────
                default: begin
                    r_state       <= R_IDLE;
                    s_axi_arready <= 1'b0;
                    s_axi_rvalid  <= 1'b0;
                end

            endcase
        end
    end

endmodule
