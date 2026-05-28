# Universal Decoupled AXI4-Lite Master Design Guide

## 1. Design Philosophy: The Universal Bridge
A professional AXI Master should act as a "Universal Bridge". It should not be hardcoded to a specific peripheral or CPU. Instead, it should provide a simple, old-school memory interface (User Logic Interface) on one side, and translate those simple pulses into complex AXI handshakes on the other side. 

This allows ANY custom hardware (RISC-V CPU, DMA Engine, AI Accelerator) to plug into the Master by simply toggling a `req` signal and waiting for a `done` signal.

## 2. Decoupled Channels vs. Single FSM
Instead of using a single "monolithic" FSM that forces the Address and Data to be sent simultaneously (which is valid but slow/restrictive), an industrial-grade Master decouples the channels. 
The AXI specification states that the Address Write (`AW`) and Data Write (`W`) channels are independent. By using independent control blocks (flags) for `AW`, `W`, and `B`, the Master can accept Address and Data in any order from the CPU, maximizing throughput and preventing deadlocks.

## 3. The Universal Master Shell (Ports)
Here is the perfect standard shell for the Master, using the correct `m_axi_` prefixes and parameterized strobe (`WSTRB`).

```verilog
module axi_lite_master #(
    parameter ADDR_WIDTH = 24,
    parameter DATA_WIDTH = 32
)(    
    // -- Global Clock & Reset --
    input  wire aclk,
    input  wire aresetn,
    
    // ==========================================================
    // USER LOGIC INTERFACE (To command the Master)
    // ==========================================================
    input  wire                  user_wr_req,
    input  wire [ADDR_WIDTH-1:0] user_wr_addr,
    input  wire [DATA_WIDTH-1:0] user_wr_data,
    output reg                   user_wr_done,
    output reg  [1:0]            user_wr_resp,
    
    // ==========================================================
    // AXI4-LITE MASTER INTERFACE
    // ==========================================================
    // -- Write Address Channel (AW) --
    output reg                   m_axi_awvalid,
    input  wire                  m_axi_awready,
    output reg  [ADDR_WIDTH-1:0] m_axi_awaddr,
    output reg  [2:0]            m_axi_awprot,
    
    // -- Write Data Channel (W) --
    output reg                   m_axi_wvalid,
    input  wire                  m_axi_wready,
    output reg  [DATA_WIDTH-1:0] m_axi_wdata,
    output reg  [(DATA_WIDTH/8)-1:0] m_axi_wstrb,
    
    // -- Write Response Channel (B) --
    input  wire                  m_axi_bvalid,
    output reg                   m_axi_bready,
    input  wire [1:0]            m_axi_bresp,
    
    // -- Read Address Channel (AR) --
    output reg                   m_axi_arvalid,
    input  wire                  m_axi_arready,
    output reg  [ADDR_WIDTH-1:0] m_axi_araddr,
    output reg  [2:0]            m_axi_arprot,
    
    // -- Read Data Channel (R) --
    input  wire                  m_axi_rvalid,
    output reg                   m_axi_rready,
    input  wire [DATA_WIDTH-1:0] m_axi_rdata,
    input  wire [1:0]            m_axi_rresp
);
```

## 4. The Decoupled Write Implementation
Here is the standard decoupled Verilog implementation for the write path. It uses internal flags to track completion.

```verilog
    // Internal flags to remember which handshakes have finished
    reg aw_done;
    reg w_done;
    reg b_done;

    // -----------------------------------------------------------
    // 1. The Write Address Channel (AW)
    // -----------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axi_awvalid <= 0;
            aw_done       <= 0;
        end else begin
            // If user requests a write, and AW is not done yet, fire VALID!
            if (user_wr_req && !aw_done && !m_axi_awvalid) begin
                m_axi_awvalid <= 1'b1;
                m_axi_awaddr  <= user_wr_addr;
                m_axi_awprot  <= 3'b000; // Standard data access
            end 
            // When Slave says READY, the address is accepted.
            else if (m_axi_awvalid && m_axi_awready) begin
                m_axi_awvalid <= 1'b0;
                aw_done       <= 1'b1;
            end
            
            // Clear the flag when the whole transaction finishes
            if (b_done) aw_done <= 1'b0;
        end
    end

    // -----------------------------------------------------------
    // 2. The Write Data Channel (W)
    // -----------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axi_wvalid <= 0;
            w_done       <= 0;
        end else begin
            // If user requests a write, and W is not done yet, fire VALID!
            if (user_wr_req && !w_done && !m_axi_wvalid) begin
                m_axi_wvalid <= 1'b1;
                m_axi_wdata  <= user_wr_data;
                m_axi_wstrb  <= {(DATA_WIDTH/8){1'b1}}; // Write all bytes
            end 
            // When Slave says READY, the data is accepted.
            else if (m_axi_wvalid && m_axi_wready) begin
                m_axi_wvalid <= 1'b0;
                w_done       <= 1'b1;
            end
            
            // Clear the flag when the whole transaction finishes
            if (b_done) w_done <= 1'b0;
        end
    end

    // -----------------------------------------------------------
    // 3. The Write Response Channel (B)
    // -----------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axi_bready <= 0;
            b_done       <= 0;
            user_wr_done <= 0;
        end else begin
            user_wr_done <= 0; // Default: don't pulse done unless finished
            b_done       <= 0;
            
            // If both Address and Data are accepted by the slave, ask for response
            if (aw_done && w_done && !m_axi_bready) begin
                m_axi_bready <= 1'b1;
            end 
            // When Slave gives the response...
            else if (m_axi_bready && m_axi_bvalid) begin
                m_axi_bready <= 1'b0;          // Stop asking
                user_wr_resp <= m_axi_bresp;   // Capture the status (00 = OKAY)
                user_wr_done <= 1'b1;          // Pulse DONE to tell the CPU/DMA!
                b_done       <= 1'b1;          // This triggers AW and W to reset
            end
        end
    end
```
