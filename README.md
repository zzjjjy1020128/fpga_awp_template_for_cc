# FPGA-AWP v0.1

**FPGA Agent Workspace Protocol** —— FPGA 项目的 agent 工作空间协议模板。

## 这是什么

FPGA-AWP 是一个最小、可复用的 FPGA 项目工作范式模板。它定义了一套目录结构、文件规范和 Agent 工作流协议，使 FPGA 项目能够被 Claude Code、Codex、subagents 及多智能体团队可靠地协作执行。

## 为什么存在

- FPGA 项目涉及 RTL 设计、仿真、综合、时序收敛、上板验证等多个环节，需要清晰的工作流支撑
- Agent（AI 编程助手）需要显式的任务合同和文件化状态，而不是依赖聊天历史
- 需要一个可复用的起点，让新项目快速启动，而不是每次都重新建立工程规范

## 预期工作流

```text
任务定义 → 明确 scope → 实现 → review → handoff → 验证（sim/synth/board） → retrospective
            ↑_______________________________________________________________|
```

1. 通过 `.awp/templates/task.template.yaml` 定义任务合同
2. Agent 在明确的 `allowed_edit_paths` 和 `forbidden_edit_paths` 范围内工作
3. 每次 session 通过 `.awp/templates/session.template.md` 记录
4. 关键阶段通过 handoff、review、board_validation 模板进行文件化交接
5. 项目结束后进行 retrospective

## 如何使用这个模板

1. Clone 或复制本仓库作为新项目的起点
2. 修改 `CLAUDE.md` 中的项目特定规则
3. 在 `.awp/workspace_manifest.json` 中填写项目元信息
4. 在 `docs/` 中逐步填充架构、验证计划等文档
5. 使用 `.awp/templates/` 中的模板创建任务、记录 session、进行 review
6. 真实 RTL 放入 `rtl/`，testbench 放入 `tb/`，约束文件放入 `constraints/`

## Workspace Protocol 与真实 FPGA 项目的区别

本仓库是 **模板**，不是真实 FPGA 项目：
- 不包含 RTL 设计
- 不包含 Vivado 工程
- 不包含仿真/综合/上板结果
- 定义了"如何工作"的规范，而不是具体设计内容

真实项目应在此基础上填充具体设计文件。

## 语言规范

- 日常交流、文档说明：中文
- 文件名、目录名、信号名、模块名、JSON/YAML key、命令：英文
- 标准协议名保持英文原样（AXI, AXI-Lite, AXI-Stream, CDC, ILA, VIO, DMA 等）
