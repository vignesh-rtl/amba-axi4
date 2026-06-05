`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/30/2026 05:54:46 PM
// Design Name: Vignesh D
// Module Name: axi_lite_master
// Project Name: 
// Target Devices: 
// Tool Versions: 2023.1
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module axi_lite_master #(
parameter ADDR_WIDTH=24,
parameter DATA_WIDTH=32
)(    
    input wire aclk,    //m_axi_aclk,
    input wire aresetn, //m_axi_aresetn,
    
    output reg  m_axi_awvalid,
    input  wire m_axi_awready,
    output reg  [ADDR_WIDTH-1:0] m_axi_awaddr,
    output reg  [2:0]  m_axi_awprot,
    
    output reg  m_axi_wvalid,
    input  wire m_axi_wready,
    output reg  [DATA_WIDTH-1:0] m_axi_wdata,
    output reg  [3:0]  m_axi_wstrb,
    
    input  wire m_axi_bvalid,
    output reg  m_axi_bready,
    input  wire [1:0] m_axi_bresp,
    
    output reg  m_axi_arvalid,
    input  wire m_axi_arready,
    output reg  [ADDR_WIDTH-1:0] m_axi_araddr,
    output reg  [2:0]  m_axi_arprot,
    
    input  wire m_axi_rvalid,
    output reg  m_axi_rready,
    input  wire [DATA_WIDTH-1:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    
    //User control
    input  wire                  user_wr_req,
    input  wire [ADDR_WIDTH-1:0] user_wr_addr,
    input  wire [DATA_WIDTH-1:0] user_wr_data,
    output reg                   user_wr_done,
    output reg  [1:0]            user_wr_resp,
    
    input  wire                  user_rd_req,
    input  wire [ADDR_WIDTH-1:0] user_rd_addr,
    output reg  [DATA_WIDTH-1:0] user_rd_data,
    output reg                   user_rd_done,
    output reg  [1:0]            user_rd_resp

    );
    
    reg aw_done;
    reg w_done;
    reg b_done;
    
    reg ar_done;
    reg r_done;
    
    //AW Channel
    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axi_awvalid <= 1'b0;
            m_axi_awaddr  <= 0;
            m_axi_awprot  <= 3'b000;
            aw_done       <= 1'b0;
        end else begin
            //User Trigger
            if (user_wr_req && !aw_done && !m_axi_awvalid) begin
                m_axi_awaddr    <= user_wr_addr;
                m_axi_awvalid   <= 1'b1;
                m_axi_awprot    <= 3'b000;
            end
            else if (m_axi_awvalid && m_axi_awready) begin
                m_axi_awvalid   <= 1'b0;
                aw_done         <= 1'b1;
            end
            if (b_done) begin 
                aw_done         <= 1'b0;
            end
        end
    end
    
    
    //W Channel
    always @(posedge aclk) begin 
        if (!aresetn) begin 
            m_axi_wvalid        <= 1'b0;
            m_axi_wdata         <= 0;
            m_axi_wstrb         <= 1'b0;
            w_done              <= 1'b0;
        end else begin 
            //User Trigger
            if (user_wr_req && !w_done && !m_axi_wvalid) begin 
                m_axi_wdata     <= user_wr_data;
                m_axi_wvalid    <= 1'b1;
                m_axi_wstrb     <= {(DATA_WIDTH/8){1'b1}};
            end
            else if (m_axi_wvalid && m_axi_wready) begin 
                m_axi_wvalid    <= 1'b0;
                w_done          <= 1'b1;
            end
            if (b_done) begin 
                w_done          <= 1'b0;
            end
        end
    end
    
    
    //B Channel
    always  @(posedge aclk) begin 
        if (!aresetn) begin 
            m_axi_bready        <= 1'b0;
            user_wr_done        <= 1'b0;
            user_wr_resp        <= 2'b00;
            b_done              <= 1'b0;
        end else begin 
            //From Slave
            user_wr_done        <= 1'b0;
            b_done              <= 1'b0;
            if (aw_done && w_done && !m_axi_bready) begin
                m_axi_bready    <= 1'b1;
            end
            else if (m_axi_bready && m_axi_bvalid) begin 
                m_axi_bready    <= 1'b0;
                user_wr_resp    <= m_axi_bresp;
                
                user_wr_done    <= 1'b1;
                b_done          <= 1'b1;
            end
        end
    end
    
    
    //R Channel
    always @(posedge aclk) begin 
        if (!aresetn) begin 
            m_axi_arvalid       <= 1'b0;
            m_axi_araddr        <= 0;
            m_axi_arprot        <= 3'b000;
            ar_done              <= 1'b0;
        end else begin 
            if (user_rd_req && !ar_done && !m_axi_arvalid) begin 
                m_axi_arvalid   <= 1'b1;
                m_axi_araddr    <= user_rd_addr;
                m_axi_arprot    <= 3'b000;  
            end
            else if (m_axi_arvalid && m_axi_arready) begin
                m_axi_arvalid   <= 1'b0;
                ar_done          <= 1'b1;
            end
            if (r_done) begin 
                ar_done          <= 1'b0;
            end
        end
    end
    
endmodule
