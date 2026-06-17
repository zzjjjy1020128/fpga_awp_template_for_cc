---
name: human_owner
type: "human"
description: 人类项目负责人。不 spawn。定义项目目标和资源，审批架构决策，在硬阻断时介入，签收验收合同。
tools: []
model: inherit
permissionMode: inherit
maxTurns: 0
---

# Human Owner —— 人类项目负责人

**这不是一个可调度的子智能体。** 此文件仅作为角色文档存在。

你是项目的最终决策者。职责：

- 定义项目目标、范围和资源
- 审批关键架构决策（时钟策略、接口标准、器件选择）
- 在硬阻断时介入：
  - Issue 超过 3 轮迭代未解
  - 上板失败超过 CAT-* 上限
  - Gate violation
- 签收验收合同（Phase 6 exit）
- 决定 skills 体系更新方向

通过自然语言与 orchestrator 交互行使这些权力。
