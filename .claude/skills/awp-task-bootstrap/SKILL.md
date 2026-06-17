---
description: Create a new AWP task following all workspace rules. Use when the user asks to create a task, define a new work item, start a project phase, or split work into tasks. Also use when the orchestrator needs to spawn a sub-agent for technical work and must first create a task contract.
when_to_use: create task, new task, define task, bootstrap task, task contract, create work item, split work
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

你正在创建一个新的 FPGA-AWP 任务。必须按以下步骤执行，每步完成后确认通过再进入下一步。

## Step 1: 确定实验项目

如果用户没有指定 EXP ID，检查 `.awp/registry/id_registry.yaml` 中已有的 EXP 条目。若尚无 EXP，先创建 EXP 条目（格式见 `.awp/registry/namespaces.yaml`）并注册。

**若本 EXP 下尚无任何 task**（新项目启动），在创建第一个 task 前，先确认是否已存在 `project_charter.md`（参照 `.awp/templates/project_charter.template.md`）。若没有，建议用户先用 planner agent 创建项目章程，定义范围、约束和验证目标。

## Step 2: 确定 Task ID

1. 检查 `.awp/registry/id_registry.yaml` 中已有的 TASK 条目
2. 检查 `.awp/tasks/` 目录下已有的 yaml 文件
3. 按 `TASK-E{exp_seq:03d}-{task_seq:03d}` 格式确定下一个可用 ID，向用户确认
4. 如用户无异议，使用该 ID

## Step 3: 填写 Task YAML

1. 复制 `.awp/templates/task.template.yaml` 的结构
2. 填写所有必填字段：

| 字段 | 要求 |
|------|------|
| `task_id` | Step 2 确定的 ID |
| `title` | 简洁描述任务目标 |
| `status` | 新任务填 `ready` |
| `agent` | 必须是 enum 中的值：`planner` `rtl_implementer` `rtl_reviewer` `integration_verifier` `vivado_integrator` `hardware_validator` `process_owner` |
| `created_date` | 今天日期 YYYY-MM-DD |
| `target_validation_level` | L0-L7，按 CLAUDE.md 的验证级别定义填写 |
| `validation_status` | 新任务全部 `pending` |
| `objective` | 一两句话描述任务目标 |
| `scope.allowed_edit_paths` | 具体列出允许修改的文件或目录 |
| `scope.forbidden_edit_paths` | 至少包含 `.awp/workspace_manifest.json` `.awp/schemas/` `.awp/registry/` |
| `acceptance` | 可验证的验收条件列表 |
| `required_outputs` | 必须产出的文件列表 |
| `handoff.next_task` | 如果知道后续 task 则填写，否则留空 `""` |
| `risk_level` | `low` `medium` `high` |

3. 写入 `.awp/tasks/{task_id}.yaml`

## Step 4: 同步 Registry

运行 `python scripts/validate_awp.py --sync` 自动将新 task ID 注册到 registry 并更新 task board。

## Step 5: 校验

运行 `python scripts/validate_awp.py`。退出码必须为 0。

若校验失败：
- 阅读错误信息
- 修正 task yaml
- 重新运行直到通过

## Step 7: 向用户汇报

总结创建的任务：
- Task ID 和标题
- 分配的 agent
- 目标验证级别
- 下一步建议（如：是否 spawn 子智能体开始执行）
