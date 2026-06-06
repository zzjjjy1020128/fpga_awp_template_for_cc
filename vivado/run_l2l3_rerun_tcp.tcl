# =============================================================================
# run_l2l3_rerun_tcp.tcl — L2+L3 重跑（step_mod 寄存器化 + 输出寄存器）
# 通过 TCP 连接到运行中的 Vivado GUI（batch 模式不可用时）
# 使用 rerun/ 子目录避免与 GUI 锁定冲突
# =============================================================================

# 关闭已有工程
# 先关闭所有打开的工程再重新打开或创建
close_project -quiet

# 设置工程目录
set script_dir [file normalize [file dirname [info script]]]
set project_dir [file join $script_dir rerun]
set rtl_dir    [file normalize [file join $script_dir .. rtl]]
set constr_dir [file normalize [file join $script_dir .. constraints]]

# =============================================================================
# Part 1: 创建 / 更新工程
# =============================================================================
puts ""
puts "========================================================================"
puts "PART 1: Creating project and adding sources"
puts "========================================================================"

file mkdir $project_dir

# 如果已有工程被打开（GUI 持有锁），用 open_project 而非 create_project
set xpr_path [file join $project_dir axil_2d_shift.xpr]
if {[file exists $xpr_path]} {
    open_project $xpr_path
    # 刷新所有源文件：删除再重新添加
    set old_files [get_files -of_objects [get_filesets sources_1] -filter {FILE_TYPE == "SystemVerilog"}]
    if {[llength $old_files] > 0} {
        remove_files $old_files
    }
    add_files -norecurse [glob -dir $rtl_dir *.sv]
    set_property TOP axil_2d_shift [current_fileset]
    # 刷新约束
    set old_constr [get_files -of_objects [get_filesets constrs_1] -filter {FILE_TYPE == "XDC"}]
    if {[llength $old_constr] > 0} {
        remove_files $old_constr
    }
    add_files -fileset constrs_1 -norecurse [file join $constr_dir timing.xdc]
} else {
    create_project axil_2d_shift $project_dir -part xc7z020clg400-1 -force
    # 添加 RTL 源文件
    add_files -norecurse [glob -dir $rtl_dir *.sv]
    set_property TOP axil_2d_shift [current_fileset]
    # 添加约束文件
    add_files -fileset constrs_1 -norecurse [file join $constr_dir timing.xdc]
}

set_property TARGET_LANGUAGE Verilog [current_project]
set_property DEFAULT_LIB work [current_project]
update_compile_order -fileset sources_1

puts "=== RTL files added ==="
foreach f [get_files -of_objects [get_filesets sources_1] -filter {FILE_TYPE == "SystemVerilog"}] {
    puts "  $f"
}

# =============================================================================
# Part 2: 综合
# =============================================================================
puts ""
puts "========================================================================"
puts "PART 2: Synthesis (synth_design)"
puts "========================================================================"
puts "  Started at: [clock format [clock seconds]]"

reset_run synth_1
launch_runs synth_1
wait_on_run synth_1

open_run synth_1 -name synth_1

# 检查综合状态
set synth_status [get_property STATUS [get_runs synth_1]]
puts "  Synthesis status: $synth_status"
puts "  Finished at: [clock format [clock seconds]]"

# 生成综合报告
report_utilization -file [file join $project_dir utilization.rpt]
report_timing_summary -file [file join $project_dir timing_summary.rpt]
report_qor_suggestions -file [file join $project_dir qor_suggestions.rpt]

# 输出综合资源
puts ""
puts "=== POST-SYNTHESIS RESOURCE UTILIZATION ==="
report_utilization -quiet

puts ""
puts "=== POST-SYNTHESIS TIMING SUMMARY ==="
report_timing_summary -quiet -no_header -max_paths 5

# =============================================================================
# Part 3: 实现
# =============================================================================
puts ""
puts "========================================================================"
puts "PART 3: Implementation (opt_design + place_design + route_design)"
puts "========================================================================"

puts ""
puts "--- Step 1/3: opt_design ---"
opt_design
report_timing -name pre_place_timing -nworst 5 -setup
puts "  opt_design completed."

puts ""
puts "--- Step 2/3: place_design ---"
place_design
report_timing -name post_place_timing -nworst 5 -setup
puts "  place_design completed."

puts ""
puts "--- Step 3/3: route_design ---"
route_design
puts "  route_design completed."

# =============================================================================
# Part 4: 报告生成
# =============================================================================
puts ""
puts "========================================================================"
puts "PART 4: Post-route reports"
puts "========================================================================"

set impl_dir [file join $project_dir axil_2d_shift.runs impl_1]
file mkdir $impl_dir

# 时序汇总报告
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -name timing_summary
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -file [file join $impl_dir post_route_timing_summary.rpt]

# 最差 setup 路径详细
report_timing -nworst 5 -setup -path_type full_clock -max_paths 5 -input_pins -name worst_setup_paths
report_timing -nworst 5 -setup -path_type full_clock -max_paths 5 -input_pins -file [file join $impl_dir worst_setup_paths.rpt]

# 最差 hold 路径
report_timing -nworst 5 -hold -max_paths 5 -input_pins -name worst_hold_paths
report_timing -nworst 5 -hold -max_paths 5 -input_pins -file [file join $impl_dir worst_hold_paths.rpt]

# 资源利用率
report_utilization -name post_route_util
report_utilization -file [file join $impl_dir post_route_utilization.rpt]

# DRC
report_drc -name drc_report
report_drc -file [file join $impl_dir drc_report.rpt]

# 写 DCP
write_checkpoint -force [file join $impl_dir axil_2d_shift_routed.dcp]

# =============================================================================
# Part 5: 关键数据输出（供自动解析）
# =============================================================================
puts ""
puts "========================================================================"
puts "FULL FLOW RESULTS"
puts "========================================================================"

# --- 时序 ---
set setup_paths [get_timing_paths -nworst 1 -setup -max_paths 1]
if {[llength $setup_paths] > 0} {
    set wns [get_property SLACK [lindex $setup_paths 0]]
} else {
    set wns "N/A"
}
puts "WNS (Setup): $wns"

set hold_paths [get_timing_paths -nworst 1 -hold -max_paths 1]
if {[llength $hold_paths] > 0} {
    set whs [get_property SLACK [lindex $hold_paths 0]]
} else {
    set whs "N/A"
}
puts "WHS (Hold): $whs"

# TNS 计算
set all_setup_violators [get_timing_paths -setup -max_paths 10000]
set tns 0
set num_failing 0
foreach path $all_setup_violators {
    set slack [get_property SLACK $path]
    if {$slack < 0} {
        set tns [expr {$tns + $slack}]
        incr num_failing
    }
}
puts "TNS (Setup): $tns"
puts "Failing endpoints (setup): $num_failing"

set all_hold_violators [get_timing_paths -hold -max_paths 10000]
set ths 0
set num_hold_failing 0
foreach path $all_hold_violators {
    set slack [get_property SLACK $path]
    if {$slack < 0} {
        set ths [expr {$ths + $slack}]
        incr num_hold_failing
    }
}
puts "THS (Hold): $ths"
puts "Hold violations: $num_hold_failing"

# --- 最差路径详情 ---
puts ""
puts "--- Worst Setup Path ---"
if {[llength $setup_paths] > 0} {
    set worst_path [lindex $setup_paths 0]
    puts "Startpoint: [get_property STARTPOINT_PIN $worst_path]"
    puts "Endpoint:   [get_property ENDPOINT_PIN $worst_path]"
    puts "Slack:      [get_property SLACK $worst_path]"
    puts "Path Delay: [get_property DATAPATH_DELAY $worst_path]"
    puts "Logic Level: [get_property LOGIC_LEVELS $worst_path]"

    # 路径级数分解
    set path_points [get_property POINTS $worst_path]
    set num_carry4 0
    set num_lut    0
    set num_dsp    0
    set num_bram   0
    foreach pt $path_points {
        set ref [get_property REF_NAME [get_property CELL $pt]]
        if {$ref eq "CARRY4"}  { incr num_carry4 }
        if {[string match "LUT*" $ref]}  { incr num_lut }
        if {$ref eq "DSP48E1"} { incr num_dsp }
        if {$ref eq "RAMB36E1" || $ref eq "RAMB18E1"} { incr num_bram }
    }
    puts "  Cell breakdown: CARRY4=$num_carry4, LUT=$num_lut, DSP48E1=$num_dsp, BRAM=$num_bram"
}

# --- 资源 ---
puts ""
puts "--- Post-Route Resource Utilization ---"
report_utilization -quiet

# --- 时序判定 ---
puts ""
if {$wns != "N/A" && $wns >= 0} {
    puts "TIMING STATUS: PASS (WNS = $wns ns)"
} elseif {$wns == "N/A"} {
    puts "TIMING STATUS: N/A (no timing constraints)"
} else {
    puts "TIMING STATUS: FAIL (WNS = $wns ns)"
}

puts ""
puts "Full flow completed successfully."
puts "Output DCP: [file join $impl_dir axil_2d_shift_routed.dcp]"
