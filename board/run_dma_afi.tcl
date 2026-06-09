# run_dma_afi.tcl —— HP0 DMA 修复：补全 ps7_init 缺失的 AFI + 时钟配置
#
# 根因: Vivado 2022.2 为 Zynq-7000 生成的 ps7_init 有两个缺陷:
#   1. AFI0/AFI1 未配置 —— 保持复位值 0x00000000 (32-bit mode)
#      但 BD 中 HP0_DATA_WIDTH=64, 导致 AXI 宽度不匹配
#   2. APER_CLK_CTRL bit11 (AXI_HP0_CPU1XCLKACT) 被显式置 0
#      —— HP0 AXI 时钟被关断
#
# 修复方案: ps7_init 之后手动补写这三个寄存器
#
# 参考:
#   - UG585 §B.28: SLCR AFI registers
#   - UG585 §B.17: APER_CLK_CTRL
#   - ps7_init.c L11978-11987: AFI sections EMPTY
#   - Xilinx embeddedsw: Zynq-7000 无独立 AFI 配置代码, 完全依赖 ps7_init
#
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}

# KEY INSIGHT: AFI registers must be written BEFORE PL is configured.
# After fpga -f, the AXI HP interface hardware locks AFI registers.
# Standard FSBL order: ps7_init → AFI config → load bitstream → load app
#
# Step 1: ps7_init (basic PLL/DDR/MIO) — BEFORE PL config
source "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/vitis_workspace/ax7010_platform/hw/ps7_init.tcl"
ps7_init
ps7_post_config
puts "PS7 init done"

# Step 2: PATCH AFI registers BEFORE loading bitstream
mwr -force 0xF8000008 0xDF0D   ;# SLCR_UNLOCK
mwr -force 0xF8000860 0x10000000  ;# AFI0: HP0 RD 64-bit
mwr -force 0xF8000864 0x10000000  ;# AFI1: HP0 WR 64-bit
mwr -force 0xF800012C [expr {[mrd -value 0xF800012C] | 0x0800}]  ;# HP0 clk on
puts "AFI HP0 patch: [format 0x%08X [mrd -value 0xF8000860]] / [format 0x%08X [mrd -value 0xF8000864]] / [format 0x%08X [mrd -value 0xF800012C]]"
mwr -force 0xF8000004 0x767B   ;# SLCR_LOCK

# Step 3: Load bitstream (AFI already configured)
fpga -f "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/shift_2d_ax7010_260608.runs/impl_1/design_1_wrapper.bit"
puts "Bitstream loaded"

# Step 4: Zero test buffers
for {set i 0} {$i < 256} {incr i} {
    mwr -force [expr {0x00110760 + $i * 4}] 0
    mwr -force [expr {0x00110B60 + $i * 4}] 0
}

# Step 5: Download and run test
dow "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/ps_dma_test/build/hp0_test.elf"
puts "hp0_test.elf loaded (no gate), running..."
con

after 30000
stop

puts "=== HP0 TEST RESULT BUFFER (0x300000) ==="
for {set i 0} {$i < 20} {incr i} {
    set addr [expr {0x00300000 + $i * 4}]
    set v [mrd -value $addr]
    puts "  R[$i] = [format 0x%08X $v]"
}

puts ""
puts "=== DECODED ==="
puts "AFI0 rdbk:  R[1]=[format 0x%08X [mrd -value 0x00300004]]"
puts "AFI1 rdbk:  R[2]=[format 0x%08X [mrd -value 0x00300008]]"
puts "CLK reg:    R[3]=[format 0x%08X [mrd -value 0x0030000C]]"
puts "DMASR after reset: MM2S=[format 0x%08X [mrd -value 0x00300020]] S2MM=[format 0x%08X [mrd -value 0x00300024]] (expect 0x0001=Halted)"
puts "DMA started: R[10]=[format 0x%08X [mrd -value 0x00300028]]"
puts "DMASR after:  MM2S=[format 0x%08X [mrd -value 0x00300030]] S2MM=[format 0x%08X [mrd -value 0x00300034]]"
puts "ACC STATUS:   R[14]=[format 0x%08X [mrd -value 0x00300038]]"
puts "Mismatch:     R[15]=[format 0x%08X [mrd -value 0x0030003C]] (0xFFFFFFFF=PASS)"
puts "PING[0:3]:    R[16]=[format 0x%08X [mrd -value 0x00300040]]"
puts "PONG[0:3]:    R[17]=[format 0x%08X [mrd -value 0x00300044]]"
puts "End:          R[18]=[format 0x%08X [mrd -value 0x00300048]] (expect 0xBEEF9999)"

disconnect
exit
