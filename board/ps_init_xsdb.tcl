# CPU reads accelerator and DMA status
connect
targets -set -filter {name =~ "APU"}

set ps7_init_path "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/vitis_workspace/ax7010_platform/hw/ps7_init.tcl"
source $ps7_init_path
ps7_init
ps7_post_config

# OCM stub
mwr -force 0x00000100 0xE59FF000
mwr -force 0x00000104 0x00000000
mwr -force 0x00000108 0x00200000

# DDR code: read status regs + pong_buf
mwr -force 0x00200000 0xE59F0050
mwr -force 0x00200004 0xE5901004
mwr -force 0x00200008 0xE59F204C
mwr -force 0x0020000C 0xE5821000
mwr -force 0x00200010 0xE5901008
mwr -force 0x00200014 0xE5821004
mwr -force 0x00200018 0xE59F0040
mwr -force 0x0020001C 0xE5901004
mwr -force 0x00200020 0xE5821008
mwr -force 0x00200024 0xE59F0038
mwr -force 0x00200028 0xE5901004
mwr -force 0x0020002C 0xE582100C
mwr -force 0x00200030 0xE59F0030
mwr -force 0x00200034 0xE5901000
mwr -force 0x00200038 0xE5821010
mwr -force 0x0020003C 0xE5901004
mwr -force 0x00200040 0xE5821014
mwr -force 0x00200044 0xEAFFFFFE

# Literal pool
mwr -force 0x00200058 0x60000000
mwr -force 0x0020005C 0x00200200
mwr -force 0x00200060 0x40400000
mwr -force 0x00200064 0x40400030
mwr -force 0x00200068 0x00110B60

# Init result sentinel
for {set i 0} {$i < 6} {incr i} {
    mwr -force [expr {0x00200200 + $i * 4}] 0xBAADF00D
}

targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
catch {stop}
rwr pc 0x00000100
con
after 500
catch {stop}

puts "=== Status Report ==="
set status [mrd -value 0x00200200]
set cfg    [mrd -value 0x00200204]
set mm2s   [mrd -value 0x00200208]
set s2mm   [mrd -value 0x0020020C]
set pong0  [mrd -value 0x00200210]
set pong1  [mrd -value 0x00200214]

puts "STATUS:       [format 0x%08X $status]"
puts "CFG:          [format 0x%08X $cfg]"
puts "MM2S_DMASR:   [format 0x%08X $mm2s]"
puts "S2MM_DMASR:   [format 0x%08X $s2mm]"
puts "pong_buf[0]:  [format 0x%08X $pong0]"
puts "pong_buf[1]:  [format 0x%08X $pong1]"

disconnect
exit
