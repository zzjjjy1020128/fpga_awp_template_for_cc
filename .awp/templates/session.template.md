# Session 记录

> 文件命名：`.awp/sessions/SESS-{exp}-OR-{seq}.md`（Session 角色固定为 OR=orchestrator）

## Session Goal
`<本次 session 的目标，一句话>`

## Tasks Worked
`<本 session 中处理的所有 task，一个 session 可包含多个 task>`

| Task ID | Agent | 状态变化 | 产出 |
|---------|-------|---------|------|
| `<TASK-E001-001>` | `<agent>` | `ready → done` | `<文件列表>` |

## Files Read
- `<文件路径>`
- `<文件路径>`

## Files Modified
- `<文件路径>` —— `<修改原因>`
- `<文件路径>` —— `<修改原因>`

## Commands Run
```text
<命令 1>
<命令 2>
```

## Key Decisions
- `<决策 1>`
- `<决策 2>`

## Issues Found
- `<问题描述和影响>`

## Gate Check
> 运行 `python scripts/validate_awp.py --gate-check` 并记录结果。
> 低级别通过后才进入高级别。L1a → L1b → L1c 必须顺序通过。

- [ ] `--gate-check` 退出码 0
- [ ] 当前 task 的 target 以下无 pending level（无 GATE GAP）

## Validation Status

| Level | Status | 备注 |
|-------|--------|------|
| L0: 静态审查 | `<pass/pending/skip>` | |
| L1a: 模块级单元仿真 | `<pass/pending/skip>` | |
| L1b: 数据通路闭环仿真 | `<pass/pending/skip>` | |
| L1c: 全系统集成仿真 | `<pass/pending/skip>` | |
| L2: 综合 | `<pass/pending/skip>` | |
| L3: 实现与时序 | `<pass/pending/skip>` | |
| L4: 比特流生成 | `<pass/pending/skip>` | |
| L5: 板上冒烟测试 | `<pass/pending/skip>` | |
| L6: 板上数据正确性 | `<pass/pending/skip>` | |
| L7: 性能/资源复盘 | `<pass/pending/skip>` | |

- [ ] `python scripts/validate_awp.py` 通过（退出码 0）

## Open Questions
- `<待解决问题>`

## Handoff（仅 session 结束时填写）

> Handoff 是 session 边界桥梁。若 session 结束后仍有未完成的后续 task，填写本节。

- Next Task：`<下一 session 需继续的 task_id>`
- Handoff File：`.awp/handoffs/HO-<EXP>-<TASK>-<SEQ>.md`
- 备注：`<下一 session 需注意的事项>`
