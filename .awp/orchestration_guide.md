# 编排指南 —— 标准角色与调度策略

> **角色定义已迁移至 `.claude/agents/*.md`。** 本文档保留编排策略和角色间协作关系。

## 角色总览

| 角色 | Agent 名 | 类型 | 说明 |
|------|---------|------|------|
| human_owner | `human_owner` | 人类 | 人类项目负责人，不可被 spawn |
| orchestrator | `orchestrator` | Session | 主 session 角色，调度子智能体 |
| planner | `planner` | Sub-agent | 架构与验证计划 |
| rtl_implementer | `rtl_implementer` | Sub-agent | RTL 设计实现 |
| rtl_reviewer | `rtl_reviewer` | Sub-agent | RTL 审查（只读 RTL） |
| tb_verifier | `tb_verifier` | Sub-agent | Testbench 与仿真 |
| vivado_integrator | `vivado_integrator` | Sub-agent | Vivado 工程与约束 |
| hardware_validator | `hardware_validator` | Sub-agent | 上板验证与 ILA/VIO |
| process_owner | `process_owner` | Sub-agent | 流程监督与复盘 |

每个角色的详细系统提示词、工具白名单、权限设置见 `.claude/agents/{agent_name}.md`。

## 合规分层

```
┌─────────────────────────────────────────┐
│ 主 Session（orchestrator）               │
│ 职责：任务拆分、进度跟踪、合规归档        │
│ 承担：session 记录、handoff、validate-awp │
│         task_board 更新、门禁检查         │
├─────────────────────────────────────────┤
│ 子智能体（worker agents）                │
│ 职责：技术产出（RTL/tb/约束/报告）        │
│ 不承担：session 记录、handoff、task_board │
│         validate-awp、门禁检查            │
│ 遵守：scope 边界、不伪造结果、语言规范    │
└─────────────────────────────────────────┘
```

## 调度规则

1. **创建 task 时**：`agent` 字段填写 agent name（如 `rtl_implementer`）
2. **执行 task 时**：orchestrator 通过 Agent 工具 spawn 对应 agent 的子智能体，将 task yaml 内容作为 context 传入
3. **子智能体返回后**：orchestrator 负责运行 `make validate-awp`、更新 task_board、创建 session 记录
4. **Session 结束时**：若后续 task 尚未完成，orchestrator 创建 handoff 文件

## 典型工作流（Project 1 示例）

```
同一 session 内，orchestrator 顺序 spawn sub-agents：

planner → 产出 architecture.md + verification_plan.md
rtl_implementer → 产出 RTL（orchestrator 传入 architecture.md 作为 context）
rtl_reviewer → 产出 review report
tb_verifier → 产出 testbench + 仿真报告
vivado_integrator → 产出 bitstream + 时序报告
hardware_validator → 产出上板验证记录
process_owner → 产出 retrospective
```

Sub-agent 之间不直接交接。每个 sub-agent 的产出由 orchestrator 接收后传入下一个 sub-agent 的 context。
Handoff 仅在 session 结束时创建。

## 角色间依赖

| 角色 | 依赖前序角色 |
|------|------------|
| rtl_implementer | planner（需 architecture.md） |
| rtl_reviewer | rtl_implementer（需 RTL 文件） |
| tb_verifier | rtl_implementer（需 RTL 文件） |
| vivado_integrator | rtl_implementer（需 RTL 文件列表） |
| hardware_validator | vivado_integrator（需 bitstream） |
| process_owner | 所有前序角色 |
