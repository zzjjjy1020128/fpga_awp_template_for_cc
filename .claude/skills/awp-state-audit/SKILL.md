# AWP 状态审计

> 触发：检查项目状态、验证 AWP 一致性、session 开始/结束时。

## 审计命令

```bash
# 完整状态审计（按此顺序执行——先修复再检查）
python scripts/validate_awp.py --sync         # 1. 自动修复 + registry 同步
python scripts/validate_awp.py                # 2. 全量校验（含 issue coverage、涟漪等）
python scripts/validate_awp.py --gate-check   # 3. gate 门禁
python scripts/validate_awp.py --guard session-start  # 4. handoff + gate + skeleton 汇总
```

## 审计检查清单

### 1. Task 状态一致性
- [ ] 所有 task 的 `status` 与 `validation_status` 一致
- [ ] 模块级 rtl_implementer task 的 L1b/L1c 不为 `skip`（skip 滥用检查）
- [ ] 无 `status=done` 但有 `validation_status=fail` 的 task
- [ ] 模块 task `status=done` 时 L1b/L1c 不为 `pending`

### 2. Gate 门禁
- [ ] `--gate-check` exit 0
- [ ] 无 target-gap（target 以下有 pending level）
- [ ] 无 gate violation（高级别 pass 但低级别未 pass）
- [ ] L1c 前 L1b 已全部 pass

### 3. 依赖链
- [ ] `depends_on` 引用的 task 全部存在
- [ ] 上游 level 回退时下游已同步（涟漪传播检查）
- [ ] 无循环依赖（当前未检查，需人工确认）

### 4. 文件完整性
- [ ] `required_outputs` 中所有文件存在
- [ ] `must_read` 中所有文件存在
- [ ] `allowed_edit_paths` / `forbidden_edit_paths` 无矛盾

### 5. Review 覆盖
- [ ] 所有 active/done 的 rtl_implementer task 有通过 review
- [ ] 所有 review 文件 frontmatter 完整（task_id, reviewer, result, date）

### 6. Issue 覆盖（G4 强制）
- [ ] 每个 status=FAIL 的 RUN 有对应 ISS issue（`detected_in_run` 字段）
- [ ] 每个 open/in_progress issue 有 `suspected_owner_task`
- [ ] 无 round_count 超过 max_rounds 的 issue（应设 blocked）

### 7. Integration scope
- [ ] integration_verifier task 的 `allowed_edit_paths` 不包含子模块 RTL（G6 规则）
- [ ] 例外：may-fix-with-record 的修改有对应 ISS issue

### 8. Session 记录
- [ ] 无残留 SKELETON-*.md 文件（未完成的 session 记录）
- [ ] Handoff 文件包含 Gate Status 表

## 常见不一致及修复

| 症状 | `--sync` 自动修复 | 手动修复 |
|------|:--:|------|
| 模块 task done 但 L1b/L1c=pending | ✅ → review | |
| 模块 task L1b/L1c=`skip` | ✅ → pending | |
| Task 有 GAP 但 status=in_progress | ✅ → blocked | |
| 上游 L1a 回退但下游 L1b 仍 pass | ❌ 仅检测 | 手动更新下游 level |
| integration_verifier scope 违规 | ❌ 仅检测 | 更新 task scope |
| Task 缺 review | ❌ 仅检测 | spawn rtl_reviewer |
| Handoff 缺 Gate Status | ❌ 仅检测 | 更新 handoff 文件 |

## 审计频率

- **每次 session 启动**：`--guard session-start` 自动运行
- **每次 Edit/Write 后**：`--sync` 自动运行
- **每次 spawn 前**：`--guard pre-spawn` 自动运行
- **手动审计**：怀疑状态不一致时运行完整检查
