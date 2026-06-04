# Session 记录

> 文件命名：`.awp/sessions/SESS-{exp}-{task_seq}-OR-{seq}.md`（Session 角色固定为 OR=orchestrator）

## Session Goal
`<本次 session 的目标，一句话>`

## Assigned Task
- Task ID：`<TASK-E001-001>`
- Agent：`<agent name>`（本 session 中 spawn 的子智能体）

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
> 上一级验证级别是否已通过？低级别通过后才进入高级别。

- [ ] 目标验证级别：`<L0-L7>`
- [ ] 前一级别已通过确认

## Validation Status
- [ ] L0: 静态审查
- [ ] L1: 仿真
- [ ] 其他
- [ ] `make validate-awp` 通过（退出码 0）

## Open Questions
- `<待解决问题>`

## Handoff（仅 session 结束时填写）

> Handoff 是 session 边界桥梁。若 session 结束后仍有未完成的后续 task，填写本节。

- Next Task：`<下一 session 需继续的 task_id>`
- Handoff File：`.awp/handoffs/HO-<EXP>-<TASK>-<SEQ>.md`
- 备注：`<下一 session 需注意的事项>`
