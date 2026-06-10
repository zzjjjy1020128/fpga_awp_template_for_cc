# AWP 流程复盘与自我改进

> AWP 机制自我完善的闭环 skill。当执行过程中发现 AWP 规范本身的缺陷时，按此流程完成：问题记录 → 根因分析 → 规范改进 → 自洽验证。

## 触发条件

自动触发（检测到以下任一条件时）：
- 同一 ISS issue 同一问题类别 ≥ 3 轮迭代未收敛
- Resource 指标超阈值：IOB > 70%, BRAM > 90%, DSP > 80%
- 同一 task 连续 3 轮 WNS 改善 < 5%
- 阶段性任务完成（L1c/L2/L3/L4 done）后的复盘

手动触发：
- 执行过程中发现 AWP 规范缺陷
- 用户要求复盘

## 执行流程

### Step 1: 问题记录

确认问题是否已在 `.awp/decisions.md` 或 `docs/retrospective_*.md` 中有记录。若没有，新建文档。

记录格式：
```markdown
# [问题标题]
- 触发事件：[具体场景]
- 现象：[可观测的行为/结果]
- 影响：[对项目/流程的影响]
```

### Step 2: 根因分析

从 AWP 规范层面分析根因（非技术层面）。对照以下 checklist：

- [ ] CLAUDE.md 的 G1-G8 规则是否存在漏洞？
- [ ] validate_awp.py 是否缺少相关检查？
- [ ] Task scope 是否限制了必要的反馈路径？
- [ ] Agent 定义是否匹配实际工作流？
- [ ] Hook 触发点是否覆盖了关键决策时刻？
- [ ] 是否有"局部进展掩盖全局方向错误"的倾向？

### Step 3: 规模判断

| 规模 | 标准 | 执行模式 |
|------|------|---------|
| 小 | ≤ 1 文件修改 + ≤ 20 行 | **自动执行**：修改规范 → 记录到 `.awp/decisions.md` |
| 大 | > 1 文件或 > 20 行 | **请求审核**：写方案文档 → 交给 human_owner 或更高能力模型评审 |

### Step 4: 动工修改（自动或审核后）

1. 按根因分析确定修改文件
2. 执行修改
3. 记录到 `.awp/decisions.md`：

```markdown
## DEC-[项目]-[序号]
- 日期：YYYY-MM-DD
- 触发：[问题简述]
- 根因：[AWP 层面的根因]
- 修改：[文件列表 + 改动摘要]
- 验证：[自洽检查结果]
```

### Step 5: 自洽验证

```bash
python scripts/validate_awp.py --sync
python scripts/validate_awp.py
python scripts/validate_awp.py --gate-check
python scripts/validate_awp.py --guard session-start
```

4 条命令全部 exit 0 后方可确认修改完成。

### Step 6: Git 提交

```text
fix(awp): [简短描述]

Trigger: [触发事件]
Root cause: [AWP 层面根因]
Changes:
  - [文件]: [改动]
```

## 历史复盘记录

| # | 问题 | 发现方式 | 修改 |
|---|------|---------|------|
| 1 | Handoff 叙事覆盖 YAML | Session 恢复时跳过 gate | B1 checklist + Gate Status 表 |
| 2 | Skip 语义滥用 | 模块 done 但 L1b/L1c=skip | skip 检查 + `--sync` auto-fix |
| 3 | Sub-agent 过度委托 | data_valid_i 端口断连 | G1 跨文件接口变更规则 |
| 4 | Issue 机制空转 | `.awp/issues/` 为空 | ISS coverage + detected_in_run |
| 5 | IOB 81.6% 方向错误 | 5 轮迭代优化错误路径 | 资源阈值 + 迭代刹车 + G1 审核职责 |
