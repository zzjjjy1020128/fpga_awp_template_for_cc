---
name: human_owner
description: NOT A SPAWNABLE AGENT. This file documents the human project owner role. The human makes final decisions on project goals, resources, and deliverables.
tools: []
model: inherit
permissionMode: inherit
maxTurns: 0
---

# human_owner（人类项目负责人）

**这不是一个可调度的子智能体。** 此文件仅作为角色文档存在。

human_owner 是你（用户）的角色。你负责：

- 定义项目目标和优先级
- 批准架构决策
- 授权上板验证
- 接受/拒绝 task 产物

你通过自然语言与 orchestrator（主 session）交互来行使这些权力。
