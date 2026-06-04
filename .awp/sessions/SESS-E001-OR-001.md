# Session 记录

> Session ID: `cf1a7e5f-5fc9-43df-91d1-610734c1c0b2`
> 日期: 2026-06-04

## Session Goal

启动 AXI-Lite 2D Shift 模块 FPGA 项目（E001），完成完整 RTL 设计与 L0/L1a 验证；
通过集成仿真失败暴露 AWP 方法论缺陷，完成复盘与规范修复。

## Tasks Worked

| Task ID | Agent | 状态变化 | 产出 |
|---------|-------|---------|------|
| TASK-E001-001 | planner | ready → done | project_charter.md, architecture.md, verification_plan.md |
| TASK-E001-002 | rtl_implementer | ready → review → fail → fixed → done | axil_slave_if.sv, regs_top.sv |
| TASK-E001-003 | rtl_implementer | ready → done | ctrl_fsm.sv |
| TASK-E001-004 | rtl_implementer | ready → done | axis_input.sv |
| TASK-E001-005 | rtl_implementer | ready → fail → fixed → done | shift_addr_gen.sv |
| TASK-E001-006 | rtl_implementer | ready → done (TB bug 修复) | axis_output.sv |
| TASK-E001-007 | rtl_implementer | ready → done | frame_buf_mgr.sv |
| TASK-E001-008 | rtl_implementer | ready → review (L0 pass, L1c TB 调试中) | axil_2d_shift.sv |

额外方法论工作：
- docs/retrospective.md — AWP 系统性缺陷分析
- AWP 规范修复（CLAUDE.md, agents, schemas, templates, scripts）
- 自洽性审核 + 8 个问题修复

## 验证结果汇总

| Task | L0 | L1a | L1b | L1c | 断言 |
|------|:--:|:---:|:---:|:---:|------|
| TASK-E001-001 | pass | skip | skip | skip | — |
| TASK-E001-002 | pass | pass | skip | skip | 16/16 |
| TASK-E001-003 | pass | pass | skip | skip | 52/52 |
| TASK-E001-004 | pass | pass | skip | skip | 126/126 |
| TASK-E001-005 | pass | pass | skip | skip | 1233/1233 |
| TASK-E001-006 | pass | pass | skip | skip | 228/228 |
| TASK-E001-007 | pass | pass | skip | skip | 195/195 |
| TASK-E001-008 | pass | skip | pending | pending | 9/269 (TB 问题) |

## Key Decisions

- 帧缓冲架构（先存后读）
- SW_RESET 统一 CTRL[1]，删除独立寄存器
- STATUS.done 在 CTRL.start 写 1 时清除
- Wrap 模运算使用 % 运算符
- zero_fill 经 1 级流水线对齐 BRAM read_data
- AWP L1 拆分为 L1a/L1b/L1c 三个子级别
- 新增 integration_verifier 角色（pro 模型，L1b/L1c）
- tb_verifier 允许诊断性 RTL 访问
- G4 失败升级改为第 2 次切换 agent 类型

## Issues Found

- RTL: NBA 竞争 bug（axil_slave_if）→ 已修复
- RTL: Wrap 模运算 bug（shift_addr_gen）→ 已修复
- RTL: shift_addr_gen 计数器跨帧残留 → 已定位根因，**未修复**（留给新 session 测试方法论）
- TB: axis_output 时序 bug → 已修复
- TB: 集成仿真 pipeline 对齐 → TB 层调试失败，根因是 DUT bug 被 TB 过度补偿
- AWP: 8 个自洽性问题 → 全部修复

## Gate Check

- [x] L0: 全部 pass
- [x] L1a: 7/7 模块 pass（1850 断言）
- [ ] L1b: 未执行（旧流程跳过）
- [ ] L1c: TASK-E001-008 集成仿真失败（TB 问题 + DUT bug）
- [x] `make validate-awp` 全程通过

## Handoff

- **Next Task**：TASK-E001-008（L1b + L1c 集成验证）
- **Handoff File**：`.awp/handoffs/HO-E001-008-001.md`
- **备注**：handoff 只描述现象不透露根因，用于测试新方法论
