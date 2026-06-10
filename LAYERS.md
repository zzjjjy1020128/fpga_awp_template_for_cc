# FPGA-AWP 三层架构定义

## 概览

```
FPGA-AWP = AWP-Core + FPGA-Method + Agent-Runtime
```

| 层 | 类比 | 负责 | 不负责 |
|---|------|------|--------|
| **AWP-Core** | 项目经理 + 技术负责人的工作习惯 | 任务治理、ID、状态、证据、交接、审查、复盘、门禁 | FPGA 技术教程、具体验证方法 |
| **FPGA-Method** | 资深 FPGA 工程师的专业经验 | RTL 设计、协议验证、Vivado 工程、时序收敛、上板调试 | 任务状态流转、session 协议 |
| **Agent-Runtime** | 工程师手里的工具链和自动化系统 | 自动化执行、hook、脚本、命令入口、agent 定义 | 技术决策本身、治理规则本身 |

---

## Layer 1: AWP-Core（工程治理协议）

**最稳定、最可迁移的一层。任何 agent-native 工程都需要。**

关键词：任务、状态、ID、关系、证据、交接、审查、复盘、门禁

回答的问题：
- 这件事是谁提出的？
- 谁负责？做到哪一步？
- 证据在哪里？谁 review 过？
- 失败几次？现在阻塞在哪里？
- 下一步是什么？这次经验沉淀到哪里？

### 目录与文件

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
| `.awp/templates/` | 治理模板（task/session/handoff/review/issue/retrospective） |
| `.awp/task_board.md` | 任务看板（自动生成） |
| `.awp/decisions.md` | 架构决策记录（ADR） |
| `.awp/retrospectives/` | 治理级复盘 |

---

## Layer 2: FPGA-Method（领域方法论与经验）

**"资深 FPGA 工程师的脑子"——不断吸收真实项目经验。**

关键词：RTL、协议、验证、约束、时序、综合、实现、上板、ILA、debug、性能、资源

回答的问题：
- 如何设计 AXI-Lite 从机？
- 如何验证 AXI-Stream backpressure？
- 如何做 CDC review？
- Vivado 报错怎么读？
- ILA 信号怎么选？
- 上板不出波形如何排查？
- DMA 写 DDR 数据错位如何定位？

### 目录与文件

| 路径 | 说明 |
|------|------|
| `.claude/skills/fpga-*/` | FPGA 领域技能（可复用操作手册） |
| `rtl/` | RTL 设计源码（SystemVerilog） |
| `tb/` | Testbench 文件 |
| `sim/` | 仿真脚本和仿真输出 |
| `constraints/` | XDC 约束文件 |
| `vivado/` | Vivado 工程 |
| `board/` | 上板验证脚本与记录 |
| `docs/` | 项目工程文档（架构/验证计划/时序/上板方案/复盘） |
| `.awp/platform/` | 硬件基座清单（跨层：含治理状态 + 技术参数） |

---

## Layer 3: Agent-Runtime（执行基础设施）

**"让前两层变成可执行系统的运行时"——不是规则本身，而是规则的执行器。**

关键词：Claude Code、hooks、Makefile、MCP、scripts、subagents、agent definitions、settings、validators

回答的问题：
- 这些规则怎么真正执行？
- schema 怎么校验？ID 怎么检查？
- status 怎么生成？task_board 怎么更新？
- 什么时候 hook 阻断？
- 哪个 agent 负责哪个角色？
- MCP 接什么工具？

### 目录与文件

| 路径 | 说明 |
|------|------|
| `CLAUDE.md` | 工作区宪法（三层索引 + 硬规则） |
| `LAYERS.md` | 本文件（三层架构定义） |
| `.claude/settings.json` | Hook 配置 |
| `.claude/agents/` | Agent 角色定义 |
| `.claude/skills/awp-*/` | AWP-Core 治理技能 |
| `.claude/orchestration_guide.md` | 编排指南（子智能体调度规则） |
| `.claude/execution_modes.md` | 执行模式定义（Mode 0-4） |
| `scripts/` | 自动化脚本（validate_awp.py, session_skeleton.py 等） |
| `Makefile` | 命令入口 |

---

## 跨层文件说明

| 文件 | 涉及层 | 说明 |
|------|--------|------|
| `CLAUDE.md` | L3 | Agent-Runtime 层的"宪法"，索引三层但不替代各层详细内容 |
| `.awp/workspace_manifest.json` | L1+L2 | AWP-Core 的 workspace 定义 + FPGA-Method 的 platform 引用 |
| `.awp/platform/hw_base_*.yaml` | L1+L2 | FPGA-Method 的技术参数 + AWP-Core 的 freeze 状态 |
| `.awp/decisions.md` | L1+L2 | 治理决策（L1）与技术决策（L2）共存的 ADR 记录 |
| `.claude/agents/` | L3 | Agent-Runtime 的角色定义，但内容引用 L1/L2 规则 |

---

## 层间关系

```
AWP-Core (L1)
  负责"如何做事"
  ↓ 引用
Agent-Runtime (L3)
  负责"如何让规则自动执行"
  ↓ 调用
FPGA-Method (L2)
  负责"具体事情怎么做对"
```

三层缺一不可：
- 只有 L1：很有条理，但不一定懂 FPGA
- 只有 L2：懂技术，但可能做事混乱、经验无法沉淀
- 只有 L3：工具很多，但没有稳定的规则和方法论，容易自动化混乱

---

## 设计原则

1. **每层只描述自己该描述的部分**——不在 AWP-Core 里写 AXI 握手教程
2. **跨层引用用指针，不复制**——CLAUDE.md 指向 LAYERS.md，不重复定义
3. **历史文件不回溯修改**——旧 handoff/session/run 中的路径引用保持原样
4. **`.awp/` = 工程治理数据库**——不放 FPGA 技术教程，不放 agent 调度规则
5. **skills = 可复用专业能力**——治理技能（awp-*）和领域技能（fpga-*）用前缀区分
