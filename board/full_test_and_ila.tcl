# Full flow: PS init + FPGA + dow + run
connect -url tcp:localhost:3121
targets -set -filter {name =~ "APU"}
catch {rst -system}
after 1000
source "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/vitis_bsp/ps7_cortexa9_0/code/ps7_init.tcl"
ps7_init
ps7_post_config
puts "PS7_INIT_DONE"

fpga -f "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/vitis_bsp/design_1_wrapper.bit"
puts "FPGA_DONE"

targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
dow "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/ps_dma_test/build/dma_xaxidma_test.elf"
puts "DOW_DONE"

con
puts "RUNNING"
after 35000
stop
puts "STOPPED"

# Read result buffer
puts "=== RESULT_A ==="
for {set i 0} {$i < 20} {incr i} {
    set addr [expr {0x00300000 + $i * 4}]
    puts "  R$i=[format 0x%08X [mrd -value $addr]]"
}
puts "=== RESULT_A_END ==="
exit
