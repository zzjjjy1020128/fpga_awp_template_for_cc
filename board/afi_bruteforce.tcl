connect -url tcp:localhost:3121
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}

# Do ps7_init first (needed to start PLLs, enable SLCR access)
source "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/vitis_workspace/ax7010_platform/hw/ps7_init.tcl"
ps7_init
puts "ps7_init done"

puts "=== TEST: brute force AFI register writes ==="

# Read initial values
puts "--- Initial state ---"
foreach addr {0xF8000860 0xF8000864 0xF8000868 0xF800086C 0xF8000870 0xF8000874 0xF8000878 0xF800087C} {
    set idx [expr {($addr - 0xF8000860) / 4}]
    puts "  AFI[$idx] $addr = [format 0x%08X [mrd -value $addr]]"
}

# Try write with unlock
puts ""
puts "--- After SLCR_UNLOCK + write 0x10000000 to all ---"
mwr -force 0xF8000008 0xDF0D
foreach addr {0xF8000860 0xF8000864 0xF8000868 0xF800086C 0xF8000870 0xF8000874 0xF8000878 0xF800087C} {
    mwr -force $addr 0x10000000
}
foreach addr {0xF8000860 0xF8000864 0xF8000868 0xF800086C 0xF8000870 0xF8000874 0xF8000878 0xF800087C} {
    set idx [expr {($addr - 0xF8000860) / 4}]
    puts "  AFI[$idx] $addr = [format 0x%08X [mrd -value $addr]]"
}

# Try writing via mask_write
puts ""
puts "--- Try mask_write ---"
mwr -force 0xF8000008 0xDF0D
mask_write 0xF8000860 0xFFFFFFFF 0x10000000
puts "  AFI0 after mask_write = [format 0x%08X [mrd -value 0xF8000860]]"

# Try different unlock key values
puts ""
puts "--- Try different unlock approaches ---"
set unlock_keys {0xDF0D 0x00000000 0xFFFFFFFF 0x767B}
foreach key $unlock_keys {
    mwr -force 0xF8000008 $key
    mwr -force 0xF8000860 0x11111111
    puts "  With unlock=$key: AFI0 = [format 0x%08X [mrd -value 0xF8000860]]"
}

# Final - check if writing has any side effect
puts ""
puts "--- Read adjacent registers for clues ---"
puts "  SLCR_UNLOCK (0xF8000008) = [format 0x%08X [mrd -value 0xF8000008]]"
puts "  SLCR_LOCK   (0xF8000004) = [format 0x%08X [mrd -value 0xF8000004]]"
puts "  PSS_IDCODE  (0xF8000000) = [format 0x%08X [mrd -value 0xF8000000]]"

exit
