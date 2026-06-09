# run_fsbl_dma.tcl — 用 FSBL 完整初始化 PS (包括 HP0), 然后跑 DMA 测试
#
# 根因: ps7_init 不初始化 HP0, 直接裸跑 APP 时 HP0 端口不工作
# 修复: 用标准 FSBL 代替 ps7_init 做 PS 初始化
#   FSBL 内部会做完整的 SLCR / AFI / 外设初始化
#
connect -url tcp:localhost:3121

# Step 1: Reset CPU
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
rst -processor
puts "CPU reset"

# Step 2: Load FSBL to OCM and run
# FSBL is linked to run from OCM (0x0 base)
targets -set -filter {name =~ "APU"}
source "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/vitis_workspace/ax7010_platform/hw/ps7_init.tcl"
ps7_init
puts "ps7_init done (pre-FSBL basic init)"

targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
# FSBL expects to run from OCM, we need to dow the ELF properly
# fsbl.elf has startup code that handles initialization
dow "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/vitis_workspace/ax7010_platform/zynq_fsbl/fsbl.elf"
puts "FSBL loaded"
con
puts "FSBL running..."

# Wait for FSBL to complete initialization
# FSBL will initialize PS, then try to load bitstream from boot device
# After FSBL init, we stop and take over
after 10000
stop
puts "FSBL complete"

# Step 3: Load bitstream (PL might have been loaded by FSBL, re-load for safety)
targets -set -filter {name =~ "APU"}
fpga -f "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/shift_2d_ax7010_260608.runs/impl_1/design_1_wrapper.bit"
puts "Bitstream loaded"

# Step 4: Run step4 DMA test
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
dow "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/ps_dma_test/build/step4.elf"
con
puts "step4 running..."
after 30000
stop

puts "=== STEP4 RESULT BUFFER ==="
for {set i 0} {$i < 16} {incr i} {
    set addr [expr {0x00300000 + $i * 4}]
    puts "  R[$i] = [format 0x%08X [mrd -value $addr]]"
}

puts ""
puts "=== DECODED ==="
puts "Mismatch:   R[9]=[format 0x%08X [mrd -value 0x00300024]] (0xFFFFFFFF=PASS)"
puts "ACC STATUS: R[10]=[format 0x%08X [mrd -value 0x00300028]]"
puts "PONG[0:3]:  R[14]=[format 0x%08X [mrd -value 0x00300038]] (expect 0x03020100)"
puts "End marker: R[15]=[format 0x%08X [mrd -value 0x0030003C]] (expect 0xDAAD9999)"

disconnect
exit
