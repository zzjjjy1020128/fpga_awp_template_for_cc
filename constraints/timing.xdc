# ============================================================================
# timing.xdc — 时钟与 I/O 约束
# 顶层模块: axil_2d_shift
# 器件: xc7z020clg400-1
# 时钟: 100 MHz, 10 ns 周期
# ============================================================================

# 主时钟约束
create_clock -period 10.000 -name clk [get_ports clk]

# 输入延迟约束（相对于 clk 的 2.0ns 输入延迟，排除 clk 端口）
set_input_delay -clock clk 2.0 [list [remove_from_list [all_inputs] [get_ports clk]]]

# 输出延迟约束（相对于 clk 的 2.0ns 输出延迟）
set_output_delay -clock clk 2.0 [all_outputs]
