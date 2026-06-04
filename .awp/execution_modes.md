# 执行模式说明

> **v0.1 主力模式：Mode 0 (Single Agent Session) 和 Mode 2 (Orchestrator + Subagents)。**
> Mode 1 (Manual Multi-Session) 用于跨 session 的长周期项目。
> Mode 3-4 为后续版本预留，当前仅作参考。

FPGA-AWP 支持多种 Agent 执行模式。选择合适的模式对项目效率至关重要。

---

## Mode 0: Single Agent Session

### 何时使用
- 单一、明确、范围小的任务
- 快速迭代和探索性工作
- 单人项目

### 何时不要使用
- 需要并行处理多个独立任务
- 需要多角色审查（RTL 实现 + review 应分离）

### 必须依赖的文件
- `CLAUDE.md` —— 全局规则
- `.awp/templates/task.template.yaml` —— 任务合同
- `.awp/templates/session.template.md` —— session 记录

### 风险
- 同一 agent 同时设计和审查自己的代码，容易产生盲点
- 上下文窗口限制可能影响大型任务

### FPGA 项目特别注意
- RTL 实现和 review 应尽量分离角色，即使是同一 agent 不同 session

---

## Mode 1: Manual Multi-Session

### 何时使用
- 任务可自然拆分为多个独立阶段
- 需要在阶段之间进行人工检查
- 不同阶段需要不同工具或环境

### 何时不要使用
- 强耦合的任务需要紧密迭代
- 手动切换引入的 overhead 大于收益

### 必须依赖的文件
- `.awp/task_board.md` —— 跟踪任务状态
- `.awp/handoffs/` —— 阶段间交接
- `.awp/templates/handoff.template.md`

### 风险
- 人工切换可能遗漏关键上下文
- Handoff 文件质量决定下一 session 的效率

### FPGA 项目特别注意
- 仿真 → 综合 → 上板是天然的多 session 边界
- 每个阶段结束后务必更新 task_board

---

## Mode 2: Orchestrator + Subagents

### 何时使用
- 任务涉及多个独立子任务
- 需要不同专业角色协同工作
- 有明确的 orchestrator 角色来拆分和分配任务

### 何时不要使用
- 子任务之间强耦合，需要大量共享上下文
- Orchestrator 本身成为瓶颈

### 必须依赖的文件
- `.awp/orchestration_guide.md` —— 编排策略与合规分层
- `.claude/agents/` —— 子智能体定义（系统提示词、工具白名单）
- `.awp/task_board.md` —— 任务分配和追踪
- `.awp/workspace_manifest.json` —— 工作空间边界

### 风险
- 子 agent 之间信息不对称
- Orchestrator 拆分任务不当导致返工

### FPGA 项目特别注意
- RTL implementer、tb_verifier、vivado_integrator 可并行工作
- 但 RTL 接口变更时必须通知所有相关 subagent

---

## Mode 3: Worktree-based Parallel Agents

### 何时使用
- 多个完全独立的设计任务
- 实验性分支需要隔离
- 大规模项目的并行开发

### 何时不要使用
- 任务之间有文件级冲突风险
- 合并成本预计很高

### 必须依赖的文件
- `CLAUDE.md`
- `.awp/workspace_manifest.json`
- Git worktree 机制

### 风险
- 合并冲突
- 不同 worktree 的状态不同步

### FPGA 项目特别注意
- 不同 IP 核可独立在 worktree 中开发
- 顶层集成需要专门的一个 session

---

## Mode 4: Future Multi-Agent Team

### 何时使用（未来）
- 大型 FPGA 项目需要多人/多 agent 长期协作
- 有专门的角色分工和权限控制

### 何时不要使用（当前）
- v0.1 阶段不推荐，等待模板经过实践验证

### 必须依赖的文件（预期）
- `.awp/orchestration_guide.md`
- `.awp/decisions.md`
- `.claude/agents/` 下的 agent 定义
- 外部编排平台或工具

### 风险
- 协调复杂度随 agent 数量指数增长
- 需要成熟的 handoff 和 review 纪律

### FPGA 项目特别注意
- 硬件资源（板卡、调试器）可能成为物理瓶颈
- 上板验证通常只能串行进行
