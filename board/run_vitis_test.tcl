# Standard Vitis "Launch on Hardware" flow
connect -url tcp:localhost:3121
targets -set -filter {name =~ "APU"}

catch {rst -system}
after 1000

# PS init from XSA (embedded in XSA, extracted to BSP)
source "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/vitis_bsp/ps7_cortexa9_0/code/ps7_init.tcl"
ps7_init
ps7_post_config
puts "PS7 init done"

# Program FPGA (bitstream extracted from XSA)
fpga -f "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/vitis_bsp/design_1_wrapper.bit"
puts "FPGA programmed"

# Load and run test
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
dow "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/ps_dma_test/build/dma_xaxidma_test.elf"
puts "ELF loaded"
con

after 30000
stop

puts "=== RESULT ==="
for {set i 0} {$i < 20} {incr i} {
    set addr [expr {0x00300000 + $i * 4}]
    puts "  R[$i] = [format 0x%08X [mrd -value $addr]]"
}

puts "=== KEY ==="
puts "S2MM Xfer ret:  R[8]=[format 0x%08X [mrd -value 0x00300020]] (0=OK)"
puts "MM2S Xfer ret:  R[9]=[format 0x%08X [mrd -value 0x00300024]] (0=OK)"
puts "S2MM IRQ:       R[11]=[format 0x%08X [mrd -value 0x0030002C]]"
puts "MM2S IRQ:       R[12]=[format 0x%08X [mrd -value 0x00300030]]"
puts "ACC STATUS:     R[13]=[format 0x%08X [mrd -value 0x00300034]]"
puts "Mismatch:       R[14]=[format 0x%08X [mrd -value 0x00300038]] (0xFFFFFFFF=PASS)"
puts "PING[0:3]:      R[15]=[format 0x%08X [mrd -value 0x0030003C]]"
puts "PONG[0:3]:      R[16]=[format 0x%08X [mrd -value 0x00300040]]"
puts "End:            R[17]=[format 0x%08X [mrd -value 0x00300044]] (expect 0xDAAA9999)"

disconnect
exit
