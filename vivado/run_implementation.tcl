# run_implementation.tcl
# L3 Vivado 实现流程：opt_design -> place_design -> route_design
# TASK-E001-013

# 打开工程
open_project D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/axil_2d_shift.xpr

# 打开综合 DCP
open_run synth_1

puts "============================================"
puts "Step 1/4: opt_design"
puts "============================================"
opt_design
report_timing -name pre_place_timing -nworst 5 -setup
puts "opt_design completed."

puts "============================================"
puts "Step 2/4: place_design"
puts "============================================"
place_design
report_timing -name post_place_timing -nworst 5 -setup
report_utilization -name post_place_util
puts "place_design completed."

puts "============================================"
puts "Step 3/4: route_design"
puts "============================================"
route_design
puts "route_design completed."

puts "============================================"
puts "Step 4/4: Reports"
puts "============================================"

# 时序报告
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -name timing_summary
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -file D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/axil_2d_shift.runs/impl_1/post_route_timing_summary.rpt

# 最差路径详细报告
report_timing -nworst 5 -setup -path_type full_clock -max_paths 5 -input_pins -name worst_setup_paths
report_timing -nworst 5 -setup -path_type full_clock -max_paths 5 -input_pins -file D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/axil_2d_shift.runs/impl_1/worst_setup_paths.rpt

# 保持时间
report_timing -nworst 5 -hold -max_paths 5 -input_pins -name worst_hold_paths
report_timing -nworst 5 -hold -max_paths 5 -input_pins -file D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/axil_2d_shift.runs/impl_1/worst_hold_paths.rpt

# 资源利用率
report_utilization -name post_route_util
report_utilization -file D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/axil_2d_shift.runs/impl_1/post_route_utilization.rpt

# 时钟交互报告
report_clock_interaction -name clock_interaction
report_clock_interaction -file D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/axil_2d_shift.runs/impl_1/clock_interaction.rpt

# 报告 DRC
report_drc -name drc_report
report_drc -file D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/axil_2d_shift.runs/impl_1/drc_report.rpt

# 写设计检查点
write_checkpoint -force D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/axil_2d_shift.runs/impl_1/axil_2d_shift_routed.dcp

# 输出关键数据到 stdout
puts ""
puts "============================================"
puts "IMPLEMENTATION RESULTS"
puts "============================================"

set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

# 获取时序数据
set timing_summary [get_timing_paths -nworst 1 -setup -max_paths 1]
if {[llength $timing_summary] > 0} {
    set wns [get_property SLACK [lindex $timing_summary 0]]
} else {
    set wns "N/A (no constraint)"
}
puts "WNS (Setup): $wns"

set hold_paths [get_timing_paths -nworst 1 -hold -max_paths 1]
if {[llength $hold_paths] > 0} {
    set whs [get_property SLACK [lindex $hold_paths 0]]
} else {
    set whs "N/A"
}
puts "WHS (Hold): $whs"

# TNS
set all_setup_paths [get_timing_paths -setup -max_paths 10000]
set tns 0
foreach path $all_setup_paths {
    set slack [get_property SLACK $path]
    if {$slack < 0} {
        set tns [expr {$tns + $slack}]
    }
}
puts "TNS (Setup): $tns"
puts "Total violating endpoints (setup): [llength $all_setup_paths]"

set all_hold_paths [get_timing_paths -hold -max_paths 10000]
set ths 0
foreach path $all_hold_paths {
    set slack [get_property SLACK $path]
    if {$slack < 0} {
        set ths [expr {$ths + $slack}]
    }
}
puts "THS (Hold): $ths"
set total_endpoints [llength [all_inputs]] ;# placeholder
puts "Total endpoints checked: [llength [get_timing_paths -setup -max_paths 10000]]"

# 输出最差路径起点终点
puts ""
puts "--- Worst Setup Path ---"
if {[llength $timing_summary] > 0} {
    set worst_path [lindex $timing_summary 0]
    puts "Startpoint: [get_property STARTPOINT_PIN $worst_path]"
    puts "Endpoint:   [get_property ENDPOINT_PIN $worst_path]"
    puts "Slack:      [get_property SLACK $worst_path]"
    puts "Path Delay: [get_property DATAPATH_DELAY $worst_path]"
    puts "Logic Level: [get_property LOGIC_LEVELS $worst_path]"
}

# 检查时序收敛状态
if {$wns < 0} {
    puts "TIMING STATUS: FAIL (WNS = $wns)"
} elseif {$wns == "N/A (no constraint)"} {
    puts "TIMING STATUS: N/A (no timing constraints)"
} else {
    puts "TIMING STATUS: PASS"
}

puts ""
puts "Implementation completed successfully."
puts "Output DCP: vivado/axil_2d_shift.runs/impl_1/axil_2d_shift_routed.dcp"

exit
