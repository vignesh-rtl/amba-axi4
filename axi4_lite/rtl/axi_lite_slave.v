`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Vignesh D
// Create Date: 04/14/2026 10:33:43 AM
// Module Name: axi_lite_slave
// Project Name: axi_lite slave RTL design
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


module axi_lite_slave(
    
    input wire s_axi_aclk,
    input wire s_axi_aresetn,
    
    input wire s_axi_awvalid,
    output reg s_axi_awready,
    input wire [23:0] s_axi_awaddr,
    input wire [2:0]  s_axi_awprot,
    
    input wire s_axi_wvalid,
    output reg s_axi_wready,
    input wire [31:0] s_axi_wdata,
    input wire [3:0]  s_axi_wstrb,
    
    output reg s_axi_bvalid,
    input wire s_axi_bready,
    output reg [1:0] s_axi_bresp,
    
    input wire s_axi_arvalid,
    output reg s_axi_arready,
    input wire [23:0] s_axi_araddr,
    input wire [2:0]  s_axi_arprot,
    
    output reg s_axi_rvalid,
    input wire s_axi_rready,
    output reg [31:0] s_axi_rdata,
    output reg [1:0]  s_axi_rresp

    );
    
    
     
    
endmodule

