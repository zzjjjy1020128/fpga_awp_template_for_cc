---
# YAML frontmatter —— 结构化元数据，可被 validate_awp.py 校验
task_id: "<TASK-E001-001>"
reviewer: "<角色>"
result: "pass"            # pass | pass_with_notes | fail
date: "<YYYY-MM-DD>"
---

# Review 记录

> 文件命名：`.awp/reviews/REV-{exp}-{task_seq}-{type}-{seq}.md`
> 格式定义：`.awp/registry/namespaces.yaml`

## Review Summary

- **Review ID**：`REV-E001-001-RTL-001`
- **Task ID**：`TASK-E001-001`
- **Reviewer**：`<角色>`
- **Date**：`<YYYY-MM-DD>`
- **Result**：`pass | pass_with_notes | fail`

## Scope

`<审查范围 —— 哪些文件/模块>`

## Checklist

- [ ] 接口兼容性
- [ ] 时序正确性（或至少无明显时序问题）
- [ ] 复位策略
- [ ] CDC 处理（如适用）
- [ ] 代码风格
- [ ] 与 architecture.md 一致性

## Findings

| # | 严重程度 | 描述 | 建议 |
|---|---------|------|------|
| 1 | `<high/medium/low>` | `<描述>` | `<建议修复方式>` |

## Commands Run

```text
<如运行了 lint、sim 等>
```

## Limitations

`<本次 review 的局限性，如未覆盖的范围>`

## Next Actions

- `<后续行动>`
