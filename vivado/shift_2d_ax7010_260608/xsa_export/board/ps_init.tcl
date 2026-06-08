# XSCT script: Initialize PS, program bitstream
# Unlocks PL clocks → ILA debug hub becomes accessible

set xsa_dir "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/xsa_export/extracted"

# Connect to hardware
connect
puts "XSCT: Connected to target"

# Select ARM Cortex-A9 core #0
targets -set -filter {name =~ "ARM*#0"}
puts "XSCT: Target set to ARM Cortex-A9 #0"

# Initialize PS (DDR, clocks, MIO, PLL)
cd $xsa_dir
source ps7_init.tcl
puts "XSCT: Loading ps7_init..."
ps7_init
puts "XSCT: PS7 initialized — PLL/DDR/Clocks running"

# PS is now initialized. PL FCLK_CLK0 should be running at 50 MHz.
# Now program the FPGA
puts "XSCT: Programming FPGA..."
fpga -file [file join $xsa_dir "design_1_wrapper.bit"]
puts "XSCT: Bitstream programmed successfully"

puts ""
puts "=== PS INIT COMPLETE ==="
puts "PL clocks should now be running."
puts "ILA debug hub should be detectable in Vivado Hardware Manager."
puts "Run: refresh_hw_device in Vivado to verify ILA cores."
