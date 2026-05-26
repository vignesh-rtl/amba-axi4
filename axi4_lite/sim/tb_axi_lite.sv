`timescale 1ns / 1ps

import axi_vip_pkg::*;
import bd_axi_vip_0_0_pkg::*;

module tb_axi_lite();

    reg aclk_0 = 0;
    reg aresetn_0 = 0;

    // Clock Generation (100 MHz)
    always #5 aclk_0 = ~aclk_0;

    // Instantiate your Block Design Wrapper
    bd_wrapper dut (
        .aclk_0(aclk_0),
        .aresetn_0(aresetn_0)
    );

    // CHANGE THIS TYPE to match your exact package name
    bd_axi_vip_0_0_mst_t master_agent;

    initial begin
        // Reset sequence
        #200 aresetn_0 = 1;
        #50;

        // Create and start the Master Agent
        master_agent = new("master_agent", dut.bd_i.axi_vip_0.inst.IF);
        master_agent.start_master();

        // Perform a Write Transaction to REG_0 (Offset 0x00)
        begin
            logic [1:0] wresp;
            master_agent.AXI4LITE_WRITE_BURST(32'h0000_0000, 3'b000, 32'hDEAD_BEEF, wresp);
            $display("Write Response: %b", wresp);
        end

        #20;

        // Perform a Read Transaction from REG_0 (Offset 0x00)
        begin
            logic [31:0] rdata;
            logic [1:0] rresp;
            master_agent.AXI4LITE_READ_BURST(32'h0000_0000, 3'b000, rdata, rresp);
            $display("Read Data: %h, Response: %b", rdata, rresp);
        end

        #100;
        $finish;
    end
endmodule
