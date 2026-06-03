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
    input wire s_axi_aclk,
    input wire s_axi_aresetn,
    
    output reg  s_axi_awvalid,
    input  wire s_axi_awready,
    output reg  [ADDR_WIDTH-1:0] s_axi_awaddr,
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
    
endmodule
