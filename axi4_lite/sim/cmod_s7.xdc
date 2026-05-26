## 12 MHz Physical System Clock on Cmod S7 (Pin M9)
## This pin constraint is only used if this module (or its wrapper) is the TOP-level design.
#set_property -dict { PACKAGE_PIN M9    IOSTANDARD LVCMOS33 } [get_ports { s_axi_aclk }];
#create_clock -add -name sys_clk_pin -period 83.333 -waveform {0 41.666} [get_ports { s_axi_aclk }];

## -----------------------------------------------------------------------------
## TIMING CONSTRAINTS FOR SYNTHESIS & TIMING ANALYSIS
## -----------------------------------------------------------------------------
## Note: Since an AXI4-Lite Slave has many signals (WDATA, AWADDR, etc.) that do
## not connect to physical pins on the chip board, you should synthesize this 
## design "Out-of-Context" (OOC) in Vivado. 
##
## To run OOC synthesis in Vivado:
## 1. Set the synthesis setting "-mode out_of_context"
## 2. Vivado will synthesize the design without trying to route the AXI bus 
##    to physical board pins, allowing you to check Fmax.
##
## Below we define a virtual 100 MHz clock target to check timing slack.
## You can adjust the "-period" to push the compiler to test the design's limits.
## E.g., period 10.0 = 100 MHz, period 4.0 = 250 MHz, period 3.33 = 300 MHz.
## -----------------------------------------------------------------------------
create_clock -period 10.000 -name virtual_axi_clk [get_ports s_axi_aclk]
