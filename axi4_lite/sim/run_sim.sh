#!/bin/bash
# Simple script to compile and run the AXI4-Lite simulation

cd "$(dirname "$0")"

echo "Compiling AXI4-Lite Simulation..."
iverilog -o sim.vvp axi_lite_master_tb.v ../rtl/axi_lite_slave.v

if [ $? -eq 0 ]; then
    echo "Compilation Successful. Running Simulation..."
    vvp sim.vvp
else
    echo "Compilation Failed!"
fi
