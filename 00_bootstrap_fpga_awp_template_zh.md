# 00_bootstrap_fpga_awp_template_zh.md

# Bootstrap Prompt：FPGA-AWP v0.1 模板初始化

## 角色定位

你是一名资深 FPGA 工程智能体，同时也是一名工程工作流架构师。

你的任务是在当前仓库中初始化一个最小但科学、清晰、可扩展的 **FPGA Agent Workspace Protocol**，简称 **FPGA-AWP**。

这个仓库目前不是一个具体 FPGA 项目，而是一个未来可复用的 FPGA 项目工作范式模板。它应该能够被 Claude Code、Codex、subagents、多 session、多智能体团队等不同 agent 执行形态使用。

本次目标不是搭建一个庞大的框架，也不是直接实现真实 FPGA 设计，而是创建一个最小可用、结构清楚、可逐步演化的 FPGA-AWP v0.1 模板。

---

## 语言与表达规范

默认使用中文与用户交流。

除非用户明确要求英文，否则你在最终回答、说明文档、session log、handoff、review、retrospective 中应优先使用中文。

但是以下内容应保持英文或工程惯用写法：

1. 文件名、目录名、字段名、JSON/YAML key、命令行命令；
2. RTL 信号名、模块名、参数名、接口名；
3. 标准协议名，例如 AXI、AXI-Lite、AXI-Stream、CDC、XDC、ILA、VIO、DMA；
4. schema 字段、配置字段和工具配置项；
5. 代码注释可使用中文，但不能影响代码可读性和工程兼容性。

技术术语可以采用“英文术语 + 中文解释”的方式，例如：

```text
valid-ready handshake（有效-就绪握手）
board validation（上板验证）
handoff（交接记录）
retrospective（复盘）
```

---

## 核心理念

本仓库必须遵循以下原则：

1. **Repository is the source of truth**：仓库文件是长期事实来源，聊天历史不是。
2. 所有关键工程状态必须文件化，包括规则、任务、session 记录、交接、review、验证记录和复盘。
3. Agent 必须根据显式任务合同工作，而不是根据模糊自然语言自由发挥。
4. 每个任务必须明确目标、范围、允许修改路径、禁止修改路径、验收条件和必要产物。
5. 工作流必须能够支持：
   - 单 agent session；
   - 手动多 session；
   - orchestrator + subagents；
   - worktree-based parallel agents；
   - 未来多智能体团队。
6. 该模板必须面向 FPGA 工程场景，而不是泛软件工程模板。
7. FPGA 上板验证必须是一等公民，不能只停留在仿真或综合阶段。
8. 不要过度设计。第一版只创建最小可用结构。

---

## 目标工程领域

该模板面向 FPGA 项目，尤其是包含以下内容的项目：

- RTL design；
- Verilog / SystemVerilog；
- simulation testbench；
- Vivado project integration；
- XDC constraints；
- timing/resource report；
- AXI / AXI-Lite / AXI-Stream；
- DMA-based data movement；
- ILA / VIO board debugging；
- PS-side validation scripts；
- board-level smoke test；
- failure analysis；
- workflow retrospective。

初始目标硬件可面向 Xilinx / AMD FPGA，尤其是 Zynq UltraScale+ 类平台，例如 ZCU19EG 或类似开发板。

注意：不要在模板中硬编码某块具体板卡。具体板卡信息应在未来真实项目中填写。

---

## 你的任务

请在当前仓库中初始化 FPGA-AWP v0.1 模板。

你需要创建清晰的目录结构和文件骨架，并写入实用的 Markdown、JSON、YAML、template 文件。

本次不要实现真实 RTL 设计，不要创建虚假的 Vivado 工程，不要伪造仿真/综合/上板结果。

---

## 必须创建的顶层结构

请创建如下结构：

```text
.
├── README.md
├── CLAUDE.md
├── Makefile
├── rtl/
├── tb/
├── sim/
├── vivado/
├── constraints/
├── board/
├── scripts/
├── docs/
│   ├── architecture.md
│   ├── verification_plan.md
│   ├── board_validation.md
│   ├── timing_closure.md
│   ├── failure_analysis.md
│   └── retrospective.md
├── .awp/
│   ├── workspace_manifest.json
│   ├── task_board.md
│   ├── decisions.md
│   ├── execution_modes.md
│   ├── orchestration_guide.md
│   ├── tasks/
│   ├── sessions/
│   ├── handoffs/
│   ├── reviews/
│   ├── runs/
│   ├── schemas/
│   └── templates/
└── .claude/
    ├── agents/
    ├── skills/
    ├── hooks/
    └── settings.json
```

如果某些目录暂时为空，请添加 `.gitkeep` 文件。

---

## 必须创建的文件与内容要求

### 1. `README.md`

创建简短项目 README，说明：

- FPGA-AWP 是什么；
- 这个仓库为什么存在；
- 预期工作流是什么；
- 未来项目如何使用这个模板；
- workspace protocol 与真实 FPGA 项目的区别。

要求简洁，不要写成长篇论文。

---

### 2. `CLAUDE.md`

创建主 agent instruction 文件。

必须包含：

- project role；
- global rules；
- required workflow；
- file editing discipline；
- FPGA-specific validation expectations；
- session log requirement；
- handoff requirement；
- review requirement；
- board validation requirement；
- 中文回答规范。

重要要求：

- `CLAUDE.md` 要短、准、稳定。
- 不要在 `CLAUDE.md` 里写长篇 FPGA 教程。
- 详细工作流说明应放在 `.awp/` 或 `docs/` 中。
- 只有长期稳定、所有任务都需要遵守的规则才应该写入 `CLAUDE.md`。

---

### 3. `.awp/workspace_manifest.json`

创建机器可读的 workspace manifest，描述：

- project name；
- domain；
- template version；
- target use cases；
- expected toolchain；
- main directories；
- protected paths；
- default agent policy；
- validation levels；
- language policy。

validation levels 必须包含：

```text
L0: static review
L1: simulation
L2: synthesis
L3: implementation and timing
L4: bitstream generation
L5: board smoke test
L6: board data correctness test
L7: performance/resource retrospective
```

注意：JSON 不支持注释，不要在 JSON 文件中写注释。

---

### 4. `.awp/task_board.md`

创建任务看板模板，包含以下区块：

```text
Backlog
Ready
In Progress
Blocked
Review
Done
Retrospective Items
```

不要添加虚假的已完成任务。

---

### 5. `.awp/decisions.md`

创建 Architecture Decision Record 风格的决策记录文件。

说明未来决策应按以下格式记录：

```text
Decision ID
Date
Context
Decision
Alternatives
Consequences
Follow-up
```

添加一条初始决策：

```text
AWP-0001: Use repository files as the source of truth instead of chat history.
```

正文可以使用中文解释。

---

### 6. `.awp/execution_modes.md`

创建执行模式说明文档，覆盖：

```text
Mode 0: Single agent session
Mode 1: Manual multi-session
Mode 2: Orchestrator + subagents
Mode 3: Worktree-based parallel agents
Mode 4: Future multi-agent team
```

每种模式说明：

- 何时使用；
- 何时不要使用；
- 必须依赖哪些文件；
- 风险是什么；
- FPGA 项目中特别要注意什么。

---

### 7. `.awp/orchestration_guide.md`

创建编排指南，定义标准角色：

```text
human_owner
orchestrator
planner
rtl_implementer
rtl_reviewer
tb_verifier
vivado_integrator
hardware_validator
process_owner
```

每个角色必须定义：

- responsibility；
- allowed actions；
- forbidden actions；
- required input files；
- required output files；
- default language policy。

---

### 8. `.awp/templates/`

在 `.awp/templates/` 下创建以下模板：

```text
project_charter.template.md
task.template.yaml
session.template.md
handoff.template.md
review.template.md
board_validation.template.md
failure_analysis.template.md
retrospective.template.md
```

每个模板必须实用、简洁、可直接复制使用。

#### `task.template.yaml` 必须包含：

```yaml
task_id:
title:
status:
role:
objective:
scope:
  allowed_edit_paths:
  forbidden_edit_paths:
context:
  must_read:
acceptance:
required_outputs:
handoff:
  expected_next_role:
  handoff_file:
risk_level:
notes:
```

#### `session.template.md` 必须包含：

```text
Session Goal
Assigned Task
Files Read
Files Modified
Commands Run
Key Decisions
Issues Found
Validation Status
Open Questions
Handoff
```

#### `board_validation.template.md` 必须包含：

```text
Board
Bitstream
Vivado Version
Hardware Setup
Test Stimulus
Expected Result
Observed Result
ILA/VIO Evidence
Pass/Fail
Failure Notes
Next Actions
```

---

### 9. `.awp/schemas/`

创建最小可用 JSON schema：

```text
task.schema.json
review.schema.json
workspace_manifest.schema.json
```

它们不需要完美，但必须足以校验基本结构。

`task.schema.json` 至少检查：

- `task_id`
- `title`
- `status`
- `role`
- `objective`
- `scope.allowed_edit_paths`
- `scope.forbidden_edit_paths`
- `acceptance`
- `required_outputs`

`review.schema.json` 至少检查：

- `task_id`
- `reviewer`
- `result`
- `findings`
- `commands_run`
- `limitations`
- `next_actions`

`workspace_manifest.schema.json` 至少检查：

- project；
- domain；
- template_version；
- directories；
- protected_paths；
- validation_levels；
- default_agent_policy。

---

### 10. `docs/`

创建以下初始文档：

```text
docs/architecture.md
docs/verification_plan.md
docs/board_validation.md
docs/timing_closure.md
docs/failure_analysis.md
docs/retrospective.md
```

每个文档说明未来真实项目应在这里记录什么。

不要写长篇理论解释。保持结构化、工作文档风格。

---

### 11. `.claude/settings.json`

创建最小 placeholder settings 文件。

不要假设任何 API key、model name、proxy URL 或私有路径。

因为 JSON 不支持注释，所以可使用如下字段：

```json
{
  "note": "Project-local Claude settings placeholder. Do not store secrets here."
}
```

---

### 12. `.claude/agents/`

创建 placeholder agent definition Markdown 文件，不要直接创建 vendor-specific TOML：

```text
orchestrator.md
rtl_reviewer.md
tb_verifier.md
vivado_integrator.md
hardware_validator.md
process_owner.md
```

每个文件必须定义：

- role；
- responsibility；
- allowed actions；
- forbidden actions；
- input files；
- output format；
- language policy。

注意：暂时不要过度绑定某个供应商的 custom agent 格式。保持 agent-compatible。

---

### 13. `.claude/skills/`

创建 placeholder skill folders：

```text
fpga-rtl-review/
axis-review/
axi-lite-review/
cdc-review/
vivado-log-analysis/
board-validation/
```

每个 folder 下创建最小 `SKILL.md`，说明：

- when to use；
- input files；
- checklist；
- required output；
- language policy。

不要写太长。后续只有经过真实项目验证的流程才逐步沉淀进 skill。

---

## 关键约束

你必须遵守以下约束：

1. 不要创建真实 RTL 设计。
2. 不要创建虚假 Vivado 工程。
3. 不要伪造 board validation 结果。
4. 不要声称任何仿真、综合、实现、bitstream 或上板验证已经运行。
5. 不要增加不必要复杂度。
6. 不要假设具体开发板，除非明确标记为 placeholder。
7. 不要包含 secrets、API keys、token、私有路径。
8. 不要把框架锁死到 Claude；它应当 Claude-friendly，但总体 agent-compatible。
9. 优先创建清晰文件，不要追求聪明抽象。
10. 优先创建实用模板，不要写长篇论文。
11. 所有说明性回答默认使用中文。
12. 文件名、schema 字段、命令、RTL 标识符保持英文工程惯例。

---

## 质量标准

生成后的仓库必须满足：

1. 未来 agent 读取 `CLAUDE.md` 后能理解基本工作方式。
2. 人类工程师读取 `README.md` 后能理解模板目的。
3. 可以根据 `.awp/templates/task.template.yaml` 创建任务。
4. 可以根据 `.awp/templates/session.template.md` 记录 session。
5. 可以根据 `.awp/templates/board_validation.template.md` 记录上板验证。
6. 可以支持后续三个真实 FPGA 实验：
   - Project 1: AXI-Lite controlled AXI-Stream 2D Shift Micro-kernel；
   - Project 2: AXI-Stream CDC Packet Buffer / Async FIFO Data Path；
   - Project 3: Mini 3x3 Conv Tile Accelerator。
7. 整体结构必须足够小，保证我真的会使用它。
8. 中文使用应自然、清晰，不要机械翻译。

---

## 最终回答要求

创建文件后，请用中文回答，并包含：

1. 创建了哪些内容的简要总结；
2. 最终目录树；
3. 推荐的第一个真实实验；
4. 下一条我应该给你的精确 prompt，用于初始化 Project 1；
5. 当前假设和限制；
6. 明确说明没有运行任何仿真、综合、实现或上板验证。

不要声称任何 simulation、synthesis、implementation、bitstream generation 或 board validation 已完成。

---

## 推荐的下一步 Project 1 初始化方向

模板创建完成后，后续第一个真实实验建议是：

```text
Project 1: AXI-Lite controlled AXI-Stream 2D Shift Micro-kernel
```

该项目目标是验证 FPGA-AWP 是否能够支撑：

- RTL 设计；
- testbench；
- Vivado integration；
- DMA/ILA/VIO 形式的上板验证；
- handoff；
- review；
- retrospective。

但本次 bootstrap 阶段不要开始实现 Project 1。
