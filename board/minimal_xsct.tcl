# minimal_xsct.tcl — replicate exactly what Vitis SDK "Launch on Hardware" does
connect -url tcp:localhost:3121

# Step 1: System reset (Vitis always does this)
targets -set -filter {name =~ "APU"}
catch {rst -system}
after 1000
puts "System reset done"

# Step 2: Full PS initialization
source "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/vitis_workspace/ax7010_platform/hw/ps7_init.tcl"
ps7_init
ps7_post_config
puts "PS7 init done"

# Step 3: Program FPGA (standard order: after PS init)
fpga -f "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/shift_2d_ax7010_260608.runs/impl_1/design_1_wrapper.bit"
puts "FPGA programmed"

# Step 4: Download app to CPU core
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
dow "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/ps_dma_test/build/hp0_test.elf"
puts "ELF loaded, starting..."
con

# Wait and read results
after 30000
stop

puts "=== RESULT ==="
for {set i 0} {$i < 17} {incr i} {
    set addr [expr {0x00300000 + $i * 4}]
    puts "  R[$i] = [format 0x%08X [mrd -value $addr]]"
}

puts ""
puts "AFI0 from CPU: [format 0x%08X [mrd -value 0x00300004]] (expect 0x10000000 if writable)"
puts "DMASR MM2S:    [format 0x%08X [mrd -value 0x00300028]]"
puts "Mismatch:      [format 0x%08X [mrd -value 0x00300034]] (0xFFFFFFFF=pass)"
puts "PONG[0:3]:     [format 0x%08X [mrd -value 0x0030003C]]"
puts "End marker:    [format 0x%08X [mrd -value 0x00300040]] (expect 0xBEEF9999)"

disconnect
exit
