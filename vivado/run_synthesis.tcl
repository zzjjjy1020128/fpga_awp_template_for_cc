# =============================================================================
# run_synthesis.tcl — Vivado 综合脚本
# 顶层模块: axil_2d_shift
# 器件: xc7z020clg400-1
# =============================================================================

# 关闭已有工程（如有）
close_project -quiet

# 创建工程
create_project axil_2d_shift [file normalize [file dirname [info script]]] -part xc7z020clg400-1 -force

# 添加 RTL 源文件（SystemVerilog）
set rtl_dir [file normalize [file join [file dirname [info script]] .. rtl]]
add_files -norecurse [glob -dir $rtl_dir *.sv]

# 设置顶层模块
set_property TOP axil_2d_shift [current_fileset]

# 添加约束文件
set constr_dir [file normalize [file join [file dirname [info script]] .. constraints]]
add_files -fileset constrs_1 -norecurse [file join $constr_dir timing.xdc]

# 设置目标语言
set_property TARGET_LANGUAGE Verilog [current_project]
set_property DEFAULT_LIB work [current_project]

# 更新编译顺序
update_compile_order -fileset sources_1

# 打印文件列表
puts "=== RTL files added ==="
foreach f [get_files -of_objects [get_filesets sources_1] -filter {FILE_TYPE == "SystemVerilog"}] {
    puts "  $f"
}

# 运行综合
puts ""
puts "=== Running synthesis ==="
puts "  Top module: axil_2d_shift"
puts "  Part: xc7z020clg400-1"
puts "  Started at: [clock format [clock seconds]]"
puts ""

reset_run synth_1
launch_runs synth_1
wait_on_run synth_1

# 打开综合设计并生成报告
open_run synth_1 -name synth_1

# 生成资源利用率报告
report_utilization -file [file join [file dirname [info script]] utilization.rpt]

# 生成时序预估报告
report_timing_summary -file [file join [file dirname [info script]] timing_summary.rpt]

# 生成所有消息摘要
report_qor_suggestions -file [file join [file dirname [info script]] qor_suggestions.rpt]

# 检查状态
set synth_status [get_property STATUS [get_runs synth_1]]
puts ""
puts "=== Synthesis completed ==="
puts "  Status: $synth_status"
puts "  Finished at: [clock format [clock seconds]]"
puts ""

# 输出关键信息用于摘要
puts "=== RESOURCE_UTILIZATION ==="
report_utilization -quiet

# 获取时序信息
puts ""
puts "=== TIMING_SUMMARY ==="
report_timing_summary -quiet -no_header -max_paths 10
