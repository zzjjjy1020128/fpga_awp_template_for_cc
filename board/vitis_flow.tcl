# No FSBL — ps7_init only (MMU off), dow to CPU core
connect; targets -set -filter {name =~ "APU"}
fpga -f "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/shift_2d_ax7010_260608.runs/impl_1/design_1_wrapper.bit"
source "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/vitis_workspace/ax7010_platform/hw/ps7_init.tcl"
ps7_init; ps7_post_config; puts "PS7"
# Zero buffers
for {set i 0} {$i < 256} {incr i} { mwr -force [expr {0x00110B60 + $i * 4}] 0; mwr -force [expr {0x00110760 + $i * 4}] 0 }
# dow ELF
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
dow "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/ps_dma_test/build/dma_nolibc.elf"
con; after 15000; stop; puts "STOP"
puts "PING:"; for {set i 0} {$i < 4} {incr i} { puts "  +$i: [mrd -value [expr {0x00110760 + $i * 4}]]" }
puts "PONG:"; for {set i 0} {$i < 4} {incr i} { puts "  +$i: [mrd -value [expr {0x00110B60 + $i * 4}]]" }
disconnect; exit
