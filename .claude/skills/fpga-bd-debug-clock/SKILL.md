---
skill_id: SKILL-FPGA-BD-DEBUG-CLOCK
name: fpga-bd-debug-clock
layer: FPGA-Method
status: local_adapted
source_basis:
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-15"
owner: human_owner
---

# Skill: bd-debug-clock

## When to use

- 在 Block Design 中需要让 ILA 使用**独立于 PS FCLK 的外部时钟源**时
- **"debug hub core was not detected" 诊断**——当 Vivado Hardware Manager 无法检测到 ILA 时的系统排查

## 核心概念：双重时钟域

System ILA 涉及**两个独立时钟**：

| 时钟域 | 引脚/网络 | 作用 | 可控性 |
|--------|----------|------|:--:|
| ILA Core Clock | `system_ila_0/clk` (BD pin) | 采样被监控信号 | BD 中手动连接 |
| Debug Hub Clock | `dbg_hub/clk` (实现后网表) | JTAG/XSDB 通信接口 | Vivado 自动从 ILA core clock 派生 |

**关键**：修改 ILA core clock ≠ 修改 debug hub clock。Vivado `opt_design` 的 "Phase 1 Generate Debug Cores" 自动将 `dbg_hub/clk` 的 PARENT 设为与 ILA core 相同的 BUFG 输出。因此**只需正确连接 ILA core clock，dbg_hub 时钟自动跟随**。

## "debug hub not detected" 诊断链

按以下顺序逐级验证，不可跳步：

### 1. BD 层：确认 ILA clk 引脚连接

```tcl
open_bd_design [get_files design_1.bd]
get_bd_nets -of_objects [get_bd_pins system_ila_0/clk]
get_bd_nets -of_objects [get_bd_pins system_ila_1/clk]
# 预期：返回有效 net 名，如 /clk_debug_50m_1 或 /processing_system7_0_FCLK_CLK0
# 若返回空：时钟浮空，需 connect_bd_net
```

### 2. 实现层：确认 dbg_hub/clk 的实际时钟源

```tcl
open_run impl_1
get_nets -hierarchical -filter {NAME =~ *dbg_hub/clk*}
# 确认 dbg_hub/clk 存在
report_property [get_nets dbg_hub/clk]
# 关键字段：PARENT = <BUFG_net_name>
# 这告诉你 dbg_hub 的真实时钟源
```

### 3. 物理层：确认 BUFG 已放置

```tcl
get_cells -hierarchical -filter {REF_NAME =~ *BUFG* && NAME =~ *<clock_name>*}
report_property [get_cells <bufg_cell>]
# 关键字段：STATUS = PLACED, LOC = BUFGCTRL_X*Y*
```

### 4. 配置层：确认 BSCAN 扫描链

```tcl
get_property C_USER_SCAN_CHAIN [get_debug_cores dbg_hub]
# 预期：1（对于 Zynq-7000）
# Hardware Manager 侧：
get_property BSCAN_SWITCH_USER_MASK [lindex [get_hw_devices] 1]
# 预期：0001（启用 chain 1）
```

### 5. 物理层：确认时钟源实际运行

- 若时钟来自 PS FCLK_CLK0：需 PS 初始化（XSDB `ps7_init` + `ps7_post_config`）
- 若时钟来自外部晶振（如 U18）：需确认板卡上该晶振**确实启振**（示波器/万用表测量）
- **板卡手册中标注"未使用"的晶振极可能未焊接或不启振**

### 诊断结果速查

| dbg_hub/clk PARENT | BUFG STATUS | 物理时钟 | 结论 |
|------|:--:|:--:|------|
| FCLK_CLK0 BUFG | PLACED | PS 未初始化 | 需要 XSDB ps7_init |
| U18 BUFG | PLACED | 晶振未启振 | 改回 FCLK_CLK0 或使能晶振 |
| 任意 | PLACED | 运行中 | 问题在 BSCAN/JTAG 层，继续排查 |

## BD 操作序列

### 连接 ILA 到 FCLK_CLK0

```tcl
# 原则：每次 run_tcl 只做一种操作，避免累积错误污染状态
# 1. 断开旧连接
disconnect_bd_net /clk_debug_50m_1 [get_bd_pins system_ila_0/clk]
disconnect_bd_net /clk_debug_50m_1 [get_bd_pins system_ila_1/clk]

# 2. 连接新时钟（pin-to-pin，不是 net-to-pin）
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins system_ila_0/clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins system_ila_1/clk]

# 3. 验证 → 保存 → 生成 wrapper
validate_bd_design
save_bd_design
make_wrapper -files [get_files design_1.bd] -top
```

### 连接 ILA 到外部晶振

```tcl
# 1. 创建外部时钟端口
create_bd_port -dir I clk_debug_50m

# 2. 连接 ILA
disconnect_bd_net <old_net> [get_bd_pins system_ila_0/clk]
connect_bd_net [get_bd_ports clk_debug_50m] [get_bd_pins system_ila_0/clk]

# 3. 对 system_ila_1 重复
```

## 反模式

### create_generated_clock 不能替代物理连接

```tcl
# 错误：这是时序约束注解，不会物理连接时钟
create_generated_clock -name dbg_hub_ext_clk \
    -source [get_ports clk_debug_50m] \
    -divide_by 1 \
    [get_nets -hierarchical dbg_hub/clk]
```

这段 XDC 有两个问题：
1. `create_generated_clock` 是**时序约束**，不是物理连接。它告诉 STA 工具时钟关系，但不会改变任何 netlist 连接。
2. XDC 解析时（实现早期）`dbg_hub/clk` **尚不存在**——它在 `opt_design` "Phase 1 Generate Debug Cores" 才被创建。约束必然失败（CRITICAL WARNING: No valid object(s) found）。

**正确做法**：在 BD 中连接 ILA clk 引脚到目标时钟源。Vivado 自动将 dbg_hub 时钟派生到同一 BUFG。

### System ILA 探针在 BD 中看起来浮空是正常的

在 BD 可视化窗口中，System ILA 的 SLOT 探针显示为未连接——这是正常现象。MARK_DEBUG 信号通过综合后自动关联到 ILA 探针，不需要在 BD 中手动连接。**不要在 BD 中 `connect_bd_net` 到 AXI 接口的个别 pin**——这会破坏 interface connection。

## XDC 约束

```tcl
# ax7010_base_physical.xdc
# ⚠️ 引脚号必须从官方板卡手册确认！
set_property PACKAGE_PIN U18 [get_ports clk_debug_50m]
set_property IOSTANDARD LVCMOS33 [get_ports clk_debug_50m]

# ax7010_base_timing.xdc
create_clock -period 20.000 -name clk_debug_50m [get_ports clk_debug_50m]
```

## 平台清单更新

- Platform ID 升版（如 v1.0 → v1.1 → v1.2）
- `freeze_rules` 中记录时钟方案变更理由
- `changelog` 添加独立调试时钟项

## 相关 Skills

- `fpga-zynq-debug-toolchain` — ILA 触发配置和 hw_server 调度
- `fpga-board-validation` — L5 冒烟测试中的 ILA 时钟验证
- `fpga-hw-pin-verify` — 时钟引脚交叉验证（U18 vs K17 案例）
- `fpga-vivado-methodology` — 综合/实现中的 ILA 探针和 debug 约束
- `fpga-iteration-economics` — BD 修改后重新综合的成本

## Language policy

- BD 操作/约束：en
- pin 说明：en
- 诊断说明：zh
