---
description: Close a session properly — complete session record, run validation, decide if handoff is needed, update task status and board. Use when the user says session is ending, wrap up, finish session, close session, or when the orchestrator detects the session is about to end. Also use when context is nearly full and compaction/continuation is needed.
when_to_use: close session, end session, finish session, wrap up, session done, compact session, continue next session
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

你正在结束当前 session。必须按以下步骤执行，确保下一 session 的 orchestrator 可以无缝继续。

## Step 1: 完成 Session 记录

1. 找到 `.awp/sessions/SKELETON-*.md` 骨架文件
2. 补填所有未完成字段：
   - Session Goal：本 session 实际完成的目标
   - Files Read / Files Modified：本次涉及的完整文件列表
   - Commands Run：所有执行的命令
   - Key Decisions：本 session 中做出的关键决策
   - Issues Found：发现的问题和影响
   - Gate Check：勾选目标验证级别，确认前一级别已通过
   - Validation Status：`make validate-awp` 的结果
3. 重命名为正式文件名 `SESS-{exp}-OR-{seq}.md`
   - {exp} 从 task_id 提取，如 TASK-E001-001 → E001
   - {seq} 为当前 exp 下 session 序号，检查已有 session 文件确定

## Step 2: 更新 Task 状态

如果本 session 中有 task 的验证级别取得进展，更新对应 `.awp/tasks/*.yaml` 中的 `validation_status` 字段（如 L0: pass）。

## Step 3: 运行校验

```bash
python scripts/validate_awp.py
```
退出码必须为 0。若失败，修正后重新运行。

## Step 4: Git 提交

1. 对每个状态变为 `done` 的 task，做一次单独提交：
   - `git add` 该 task 的产出文件
   - 按 `.gitmessage` 模板编写提交信息（Task/Session/Validation trailer）
   - `git commit`（pre-commit hook 自动 validate-awp）
2. 所有 task 提交后，检查是否有未提交改动（如 registry、task_board 更新），如有则做最后一次补充提交。
3. 同一 task 的多个产出文件合并为一次提交。

## Step 5: 门禁检查

```bash
python scripts/validate_awp.py --gate-check
```
若有 gate violation，判断是否需要在本 session 修复或记录为已知问题。

## Step 6: 判断是否需要 Handoff

**需要创建 handoff** 的情况：
- 当前 session 结束时，后续 task 尚未完成（检查 task_board 中是否有非 done 状态的 task）
- 上下文即将满，需要 compact 后新 session 继续

**不需要 handoff** 的情况：
- 所有 task 已完成（全部 done）
- 项目已完结

## Step 7: 创建 Handoff（如需要）

1. 复制 `.awp/templates/handoff.template.md` 结构
2. 填写：已完成 task 列表、未完成 task 列表、关键文件路径、已知问题、下一步行动
3. 写入 `.awp/handoffs/HO-{exp}-{task_seq}-{seq}.md`
4. 在 `.awp/registry/id_registry.yaml` 中注册 handoff ID
5. 在 `.awp/registry/relations.yaml` 中添加 handoff 关联的 task 关系

## Step 8: 更新 Task Board

```bash
python scripts/validate_awp.py --gen-task-board
```

## Step 9: 向用户汇报

输出 session 结束摘要：
- 本 session 完成的 task 和验证级别
- 是否创建了 handoff（如有，给出文件路径）
- 下一 session 的推荐入口（下一个待执行的 task_id 或 handoff 文件路径）
