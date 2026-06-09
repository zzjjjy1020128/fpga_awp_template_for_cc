#==============================================================================
# ax7010_base_physical.xdc — AX7010 基座物理约束
# 目标: xc7z010clg400-1 (Zynq-7000, Alinx AX7010)
# 版本: v1.1 — 添加独立调试时钟引脚
#==============================================================================
# DDR 与 FIXED_IO 的引脚由 PS7 IP board automation 自动处理。
#==============================================================================

# 独立调试时钟 — 板载 50 MHz 有源晶振 (Y2, PL U18)
# 用途: System ILA 独立时钟域，摆脱 PS FCLK 依赖
set_property PACKAGE_PIN U18 [get_ports clk_debug_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_debug_50m]
