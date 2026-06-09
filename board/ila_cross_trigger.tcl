# ila_cross_trigger.tcl — ILA cross-trigger automation
# UG908 flow: arm all ILAs → confirm Waiting for Trigger → start PS → capture
#
# Architecture:
#   PL anchor event (dbg_trig_pulse from dbg_trigger_hub)
#     → ila_ctrl_cross.trig_in (TRIG_IN_ONLY)
#     → ila_data_cross.trig_in (TRIG_IN_ONLY)
#   PS starts only after all ILAs are armed.

# Connect to shared hw_server daemon
open_hw_manager
connect_hw_server -url TCP:localhost:3121
open_hw_target [lindex [get_hw_targets] 0]

# Program device
set dev [lindex [get_hw_devices] 1]
set_property PROGRAM.FILE {design_1_wrapper.bit} $dev
set_property PROBES.FILE  {debug_nets.ltx} $dev
program_hw_devices $dev
refresh_hw_device $dev

# Get ILA cores
set ila_ctrl [get_hw_ilas -filter {NAME =~ *ctrl*}]
set ila_data [get_hw_ilas -filter {NAME =~ *data*}]

puts "ILA_CTRL: $ila_ctrl"
puts "ILA_DATA: $ila_data"

# Configure ILAs for TRIG_IN_ONLY mode (external trigger from dbg_trig_pulse)
# Control plane ILA
set_property CONTROL.TRIGGER_MODE TRIG_IN_ONLY $ila_ctrl
set_property CONTROL.CAPTURE_MODE ALWAYS $ila_ctrl
set_property CONTROL.DATA_DEPTH 2048 $ila_ctrl
set_property CONTROL.TRIGGER_POSITION 1024 $ila_ctrl
set_property CONTROL.TRIG_OUT_MODE DISABLED $ila_ctrl

# Data path ILA
set_property CONTROL.TRIGGER_MODE TRIG_IN_ONLY $ila_data
set_property CONTROL.CAPTURE_MODE ALWAYS $ila_data
set_property CONTROL.DATA_DEPTH 4096 $ila_data
set_property CONTROL.TRIGGER_POSITION 2048 $ila_data
set_property CONTROL.TRIG_OUT_MODE DISABLED $ila_data

# Step 1: Arm all ILAs FIRST
puts "Arming ILAs..."
run_hw_ila $ila_ctrl
run_hw_ila $ila_data
puts "ILAs armed — Waiting for Trigger"

# Step 2: Confirm ILA status
after 500
set ctrl_status [get_property STATUS.CORE_STATUS $ila_ctrl]
set data_status [get_property STATUS.CORE_STATUS $ila_data]
puts "Ctrl ILA: $ctrl_status"
puts "Data ILA: $data_status"

# Step 3: NOW start PS (via external XSCT script)
# This script exits here — separate XSCT script does: connect → con
# The anchor event from PL triggers both ILAs simultaneously.

puts "READY_FOR_PS_START"
puts "Run: xsct -eval \"connect -url tcp:localhost:3121; \
      targets -set -filter {name =~ \\\"ARM Cortex-A9 MPCore #0\\\"}; con\""

# After PS test completes (user or automation triggers capture):
# Step 4: Wait for capture (or upload immediately for ALWAYS mode)
wait_on_hw_ila $ila_ctrl
wait_on_hw_ila $ila_data

# Step 5: Upload and export
puts "Uploading ILA data..."
upload_hw_ila_data $ila_ctrl
upload_hw_ila_data $ila_data

# Export as CSV for analysis
write_hw_ila_data -csv_file -force ila_ctrl_capture.csv [lindex [get_hw_ila_datas] 0]
write_hw_ila_data -csv_file -force ila_data_capture.csv [lindex [get_hw_ila_datas] 1]
write_hw_ila_data -force ila_ctrl_capture.ila [lindex [get_hw_ila_datas] 0]
write_hw_ila_data -force ila_data_capture.ila [lindex [get_hw_ila_datas] 1]

puts "ILA data saved: ila_ctrl_capture.{ila,csv}, ila_data_capture.{ila,csv}"
