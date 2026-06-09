connect -url tcp:localhost:3121
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
dow D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/ps_dma_test/build/dma_xaxidma_test.elf
puts "DOW_DONE"
