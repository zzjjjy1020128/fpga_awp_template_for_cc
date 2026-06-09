# run_fsbl_flow.tcl — FSBL-based boot: loads FSBL first to configure AFI/HP0,
# then loads and runs the application.
#
# Why: ps7_init alone does NOT configure AFI (HP0) registers.
# FSBL's full init sequence is required for DMA to work through HP0.

connect
puts "JTAG connected"

# Set APU as target for PS init
targets -set -filter {name =~ "APU"}
puts "Target: APU"

# Step 1: Source and run ps7_init for basic PLL/DDR/MIO setup
source "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/vitis_workspace/ax7010_platform/hw/ps7_init.tcl"
ps7_init
ps7_post_config
puts "PS7 basic init done (ps7_init + post_config)"

# Step 2: Load and run FSBL to complete PS initialization (AFI, peripherals, etc.)
# The FSBL will find that DDR is already configured and will set up the rest
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
dow -data "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/vitis_workspace/ax7010_platform/zynq_fsbl/fsbl.elf" 0x0
puts "FSBL loaded to OCM"
con
puts "FSBL running..."
after 5000
stop
puts "FSBL init complete"

# Step 3: Load bitstream (FSBL already configured PL power/clock, now load PL)
targets -set -filter {name =~ "APU"}
fpga -f "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/shift_2d_ax7010_260608.runs/impl_1/design_1_wrapper.bit"
puts "Bitstream loaded"

# Step 4: Download and run test application
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
# Zero out test buffers in DDR (optional, for clean state)
for {set i 0} {$i < 256} {incr i} {
    mwr -force [expr {0x00110760 + $i * 4}] 0
    mwr -force [expr {0x00110B60 + $i * 4}] 0
}
dow "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/ps_dma_test/build/dma_nolibc.elf"
puts "App loaded"
con
puts "App running..."

# Wait for test to complete
after 30000
stop

# Read results
puts "=== RESULTS ==="
puts "PING buf:"
for {set i 0} {$i < 4} {incr i} { puts "  +$i: [mrd -value [expr {0x00110760 + $i * 4}]]" }
puts "PONG buf:"
for {set i 0} {$i < 4} {incr i} { puts "  +$i: [mrd -value [expr {0x00110B60 + $i * 4}]]" }
puts "DMA STATUS:"
puts "  MM2S DMASR: [mrd -value 0x40400004]"
puts "  S2MM DMASR: [mrd -value 0x40400034]"

disconnect
exit
