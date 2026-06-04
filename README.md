# FPGA-AWP v0.1

**FPGA Agent Workspace Protocol** —— FPGA 项目的 agent 工作空间协议模板。

---

## 快速开始

**你只需要做一件事：告诉 orchestrator 你想做什么。**

```
1. 在 Claude Code 中打开本仓库
2. 输入：我想开始一个新的 FPGA 项目，做一个 AXI-Lite 控制的 2D shift 模块
3. orchestrator（CTO agent）会自动：
   - 创建项目章程（project_charter.md）—— 定义范围、约束、验证目标
   - 拆分任务（architecture → RTL → review → simulation → board）
   - 为每个任务创建合同（task yaml）
   - spawn 对应的工程师子智能体来干活
   - 运行校验、更新看板、记录 session
4. 你只需要确认关键决策，其余交给 orchestrator
5. 结束时输入：/session-close
```

**不想从零开始？** 直接告诉 orchestrator 你的具体需求，它会判断从哪里切入。

---

## 核心概念

| 概念 | 你是这么理解的 |
|------|--------------|
| **orchestrator（CTO）** | 和你对话的主 agent。它拆分你提出的任务、调度子智能体执行、保障流程合规。**你主要和它交互。** |
| **子智能体（engineer）** | 被 CTO 派去干活的专业 agent。有 7 种角色：planner（架构）、rtl_implementer（RTL 编码）、rtl_reviewer（审查）、tb_verifier（仿真）、vivado_integrator（Vivado 集成）、hardware_validator（上板验证）、process_owner（复盘）。**你一般不和子智能体直接对话。** |
| **task（任务合同）** | 每个工作的 YAML 合同，明确：谁做、做什么、改哪些文件、怎么验收、验证到几级。 |
| **session（会话）** | 一次从打开到关闭的对话。session 结束时 CTO 会归档记录，必要时创建 handoff 供下次继续。 |
| **handoff（交接记录）** | session 之间的桥梁。下次打开 Claude Code 时 CTO 自动读取。 |
| **验证级别 L0-L7** | 8 级递进：L0 代码审查 → L1 仿真 → L2 综合 → L3 实现/时序 → L4 bitstream → L5 上板冒烟 → L6 数据正确性 → L7 复盘。低级别通过后才进入高级别。 |
| **仓库是事实来源** | 所有关键状态（任务、session 记录、审查结果、验证报告）都文件化在仓库中，不依赖聊天历史。 |

---

## 全局视角：一眼看清项目全貌

自动化不代表黑盒。以下入口让你随时掌握全局状态：

| 你想知道 | 怎么看 |
|---------|--------|
| **项目整体状态** | 运行 `make status` —— 显示所有 task、验证进度、最近 session、待解决问题、下一步行动 |
| **任务列表** | 查看 `.awp/task_board.md`（`make task-board` 自动生成，每次 task 状态变更后更新） |
| **某个 task 的细节** | 打开 `.awp/tasks/TASK-xxx.yaml`，包含 scope、验收条件、产出文件、验证状态 |
| **历史记录** | 浏览 `.awp/sessions/` 目录，每次 session 都有完整记录（做了啥、改了啥、决策了啥） |
| **交接记录** | 查看 `.awp/handoffs/` 目录，了解 session 之间传递了哪些关键上下文 |
| **架构决策** | 阅读 `.awp/decisions.md`，记录了所有 ADR 风格的架构决策 |
| **审查结果** | 打开 `.awp/reviews/` 目录，每次 review 都有独立记录 |
| **上板验证** | 查看 `.awp/runs/` 目录，每次运行都有板卡、bitstream、ILA/VIO 证据记录 |
| **项目演进** | 运行 `git log --oneline`，每次提交都有 Task/Session/Validation trailer 可追溯 |

**建议**：每次打开项目先运行 `make status` 了解当前全局状态，再决定下一步做什么。

## 可用命令/技能

| 命令 | 什么时候用 | 会发生什么 |
|------|-----------|----------|
| `/task-bootstrap` | 你想创建新任务 | CTO 引导你填写任务合同，自动注册 ID，运行校验 |
| `/session-close` | 你这次工作做完了 | CTO 补全 session 记录、运行校验、判断是否需要 handoff、提交 git |
| 自然语言 | 任何时候 | 直接告诉 CTO 你的需求，它会自动判断该做什么 |

---

## 你的角色：与 CTO 协作

当你和 orchestrator 对话时，它会：

1. **主动拆分** —— 把大目标拆成具体任务，列出 task 列表征求你确认
2. **主动调度** —— 确认后自动 spawn 对应的子智能体执行
3. **主动审查** —— RTL 完成后自动触发代码审查，无需你提醒
4. **主动归档** —— 每个 task 完成后自动运行校验，session 结束时归档
5. **向你汇报** —— 进度更新、遇到阻塞、需要关键决策时

**你的职责**：提供目标、确认 task 拆分、批准关键决策、验收最终产出。

**你不需要做**：记住流程规则、创建模板文件、运行校验命令 —— 这些 CTO 负责。

---

## 常见问题

**Q: validate-awp 出错了怎么办？**
A: CTO 会看到错误信息并自动修复。如果是严重问题（G4 规则：连败三次），CTO 会停止并请求你的决定。

**Q: Session 被中断（断线/关窗口）怎么办？**
A: 重新打开 Claude Code。CTO 会自动检查 handoff 文件并恢复上次的上下文。

**Q: CTO 说需要 handoff，我需要做什么？**
A: 你不需要做任何事。CTO 自动创建 handoff 文件，下次会话自动恢复。

**Q: 子智能体反复失败怎么办？**
A: CTO 按 G4 规则处理：1 次→重试，2 次→重点修复，3 次→停止并请你决策。

**Q: Review 不通过怎么办？**
A: CTO 会创建修复 task，重新 spawn 原 agent 修改。不需要你干预。

**Q: 我想跳过某个步骤可以吗？**
A: 告诉 CTO。CTO 会在合规范围内调整，但如果跳过关键的验证门禁（如 L1 未通过进 L2），会被硬阻断。

---

## 预期工作流

```text
项目启动 → project_charter → architecture → RTL 实现 → 代码审查
         → testbench + 仿真 → Vivado 集成 → 上板验证 → 复盘
         
每个阶段：创建 task → spawn 子智能体 → 产出结果 → validate → 更新看板
Session 结束时：/session-close → 记录归档 → git commit → handoff（如需要）
```

---

## 如何使用这个模板

1. Clone 或复制本仓库
2. 在 Claude Code 中打开
3. 说出你的 FPGA 项目目标
4. orchestrator 自动完成其余工作

## Workspace Protocol 与真实 FPGA 项目的区别

本仓库是 **模板**，不是真实 FPGA 项目：
- 不包含 RTL 设计
- 不包含 Vivado 工程
- 不包含仿真/综合/上板结果
