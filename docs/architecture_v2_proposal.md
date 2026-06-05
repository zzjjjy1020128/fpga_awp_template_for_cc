# FPGA-AWP Agent 架构重构方案 v0.2

> 导出日期：2026-06-05
> 项目：fpga_awp_template（FPGA Agent Workspace Protocol）
> 当前分支：exp/E001
> 目的：提交给外部模型进行深度评审和优化，优化后返回继续实施

---

## 一、项目前置信息

### 1.1 项目背景

**fpga_awp_template** 是一个 FPGA 开发工作空间的元协议（Agent Workspace Protocol），用于规范基于 Claude Code 的 FPGA 设计验证流程。当前实验项目为 **AXI-Lite 2D Shift** —— 一个通过 AXI-Lite 接口配置、AXI-Stream 输入/输出的 2D 图像移位模块。

### 1.2 现有子模块（7 个，全部 RTL 已完成 + L1a 单元仿真通过）

| 模块 | 文件 | 功能 |
|------|------|------|
| axil_slave_if + regs_top | `rtl/axil_slave_if.sv` `rtl/regs_top.sv` | AXI-Lite 从接口 + 寄存器文件 |
| ctrl_fsm | `rtl/ctrl_fsm.sv` | 主控制状态机（IDLE→CAPTURE→SHIFT→DONE） |
| axis_input | `rtl/axis_input.sv` | AXI-Stream 输入，raster-scan 写帧缓冲 |
| shift_addr_gen | `rtl/shift_addr_gen.sv` | 2D 移位地址生成器（5 种模式） |
| axis_output | `rtl/axis_output.sv` | AXI-Stream 输出，backpressure 支持 |
| frame_buf_mgr | `rtl/frame_buf_mgr.sv` | 双端口 BRAM 帧缓冲控制器 |
| axil_2d_shift (top) | `rtl/axil_2d_shift.sv` | 顶层集成，实例化以上 7 个模块 |

### 1.3 验证体系（L0-L7 共 10 级）

```
L0  = 静态审查（代码审查、lint、CDC 审查）
L1a = 模块级单元仿真（单模块，单帧/单事务）
L1b = 数据通路闭环仿真（≥2 个数据通路模块串联，含跨帧测试）
L1c = 全系统集成仿真（完整系统，所有接口，多帧/多事务）
L2  = 综合
L3  = 实现与时序
L4  = 比特流生成
L5  = 板上冒烟测试
L6  = 板上数据正确性测试
L7  = 性能/资源复盘
```

**关键规则**：L1a → L1b → L1c 必须顺序通过，不可跳过 L1b 直接进入 L1c。

### 1.4 当前项目状态

- TASK-E001-002~007（6 个 RTL 模块）：status=`review`，L1a=pass，L1b/L1c=pending
- TASK-E001-008（顶层集成）：status=`blocked`，L1b=pending（GAP），等待创建 L1b 数据通路闭环仿真 task
- L1c 全系统集成仿真曾失败（TC01-TC07 全部 fail），根因疑似子模块 bug 但受限于 AWP 规范不允许修改"done"状态的子模块，导致在 testbench 层面无效修补

### 1.5 技术栈

- 仿真器：Icarus Verilog (iverilog + vvp)
- Python：PyYAML（task YAML 解析）、验证脚本（`scripts/validate_awp.py`）
- 版本控制：Git（分支 `exp/E001`，模板分支 `main`）
- Claude Code hooks：SessionStart、PreToolUse、PostToolUse、Stop

### 1.6 关键文件路径

```
CLAUDE.md                       ← 主 Agent 指令（编排规则、验证规范）
.claude/settings.json           ← hooks 配置
.claude/agents/                 ← 各 agent 角色定义
scripts/validate_awp.py         ← 验证器（schema/gate/guard/sync）
scripts/session_skeleton.py     ← Session 骨架生成器
.awp/tasks/TASK-E001-*.yaml     ← 任务合同
.awp/templates/task.template.yaml
.awp/templates/handoff.template.md
.awp/templates/session.template.md
.awp/templates/review.template.md
.awp/schemas/task.schema.json
.awp/schemas/workspace_manifest.schema.json
.awp/workspace_manifest.json
.awp/registry/                  ← ID 注册表 + 关系图
.awp/handoffs/                  ← Session 交接文件
.awp/reviews/                   ← Review 记录
.awp/runs/                      ← 仿真/验证运行记录
```

---

## 二、当前架构的核心问题

### 2.1 问题一：设计与验证角色分家 → 通讯成本高

**现状**：每个 RTL 模块分配一个 `rtl_implementer`（设计）+ 一个 `tb_verifier`（验证 L1a），两个 agent 通过 orchestrator 传话。

**问题**：
- L1a 单元仿真是设计者自己就该做的事。真实 FPGA 流程中，写 RTL 的人自己写 testbench 跑基本用例，确认模块能工作后才交出去。设计意图和验证策略在同一个人脑子里，不需要通讯。
- 当前模型把 L1a 拆成两个 agent，导致：
  - `rtl_implementer` 写完 RTL 就"交差"，不关心仿真结果
  - `tb_verifier` 对设计意图理解有限，可能写错 TB 或误判 bug
  - Orchestrator 在两个 agent 之间传递失败信息，每次传递都有信息损失
  - 当仿真失败时，无法确定是 DUT bug 还是 TB bug——因为两个 agent 各写各的

**影响**：无意义的通讯开销 + 责任分散 + 调试困难。

### 2.2 问题二：模块 → 全系统跳跃 → 集成压力集中

**现状**：所有 7 个模块 L1a pass 后直接冲向 L1c（全系统集成仿真）。L1b（数据通路闭环）规范上存在但从未被创建执行。

**问题**：
- 全系统集成仿真一次性面对 7 个模块的所有交互，任何问题都极难定位
- 没有中间 checkpoint——没有逐步验证"axis_input → frame_buf_mgr 写通路"或"shift_addr_gen → frame_buf_mgr → axis_output 读通路"
- L1b 规范写了"每 3-4 个模块后必须创建 L1b task"，但没有自动化阻断——orchestrator 疏忽就直接跳过
- 集成验证人员面对的不是 2-3 个已确认互联的模块组，而是 7 个从未一起跑过的模块

**影响**：集成验证变成"大海捞针"，发现 bug 后无法缩小范围。

### 2.3 问题三：验证人员无迭代约束 → 无限探索

**现状**：tb_verifier/integration_verifier 失败 → orchestrator 再 spawn → 再失败 → 循环。G4 写了"三次失败停止"但存在以下缺陷：

**问题**：
- **每次 spawn 是新 agent，无状态**：新 agent 不知道上一个 agent 试过什么假设、排除了什么方向
- **缺少"回给设计者"的反馈循环**：验证发现问题后，应该回到模块设计者，而不是换个验证的人继续猜
- **"仿真失败可能是 DUT bug 而非 TB bug"** 这条规则虽然写了，但没有强制机制——验证 agent 倾向于假设 TB 有问题而反复修改 TB
- **L1a 通过的模块被"done"锁死**（现已修复：done → review），集成验证发现其缺陷时无法修改 RTL，被迫在 TB 中 workaround

**影响**：验证 agent 在错误假设前提下无限探索，不返回设计者修复真正的根因。

---

## 三、重构方案

### 3.1 核心思路

**模块 owner 模式** + **分级 checkpoint** + **迭代闭环**

```
┌─────────────────────────────────────────────────────────┐
│                    orchestrator                         │
│          (管理迭代周期、gate 门禁、合规归档)              │
│                                                         │
│   ┌──────────┐   ┌──────────┐   ┌──────────┐           │
│   │ module   │   │ module   │   │ module   │           │
│   │ owner A  │   │ owner B  │   │ owner C  │           │
│   │          │   │          │   │          │           │
│   │ RTL 设计 │   │ RTL 设计 │   │ RTL 设计 │           │
│   │ +        │   │ +        │   │ +        │           │
│   │ L1a 验证 │   │ L1a 验证 │   │ L1a 验证 │           │
│   └────┬─────┘   └────┬─────┘   └────┬─────┘           │
│        │               │               │                │
│        └───────┬───────┘               │                │
│                │                       │                │
│                ▼                       │                │
│        ┌──────────────┐                │                │
│        │ integration  │◄───────────────┘                │
│        │ verifier     │                                 │
│        │ (L1b: DP闭环)│                                 │
│        └──────┬───────┘                                 │
│               │                                          │
│               ▼                                          │
│        ┌──────────────┐                                 │
│        │ integration  │                                 │
│        │ verifier     │                                 │
│        │ (L1c: 全系统)│                                 │
│        └──────────────┘                                 │
└─────────────────────────────────────────────────────────┘

迭代闭环（当集成验证发现子模块 bug 时）：
  L1b/L1c 失败 → 定位到 module_owner
      → module_owner 修改 RTL → 重跑 L1a → 自证修复
      → 返回集成验证 → L1b/L1c 重验 → pass 或继续迭代
```

### 3.2 角色重定义

| 角色 | 旧 | 新 | 说明 |
|------|:--:|:--:|------|
| `module_owner` | 不存在 | **新增** | 合并 rtl_implementer + tb_verifier(L1a)。负责单个模块的 RTL 设计 + L1a 单元仿真。一个 agent 拥有完整的设计意图和验证策略。 |
| `integration_verifier` | L1b/L1c | **保留** | 负责数据通路闭环（L1b）和全系统集成（L1c）仿真。不写子模块 RTL，但发现 bug 时向 module_owner 反馈。 |
| `rtl_reviewer` | 代码审查 | **保留** | 代码审查（L0），交叉审查 architecture 和 XDC。 |
| `vivado_integrator` | 综合/实现 | **保留** | Vivado 工程、XDC 约束、综合/实现/比特流。 |
| `hardware_validator` | 上板验证 | **保留** | L5-L6 板上验证。 |
| `planner` | 架构规划 | **保留** | 项目章程、架构设计。 |
| `process_owner` | 流程复盘 | **保留** | 项目复盘、质量检查。 |

**移除的角色**：`tb_verifier`（模块级 L1a 验证能力合并到 `module_owner`）

### 3.3 验证分级与 checkpoint

```
L0  ← 静态审查（rtl_reviewer）
 │
L1a ← 模块级单元仿真（module_owner 自验）—— 单模块，单帧/单事务
 │    └─ 3~4 个模块 L1a pass → checkpoint 1: 强制创建 L1b task
 │
L1b ← 数据通路闭环仿真（integration_verifier）—— ≥2 模块串联，跨帧
 │    └─ 所有 L1b task pass → checkpoint 2: 强制创建 L1c task
 │
L1c ← 全系统集成仿真（integration_verifier）—— 全系统，多帧/多事务
 │
L2~L7 ← 综合→实现→比特流→上板→复盘（vivado_integrator → hardware_validator）
```

**checkpoint 硬阻断**：pre-spawn guard 检测"有足够模块 ready for L1b 但没有对应 L1b task"时阻断任何 spawn。

### 3.4 迭代工作模型

```
┌─────────────────────────────────────────────┐
│              单模块迭代周期                   │
│                                             │
│  module_owner 写 RTL                        │
│       │                                     │
│       ▼                                     │
│  module_owner 写 L1a testbench + 跑仿真     │
│       │                                     │
│       ├── fail → 修 RTL → 重跑 L1a ──┐      │
│       │                              │      │
│       └── pass → L1a=pass ───────────┘      │
│                                             │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│            集成验证迭代周期                   │
│                                             │
│  integration_verifier 跑 L1b/L1c            │
│       │                                     │
│       ├── pass → level=pass                 │
│       │                                     │
│       └── fail → 定位故障模块               │
│              │                              │
│              ▼                              │
│         module_owner 接收失败报告           │
│              │                              │
│              ▼                              │
│         module_owner 修改 RTL               │
│              │                              │
│              ▼                              │
│         module_owner 重跑 L1a（自证）       │
│              │                              │
│              ▼                              │
│         返回 integration_verifier 重验      │
│              │                              │
│              └── 循环直到 pass              │
│                                             │
│  迭代限制：同一故障最多 3 轮往返             │
│  超过 3 轮 → 创建 ISS issue + 请求人工介入   │
└─────────────────────────────────────────────┘
```

### 3.5 G4 失败升级重写

```
第 1 轮：integration_verifier 失败
  → 输出详细失败报告（信号值、波形时间戳、失败 case、根因假设）
  → 定位到具体 module_owner

第 2 轮：module_owner 修复
  → 接收失败报告
  → 排查 DUT（优先）→ 修改 RTL
  → 排查 TB（仅当排除 DUT 问题后）→ 修改 TB
  → 重跑 L1a 自证 → 返回

第 3 轮：integration_verifier 重验
  → 重跑 L1b/L1c
  → pass → 继续
  → 仍 fail → 回到 module_owner（第 2 轮）

第 4 轮（第 2 次往返）：
  → 切换策略：spawn rtl_reviewer 深度审查故障模块
  → 或切换 module_owner（换一个 agent 重新审视）

第 5 轮+（第 3 次往返后仍失败）：
  → 停止迭代
  → 创建 ISS issue 文件
  → 向 human_owner 报告并等待指示
```

### 3.6 Scope 规则调整

| Task 类型 | 允许编辑 | 禁止编辑 |
|-----------|---------|---------|
| module_owner (L1a) | 本模块 RTL + 本模块 TB | 其他模块 RTL、架构文档 |
| module_owner (修复) | 本模块 RTL + 本模块 TB（即使 status=review） | 集成 TB、其他模块 |
| integration_verifier (L1b) | 集成 TB + 数据通路涉及的模块 RTL（需标注） | 架构文档、无关模块 |
| integration_verifier (L1c) | 集成 TB + 全系统涉及的模块 RTL（需标注） | 架构文档 |

### 3.7 验证状态流转（更新后）

```
子模块 task：
  ready → in_progress (module_owner 开始设计)
  in_progress → review (L1a pass，等待 L1b 集成确认)
  review → in_progress (L1b/L1c 发现 bug，回退修改)
  review → done (L1b + L1c 全部 pass)

集成 task：
  ready → in_progress (integration_verifier 开始)
  in_progress → review (仿真完成，等待 review)
  review → done (全部通过)
  review → in_progress (review 不过/module_owner 修复后重验)
```

---

## 四、实施计划

### 4.1 改动清单

| # | 文件 | 改动 |
|---|------|------|
| 1 | `.claude/agents/module_owner.md` | 新建 agent 定义：合并 rtl_implementer + tb_verifier(L1a) 能力 |
| 2 | `.claude/agents/integration_verifier.md` | 更新：明确 L1b/L1c 职责、module_owner 反馈机制 |
| 3 | `CLAUDE.md` G1 调度表 | 重写：移除 tb_verifier，新增 module_owner |
| 4 | `CLAUDE.md` G4 | 重写：基于迭代轮次的失败升级模型 |
| 5 | `CLAUDE.md` G5 | 更新：L1b checkpoint 硬阻断规则 |
| 6 | `CLAUDE.md` G7 | 更新：状态转换 + done 准入条件 |
| 7 | `scripts/validate_awp.py` | 新增：L1b checkpoint 缺失检测；更新 agent 枚举 |
| 8 | `.awp/schemas/task.schema.json` | agent 枚举更新：移除 tb_verifier，新增 module_owner |
| 9 | `.awp/templates/task.template.yaml` | 默认 agent + validation_status 更新 |
| 10 | `.awp/tasks/TASK-E001-002~007.yaml` | agent 字段更新：rtl_implementer → module_owner |
| 11 | `.awp/tasks/TASK-E001-001.yaml` | agent=planner，不变 |
| 12 | `.awp/tasks/TASK-E001-008.yaml` | agent + scope 可能需要更新 |

### 4.2 兼容性注意事项

- 已有的 REV review 文件和 RUN 仿真报告不变（历史记录）
- TASK-E001-008 的 forbidden_edit_paths 需要更新以反映新 scope 规则
- 旧的 `tb_verifier` agent 定义文件可保留但标记 deprecated
- `rtl_implementer` agent 定义可保留（用于非 module_owner 场景的纯 RTL 修改）

### 4.3 未决问题（供评审）

1. **module_owner 粒度**：一个 module_owner 负责一个模块还是可以负责 2-3 个紧密相关的小模块？合并标准是什么？
2. **agent 续接机制**：是否需要利用 SendMessage 做 module_owner 持久化？还是每次重新 spawn？
3. **L1b 分组策略**：7 个模块如何分组进行 L1b 验证？axis_input+frame_buf_mgr（写通路）一组、shift_addr_gen+frame_buf_mgr+axis_output（读通路）一组？
4. **checkpoint 的自动化程度**：pre-spawn guard 检测 L1b 缺失，是阻断所有 spawn 还是只阻断集成相关 spawn？
5. **迭代轮次计数**：跨 agent 的迭代如何追踪轮次？是在 task YAML 中增加字段还是通过 handoff/session 记录？

---

## 五、附录：当前 AWP Guard/Hook 架构

### 5.1 Hook 触发点

```
SessionStart       → session_skeleton.py + guard session-start  [提醒]
PreToolUse(Agent)  → guard pre-spawn (仅 active task 的 GAP)   [阻断]
PostToolUse(Edit)  → --sync (board 重生 + GAP auto-fix)        [修复]
PostToolUse(Write) → --sync                                     [修复]
Stop               → guard pre-stop                             [提醒]
PreCommit          → validate_awp                               [阻断]
```

### 5.2 validate_awp.py 检查覆盖

- YAML schema + ID 格式校验
- 跨文件引用完整性（review → task，depends_on 链）
- Review frontmatter + 覆盖检查（G3）
- required_outputs / must_read 文件存在性
- skip 语义有效性（rtl_implementer 模块级 task 的 L1b/L1c 不得为 skip）
- fail 状态一致性
- Gate 递进 + target-gap
- `--sync` 自动修复：GAP → blocked、done+L1b/L1c pending → review、skip 滥用修正、board 重生

### 5.3 当前 task 状态

| Task | Agent | Status | L0 | L1a | L1b | L1c | Target |
|------|-------|--------|----|-----|-----|-----|--------|
| TASK-E001-001 | planner | done | pass | skip | skip | skip | L0 |
| TASK-E001-002 | rtl_implementer | review | pass | pass | pending | pending | L1a |
| TASK-E001-003 | rtl_implementer | review | pass | pass | pending | pending | L1a |
| TASK-E001-004 | rtl_implementer | review | pass | pass | pending | pending | L1a |
| TASK-E001-005 | rtl_implementer | review | pass | pass | pending | pending | L1a |
| TASK-E001-006 | rtl_implementer | review | pass | pass | pending | pending | L1a |
| TASK-E001-007 | rtl_implementer | review | pass | pass | pending | pending | L1a |
| TASK-E001-008 | rtl_implementer | blocked | pass | skip | pending | pending | L1c |
