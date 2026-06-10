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
| rtl_implementer | `rtl_implementer` | Sub-agent | RTL 设计 + L1a 仿真验证 |
| rtl_reviewer | `rtl_reviewer` | Sub-agent | RTL 审查（只读 RTL） |
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
rtl_implementer → 产出 RTL + L1a testbench + 仿真报告（orchestrator 传入 architecture.md）
rtl_reviewer → 产出 review report（L0）
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
| integration_verifier | rtl_implementer（需已验证的子模块 RTL） |
| vivado_integrator | rtl_implementer（需 RTL 文件列表） |
| hardware_validator | vivado_integrator（需 bitstream） |
| process_owner | 所有前序角色 |

---

## G1: Spawn 决策规则

收到用户需求时，按以下优先级判断是否需要 spawn 子智能体：

1. **用户显式指定了 agent** → 直接 spawn
2. **已有 task yaml 且 agent 字段非空** → spawn 对应 agent
3. **需求属于以下技术工作** → 创建 task yaml，然后 spawn：

| 需求类别 | agent |
|---------|------|
| 启动新 FPGA 项目 | `planner` |
| 架构设计/验证规划 | `planner` |
| 模块 RTL 设计 + L1a 验证 | `rtl_implementer` |
| L1a 完成后的代码审查 | `rtl_reviewer` |
| 数据通路闭环仿真 (L1b) | `integration_verifier` |
| 全系统集成仿真 (L1c) | `integration_verifier` |
| 集成失败回修 | `rtl_implementer` |
| XDC 约束编写 | `vivado_integrator` |
| Vivado 工程/综合/实现 | `vivado_integrator` |
| 上板验证 (L5/L6) | `hardware_validator` |
| 流程检查/复盘 | `process_owner` |

4. **需求是管理工作** → orchestrator 自己处理，不 spawn
5. **涉及跨文件接口变更** → 不得委托 sub-agent，orchestrator 亲自执行

**不确定时，优先 spawn 子智能体。** 但跨文件接口变更必须亲自执行。

## G2: Handoff 决策规则

Handoff 是 **session 边界** 机制，不是 agent 边界机制。

- **同一 session 内**：orchestrator spawn sub-agent A → 接收结果 → spawn sub-agent B 时传入 A 的产出。**不需要 handoff**
- **Session 结束时**：后续 task 尚未完成 → 创建 handoff（含 Gate Status 表）
- **Compact 触发时**：视为 session 边界，同样需要 handoff
- **所有 task 已完成**：不需要 handoff

## G3: Review 范围决策规则

| 文件类型 | Review 要求 | Reviewer |
|---------|:--:|------|
| 所有 RTL 文件 (`rtl/*.v` / `rtl/*.sv`) | **必须** | rtl_reviewer |
| 所有 XDC 约束 | **必须** | rtl_reviewer 或 vivado_integrator |
| architecture.md / verification_plan.md | **必须** | rtl_reviewer 或 planner（交叉审查） |
| Testbench（模块级定向测试） | 可选 | orchestrator 判断 |
| Testbench（UVM/复杂随机测试） | **必须** | 交叉审查 |
| 集成 Testbench（L1b/L1c） | **必须** | rtl_reviewer 或 integration_verifier（交叉审查） |
| Tcl 脚本、board 脚本 | 可选 | orchestrator 判断 |

## G4: 验证失败升级规则（v0.2 issue-centered iteration）

### L1b/L1c 失败处理流程

```
integration_verifier 发现失败
  ├─ 1. 创建 ISS issue
  ├─ 2. orchestrator 分配给 suspected module_owner
  ├─ 3. module_owner 修复（优先排查 DUT）
  ├─ 4. integration_verifier 重验
  └─ 迭代控制：
       round 1-2：正常往返
       round 3：spawn rtl_reviewer 深度审查
       round > 3：停止迭代，status=blocked，请求 human_owner 介入
```

### 阻断规则

| 情况 | 动作 |
|------|------|
| 未创建 ISS issue 就反复修改 TB 重试 | **硬阻断** |
| 在 TB 中 workaround 绕过疑似 DUT bug | **硬阻断** |
| 同一 issue 超过 3 轮仍未解决 | **硬阻断**，转 human_owner |
| Gate violation（跳级） | **硬阻断** |
| integration_verifier 擅自修改子模块 RTL | **硬阻断**（除非 human_owner 授权） |

### 迭代方向刹车

同一 ISS issue 连续 3 轮 WNS 改善 < 5% 且某资源（IOB/BRAM/DSP）> 75% → 阻断 spawn，orchestrator 必须写根因分析并请求 human_owner 确认方向。

### B-G4：上板验证失败处理

上板失败按类别分诊（各类别独立上限）：

| 类别 | 含义 | 上限 | 超限动作 |
|------|------|:--:|---------|
| CAT-HW | JTAG 链/电源/线缆物理问题 | 2 | → human_owner |
| CAT-BS | PS 启动失败/时钟异常/比特流加载失败 | 2 | → human_owner |
| CAT-AX | AXI-Lite 寄存器读写异常 | 2 | → vivado_integrator |
| CAT-IL | ILA 触发不工作/探针无信号 | 2 | → vivado_integrator |
| CAT-SW | PS 软件 bug（DMA/Cache） | 3 | → human_owner |
| CAT-DT | DMA 传输完成但数据异常 | 3 | → vivado_integrator 或 rtl_implementer |
| CAT-RT | ILA 证据确认的 RTL 逻辑 bug | 3 | → rtl_implementer（完整回修链） |

每次上板 session 失败必须一次性采集三类证据：ILA 波形 + PS 日志 + 比特流版本。缺少任意一项 → 不得关闭 session。
CAT-RT 必须经 ILA 证据确认后才能发起 RTL 回修。

## G5: Task 粒度决策规则

- **默认**：一个功能模块 = 一个 task（agent: `rtl_implementer`）
- **合并**：强耦合、接口不可分割的小模块 → 合并为一个 task
- **上限**：单个 task 的 `required_outputs` 不超过 5 个文件
- **L1b 集成验证**：按数据通路切片创建（agent: `integration_verifier`），每个切片包含 ≥2 个数据通路模块
- **L1c 全系统集成**：所有 L1b pass 后创建（`integration_scope: system`，target: `L1c`）

## G6: Scope 规则（分层责任边界）

integration_verifier 对子模块 RTL 的修改权限：

| 层级 | 条件 | 权限 |
|------|------|------|
| **may-fix-with-record** | 发现 bug 且修复明确（≤5 行改动） | 允许修改子模块 RTL，必须创建 ISS issue 记录 + 触发 L1a 回验 |
| **must-report** | 发现 bug 但修复不明确或涉及接口变更 | 禁止修改，创建 ISS issue，交回 rtl_implementer |
| **must-escalate** | 无法定位根因或涉及架构级问题 | 创建 ISS issue，status=blocked，转 human_owner |

| Agent | 允许编辑 | 禁止编辑 |
|-------|---------|---------|
| `rtl_implementer` | 本模块 RTL + L1a TB + 本模块文档 | 其他模块 RTL、集成 TB、架构文档 |
| `rtl_implementer` (fix) | 本模块 RTL + L1a TB（即使 status=review） | 其他模块 RTL、集成 TB |
| `integration_verifier` (L1b/L1c) | L1b/L1c TB、golden model、run script、ISS issue；子模块 RTL 仅 may-fix-with-record | 架构文档 |
| `rtl_reviewer` | review report、issue 建议 | 默认不直接改 RTL |

## G7: Task 状态转换规则

| 转换 | 触发条件 | 执行者 |
|------|---------|--------|
| `ready` → `in_progress` | orchestrator spawn 子智能体开始执行 | orchestrator |
| `in_progress` → `review` | rtl_implementer 完成 L1a 自证，L1b/L1c 待集成确认 | orchestrator |
| `in_progress` → `blocked` | 依赖的 task 未完成、Gate violation、等待用户决策 | orchestrator |
| `blocked` → `in_progress` | 阻塞解除 | orchestrator |
| `review` → `done` | 全部 applicable level pass + acceptance 全满足 + required_outputs 完整 | orchestrator |
| `review` → `in_progress` | 集成验证发现缺陷 → rtl_implementer 回修 | orchestrator |
| `in_progress` → `done` | 不需要 review 的非 RTL task，验收条件满足 | orchestrator |
| `done` → `review` | sync 检测到模块 task done 但 L1b/L1c=pending | sync |

**done 的 v0.2 准入条件**：
1. `acceptance` 全部通过
2. `required_outputs` 全部存在且内容完整
3. 所有 applicable 的验证 level 均为 pass
4. 无 open status 的 blocking issue 关联本 task
5. 模块 task 的 L1b/L1c=pending 时 status 不得为 done（sync 自动修正为 review）

## G8: 项目完成触发

当 task_board 中所有 task 状态均为 `done` 时：
1. 创建 `process_owner` 任务，spawn 子智能体编写复盘
2. 完成最终 session 记录和 handoff
3. 向用户汇报项目总结

## G9: 平台合同管理

- 平台在冻结后 BD 不可修改，约束文件冻结
- accelerator IP 可独立迭代（RTL 变更 → 重新打包 IP → BD 中 Upgrade IP）
- 基座升版需更新平台清单版本号 + CHANGELOG + ADR
- 同一 Vivado 工程不可同时被 GUI 和 MCP Tcl 打开
- `make_wrapper` 需在 `validate_bd_design` 通过后执行
