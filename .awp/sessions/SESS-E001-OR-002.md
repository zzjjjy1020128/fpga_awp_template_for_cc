# Session 记录

> Session ID: SESS-E001-OR-002

## Session Goal

FPGA-AWP v0.2 架构全面升级：从 RTL 设计验证到 Vivado 综合实现的完整闭环，并多次复盘改进 AWP 规范自身。

## Tasks Worked

| Task ID | Agent | 状态变化 | 产出 |
|---------|-------|---------|------|
| TASK-E001-001~011 | 各 agent | review → done | L0-L1c 全验证通过 |
| TASK-E001-012 | vivado_integrator | ready → done | L2 综合 PASS |
| TASK-E001-013 | vivado_integrator | ready → done | L3 实现 WNS=+0.364ns |
| TASK-E001-014 | planner | ready → done | ZCU102 BD 架构设计文档 |
| TASK-E001-015 | vivado_integrator | ready → in_progress | BD 创建（Tcl 自动化受阻） |

## Key Decisions

1. v0.2 架构：module_owner 合并 RTL+L1a、L1b 数据通路 checkpoint、ISS issue 系统
2. G1 跨文件接口变更规则——不得委托 sub-agent
3. G4 迭代刹车——同一 issue ≥3 轮 + WNS 改善 <5% → 阻断
4. G1 orchestrator 必须审核资源报告（IOB/BRAM/DSP > 70%）
5. Registry 从手动记录改为 `--sync` 自动生成
6. Vivado 2022.2 BD 必须在 GUI 创建（Tcl make_wrapper 不可用）
7. Port connectivity 检查加入 validate_awp.py
8. IOB 81.6% 方向错误复盘 → awp-retrospect skill

## Issues Found

1. Vivado 2022.2 Tcl `make_wrapper` + `validate_bd_design` 对含 PS 的 BD 一致失败
2. sub-agent 跨文件端口变更遗漏实例化点连接（data_valid_i 事件）
3. xc7z020 102 IOB 架构方向错误——应走 ZCU102 MPSoC + PS AXI
4. MCP generate_bitstream 在 CW 存在时假报成功但 .bit 未生成

## Gate Check

- [x] `--gate-check` 退出码 0
- [x] 当前 task 的 target 以下无 pending level

## Validation Status

| Level | Status | 备注 |
|-------|--------|------|
| L0: 静态审查 | pass | 全部模块 + 架构 |
| L1a: 模块级单元仿真 | pass | 1,233+ assertions |
| L1b: 数据通路闭环仿真 | pass | WRITE/READ/CONTROL |
| L1c: 全系统集成仿真 | pass | 247/247 assertions |
| L2: 综合 | pass | Zynq-7000 + MPSoC 均 PASS |
| L3: 实现与时序 | pass | WNS=+0.364ns (Zynq-7000) |
| L4: 比特流生成 | pending | CW 阻塞，需 GUI 生成 |
| L5-L7 | pending | 未执行 |

- [x] `python scripts/validate_awp.py` 通过

## Handoff

- Next Task：TASK-E001-015（BD 自动化完成）或 L5 上板验证
- Handoff File：`.awp/handoffs/HO-E001-015-001.md`
- Gate Status 已填写：是
- 备注：Vivado 2022.2 BD 创建需在 GUI 中完成（Run Block Automation → Create HDL Wrapper），之后 MCP 全自动化
