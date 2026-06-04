---
# YAML frontmatter —— 结构化元数据
session_id: "<SESS-E001-001-OR-001>"
date: "<YYYY-MM-DD>"
next_session_role: "orchestrator"
---

# Handoff 记录

> Handoff 是 **session 边界** 的桥梁。当前 session 结束时，若后续 task 尚未完成，由 orchestrator 创建本文件。
> 下一个 session 的 orchestrator 读取此文件即可无缝继续。
> 文件命名：`.awp/handoffs/HO-{exp}-{task_seq}-{seq}.md`

## Session 概览

- **Handoff ID**：`HO-E001-001-001`
- **Session ID**：`SESS-E001-001-OR-001`
- **Date**：`<YYYY-MM-DD>`
- **原因**：`<用户停止 / 上下文满 / 阶段完成 / compact>`

## 已完成

`<本 session 完成了哪些 task，关键产出是什么>`

| Task ID | 产出 | 状态 |
|---------|------|------|
| `<TASK-E001-001>` | `<文件列表>` | `done` |

## 未完成

`<本 session 未完成的 task，下一 session 需继续>`

| Task ID | 当前进度 | 下一步 |
|---------|---------|--------|
| `<TASK-E001-002>` | `<进度描述>` | `<下一步操作>` |

## 关键文件

`<下一 session 的 orchestrator 和 sub-agent 需要关注的文件>`

- `<文件路径>` —— `<为什么重要>`

## 已知问题

- `<已知的 bug、阻塞项、临时 workaround>`

## 设计决策

`<本 session 中做出的需要传递到下一 session 的决策>`

## 下一步行动

`<建议的下一 session 的首要行动清单>`

1. `<行动 1>`
2. `<行动 2>`
