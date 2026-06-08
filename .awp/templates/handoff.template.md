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
- **原因**：`<用户停止 / 上下文满 / compact>`（注：所有 task 已完成时不创建 handoff，直接做 session 记录和复盘）

## Gate Status（强制必填）

> **此节为强制项**。缺少此节的 handoff 在 `validate_awp` 中视为硬错误。
> 列出本次 handoff 涉及的所有 task 的验证状态。**handoff 的"下一步行动"不得跨越未通过的 gate**。
> 若 L1b=pending 而 L1c=target，handoff 应指明先创建 L1b task，而非直接调试 L1c。

| Task ID | Target Level | 当前最高通过 | L0 | L1a | L1b | L1c | L2+ |
|---------|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| `<TASK-E001-xxx>` | `L1b` | `L1a` | pass | pass | pending | — | — |

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

## 仿真失败调试线索

> **重要**：如果本 session 以仿真失败告终，请在此记录具体的调试线索，供下一 session 快速接续。不要只写"X 个失败"。

- **失败的测试用例**：`<TCxx, TCxx — 具体哪些用例失败>`
- **关键调试输出**：`<DBG 输出中的关键信号值，如计数器初始值、pipeline 延迟周期数>`
- **可疑方向**：`<已排除的假设、正在追踪的假设>`
- **相关波形/日志路径**：`<sim/*.vcd, sim/*.log>`

## 设计决策

`<本 session 中做出的需要传递到下一 session 的决策>`

## 下一步行动

`<建议的下一 session 的首要行动清单>`

1. `<行动 1>`
2. `<行动 2>`
