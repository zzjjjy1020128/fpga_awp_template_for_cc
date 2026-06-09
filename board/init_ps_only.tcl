# PS init + FPGA programming only (no app run yet)
connect -url tcp:localhost:3121
targets -set -filter {name =~ "APU"}
catch {rst -system}
after 1000
source "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/vitis_bsp/ps7_cortexa9_0/code/ps7_init.tcl"
ps7_init
ps7_post_config
fpga -f "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/vitis_bsp/design_1_wrapper.bit"
puts "READY_FOR_ILA"
