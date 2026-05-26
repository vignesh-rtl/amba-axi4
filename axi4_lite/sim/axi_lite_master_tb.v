`timescale 1ns / 1ps
//==============================================================================
// Module:      axi_lite_master_tb
// Engineer:    Vignesh D
// Description: Professional AXI4-Lite Master Testbench (BFM).
//              This testbench mimics a CPU or DMA controller by initiating
//              AXI4-Lite transactions to verify the slave IP.
//
// Features:
//   - Encapsulated AXI Write and Read tasks
//   - Self-checking tests with [PASS]/[FAIL] logging
//   - Tests normal R/W, WSTRB (Byte enables), and Read-Only violations
//   - Tests Out-of-Bounds addressing (SLVERR)
//==============================================================================

module axi_lite_master_tb;

    // ── Configuration Parameters ─────────────────────────────────────────
    parameter ADDR_WIDTH = 24;
    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10; // 100 MHz clock

    // ── Global Signals ──────────────────────────────────────────────────
    reg aclk;
    reg aresetn;

    // ── AXI4-Lite Master Signals ────────────────────────────────────────
    // AW Channel
    reg  [ADDR_WIDTH-1:0]   awaddr;
    reg  [2:0]              awprot;
    reg                     awvalid;
    wire                    awready;
    // W Channel
    reg  [DATA_WIDTH-1:0]   wdata;
    reg  [DATA_WIDTH/8-1:0] wstrb;
    reg                     wvalid;
    wire                    wready;
    // B Channel
    wire [1:0]              bresp;
    wire                    bvalid;
    reg                     bready;
    // AR Channel
    reg  [ADDR_WIDTH-1:0]   araddr;
    reg  [2:0]              arprot;
    reg                     arvalid;
    wire                    arready;
    // R Channel
    wire [DATA_WIDTH-1:0]   rdata;
    wire [1:0]              rresp;
    wire                    rvalid;
    reg                     rready;

    // ── Testbench Variables ─────────────────────────────────────────────
    integer error_count = 0;
    reg [31:0] read_data_out;
    reg [1:0]  resp_out;

    // ── Instantiate the Slave IP (Device Under Test) ────────────────────
    axi_lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) DUT (
        .s_axi_aclk    (aclk),
        .s_axi_aresetn (aresetn),
        
        .s_axi_awaddr  (awaddr),
        .s_axi_awprot  (awprot),
        .s_axi_awvalid (awvalid),
        .s_axi_awready (awready),
        
        .s_axi_wdata   (wdata),
        .s_axi_wstrb   (wstrb),
        .s_axi_wvalid  (wvalid),
        .s_axi_wready  (wready),
        
        .s_axi_bresp   (bresp),
        .s_axi_bvalid  (bvalid),
        .s_axi_bready  (bready),
        
        .s_axi_araddr  (araddr),
        .s_axi_arprot  (arprot),
        .s_axi_arvalid (arvalid),
        .s_axi_arready (arready),
        
        .s_axi_rdata   (rdata),
        .s_axi_rresp   (rresp),
        .s_axi_rvalid  (rvalid),
        .s_axi_rready  (rready)
    );

    // ── Clock Generation ────────────────────────────────────────────────
    initial begin
        aclk = 0;
        forever #(CLK_PERIOD/2) aclk = ~aclk;
    end

    // ════════════════════════════════════════════════════════════════════
    // AXI MASTER TASKS (Bus Functional Models)
    // ════════════════════════════════════════════════════════════════════

    // ── TASK: Initialize Bus ────────────────────────────────────────────
    task init_bus();
    begin
        awaddr  = 0;
        awprot  = 0;
        awvalid = 0;
        wdata   = 0;
        wstrb   = 0;
        wvalid  = 0;
        bready  = 0;
        araddr  = 0;
        arprot  = 0;
        arvalid = 0;
        rready  = 0;
    end
    endtask

    // ── TASK: AXI4-Lite Write Transaction ───────────────────────────────
    task axi_write(
        input  [ADDR_WIDTH-1:0] addr_in,
        input  [DATA_WIDTH-1:0] data_in,
        input  [3:0]            strb_in,
        output [1:0]            resp_out
    );
    begin
        // 1. Drive Address and Data channels simultaneously
        @(posedge aclk);
        awaddr  <= addr_in;
        awvalid <= 1'b1;
        wdata   <= data_in;
        wstrb   <= strb_in;
        wvalid  <= 1'b1;
        bready  <= 1'b1;  // We are ready to accept the response

        // 2. Wait for Slave to accept Address (AWREADY)
        fork
            begin : wait_awready
                wait(awready == 1'b1);
                @(posedge aclk);
                awvalid <= 1'b0;
            end
            // 3. Wait for Slave to accept Data (WREADY)
            begin : wait_wready
                wait(wready == 1'b1);
                @(posedge aclk);
                wvalid <= 1'b0;
            end
        join

        // 4. Wait for Write Response (BVALID)
        wait(bvalid == 1'b1);
        @(posedge aclk);
        resp_out = bresp; // Capture the response (OKAY or SLVERR)
        bready <= 1'b0;    // Finish handshake
    end
    endtask

    // ── TASK: AXI4-Lite Read Transaction ────────────────────────────────
    task axi_read(
        input  [ADDR_WIDTH-1:0] addr_in,
        output [DATA_WIDTH-1:0] data_out,
        output [1:0]            resp_out
    );
    begin
        // 1. Drive Read Address channel
        @(posedge aclk);
        araddr  <= addr_in;
        arvalid <= 1'b1;
        rready  <= 1'b1;  // Ready to accept read data

        // 2. Wait for Slave to accept Address (ARREADY)
        wait(arready == 1'b1);
        @(posedge aclk);
        arvalid <= 1'b0;

        // 3. Wait for Read Data and Response (RVALID)
        wait(rvalid == 1'b1);
        @(posedge aclk);
        data_out = rdata; // Capture the read data
        resp_out = rresp; // Capture the response code
        rready   <= 1'b0;  // Finish handshake
    end
    endtask

    // ════════════════════════════════════════════════════════════════════
    // MAIN TEST SEQUENCE
    // ════════════════════════════════════════════════════════════════════

    initial begin
        $dumpfile("axi_lite_sim.vcd");
        $dumpvars(0, axi_lite_master_tb);
        
        // 1. Apply Reset
        $display("==================================================");
        $display("   STARTING AXI4-LITE SLAVE VERIFICATION          ");
        $display("==================================================");
        aresetn = 0;
        init_bus();
        #(CLK_PERIOD * 5);
        aresetn = 1;
        #(CLK_PERIOD * 5);

        // -----------------------------------------------------------------
        // TEST 1: Standard Write & Read (REG_0 at 0x00)
        // -----------------------------------------------------------------
        $display("\n[TEST 1] Standard R/W to REG_0 (0x00)");
        axi_write(24'h000000, 32'h11223344, 4'b1111, resp_out);
        if (resp_out !== 2'b00) begin
            $display("  [FAIL] Write returned error response! Expected 00, got %b", resp_out);
            error_count = error_count + 1;
        end

        axi_read(24'h000000, read_data_out, resp_out);
        if (read_data_out === 32'h11223344 && resp_out === 2'b00)
            $display("  [PASS] Read successful. Data: %h", read_data_out);
        else begin
            $display("  [FAIL] Read mismatch! Expected 11223344, got %h", read_data_out);
            error_count = error_count + 1;
        end

        // -----------------------------------------------------------------
        // TEST 2: WSTRB Byte Enable Test (REG_1 at 0x04)
        // -----------------------------------------------------------------
        $display("\n[TEST 2] WSTRB Byte Enable to REG_1 (0x04)");
        // Write all 0s first
        axi_write(24'h000004, 32'h00000000, 4'b1111, resp_out);
        // Write all 1s, but only enable Top and Bottom bytes (WSTRB = 1001)
        axi_write(24'h000004, 32'hFFFFFFFF, 4'b1001, resp_out);
        
        axi_read(24'h000004, read_data_out, resp_out);
        if (read_data_out === 32'hFF0000FF)
            $display("  [PASS] WSTRB logic correct. Data: %h", read_data_out);
        else begin
            $display("  [FAIL] WSTRB failed! Expected FF0000FF, got %h", read_data_out);
            error_count = error_count + 1;
        end

        // -----------------------------------------------------------------
        // TEST 3: Write to Read-Only Register (REG_3 at 0x0C)
        // -----------------------------------------------------------------
        $display("\n[TEST 3] Write to Read-Only Register REG_3 (0x0C)");
        axi_write(24'h00000C, 32'h99999999, 4'b1111, resp_out);
        if (resp_out === 2'b10)
            $display("  [PASS] Slave correctly rejected write with SLVERR.");
        else begin
            $display("  [FAIL] Slave accepted read-only write! Response: %b", resp_out);
            error_count = error_count + 1;
        end

        axi_read(24'h00000C, read_data_out, resp_out);
        if (read_data_out === 32'hDEADBEEF)
            $display("  [PASS] Read-Only Register data untouched: %h", read_data_out);
        else begin
            $display("  [FAIL] Read-Only Register was corrupted! Data: %h", read_data_out);
            error_count = error_count + 1;
        end

        // -----------------------------------------------------------------
        // TEST 4: Out of Bounds Address
        // -----------------------------------------------------------------
        $display("\n[TEST 4] Out of Bounds Address (0x10)");
        axi_write(24'h000010, 32'hAAAAAAAA, 4'b1111, resp_out);
        if (resp_out === 2'b10)
            $display("  [PASS] Slave rejected out-of-bounds WRITE with SLVERR.");
        else begin
            $display("  [FAIL] Slave accepted out-of-bounds WRITE!");
            error_count = error_count + 1;
        end

        axi_read(24'h000010, read_data_out, resp_out);
        if (resp_out === 2'b10 && read_data_out === 32'hBADACCE5)
            $display("  [PASS] Slave rejected out-of-bounds READ with SLVERR and BAD_ACCE5.");
        else begin
            $display("  [FAIL] Slave failed out-of-bounds READ check! Resp: %b, Data: %h", resp_out, read_data_out);
            error_count = error_count + 1;
        end

        // -----------------------------------------------------------------
        // TEST SUMMARY
        // -----------------------------------------------------------------
        $display("\n==================================================");
        if (error_count == 0)
            $display("   ALL TESTS PASSED SUCCESSFULLY!                 ");
        else
            $display("   FAILED %0d TESTS!                              ", error_count);
        $display("==================================================\n");

        #(CLK_PERIOD * 10);
        $finish;
    end

endmodule
