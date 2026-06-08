#==============================================================================
# debug.xdc -- AX7010 调试探针配置 (Debug Probe Configuration)
#
# 目标器件: xc7z010clg400-1 (Alinx AX7010)
# 平台: HW_BASE_AX7010_v2.0 (独立调试时钟)
# 工具: Vivado 2022.2
#
# 功能:
#   通过 set_property MARK_DEBUG 将关键内部信号连接到 System ILA 探针。
#   Vivado 在综合/实现过程中自动将 MARK_DEBUG 信号路由至可用 ILA 核。
#
# v2.0 新增: dbg_hub 时钟强制绑定到外部 K17 50MHz
#   create_generated_clock 将 dbg_hub/clk 定义为 clk_debug_50m 的衍生时钟,
#   迫使 Vivado 综合引擎将 dbg_hub 时钟域从 FCLK_CLK0 切换到外部晶振。
#==============================================================================

#------------------------------------------------------------------------------
# dbg_hub 独立时钟域 (v2.0 新增)
#   将 auto-generated debug hub 时钟强制绑定到外部 K17 50MHz 晶振,
#   摆脱 PS FCLK_CLK0 依赖, 实现 Vivado 烧录后 ILA 即刻可用。
#------------------------------------------------------------------------------
create_generated_clock -name dbg_hub_ext_clk \
    -source [get_ports clk_debug_50m] \
    -divide_by 1 \
    [get_nets -hierarchical dbg_hub/clk]
#
# 探针分配计划:
#   system_ila_0 (SLOT_0_AXI, ～143 probes): AXI 控制面监控
#     - 寄存器读写 strobe (wr_strobe/rd_strobe)
#     - 写数据/读数据 (wdata/rdata)
#     - 配置寄存器输出 (ctrl_start, cfg_dir, cfg_step, cfg_wrap_en, img_rows, img_cols)
#     - 状态标志 (status_idle, status_busy_capture, status_busy_shift, status_done)
#
#   system_ila_1 (SLOT_0_AXI, ～143 probes): 数据通路监控
#     - AXI-Stream 输入 (s_axis_tdata/tvalid/tready/tlast/tuser)
#     - AXI-Stream 输出 (m_axis_tdata/tvalid/tready/tlast/tuser)
#     - FSM 控制信号 (capture_en, shift_en, shift_en_ao, capture_done, shift_done)
#     - BRAM 写 (write_addr, write_data, write_en)
#     - BRAM 读 (read_addr, read_data)
#     - 流水线控制 (zero_fill, zero_fill_d1)
#
# 层次路径说明:
#   顶层: design_1_wrapper
#     -> design_1_i (BD 例化)
#       -> axil_2d_shift_0 (加速器 IP 例化)
#         -> inst (axil_2d_shift 顶层模块, 在 IP wrapper 内部)
#           -> u_axil_slave_if, u_ctrl_fsm, 等子模块
#
# MARK_DEBUG 与 OOC IP:
#   本设计使用 OOC (Out-of-Context) 综合模式，IP 核内部信号在顶层综合
#   时通过 DCP 链接后可访问。本 XDC 使用 processing_order LATE，
#   确保在综合链接后处理。
#
# 验证路径方法 (综合后):
#   open_run synth_1
#   get_nets -hierarchical -filter {NAME =~ *axil_2d_shift_0*<signal_name>*}
#==============================================================================

#------------------------------------------------------------------------------
# system_ila_0: AXI 控制面 (AXI Control Plane) -- ～118 probes 估计
#------------------------------------------------------------------------------

# 寄存器写选通 (16 bit) -- 指示哪个寄存器槽被写入
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/wr_strobe]

# 寄存器读选通 (16 bit) -- 指示哪个寄存器槽被读取
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/rd_strobe]

# 写数据 (32 bit) -- AXI-Lite 写入的 32 位数据值
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/wdata]

# 读数据 (32 bit) -- AXI-Lite 读取返回的 32 位数据值
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/rdata]

# 启动脉冲 (1 bit) -- 软件写 CTRL[0] 触发
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/ctrl_start]

# 软复位脉冲 (1 bit) -- 软件写 CTRL[1] 触发
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/ctrl_sw_reset]

# 移位方向 (3 bit) -- 000=NONE, 001=UP, 010=DOWN, 011=LEFT, 100=RIGHT
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/cfg_dir]

# 移位步长 (5 bit, 0-31)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/cfg_step]

# 缠绕使能 (1 bit) -- 0=补零, 1=缠绕
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/cfg_wrap_en]

# 图像行数 (10 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/img_rows]

# 图像列数 (10 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/img_cols]

# 状态: 空闲 (1 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/status_idle]

# 状态: 采集中 (1 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/status_busy_capture]

# 状态: 移位中 (1 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/status_busy_shift]

# 状态: 完成 (1 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/status_done]

#------------------------------------------------------------------------------
# system_ila_1: 数据通路 (Data Path) -- ～72 probes 估计
#------------------------------------------------------------------------------

# ---- AXI-Stream 输入接口 ----
# 输入数据 (8 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/s_axis_tdata]

# 输入有效 (1 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/s_axis_tvalid]

# 输入就绪 (1 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/s_axis_tready]

# 行结束标志 (1 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/s_axis_tlast]

# 帧起始标志 (1 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/s_axis_tuser]

# ---- AXI-Stream 输出接口 ----
# 输出数据 (8 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/m_axis_tdata]

# 输出有效 (1 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/m_axis_tvalid]

# 输出就绪 (1 bit, 来自下游)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/m_axis_tready]

# 输出行结束 (1 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/m_axis_tlast]

# 输出帧起始 (1 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/m_axis_tuser]

# ---- FSM 控制信号 ----
# 采集使能 (1 bit, ctrl_fsm -> axis_input)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/capture_en]

# 移位使能 (1 bit, ctrl_fsm -> shift_addr_gen)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/shift_en]

# 延迟移位使能 (1 bit, 给 axis_output, 晚 shift_en 2 拍)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/shift_en_ao]

# 采集完成脉冲 (1 bit, axis_input -> ctrl_fsm)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/capture_done]

# 移位完成脉冲 (1 bit, axis_output -> ctrl_fsm)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/shift_done]

# ---- BRAM 写接口 (axis_input -> frame_buf_mgr) ----
# 写地址 (12 bit, 64*64=4096 深度)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/write_addr]

# 写数据 (8 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/write_data]

# 写使能 (1 bit)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/write_en]

# ---- BRAM 读接口 (shift_addr_gen -> frame_buf_mgr -> axis_output) ----
# 读地址 (12 bit, shift_addr_gen -> frame_buf_mgr)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/read_addr]

# 读数据 (8 bit, frame_buf_mgr -> axis_output, 1 周期延迟)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/read_data]

# ---- 流水线控制 ----
# 补零标志 (shift_addr_gen 流水线输出, 与 read_addr 同步)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/zero_fill]

# 延迟补零标志 (对齐到 BRAM 读延迟, 送 axis_output)
set_property MARK_DEBUG true [get_nets design_1_i/axil_2d_shift_0/inst/zero_fill_d1]

#------------------------------------------------------------------------------
# 处理顺序说明
#
# 因为 axil_2d_shift_0 IP 使用 OOC 综合，内部信号在顶层综合的早期阶段
# 不可见。将本文件的 processing_order 设为 LATE，使其在综合链接后处理。
#
# 使用方法--在 Vivado Tcl Console 或 project 中设置:
#   set_property PROCESSING_ORDER LATE [get_files constraints/debug.xdc]
#
# 如果综合后 MARK_DEBUG 未生效，可能是因为 OOC IP 的层次路径与预期不同。
# 参考以下方法确定实际路径:
#
#   # 在 synth_1 打开后执行:
#   open_run synth_1
#   # 查找 ctrl_fsm 状态信号
#   get_nets -hierarchical -filter {NAME =~ *state*}
#   # 确认路径后，更新本文件中的层次前缀
#==============================================================================
