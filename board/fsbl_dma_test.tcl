# Minimal FSBL + DMA test
connect -url tcp:localhost:3121
targets -set -filter {name =~ "APU"}

# Init PS (no reset)
source "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/vitis_workspace/ax7010_platform/hw/ps7_init.tcl"
ps7_init
ps7_post_config
puts "PS7 initialized"

# Load bitstream
fpga -f "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/shift_2d_ax7010_260608.runs/impl_1/design_1_wrapper.bit"
puts "Bitstream loaded"

# Verify HP0: read DMA ID register (should be 0x0000 at 0x40400000 before any config)
# If accessible, HP0 PL-side path is working
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
puts "DMA MM2S DMACR (reset): [mrd -value 0x40400000]"
puts "DMA S2MM DMACR (reset): [mrd -value 0x40400030]"

# Quick register access test: write DMA register, read back
mwr -force 0x40400000 4
puts "DMA MM2S DMACR (after mwr 4): [mrd -value 0x40400000]"

# The mrd here uses JTAG to read PL register — this tests PL AXI accessibility
# from JTAG side. For HP0 test, we need the DMA to access DDR.

# Test: write DMA SA, Length, then start MM2S
mwr -force 0x40400000 0         ;# clear reset
mwr -force 0x40400018 0x00108000 ;# SA = ping_buf address
mwr -force 0x40400028 64        ;# 64 bytes
mwr -force 0x40400000 1         ;# RS=1, start MM2S
after 2000
puts "MM2S DMASR after start: [mrd -value 0x40400004]"
# DMASR bit0=0=RUNNING, bit0=1=HALTED
# If stuck at 0x00000000, engine is running but AXI hung

exit
