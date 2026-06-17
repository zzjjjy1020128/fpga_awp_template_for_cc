# METHODOLOGY.md —— FPGA-AWP 方法论宣言

> **这是整个 FPGA-AWP 工作区的入口文档。** 定义项目的完整生命周期、执行模型和核心原则。
> 新加入的工程师/智能体从此文档开始。所有其他文档通过底部索引指向。

---

## 1. 这是什么

FPGA-AWP 是一套面向 FPGA 开发的 **智能体优先（Agent-Native）方法论**，覆盖从项目启动到验收签收的完整闭环。

**适用场景**：单人或小团队的 FPGA 项目，使用 Vivado + Vitis 工具链，基于 Zynq / Artix / Kintex 等 Xilinx 器件。

**核心理念**：不追求大团队角色分离，而是让一个拥有全局视野的执行者（orchestrator）借助专业工具（子智能体）完成全链路工作。

---

## 2. 生命周期模型

FPGA-AWP 项目经历 6 个 Phase。每个 Phase 有明确的 **entry criteria**（进入条件）、**输出 artifact**（必须产出）、**exit criteria**（退出条件，即门禁）。

```
 Phase 0           Phase 1           Phase 2            Phase 3
┌─────────┐      ┌─────────┐       ┌─────────┐        ┌─────────┐
│ 项目启动 │ ───→ │ 架构设计 │ ────→ │ RTL+验证 │ ────→  │ 集成验证 │
│         │      │         │       │  L0,L1a │        │ L1b,L1c │
└─────────┘      └─────────┘       └─────────┘        └─────────┘
                                                           │
 Phase 6           Phase 5            Phase 4              │
┌─────────┐      ┌─────────┐       ┌─────────┐            │
│ 收尾复盘 │ ←─── │ 上板验证 │ ←──── │ 硬件实现 │ ←──────────┘
│   L7    │      │  L5,L6  │       │ L2,L3,L4│
└─────────┘      └─────────┘       └─────────┘
```

### Phase 0: 项目启动

| 项 | 内容 |
|---|------|
| **目标** | 确定项目范围、验收标准、干系人和约束 |
| **输入** | 用户需求（自然语言描述） |
| **输出** | `PROJECT_CHARTER.md`、`ACCEPTANCE_CONTRACT.md` |
| **Entry** | 用户确认启动项目 |
| **Exit** | 章程定义了明确的 scope 边界 + 验收合同定义了每级的 pass/fail 标准 |
| **执行者** | orchestrator（必要时 spawn planner 辅助生成模板） |
| **关联 Skills** | `fpga-project-charter`、`fpga-project-acceptance` |

### Phase 1: 架构设计

| 项 | 内容 |
|---|------|
| **目标** | 将需求转化为可量化的硬件架构规格 |
| **输入** | 项目章程、验收合同 |
| **输出** | `architecture.md`、`verification_plan.md` |
| **Entry** | Phase 0 exit criteria 满足 |
| **Exit** | 模块划分明确 + 接口规格（协议/位宽/方向）完整 + 时钟域定义清晰 + 验证计划覆盖所有验收场景 |
| **执行者** | orchestrator（必要时 spawn planner 辅助模板化和搜索） |
| **关联 Skills** | `fpga-validation-levels`、`fpga-software-env-profile` |

### Phase 2: RTL 设计与单元验证

| 项 | 内容 |
|---|------|
| **目标** | 逐模块实现 RTL 并通过 L0 静态审查 + L1a 单元仿真 |
| **输入** | `architecture.md`、`verification_plan.md` |
| **输出** | 每个模块：`rtl/<module>.sv`、`tb/tb_<module>.sv`、`RUN-E001-L1A-*.md`（仿真报告） |
| **Entry** | Phase 1 exit criteria 满足 + 目标模块的前置依赖模块已 pass |
| **Exit** | L0 pass（rtl_reviewer cross-check 或 orchestrator 自审）+ L1a pass（定向测试，至少覆盖正常帧 + 2 个边界条件） |
| **执行者** | orchestrator（RTL 设计、TB 编写、仿真调试），可 spawn rtl_implementer 做独立模块生成、spawn rtl_reviewer 做 checklist 扫描 |
| **关联 Skills** | `fpga-module-owner-l1a`、`fpga-rtl-review`、`fpga-rtl-style`、`fpga-cdc-review`、`fpga-axi-lite-review`、`fpga-axis-review`、`fpga-sim-verification`、`fpga-formal-sanity` |

**每个模块的推荐模板**：`.awp/templates/module_spec.template.yaml`（接口规格），`.awp/templates/test_plan.template.yaml`（测试计划）。

### Phase 3: 集成验证

| 项 | 内容 |
|---|------|
| **目标** | 验证模块间数据通路和控制通路的正确性 |
| **输入** | 2 个以上 Phase 2 pass 的子模块 RTL + 集成 TB |
| **输出** | `RUN-E001-L1B-*.md`（每个数据通路切片）、`RUN-E001-L1C-*.md`（全系统）、失败时 `ISS-*.yaml` |
| **Entry** | 足够模块 Phase 2 pass |
| **Exit** | L1b 所有切片 pass + L1c pass（全系统集成仿真 ≥ 10^5 cycles） |
| **执行者** | orchestrator（编写集成 TB、执行仿真、诊断失败），可 spawn integration_verifier 生成仿真脚本模板 |
| **关联 Skills** | `fpga-l1b-datapath-verify`、`fpga-integration-failure-debug` |

**失败处理**：
```
仿真失败 → 创建 ISS issue → orchestrator 诊断根因（优先排查 DUT）
    → RTL 修复 → L1a 回验 → 重跑失败 level
    → 同一 issue 3 轮未解 → 升级 human_owner，不继续迭代
```

**切片定义**：Write Path (axis_input → frame_buf_mgr)、Read Path (shift_addr_gen → frame_buf_mgr → axis_output)、Control Path (axil_slave_if → ctrl_fsm → datapath stubs)。

### Phase 4: 硬件实现

| 项 | 内容 |
|---|------|
| **目标** | 将验证通过的 RTL 转化为 FPGA 比特流 |
| **输入** | L1c pass 的完整 RTL + 约束文件 |
| **输出** | `.bit` 比特流文件、`.xsa` 硬件描述文件、综合/实现/时序报告 |
| **Entry** | Phase 3 exit criteria 满足 + 约束文件就绪 + 主机环境 active (`host_env.yaml`) |
| **Exit** | L2 综合 pass (0 CW) + L3 时序收敛 (WNS/WHS ≥ 0) + L4 比特流生成成功 + XSA 导出成功 |
| **执行者** | orchestrator 决策（时钟频率、约束策略），**spawn vivado_integrator 执行工具操作**（综合/实现/比特流） |
| **关联 Skills** | `fpga-vivado-preflight`（操作前必调）、`fpga-vivado-methodology`、`fpga-vivado-log-analysis`、`fpga-platform-freeze`、`fpga-bd-debug-clock`、`fpga-host-env-detect` |

**重要**：Vivado 综合/实现是典型的长耗时工具操作——它是 **orchestrator 最应该 spawn 子智能体的场景**。子智能体不需要项目上下文，只需要工程路径和目标。

### Phase 5: 上板验证

| 项 | 内容 |
|---|------|
| **目标** | 在真实硬件上验证比特流功能的正确性 |
| **输入** | `.bit` 文件 + `.xsa` 文件 + PS 测试程序（Vitis 编译产物） |
| **输出** | `RUN-E001-BOARD-*.md`（冒烟 + 数据正确性 + ILA 证据） |
| **Entry** | Phase 4 exit criteria 满足 + debug infra (B0) 就绪（ILA 探针已配置） |
| **Exit** | L5 pass（JTAG 检测/时钟/基本 IO）+ L6 pass（DMA 传输 + golden 数据比对 + ILA 波形证据） |
| **执行者** | orchestrator 分析数据，**spawn hardware_validator 执行烧录/ILA 抓数/数据比对** |
| **关联 Skills** | `fpga-board-validation`（烧录前必调）、`fpga-zynq-debug-toolchain`（ILA 前必调）、`fpga-hw-pin-verify`、`fpga-vitis-cli-build` |

**失败分诊**：上板失败按类别独立处理，各类别有独立迭代上限（详见 `fpga-board-validation`）：
- CAT-HW (JTAG/电源) → 2 次 → human_owner
- CAT-BS (PS 启动/时钟) → 2 次 → human_owner
- CAT-AX (AXI-Lite 异常) → 2 次 → vivado_integrator
- CAT-IL (ILA 不工作) → 2 次 → vivado_integrator
- CAT-SW (PS 软件 bug) → 3 次 → human_owner
- CAT-DT (DMA 数据异常) → 3 次 → vivado_integrator/rtl_implementer
- CAT-RT (RTL 逻辑 bug) → 3 次 → 完整回修链（必须 ILA 证据确认）

### Phase 6: 收尾复盘

| 项 | 内容 |
|---|------|
| **目标** | 汇总项目数据、沉淀经验到 skills 体系 |
| **输入** | 全部 Phase 的 RUN 报告 + ISS issue 记录 |
| **输出** | L7 复盘报告（资源/性能/issue 统计/经验教训）、updated skills |
| **Entry** | 所有 task 状态为 done + L5/L6 全部 pass |
| **Exit** | 复盘报告完成 + 验收合同全部签收 + 经验已写入对应 skills |
| **执行者** | orchestrator 主导，spawn process_owner 生成结构化复盘报告 |
| **关联 Skills** | `fpga-iteration-economics`、`awp-retrospect`、`fpga-project-acceptance` |

---

## 3. 执行模型：全视野优先

### 核心原则

> **Orchestrator 拥有完整项目上下文。任何涉及跨模块判断、架构决策、或 bug 诊断的操作，由 orchestrator 在全局视野下直接执行。子智能体仅在满足"工具自动化"或"无状态探索"条件时使用。**

### Orchestrator 不委托的事

- 架构设计决策（模块如何划分、接口如何定义）
- 跨模块 RTL 修改（会影响其他模块的接口或时序）
- Bug 诊断与修复（bug 本质往往是跨边界的）
- 代码审查的最终判断（需要全局视野评估影响）
- 仿真激励设计（需要理解系统级行为）
- 任何影响多个文件的操作

### 子智能体的合法使用场景

| 场景 | 子智能体类型 | 示例 |
|------|:--:|------|
| **工具自动化** | `tool-executor` | Vivado 综合/实现/比特流、XSCT 烧录、ILA 抓数 |
| **无状态探索** | `explorer` | 搜索代码库、查阅外部文档、多方案对比研究 |
| **独立模板生成** | `tool-executor` | 依据 spec 填写 RTL 模板、依据场景生成 TB 骨架 |

### 反模式（禁止）

```
❌ spawn rtl_implementer "去实现这个模块" → orchestrator 自己不看接口定义
❌ spawn rtl_reviewer "审查这段代码" → orchestrator 自己不读代码
❌ spawn integration_verifier "跑一下集成仿真看看有没有问题"
     → orchestral 自己不分析跨模块时序
```

### 正确模式

```
✓ orchestrator 设计模块接口、编写关键逻辑 → 
  spawn rtl_implementer 填充重复性代码（寄存器定义、AXI 握手模板）
✓ orchestrator 读完整 RTL → 
  spawn rtl_reviewer 做 checklist 扫描（风格违规、CDC 模式、AXI 规范）
✓ orchestrator 分析仿真失败、定位疑似 root cause → 
  spawn integration_verifier 用 orchestrator 提供的场景参数跑仿真、收集波形
✓ orchestrator 决定时钟约束策略 → 
  spawn vivado_integrator 执行 Vivado 综合/实现/比特流（纯工具操作）
```

---

## 4. 角色定义

### Orchestrator（唯一全视野执行者）

| 项 | 内容 |
|---|------|
| **类型** | 主执行者（不是管理者） |
| **拥有** | 完整项目上下文、历史决策记忆、跨模块接口知识 |
| **执行** | 架构设计、RTL 实现、测试调试、审查判断、根因分析 |
| **委托** | 仅委托工具自动化 + 无状态探索 |
| **记录** | Session 记录、task 状态更新、handoff 编写 |
| **定义** | `.claude/agents/orchestrator.md` |

### 子智能体：工具执行者（Tool Executor）

| Agent | 接受 | 产出 | 何时 spawn |
|-------|------|------|-----------|
| `vivado_integrator` | 工程路径 + 目标 run | 综合/实现/比特流 + 报告 | Phase 4 工具操作 |
| `hardware_validator` | 比特流路径 + 测试步骤 | ILA 抓数 + 数据比对报告 | Phase 5 烧录/ILA |
| `rtl_implementer` | 接口规格 + 参考 RTL | 模块 RTL 骨架 | Phase 2 重复性模板代码 |
| `rtl_reviewer` | RTL 文件 + checklist | 审查报告（扫描结果） | Phase 2 风格/规范检查 |
| `integration_verifier` | 模块列表 + 测试场景 | 仿真脚本 + 报告 | Phase 3 仿真执行 |

### 子智能体：浏览器（Explorer）

| Agent | 接受 | 产出 | 何时 spawn |
|-------|------|------|-----------|
| `planner` | 需求描述 + 器件信息 | 架构文档草稿 | Phase 1 模板化搜索 |
| `process_owner` | 全项目状态 | 复盘报告 + skills 更新建议 | Phase 6 结构化汇总 |

### Human Owner

人类项目负责人，拥有最终决策权。不 spawn。职责：
- 定义项目目标和资源
- 审批架构决策（特别是时钟/接口/器件选择）
- 在硬阻断时介入（issue 3 轮未解、上板失败超限）
- 签收验收合同

---

## 5. 核心原则（5 条）

### P1: 全视野优先
跨模块判断、架构决策、bug 诊断 → orchestrator 在完整上下文中直接执行。子智能体仅用于工具自动化和无状态探索。

### P2: 文件即事实
仓库文件是唯一真相。聊天历史不是长期记录。所有关键状态必须文件化（TASK.yaml、RUN-*.md、HO-*.md）。

### P3: 按合同工作
每个任务必须有明确的任务合同（`task_id`、`objective`、`scope`、`acceptance`、`required_outputs`）。不根据模糊自然语言自由发挥。

### P4: 不跳级验证
L0 → L1a → L1b → L1c → L2 → L3 → L4 → L5 → L6 → L7 必须顺序通过。低级别 pass 后才进高级别。GAP 由 `validate_awp.py --gate-check` 自动检测。

### P5: Skill 先于工具
任何会改变 FPGA 状态的操作（烧录/综合/实现/比特流/ILA），先调用对应 skill gate 做前置检查。Skill 是"起飞前检查单"——不跳过不是因为遵守规则，而是因为不检查就会踩坑。

---

## 6. Session 协议（摘要）

详细规则见 `.claude/orchestration_guide.md`。此处仅列关键步骤：

**启动**：
1. 检查最新 handoff → 恢复上下文
2. 加载平台清单（`host_env.yaml` + `hw_base_*.yaml`）
3. `validate_awp.py --gate-check` 确认无 GAP 阻断
4. 读 YAML 不信叙事——以 task YAML `validation_status` 为准

**关闭**：
1. 补全 session 骨架 → `SESS-{exp}-OR-{seq}.md`
2. `validate_awp.py` 退出码 0
3. 后续 task 未完成 → 创建 handoff（含 Gate Status 表）
4. Git commit（格式见 `.gitmessage`）

---

## 7. 文档索引

### 顶层文档

| 文档 | 内容 | 何时读 |
|------|------|--------|
| **`METHODOLOGY.md`**（本文件） | 生命周期、执行模型、核心原则 | **先读这个** |
| `CLAUDE.md` | 运行时规则、MCP-Skill 层级、Git 纪律 | 每次 session 加载 |
| `LAYERS.md` | 三层架构定义（AWP-Core / FPGA-Method / Agent-Runtime） | 理解文件组织 |
| `.claude/orchestration_guide.md` | 工具链边界检查、G1-G9 规则、Session 协议详情 | 执行跨阶段操作前 |

### 生命周期 Phase 参考

| Phase | 关键 Skills | 关键模板 |
|-------|------------|---------|
| **P0 启动** | `fpga-project-charter`、`fpga-project-acceptance` | charter/accepptance 模板 |
| **P1 架构** | `fpga-validation-levels`、`fpga-software-env-profile` | — |
| **P2 RTL+验证** | `fpga-module-owner-l1a`、`fpga-rtl-review`、`fpga-rtl-style`、`fpga-cdc-review`、`fpga-axi-lite-review`、`fpga-axis-review`、`fpga-sim-verification`、`fpga-formal-sanity` | `module_spec.template.yaml`、`test_plan.template.yaml` |
| **P3 集成** | `fpga-l1b-datapath-verify`、`fpga-integration-failure-debug` | — |
| **P4 硬件实现** | `fpga-vivado-preflight`、`fpga-vivado-methodology`、`fpga-vivado-log-analysis`、`fpga-platform-freeze`、`fpga-bd-debug-clock`、`fpga-host-env-detect` | — |
| **P5 上板** | `fpga-board-validation`、`fpga-zynq-debug-toolchain`、`fpga-hw-pin-verify`、`fpga-vitis-cli-build` | — |
| **P6 收尾** | `fpga-iteration-economics`、`awp-retrospect` | — |

### 横向 Skills（跨 Phase）

| Skill | 用途 |
|-------|------|
| `fpga-host-env-detect` | 主机环境检测（Phase 4/5 前置） |
| `fpga-official-doc-first` | 官方文档优先原则 |
| `fpga-skill-navigator` | Skills 导航器（不确定用哪个 skill 时先调它） |
| `fpga-validation-levels` | L0-L7 验证级别详细定义 + skip 规则 |

### 治理层（AWP-Core）

| Skill | 用途 |
|-------|------|
| `awp-task-bootstrap` | 创建新任务合同 |
| `awp-session-close` | Session 关闭流程 |
| `awp-state-audit` | 工作区状态审计 |
| `awp-retrospect` | 流程复盘 |

### 治理文件

| 找什么 | 去哪里 |
|--------|--------|
| 任务合同 | `.awp/tasks/TASK-*.yaml` |
| Session 记录 | `.awp/sessions/SESS-*.md` |
| Handoff 交接 | `.awp/handoffs/HO-*.md` |
| Review 报告 | `.awp/reviews/REV-*.md` |
| Issue 跟踪 | `.awp/issues/ISS-*.yaml` |
| Run 记录 | `.awp/runs/RUN-*.md` |
| 平台清单（硬件） | `.awp/platform/hw_base_*.yaml` |
| 平台清单（主机） | `.awp/platform/host_env.yaml` |
| Agent 定义 | `.claude/agents/*.md` |
| 架构文档 | `docs/architecture*.md` |
| 验证计划 | `docs/verification_plan.md` |
| 工作空间定义 | `.awp/workspace_manifest.json` |
| 任务看板 | `.awp/task_board.md`（自动生成） |
