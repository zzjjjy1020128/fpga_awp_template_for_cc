# Phase 1: PS init + FPGA + dow + con (CPU runs to gate, stops)
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
dow "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/ps_dma_test/build/dma_gated.elf"
puts "DOW_DONE"

con
puts "CPU_RUNNING_TO_GATE"
after 5000
stop

# Verify at gate
puts "GATE_CHECK: R[9]=[format 0x%08X [mrd -value 0x00300024]] (expect 0xDAAD0009=READY)"
puts "GATE_CHECK: R[10]=[format 0x%08X [mrd -value 0x00300028]] (expect 0xDAAD000A=waiting)"
puts "GATE_FLAG:  [mrd -value 0x00300100]"

puts "CPU_AT_GATE"
