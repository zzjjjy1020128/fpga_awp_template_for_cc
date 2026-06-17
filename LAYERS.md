# FPGA-AWP 三层架构定义

> 方法论入口见 `METHODOLOGY.md`。本文件定义工作区的三层架构——文件如何组织、各层负责什么、层间如何交互。

## 概览

```
FPGA-AWP = AWP-Core (L1) + FPGA-Method (L2) + Agent-Runtime (L3)
```

| 层 | 类比 | 负责 | 不负责 |
|---|------|------|--------|
| **L1 AWP-Core** | 项目经理的工作习惯 | 任务治理、ID、状态、证据、交接、审查、复盘、门禁 | FPGA 技术教程、具体验证方法 |
| **L2 FPGA-Method** | 资深 FPGA 工程师的经验 | RTL 设计、协议验证、Vivado 工程、时序收敛、上板调试 | 任务状态流转、session 协议 |
| **L3 Agent-Runtime** | 工程师手里的工具链 | 自动化执行、hook、脚本、agent 定义、命令入口 | 技术决策本身、治理规则本身 |

---

## 层间 API（L1 → L2 → L3）

### L1 提供给 L2
- **任务合同格式**（`TASK-*.yaml`）：`task_id`、`objective`、`scope`、`acceptance`、`required_outputs`、`validation_status`
- **Session/Handoff 格式**：上下文恢复、Gate Status 表
- **门禁 API**：`validate_awp.py --gate-check` 判断是否可进入下一 level

### L2 提供给 L3
- **验证级别定义**：L0-L7，每级的 pass/fail/skip 语义
- **Skill 前置条件**：每个 `fpga-*` skill 的 entry criteria 和反模式
- **Agent 能力边界**：每个 agent 的 `inputs`/`outputs`/`limitations` 契约

### L3 提供给 L1/L2
- **自动化校验**：`validate_awp.py --sync` 自动修正 status 不一致
- **Hook 触发**：SessionStart（gate-check + skeleton）、PostToolUse（validate）
- **Agent 执行**：spawn 子智能体执行 L2 定义的工具操作

---

## 各层目录

### Layer 1: AWP-Core（工程治理协议）

`.awp/` 下所有内容。**最稳定、最可迁移的一层。**

| 路径 | 说明 |
|------|------|
| `.awp/tasks/` | 任务合同（TASK-*.yaml） |
| `.awp/sessions/` | Session 记录（SESS-*.md） |
| `.awp/handoffs/` | Session 间交接（HO-*.md） |
| `.awp/reviews/` | 审查报告（REV-*.md） |
| `.awp/issues/` | 问题跟踪（ISS-*.yaml） |
| `.awp/runs/` | 运行记录（RUN-*.md） |
| `.awp/schemas/` | JSON Schema 校验定义 |
| `.awp/registry/` | ID 注册表与命名空间 |
| `.awp/templates/` | 治理模板 |
| `.awp/task_board.md` | 任务看板（自动生成） |

### Layer 2: FPGA-Method（领域方法论与经验）

**"资深 FPGA 工程师的脑子"——不断吸收真实项目经验。**

| 路径 | 说明 |
|------|------|
| `.claude/skills/fpga-*/` | FPGA 领域技能 |
| `rtl/` | RTL 设计源码 |
| `tb/` | Testbench 文件 |
| `sim/` | 仿真脚本和输出 |
| `constraints/` | XDC 约束文件 |
| `vivado/` | Vivado 工程 |
| `board/` | 上板验证脚本与记录 |
| `docs/` | 项目文档（架构/验证计划/时序/上板方案/复盘） |
| `.awp/platform/` | 硬件基座清单（跨层：治理状态 + 技术参数） |
| `METHODOLOGY.md` | 方法论宣言（跨层入口） |

### Layer 3: Agent-Runtime（执行基础设施）

**让 L1/L2 变成可执行系统的运行时。**

| 路径 | 说明 |
|------|------|
| `CLAUDE.md` | 运行时规则清单 |
| `.claude/settings.json` | Hook 配置 |
| `.claude/agents/` | Agent 定义（工具执行者契约） |
| `.claude/skills/awp-*/` | AWP-Core 治理技能 |
| `.claude/orchestration_guide.md` | Session 协议 + 调度规则 |
| `scripts/` | 自动化脚本 |
| `Makefile` | 命令入口 |

---

## 跨层文件说明

| 文件 | 涉及层 | 说明 |
|------|--------|------|
| `METHODOLOGY.md` | L2+L3 | 入口文档——生命周期定义（L2）+ 执行模型（L3） |
| `CLAUDE.md` | L3 | 运行时规则——每次 session 加载 |
| `.awp/workspace_manifest.json` | L1+L2 | workspace 定义（L1）+ platform 引用（L2） |
| `.awp/platform/hw_base_*.yaml` | L1+L2 | 技术参数（L2）+ freeze 状态（L1） |
| `.claude/agents/` | L3 | 工具执行者定义——引用 L1/L2 规则 |

---

## 设计原则

1. **每层只描述自己该描述的部分**——不在 L1 里写 AXI 握手教程
2. **跨层引用用指针，不复制**——METHODOLOGY.md 指向 LAYERS.md，CLAUDE.md 指向 METHODOLOGY.md
3. **历史文件不回溯修改**——旧 handoff/session/run 中的路径引用保持原样
4. **`.awp/` = 工程治理数据库**——不放技术教程，不放调度规则
5. **skills = 可复用专业能力**——`awp-*`（L1 治理）和 `fpga-*`（L2 领域）用前缀区分
