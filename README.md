# FPGA-AWP v0.2

**FPGA Agent Workspace Protocol** —— 面向 FPGA 开发的智能体优先（Agent-Native）方法论与工作区模板。

> 入口文档是 `METHODOLOGY.md`。`CLAUDE.md` 是每次 session 加载的运行时规则。

---

## 环境准备

依赖 Python 3.8+ 和 PyYAML：

```bash
pip install -r requirements.txt
make verify-env
```

Windows 无 `make` 时直接用 Python 替代：

| make 命令 | Python 替代 | 作用 |
|-----------|------------|------|
| `make status` | `python scripts/validate_awp.py --dashboard` | 项目全局仪表盘 |
| `make validate-awp` | `python scripts/validate_awp.py` | 工作空间完整性校验 |
| `make task-board` | `python scripts/validate_awp.py --gen-task-board` | 生成任务看板 |

---

## 快速开始

```text
1. 克隆本仓库，在 Claude Code 中打开
2. 说出你想做的 FPGA 项目
3. orchestrator 引导你走完 6-Phase 生命周期：
   P0 项目启动 → P1 架构设计 → P2 RTL+验证 → P3 集成验证
   → P4 硬件实现 → P5 上板验证 → P6 收尾复盘
```

**orchestrator 是拥有完整项目上下文的执行者**——它自己做架构决策、跨模块设计、bug 诊断。子智能体仅在 Vivado 综合/上板烧录等长耗时工具操作时使用，作为"手臂的延伸"而非独立的工程师同事。

---

## 核心概念

| 概念 | 说明 |
|------|------|
| **METHODOLOGY.md** | 体系入口——6-Phase 生命周期、全视野优先原则、角色定义、文档索引 |
| **CLAUDE.md** | 运行时规则——每次 session 加载的硬规则、MCP-Skill 层级、Git 纪律 |
| **orchestrator** | 唯一全视野执行者。自己做跨模块决策，仅 spawn 子智能体做工具自动化和无状态探索 |
| **子智能体** | 工具执行者或浏览器，不是独立工程师。Vivado 综合/上板烧录/代码搜索/复盘汇总 |
| **task（任务合同）** | YAML 文件，明确 scope、acceptance、required_outputs、validation_status |
| **session** | 一次对话。结束时 orchestrator 归档记录，必要时创建 handoff |
| **handoff** | session 间桥梁。下次打开时自动恢复上下文 |
| **L0-L7 验证** | 8 级递进门禁：L0 审查 → L1a 单元仿真 → L1b 数据通路 → L1c 全系统 → L2 综合 → L3 实现 → L4 比特流 → L5 冒烟 → L6 数据正确 → L7 复盘 |

---

## 全局视角

| 你想知道 | 怎么看 |
|---------|--------|
| 项目整体状态 | `make status` |
| 任务看板 | `.awp/task_board.md`（自动生成） |
| 某个 task 细节 | `.awp/tasks/TASK-*.yaml` |
| 历史记录 | `.awp/sessions/` |
| 交接记录 | `.awp/handoffs/` |
| 架构决策 | `.awp/decisions.md` |
| 审查结果 | `.awp/reviews/` |
| 上板验证 | `.awp/runs/` |

---

## 会话命令

| 命令 | 作用 |
|------|------|
| `/task-bootstrap` | 创建新任务合同 |
| `/session-close` | 结束 session：归档记录、校验、判断 handoff、git commit |
| 自然语言 | 直接告诉 orchestrator 你的需求 |

---

## 分支结构

```
master     ← v0.2 干净模板（0 tasks, 0 entities）
exp/E001   ← AXI-Lite 2D Shift 项目实例
```

新项目：`git checkout -b exp/NewProject master` → 获得完整模板，无任何残留。

---

## 项目 vs 模板

本仓库的 `master` 分支是纯模板。`exp/*` 分支是真实项目实例（含 RTL、Vivado 工程、约束、上板记录）。

模板层文件（`awp`/`conf` scope）改进后从 exp 分支 cherry-pick 回 master。
