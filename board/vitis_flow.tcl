# No FSBL — ps7_init only (MMU off), dow to CPU core
connect; targets -set -filter {name =~ "APU"}
fpga -f "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/shift_2d_ax7010_260608.runs/impl_1/design_1_wrapper.bit"
source "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/vitis_workspace/ax7010_platform/hw/ps7_init.tcl"
ps7_init; ps7_post_config; puts "PS7"
# PATCH: ps7_init AFI registers are empty; HP0 clock disabled at bit11
# Fix: 64-bit AFI + enable HP0 clock
mwr -force 0xF8000008 0xDF0D
mwr -force 0xF8000860 0x10000000; # AFI0: HP0 64-bit RD
mwr -force 0xF8000864 0x10000000; # AFI1: HP0 64-bit WR
set v [mrd -value 0xF800012C]; mwr -force 0xF800012C [expr {$v | 0x0800}]; # HP0 clk on
mwr -force 0xF8000004 0x767B; puts "HP0 AFI patched"
# Zero buffers
for {set i 0} {$i < 256} {incr i} { mwr -force [expr {0x00110B60 + $i * 4}] 0; mwr -force [expr {0x00110760 + $i * 4}] 0 }
# dow ELF
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
dow "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/ps_dma_test/build/dma_nolibc.elf"
con; after 15000; stop; puts "STOP"
puts "PING:"; for {set i 0} {$i < 4} {incr i} { puts "  +$i: [mrd -value [expr {0x00110760 + $i * 4}]]" }
puts "PONG:"; for {set i 0} {$i < 4} {incr i} { puts "  +$i: [mrd -value [expr {0x00110B60 + $i * 4}]]" }
disconnect; exit
