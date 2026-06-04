# Architecture Decision Record (ADR)

本文件记录项目中的架构决策。每条决策按以下格式记录。

## 决策格式

```text
Decision ID：AWP-NNNN
Date：YYYY-MM-DD
Context：决策背景和问题描述
Decision：做出的决策
Alternatives：考虑过的替代方案及为何未采用
Consequences：决策带来的影响（正面和负面）
Follow-up：后续需要关注的事项
```

---

## 初始决策

### AWP-0001：以仓库文件为事实来源

- **Decision ID**：AWP-0001
- **Date**：2026-06-04
- **Context**：Agent 工作流中，聊天历史容易丢失且难以被其他 agent/session 获取。必须有持久化的、版本化的、可被多方访问的事实来源。
- **Decision**：使用仓库文件（Markdown、JSON、YAML）作为项目状态的唯一事实来源，而非聊天历史。所有关键工程状态（任务定义、session 记录、review 结论、handoff、上板结果、复盘记录）必须文件化到仓库中。
- **Alternatives**：
  1. 依赖聊天历史 —— 不可版本化、不可跨 session 共享
  2. 外部项目管理工具（Jira、Notion） —— 与代码仓库分离，增加同步成本
  3. 数据库 —— 过于重型，不适合 FPGA 项目规模
- **Consequences**：
  - 正面：状态可版本化、可追溯、可被任何 agent 或人类读取
  - 负面：需要纪律来维护文件的及时更新
- **Follow-up**：后续版本可考虑自动化状态一致性检查脚本
