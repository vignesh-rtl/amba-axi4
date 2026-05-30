`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Vignesh D
// 
// Create Date: 05/30/2026 
// Design Name: Universal AXI4-Lite Master
// Module Name: axi_lite_master
// Project Name: AXI4-Lite Protocol Implementation
// Target Devices: Kria K26 / Cmod S7
// Tool Versions: 2023.1
// Description: A fully decoupled, independent-channel AXI4-Lite Master.
//              Designed for maximum Fmax using registered outputs and 
//              independent AW/W/B and AR/R control blocks.
//////////////////////////////////////////////////////////////////////////////////

module axi_lite_master #(
    parameter ADDR_WIDTH = 24,
    parameter DATA_WIDTH = 32
)(    
    // System Clock and Reset
    input  wire                  aclk,
    input  wire                  aresetn,
    
    // ==========================================
    // USER CONTROL INTERFACE (From CPU / Logic)
    // ==========================================
    // Write Interface
    input  wire                  user_wr_req,
    input  wire [ADDR_WIDTH-1:0] user_wr_addr,
    input  wire [DATA_WIDTH-1:0] user_wr_data,
    output reg                   user_wr_done,
    output reg  [1:0]            user_wr_resp,
    
    // Read Interface
    input  wire                  user_rd_req,
    input  wire [ADDR_WIDTH-1:0] user_rd_addr,
    output reg                   user_rd_done,
    output reg  [DATA_WIDTH-1:0] user_rd_data,
    output reg  [1:0]            user_rd_resp,

    // ==========================================
    // AXI4-LITE MASTER INTERFACE (To Bus/Slave)
    // ==========================================
    // Write Address Channel (AW)
    output reg                   m_axi_awvalid,
    input  wire                  m_axi_awready,
    output reg  [ADDR_WIDTH-1:0] m_axi_awaddr,
    output reg  [2:0]            m_axi_awprot,
    
    // Write Data Channel (W)
    output reg                   m_axi_wvalid,
    input  wire                  m_axi_wready,
    output reg  [DATA_WIDTH-1:0] m_axi_wdata,
    output reg  [3:0]            m_axi_wstrb,
    
    // Write Response Channel (B)
    input  wire                  m_axi_bvalid,
    output reg                   m_axi_bready,
    input  wire [1:0]            m_axi_bresp,
    
    // Read Address Channel (AR)
    output reg                   m_axi_arvalid,
    input  wire                  m_axi_arready,
    output reg  [ADDR_WIDTH-1:0] m_axi_araddr,
    output reg  [2:0]            m_axi_arprot,
    
    // Read Data Channel (R)
    input  wire                  m_axi_rvalid,
    output reg                   m_axi_rready,
    input  wire [DATA_WIDTH-1:0] m_axi_rdata,
    input  wire [1:0]            m_axi_rresp
);

    // =========================================================================
    // INTERNAL TRACKING FLAGS
    // =========================================================================
    // We use these flags to track which channels have finished their handshakes.
    reg aw_done;
    reg w_done;
    reg b_done;
    
    reg ar_done;
    reg r_done;

    // =========================================================================
    // WRITE TRANSACTION CHANNELS (AW, W, B)
    // =========================================================================
    
    // ----------------------------------------------------
    // 1. Write Address Channel (AW)
    // ----------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axi_awvalid <= 1'b0;
            m_axi_awaddr  <= 0;
            m_axi_awprot  <= 3'b000;
            aw_done       <= 1'b0;
        end else begin
            // Trigger: User requests write, and AW hasn't finished yet
            if (user_wr_req && !aw_done && !m_axi_awvalid) begin
                m_axi_awvalid <= 1'b1;
                m_axi_awaddr  <= user_wr_addr;
                m_axi_awprot  <= 3'b000; // Unprivileged, Secure, Data access
            end 
            // Handshake: Slave accepts the address
            else if (m_axi_awvalid && m_axi_awready) begin
                m_axi_awvalid <= 1'b0;
                aw_done       <= 1'b1;
            end
            
            // Reset flag when the entire write transaction finishes
            if (b_done) begin
                aw_done <= 1'b0;
            end
        end
    end

    // ----------------------------------------------------
    // 2. Write Data Channel (W)
    // ----------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axi_wvalid <= 1'b0;
            m_axi_wdata  <= 0;
            m_axi_wstrb  <= 0;
            w_done       <= 1'b0;
        end else begin
            // Trigger: User requests write, and W hasn't finished yet
            if (user_wr_req && !w_done && !m_axi_wvalid) begin
                m_axi_wvalid <= 1'b1;
                m_axi_wdata  <= user_wr_data;
                m_axi_wstrb  <= {(DATA_WIDTH/8){1'b1}}; // Enable all bytes
            end 
            // Handshake: Slave accepts the data
            else if (m_axi_wvalid && m_axi_wready) begin
                m_axi_wvalid <= 1'b0;
                w_done       <= 1'b1;
            end
            
            // Reset flag when the entire write transaction finishes
            if (b_done) begin
                w_done <= 1'b0;
            end
        end
    end

    // ----------------------------------------------------
    // 3. Write Response Channel (B)
    // ----------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axi_bready <= 1'b0;
            user_wr_done <= 1'b0;
            user_wr_resp <= 2'b00;
            b_done       <= 1'b0;
        end else begin
            // Pulse logic: Only assert done for exactly 1 cycle
            user_wr_done <= 1'b0; 
            b_done       <= 1'b0;
            
            // Trigger: Both Address and Data have been accepted
            if (aw_done && w_done && !m_axi_bready) begin
                m_axi_bready <= 1'b1;
            end 
            // Handshake: Slave sends the write response
            else if (m_axi_bready && m_axi_bvalid) begin
                m_axi_bready <= 1'b0;
                user_wr_resp <= m_axi_bresp;
                
                // Signal completion to User and reset AW/W blocks
                user_wr_done <= 1'b1;
                b_done       <= 1'b1;
            end
        end
    end

    // =========================================================================
    // READ TRANSACTION CHANNELS (AR, R)
    // =========================================================================
    
    // ----------------------------------------------------
    // 4. Read Address Channel (AR)
    // ----------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axi_arvalid <= 1'b0;
            m_axi_araddr  <= 0;
            m_axi_arprot  <= 3'b000;
            ar_done       <= 1'b0;
        end else begin
            // Trigger: User requests read, and AR hasn't finished yet
            if (user_rd_req && !ar_done && !m_axi_arvalid) begin
                m_axi_arvalid <= 1'b1;
                m_axi_araddr  <= user_rd_addr;
                m_axi_arprot  <= 3'b000;
            end 
            // Handshake: Slave accepts the read address
            else if (m_axi_arvalid && m_axi_arready) begin
                m_axi_arvalid <= 1'b0;
                ar_done       <= 1'b1;
            end
            
            // Reset flag when the entire read transaction finishes
            if (r_done) begin
                ar_done <= 1'b0;
            end
        end
    end

    // ----------------------------------------------------
    // 5. Read Data & Response Channel (R)
    // ----------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axi_rready <= 1'b0;
            user_rd_data <= 0;
            user_rd_resp <= 2'b00;
            user_rd_done <= 1'b0;
            r_done       <= 1'b0;
        end else begin
            // Pulse logic: Only assert done for exactly 1 cycle
            user_rd_done <= 1'b0;
            r_done       <= 1'b0;
            
            // Trigger: Address has been accepted, wait for read data
            if (ar_done && !m_axi_rready) begin
                m_axi_rready <= 1'b1;
            end 
            // Handshake: Slave sends data and response
            else if (m_axi_rready && m_axi_rvalid) begin
                m_axi_rready <= 1'b0;
                user_rd_data <= m_axi_rdata;
                user_rd_resp <= m_axi_rresp;
                
                // Signal completion to User and reset AR block
                user_rd_done <= 1'b1;
                r_done       <= 1'b1;
            end
        end
    end

endmodule
