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


module axi_lite_slave #(
parameter ADDR_WIDTH=24,
parameter DATA_WIDTH=32
)(    
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
    
    //Write sequence and responce FSM
    localparam [4:0] W_IDLE      = 5'b00001;
    localparam [4:0] W_WAIT_DATA = 5'b00010;
    localparam [4:0] W_WAIT_ADDR = 5'b00100;
    localparam [4:0] W_WRITE     = 5'b01000;
    localparam [4:0] W_RESP      = 5'b10000;
    
    //Read sequence FSM
    localparam [2:0] R_IDLE      = 3'b001;
    localparam [2:0] R_READ      = 3'b010;
    localparam [2:0] R_RESP      = 3'b100;
    
    //RESP codes 00--OKAY 10--SLVERR
    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;
    
    //Dummy Registers
    localparam REG_0_ADDR = 2'd0;   // Offset 0x00
    localparam REG_1_ADDR = 2'd1;   // Offset 0x04
    localparam REG_2_ADDR = 2'd2;   // Offset 0x08
    localparam REG_3_ADDR = 2'd3;   // Offset 0x0C (Read-Only)
    
    localparam REG_3_HARDWIRED = 32'hDEAD_BEEF;
    
    //FSM Status reg
    reg [4:0] w_state;
    reg [2:0] r_state;
    
    //Latching Registers
    reg [ADDR_WIDTH-1:0]   aw_addr_latched;
    reg [DATA_WIDTH-1:0]   w_data_latched;
    reg [DATA_WIDTH/8-1:0] w_strb_latched;
    reg [ADDR_WIDTH-1:0]   ar_addr_latched;
    
    //User registers
    reg [DATA_WIDTH-1:0]   reg_0;    // R/W - scratch register
    reg [DATA_WIDTH-1:0]   reg_1;    // R/W - scratch register
    reg [DATA_WIDTH-1:0]   reg_2;    // R/W - scratch register
    
    //Decode address Helpers
    wire [1:0] aw_reg_sel;
    wire [1:0] ar_reg_sel;
    wire       ar_addr_valid;
    wire       aw_addr_valid;
    
    assign aw_reg_sel = aw_addr_latched[3:2];
    assign ar_reg_sel = ar_addr_latched[3:2];
    assign aw_addr_valid = (aw_addr_latched[ADDR_WIDTH-1:4]=={(ADDR_WIDTH-4){1'b0}});
    assign ar_addr_valid = (ar_addr_latched[ADDR_WIDTH-1:4]=={(ADDR_WIDTH-4){1'b0}});
    
      
    //============Write FSM============
    always@(posedge s_axi_aclk or negedge s_axi_aresetn ) begin
	    //
        if(!s_axi_aresetn) begin
            w_state = W_IDLE ;
            s_axi_awready <= 1'b0; 
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp     <= RESP_OKAY;
            
            aw_addr_latched <= {ADDR_WIDTH{1'b0}};
            w_data_latched  <= {DATA_WIDTH{1'b0}};
            w_strb_latched  <= {(DATA_WIDTH/8){1'b0}};
            
            reg_0           <= 32'h0;
            reg_1           <= 32'h0;
            reg_2           <= 32'h0;
        end else begin
            case(w_state)
            
            //Write IDLE case
            W_IDLE: begin
                //
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                s_axi_bvalid  <= 1'b0;
                //
                if (s_axi_awvalid && s_axi_wvalid) begin
                    aw_addr_latched <= s_axi_awaddr;
                    w_data_latched  <= s_axi_wdata;
                    w_strb_latched  <= s_axi_wstrb; 
                    s_axi_awready   <= 1'b0;
                    s_axi_wready    <= 1'b0;
                    w_state         <= W_WRITE;
                end
                //
                if (s_axi_awvalid && !s_axi_wvalid) begin
                    aw_addr_latched <= s_axi_awaddr;
                    s_axi_awready   <= 1'b0;
                    w_state         <= W_WAIT_DATA;
                end
                //
                if (!s_axi_awvalid && s_axi_wvalid) begin
                    w_data_latched  <= s_axi_wdata;
                    s_axi_wready    <= 1'b0;
                    w_state         <= W_WAIT_ADDR;
                end
            end
			
			
			W_WAIT_DATA: begin
			    if (s_axi_wvalid) begin
			         w_data_latched <= s_axi_wdata;
			         w_strb_latched <= s_axi_wstrb;
			         s_axi_wready   <= 1'b0;
			         w_state        <= W_WRITE;
			    end
			 //    
			end
			
			W_WAIT_ADDR: begin
			     if (s_axi_awvalid) begin
			         aw_addr_latched <= s_axi_awaddr;
			         s_axi_awready   <= 1'b0;
			         w_state         <= W_WRITE;
			     end
			end
			
			
			W_WRITE: begin
			//
			s_axi_bresp <= RESP_SLVERR;
			//
			     if (aw_addr_valid) begin
			         case(aw_reg_sel) 
			         //
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
			     
			     W_RESP: begin
                    if (s_axi_bready) begin
                        // Master accepted the response
                        s_axi_bvalid <= 1'b0;   // De-assert BVALID
                         w_state      <= W_IDLE;  // Ready for next transaction
                  end
                   // else: hold BVALID=1 and BRESP stable until BREADY
                    // AXI Rule 3: VALID must stay high until READY goes high
                  end
    
	               endcase
			
			     end
			
			  end
			
			endcase
		end
	 end
     
    
endmodule
