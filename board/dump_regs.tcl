connect -url tcp:localhost:3121
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}

# Read AFI register current values
puts "=== AFI REGISTER DUMP ==="
puts "AFI0  (0xF8000860 RD): [format 0x%08X [mrd -value 0xF8000860]]"
puts "AFI1  (0xF8000864 WR): [format 0x%08X [mrd -value 0xF8000864]]"
puts "CLK   (0xF800012C):    [format 0x%08X [mrd -value 0xF800012C]]"
puts "LVL   (0xF8000900):    [format 0x%08X [mrd -value 0xF8000900]]"
puts "RST   (0xF8000240):    [format 0x%08X [mrd -value 0xF8000240]]"

puts ""
puts "=== DEBUG: verify AFI writes took effect ==="
puts "Bit11 (HP0 clk) = [expr {([mrd -value 0xF800012C] >> 11) & 1}]"
puts "AFI0[31:28] (HP0 RD width) = [expr {([mrd -value 0xF8000860] >> 28) & 0xF}]"
puts "AFI1[31:28] (HP0 WR width) = [expr {([mrd -value 0xF8000864] >> 28) & 0xF}]"

exit
