# Skill: bd-debug-clock

## When to use

在 Zynq-7000 / MPSoC Block Design 中，需要让 ILA 调试核使用**独立于 PS FCLK 的外部时钟源**时使用。
典型场景：Vivado Hardware Manager 烧写 bitstream 后 ILA 立即可用，无需等待 PS 初始化。

## 关键发现

1. **System ILA v1.1 有显式 `clk` 和 `resetn` 引脚**，不是只能 auto-clock。可以通过 BD 手动连接。
2. **dbg_hub 时钟是独立问题**——ILA 核心时钟可改，但 debug hub（XSDB/JTAG 接口）由 Vivado 自动选时钟。
3. 外部时钟引脚约束**必须从官方板卡手册确认**，不能信任 sub-agent 或记忆。

## BD 操作序列

```tcl
# 1. 创建外部时钟端口
create_bd_port -dir I clk_debug_50m

# 2. 创建常高复位（ILA 不需 proc_sys_reset）
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_vcc_ila
set_property CONFIG.CONST_VAL 1 $vcc
set_property CONFIG.CONST_WIDTH 1 $vcc

# 3. 断开 ILA 原有 clk（通常连在 FCLK_CLK0）
disconnect_bd_net <FCLK_net> [get_bd_pins system_ila_0/clk]
connect_bd_net [get_bd_ports clk_debug_50m] [get_bd_pins system_ila_0/clk]

# 4. 断开 ILA resetn（通常连在 proc_sys_reset）
disconnect_bd_net <reset_net> [get_bd_pins system_ila_0/resetn]
connect_bd_net [get_bd_pins const_vcc_ila/dout] [get_bd_pins system_ila_0/resetn]

# 5. 对 system_ila_1 重复
# 6. validate_bd_design → save_bd_design → make_wrapper
```

## XDC 约束更新

```tcl
# ax7010_base_physical.xdc
# ⚠️ 引脚号必须从官方板卡手册确认！
set_property PACKAGE_PIN U18 [get_ports clk_debug_50m]   # AX7010: 50MHz on U18
set_property IOSTANDARD LVCMOS33 [get_ports clk_debug_50m]

# ax7010_base_timing.xdc
create_clock -period 20.000 -name clk_debug_50m [get_ports clk_debug_50m]
```

## 平台清单更新

- Platform ID 升版（如 v1.0 → v1.1）
- `freeze_rules` 中记录时钟方案变更理由
- `changelog` 添加独立调试时钟项

## 已知限制

- **dbg_hub 时钟可能仍依赖 FCLK**：修改 ILA 核心时钟 ≠ 修改 debug hub 时钟
- System ILA 在 BD 可视化窗口中探针显示浮空是**正常现象**——通过 MARK_DEBUG + 综合自动连接
- Vivado `opt_design` 的 "Phase 1 Generate Debug Cores" 会重建 debug core 基础设施，
  `connect_debug_port dbg_hub/clk` 的修改可能在此时丢失

## Language policy

- BD 操作/约束：en
- pin 说明：en
