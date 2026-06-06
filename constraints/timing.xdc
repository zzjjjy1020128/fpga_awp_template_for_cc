# ============================================================================
# timing.xdc — 时钟与 I/O 约束
# 顶层模块: axil_2d_shift
# 器件: xc7z020clg400-1
# 时钟: 100 MHz, 10 ns 周期
# ============================================================================

# 主时钟约束
create_clock -period 10.000 -name clk [get_ports clk]

# 输入延迟约束（相对于 clk 的 2.0ns 输入延迟，排除 clk 端口）
set_input_delay -clock clk 2.0 [get_ports {rstn s_axil_awaddr[*] s_axil_awvalid s_axil_wdata[*] s_axil_wstrb[*] s_axil_wvalid s_axil_bready s_axil_araddr[*] s_axil_arvalid s_axil_rready s_axis_tdata[*] s_axis_tvalid s_axis_tlast s_axis_tuser m_axis_tready}]

# 输出延迟约束（相对于 clk 的 2.0ns 输出延迟）
# 输出 delay = 1.0ns（xc7z020 IOB 时钟偏斜 ~5.2ns，需较小 output_delay 收敛）
set_output_delay -clock clk 1.0 [all_outputs]

# ============================================================================
# IOB 寄存器打包：将输出寄存器放入 IOB 逻辑
# 消除 fabric 到 OBUF 的长路径延迟和 clock skew 影响
# ============================================================================
set_property IOB TRUE [get_cells -hier -filter {NAME =~ "*s_axil_rdata_reg*"}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ "*s_axil_rresp_reg*"}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ "*s_axil_rvalid_reg*"}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ "*s_axil_bvalid_reg*"}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ "*s_axil_bresp_reg*"}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ "*s_axil_wready_reg*"}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ "*s_axil_awready_reg*"}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ "*s_axil_arready_reg*"}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ "*m_axis_tdata_reg*"}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ "*m_axis_tvalid_reg*"}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ "*m_axis_tlast_reg*"}]
set_property IOB TRUE [get_cells -hier -filter {NAME =~ "*m_axis_tuser_reg*"}]

# ============================================================================
# 多周期路径：step_mod 和配置寄存器仅在帧间变化
# 允许 2 个周期完成计算（setup=2, hold=1）
# ============================================================================
set_multicycle_path -setup 2 -from [get_cells -hier -filter {NAME =~ "*img_rows_r_reg*"}] -to [get_cells -hier -filter {NAME =~ "*step_mod*"}]
set_multicycle_path -hold  1 -from [get_cells -hier -filter {NAME =~ "*img_rows_r_reg*"}] -to [get_cells -hier -filter {NAME =~ "*step_mod*"}]
set_multicycle_path -setup 2 -from [get_cells -hier -filter {NAME =~ "*img_cols_r_reg*"}] -to [get_cells -hier -filter {NAME =~ "*step_mod*"}]
set_multicycle_path -hold  1 -from [get_cells -hier -filter {NAME =~ "*img_cols_r_reg*"}] -to [get_cells -hier -filter {NAME =~ "*step_mod*"}]
set_multicycle_path -setup 2 -from [get_cells -hier -filter {NAME =~ "*cfg_step_r_reg*"}] -to [get_cells -hier -filter {NAME =~ "*step_mod*"}]
set_multicycle_path -hold  1 -from [get_cells -hier -filter {NAME =~ "*cfg_step_r_reg*"}] -to [get_cells -hier -filter {NAME =~ "*step_mod*"}]
