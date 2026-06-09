connect -url tcp:localhost:3121
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
puts "=== RESULT BUFFER ==="
for {set i 0} {$i < 24} {incr i} {
    set addr [expr {0x00300000 + $i * 4}]
    if {[catch {set v [mrd -value $addr]} err]} {
        puts "  +$i: ERROR"
    } else {
        puts "  +$i: [format 0x%08X $v]"
    }
}
exit
