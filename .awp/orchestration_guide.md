# 编排指南 —— 标准角色与调度策略

> **角色定义已迁移至 `.claude/agents/*.md`。** 本文档保留编排策略和角色间协作关系。

## 工具链边界检查（所有 session 进入跨工具链工作前的强制关卡）

> FPGA 工具链是一个闭合环路。**任何一个环节的断裂都会导致下游全部白费。**

```
Vivado BD → XSA → Vitis/BSP → C code → XSCT → hardware → ILA 观察 → (反馈回 BD)
```

在跨越环节边界时（特别是 Vivado→Vitis 和 Vitis→上板），必须执行以下检查。

### 边界 1：Vivado → Vitis（进入软件工作前）

```
[ ] BD 完整性
    - ILA probe 是否悬空？每个 SLOT 是否连接到了正确的 AXI 接口？
    - Accelerator 的 s_axis / m_axis / s_axil 是否全部连接？
    - DMA → Interconnect → HP0 的 AXI 通路无断点？
    - validate_bd_design 是否通过？

[ ] XSA 新鲜度
    - 用户最近一次 export XSA 是什么时候？
    - 晚于最后一次 BD/RTL 修改吗？
    - 用户是否明确说了"已重新生成 BD → bitstream → export XSA"？
      如果是 → 丢弃所有旧的 XSA 和 Vitis 工作区，从新 XSA 开始

[ ] XSA ↔ bitstream 配套
    - bitstream 和 ps7_init.tcl 是从同一个 XSA 中提取的吗？
    - 不是的话 Vitis BSP 的 xparameters.h 地址会与实际硬件不匹配
```

### 边界 2：Vitis → 上板（烧录前）

```
[ ] PS 初始化只用 XSCT
    - 永远不用 Vivado Hardware Manager 的 program_hw_devices（覆盖 PS 状态）

[ ] ILA 触发条件已设
    - 触发值不能是 eq*'hX（don't-care，会导致立即填满 IDLE 数据）
    - 应设为 tvalid=eq1'b1 AND tready=eq1'b1（AXI Stream handshake）

[ ] 软件 Gate 可用
    - 对时序敏感的捕获（DMA stream），CPU 侧需要 gate 等待机制
    - 流程: CPU 停 gate → arm ILA → 释放 gate → DMA 跑 → ILA 捕获
```

### 边界 3：收到用户声明"已重新生成"时

```
这是最高优先级的信号。立即执行:
1. 停止当前所有基于旧 XSA 的 Vitis 编译/测试
2. 从用户指定的 XSA 路径开始重建 BSP
3. 用新 XSA 的 ps7_init.tcl 和 bitstream 替换所有旧文件
4. 重新编译所有 C 代码（因为 xparameters.h 可能已变化）
```

> **核心教训**：在边界检查通过之前，不要在工具链下游做任何工作。
> 今天的 session 中 4 小时被浪费，根因就是跨边界时没有检查 BD 完整性和 XSA 同步状态。

---

## 角色总览

| 角色 | Agent 名 | 类型 | 说明 |
|------|---------|------|------|
| human_owner | `human_owner` | 人类 | 人类项目负责人，不可被 spawn |
| orchestrator | `orchestrator` | Session | 主 session 角色，调度子智能体 |
| planner | `planner` | Sub-agent | 架构与验证计划 |
| rtl_implementer | `rtl_implementer` | Sub-agent | RTL 设计实现 |
| rtl_reviewer | `rtl_reviewer` | Sub-agent | RTL 审查（只读 RTL） |
| tb_verifier | `tb_verifier` | Sub-agent | 模块级 Testbench 与仿真（L1a） |
| integration_verifier | `integration_verifier` | Sub-agent | 集成仿真验证（L1b/L1c），跨模块时序与多帧测试 |
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
rtl_reviewer → 产出 review report（L0）
tb_verifier → 产出模块级 testbench + 仿真报告（L1a）
  ↓ 每 3-4 个模块后：
integration_verifier → 产出数据通路闭环仿真报告（L1b）
  ↓ 全部模块完成后：
integration_verifier → 产出全系统集成仿真报告（L1c）
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
| integration_verifier | tb_verifier + rtl_implementer（需已验证的子模块 RTL） |
| vivado_integrator | rtl_implementer（需 RTL 文件列表） |
| hardware_validator | vivado_integrator（需 bitstream） |
| process_owner | 所有前序角色 |
