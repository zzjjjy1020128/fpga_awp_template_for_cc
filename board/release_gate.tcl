connect -url tcp:localhost:3121
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
mwr -force 0x00300100 1
puts "GATE_RELEASED"
con
puts "CPU_RUNNING"
after 30000
stop

puts "=== RESULT ==="
for {set i 0} {$i < 24} {incr i} {
    set addr [expr {0x00300000 + $i * 4}]
    puts "  R$i=[format 0x%08X [mrd -value $addr]]"
}
exit
