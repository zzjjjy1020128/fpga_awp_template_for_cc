# FPGA-AWP Agent 架构重构方案 v0.2 外部评审建议

> 文档目的：对 `architecture_v2_proposal.md` 中提出的 FPGA-AWP v0.2 重构方案进行结构化评审，并给出可执行的修订建议。  
> 适用场景：提交给 Claude Code / orchestrator / process_owner 继续实施 v0.2 架构补丁。  
> 评审结论：建议采纳 v0.2 主方向，但需要收紧 scope 权限、将 L1b 按数据通路切片而非模块数量触发、并引入 issue-centered debug loop 作为失败迭代的状态载体。

---

## 1. 总体判断

当前 v0.2 方案的方向是正确的。

它已经从早期的“多 agent 分工”升级到更成熟的“工程责任闭环”。当前 E001 项目中暴露的问题并不是单个 RTL bug，而是流程拓扑问题：

1. L1a 阶段设计与验证分家，导致责任分散；
2. L1b 虽然在规范中存在，但实际没有被创建和执行；
3. 所有模块 L1a pass 后直接进入 L1c，导致集成验证失败时难以定位；
4. 验证 agent 失败后缺少回到设计 owner 的反馈闭环；
5. 在验证失败时，agent 容易在 testbench 层面反复 workaround，而不是定位 DUT 根因。

因此，v0.2 的核心重构方向应当保留：

```text
module_owner 模式
+ L1b 分级 checkpoint
+ integration failure 回到 module_owner 的迭代闭环
```

但是当前方案还需要进一步收紧：

```text
1. integration_verifier 不应默认拥有子模块 RTL 修改权；
2. L1b checkpoint 不应按“每 3-4 个模块”触发，而应按数据通路切片触发；
3. 失败迭代不应只靠 handoff/session 记录，而应绑定到 ISS issue；
4. pre-spawn guard 不应阻断所有 spawn，而应只阻断越级行为；
5. task status 与 validation_status 应彻底分离。
```

---

## 2. 对 v0.2 核心方向的确认

### 2.1 module_owner 模式应当采纳

建议将原有：

```text
rtl_implementer + tb_verifier(L1a)
```

合并为：

```text
module_owner
```

这是 v0.2 中最重要的结构升级。

原因如下：

1. L1a 模块级单元仿真本质上是模块作者的自证环节；
2. RTL 设计意图、接口语义、边界条件、最小 TB 策略应由同一个 owner 掌握；
3. 拆成设计 agent 与验证 agent 会带来不必要的通信成本；
4. 失败时很难区分 DUT bug、TB bug、接口理解偏差；
5. module_owner 模式能让“写 RTL 的人”同时承担“证明模块可进入集成”的责任。

建议定义：

```text
module_owner 不是简单的 RTL 实现者，
而是某个模块在 L1a 阶段的唯一责任人。
```

module_owner 必须交付：

```text
1. 本模块 RTL；
2. 本模块 L1a testbench；
3. L1a run record；
4. 模块接口/行为说明；
5. 已知限制；
6. 给 integration_verifier 的 handoff。
```

---

### 2.2 L1b checkpoint 必须变成硬门禁

当前规范中已经有 L1a → L1b → L1c 的分级思想，但实际执行时跳过了 L1b，导致系统集成压力集中到 L1c。

v0.2 应将 L1b 从“文档建议”升级为“硬门禁”。

建议原则：

```text
任何 L1c / L2 / L3 / L4 / L5 / L6 推进前，
必须确认相关 L1b 数据通路闭环任务已经存在且通过。
```

但是，L1b 不建议按“每 3-4 个模块”机械触发，而应按数据通路切片触发。

---

### 2.3 集成失败回到 module_owner 是正确闭环

当前 v0.2 方案中提出：

```text
L1b/L1c fail
  → integration_verifier 输出失败报告
  → 定位到 module_owner
  → module_owner 修改 RTL/TB
  → 重跑 L1a 自证
  → 返回 integration_verifier 重验
```

这个闭环应当保留。

它的本质是：

```text
验证失败不是换一个 verifier 继续猜，
而是形成 defect ownership。
```

建议将该机制显式命名为：

```text
Issue-centered debug loop
```

也就是每一次集成失败，都必须创建或更新一个 `ISS-*` issue 对象，所有失败证据、归因假设、修复尝试、复测结果、迭代次数都挂在同一个 issue 上。

---

## 3. 必须修正的关键问题

### 3.1 收紧 integration_verifier 的 RTL 修改权限

当前方案中写到：

```text
integration_verifier (L1b) 允许修改：集成 TB + 数据通路涉及的模块 RTL（需标注）
integration_verifier (L1c) 允许修改：集成 TB + 全系统涉及的模块 RTL（需标注）
```

这个规则不建议采纳。

原因：

1. 这会破坏刚建立起来的 module_owner 责任边界；
2. integration_verifier 可能为了让系统仿真通过而直接在子模块 RTL 中 workaround；
3. 子模块 RTL 被 integration_verifier 修改后，L1a 自证链路会被绕过；
4. 后续很难追踪某个 bug 到底是 module_owner 修的，还是 integration_verifier 修的；
5. 这会使 v0.2 重新退化为“验证 agent 自行修补系统”。

建议修改为：

| Task 类型 | 允许编辑 | 禁止编辑 |
|---|---|---|
| `module_owner (L1a)` | 本模块 RTL + 本模块 TB + 本模块文档 | 其他模块 RTL、集成 TB、架构文档 |
| `module_owner (fix)` | 本模块 RTL + 本模块 TB，即使当前状态为 `review` | 其他模块 RTL、集成 TB |
| `integration_verifier (L1b)` | L1b TB、golden model、run script、debug notes、failure report | 子模块 RTL，除非 human_owner 明确授权 |
| `integration_verifier (L1c)` | L1c/system TB、golden model、run script、failure report | 子模块 RTL，除非 human_owner 明确授权 |
| `rtl_reviewer` | review/report/issue 建议 | 默认不直接改 RTL |
| `human_owner emergency patch` | 可授权跨边界修改 | 必须记录 issue、patch note、required rerun |

更严格的规则：

```text
integration_verifier 负责定位和报告；
module_owner 负责修复和自证；
orchestrator 负责 gate 和 issue lifecycle。
```

---

### 3.2 L1b 应按数据通路切片，而不是按模块数量触发

当前方案写到：

```text
3~4 个模块 L1a pass → checkpoint 1: 强制创建 L1b task
```

这个规则有价值，但过于机械。

更合理的是按接口闭环和数据通路切片。

对于当前 E001：AXI-Lite controlled AXI-Stream 2D Shift Micro-kernel，建议创建至少 3 个 L1b task：

#### TASK-E001-L1B-WRITE

```text
路径：
axis_input → frame_buf_mgr

验证目标：
1. AXI-Stream 输入握手；
2. raster-scan 写帧缓冲；
3. frame boundary；
4. write address increment；
5. write enable；
6. input backpressure；
7. reset during frame；
8. 多帧写入一致性。
```

#### TASK-E001-L1B-READ

```text
路径：
shift_addr_gen → frame_buf_mgr → axis_output

验证目标：
1. 2D shift 读地址生成；
2. padding 区域行为；
3. frame_buf_mgr 读端口行为；
4. AXI-Stream 输出顺序；
5. output backpressure；
6. tlast/tuser 或等价 frame marker 行为；
7. 跨帧读取一致性。
```

#### TASK-E001-L1B-CONTROL

```text
路径：
axil_slave_if / regs_top → ctrl_fsm → datapath control stubs

验证目标：
1. AXI-Lite 配置写入；
2. cfg latch 时机；
3. start/busy/done；
4. IDLE/CAPTURE/SHIFT/DONE 状态转换；
5. 非法启动或重复启动行为；
6. 配置更新与工作期隔离；
7. reset 后状态恢复。
```

之后再创建：

#### TASK-E001-L1C-SYSTEM

```text
路径：
完整 axil_2d_shift top

验证目标：
1. AXI-Lite 配置；
2. AXI-Stream 输入；
3. frame buffer；
4. shift address generation；
5. AXI-Stream 输出；
6. 多帧/多事务；
7. backpressure；
8. reset；
9. golden model 比对。
```

核心原则：

```text
L1b 的目标不是覆盖所有系统功能，
而是在进入 L1c 前确认主要跨模块协议边界没有大问题。
```

---

### 3.3 引入 issue-centered iteration tracking

当前 G4 失败升级模型方向正确，但状态载体还不够明确。

不建议只依赖：

```text
session log
handoff
review
```

因为这些文件是过程记录，不适合作为失败迭代的中心状态。

建议新增：

```text
.awp/issues/
.awp/templates/issue.template.yaml
.awp/schemas/issue.schema.json
```

每个集成失败都应创建或更新 `ISS-*` 文件。

示例：

```yaml
schema: ".awp/schemas/issue.schema.json"

issue_id: "ISS-E001-001"
title: "L1b write path frame buffer address mismatch"
status: "open"

detected_at_level: "L1b"
detected_by_task: "TASK-E001-L1B-WRITE"
detected_by_session: "SESS-E001-L1B-WRITE-001"

suspected_owner_task: "TASK-E001-004"
suspected_module: "frame_buf_mgr"

round_count: 1
max_rounds: 3

failure_signature:
  test_case: "TC_L1B_WRITE_003"
  timestamp: "1250ns"
  signal: "wr_addr"
  expected: "16'h0020"
  observed: "16'h001F"

evidence:
  waveform:
    - "sim/waves/l1b_write_tc003.vcd"
  logs:
    - ".awp/runs/RUN-E001-L1B-WRITE-001.json"
  notes:
    - "Address mismatch occurs only at row boundary."

attempts:
  - round: 1
    verifier_session: "SESS-E001-L1B-WRITE-001"
    owner_session:
    action: "Created issue and assigned to module_owner."
    result: "pending"

next_action:
  role: "module_owner"
  action: "Inspect frame_buf_mgr row-boundary write address update and rerun L1a."
```

这样 G4 失败升级可以基于 issue 状态执行：

```text
round_count = 1:
  交给 suspected module_owner 修复

round_count = 2:
  module_owner 修复后 integration_verifier 重验

round_count = 3:
  spawn rtl_reviewer 做深度审查，或切换 module_owner

round_count > 3:
  stop iteration，status=blocked，转 human_owner
```

---

### 3.4 pre-spawn guard 不应阻断所有 spawn

当前方案提出：

```text
有足够模块 ready for L1b 但没有对应 L1b task 时，阻断任何 spawn。
```

建议改为：

```text
L1b GAP 存在时，只阻断越级行为，不阻断修复、建 task、复盘和审查。
```

建议规则：

| L1b GAP 存在时 | 是否允许 spawn |
|---|---|
| `planner` 创建 L1b task | 允许 |
| `integration_verifier` 执行 L1b | 允许 |
| `module_owner` 修复已知 issue | 允许 |
| `process_owner` 修复 AWP 元数据 | 允许 |
| `rtl_reviewer` 做 gap/review 分析 | 允许 |
| `integration_verifier` 执行 L1c | 阻断 |
| `vivado_integrator` 执行 L2-L4 | 阻断 |
| `hardware_validator` 执行 L5-L6 | 阻断 |
| 新增无关 RTL feature task | 阻断 |

这个规则的目的不是让项目停摆，而是防止绕过 L1b 继续向后推进。

---

### 3.5 task status 与 validation_status 必须分离

当前状态流转中，`review` 同时承担了多种含义：

```text
1. 等待 reviewer 审查；
2. L1a pass，等待 L1b；
3. L1b pending；
4. L1c pending；
5. 可被集成失败回退。
```

这容易让 agent 误解。

建议将 task 状态和验证状态彻底分离。

#### task status

```yaml
status: "review"
```

只描述任务生命周期：

```text
draft
ready
in_progress
blocked
review
done
cancelled
superseded
```

#### validation_status

```yaml
validation_status:
  L0: "pass"
  L1a: "pass"
  L1b: "pending"
  L1c: "pending"
  L2: "not_applicable"
  L3: "not_applicable"
  L4: "not_applicable"
  L5: "not_applicable"
  L6: "not_applicable"
  L7: "not_applicable"
```

done 准入条件应写成：

```text
模块 task 只有在：
1. L0 = pass；
2. L1a = pass；
3. 所有关联 L1b = pass；
4. L1c = pass；
5. 无 open/blocking issue；
时才允许 status=done。
```

这样 `status=review` 就不会被过度解释。

---

## 4. 对未决问题的逐项建议

### 4.1 module_owner 粒度

建议：

```text
默认一个模块一个 module_owner。
只有强耦合、接口语义不可分割的小模块才允许合并为 owner_group。
```

合并标准：

满足以下至少 3 条，才允许合并：

```text
1. 两个模块总是成对实例化；
2. 两个模块之间没有稳定独立协议边界；
3. 单独测试其中一个模块的 TB 价值很低；
4. 二者共享同一组配置/状态机语义；
5. 合并后 L1a TB 更自然，而不是更复杂。
```

当前 E001 建议：

| Owner | 模块 |
|---|---|
| `OWNER-GRP-AXIL` | `axil_slave_if` + `regs_top` |
| `OWNER-CTRL` | `ctrl_fsm` |
| `OWNER-IN` | `axis_input` |
| `OWNER-ADDR` | `shift_addr_gen` |
| `OWNER-OUT` | `axis_output` |
| `OWNER-FBUF` | `frame_buf_mgr` |
| `TOP-INTEGRATION` | `axil_2d_shift`，不作为普通 module_owner，而作为 integration target |

---

### 4.2 agent 续接机制

建议：

```text
以文件持久化为主，SendMessage / 持久 agent session 为辅。
```

不要让 AWP 依赖某个 agent session 必须一直存在。

原则：

```text
同一个 agent session 能继续 → 使用 SendMessage，减少冷启动；
同一个 agent session 不能继续 → 新 agent 读取 task + issue + handoff + run record 后必须能恢复上下文。
```

module_owner 修复前必须读取：

```text
1. 原 task；
2. 相关 issue；
3. 失败 run record；
4. integration_verifier failure report；
5. 上一次 session/handoff；
6. 本模块 RTL/TB；
7. 本模块接口说明。
```

---

### 4.3 L1b 分组策略

当前 E001 建议至少创建：

```text
TASK-E001-L1B-WRITE
TASK-E001-L1B-READ
TASK-E001-L1B-CONTROL
TASK-E001-L1C-SYSTEM
```

其中：

```text
L1b-WRITE 验证写通路；
L1b-READ 验证读通路；
L1b-CONTROL 验证控制通路；
L1c-SYSTEM 验证完整系统。
```

---

### 4.4 checkpoint 自动化程度

建议：

```text
L1b GAP 只阻断越级推进，不阻断修复、建 task、审查和流程修补。
```

具体阻断范围：

```text
阻断：
- L1c；
- L2-L7；
- 新增无关 RTL feature；
- 标记 module task 为 done。

允许：
- 创建 L1b task；
- 执行 L1b；
- 修复已知 issue；
- 更新 task metadata；
- process_owner 复盘和补规则。
```

---

### 4.5 迭代轮次计数

建议放在 issue 文件中，而不是 task YAML 或 handoff 中。

原因：

```text
task 表达工作单元；
handoff 表达一次交接；
session 表达一次 agent 执行；
issue 才表达一个跨 session、跨角色、跨验证层级的问题闭环。
```

建议字段：

```yaml
round_count: 1
max_rounds: 3
attempts:
  - round:
    verifier_session:
    owner_session:
    reviewer_session:
    action:
    result:
```

---

## 5. 建议实施路线

不要一次性大改所有东西。建议分四个补丁推进。

---

### Patch 1：角色体系补丁

目标：让系统认识 `module_owner` 和新的 `integration_verifier`。

修改：

```text
.claude/agents/module_owner.md
.claude/agents/integration_verifier.md
CLAUDE.md
.awp/schemas/task.schema.json
.awp/templates/task.template.yaml
```

建议：

```text
1. 保留 rtl_implementer，但标记为 deprecated 或仅用于纯 RTL 小修；
2. 移除 tb_verifier 作为 L1a 角色；
3. module_owner 负责 RTL + L1a；
4. integration_verifier 负责 L1b/L1c，默认只读子模块 RTL。
```

---

### Patch 2：L1b task 补丁

目标：停止直接冲 L1c，补齐 L1b 分级验证。

新增：

```text
TASK-E001-L1B-WRITE
TASK-E001-L1B-READ
TASK-E001-L1B-CONTROL
```

保持：

```text
TASK-E001-008 / L1c top integration = blocked
```

直到所有必要 L1b pass。

---

### Patch 3：Issue 闭环补丁

目标：让失败迭代有统一状态载体。

新增：

```text
.awp/issues/
.awp/templates/issue.template.yaml
.awp/schemas/issue.schema.json
```

更新：

```text
CLAUDE.md G4
.awp/orchestration_guide.md
scripts/validate_awp.py
```

要求：

```text
每个 L1b/L1c fail 必须创建或更新 ISS issue；
同一 issue 往返超过 3 轮必须 blocked 并请求 human_owner。
```

---

### Patch 4：Guard/Validator 补丁

目标：让规则真正生效。

增强 `scripts/validate_awp.py`：

```text
1. 检查 L1b GAP；
2. 检查 L1c/L2+ 是否越级；
3. 检查模块 task done 准入；
4. 检查 issue.round_count；
5. 检查 integration_verifier 是否越权编辑子模块 RTL；
6. 检查 open/blocking issue 是否阻塞对应任务 done。
```

增强 Makefile：

```text
make validate-awp
make status
make task-board
```

---

## 6. 推荐写入 CLAUDE.md 的关键规则

建议将以下内容压缩后写入 `CLAUDE.md` 的长期规则中。

### G1：角色调度规则

```text
module_owner:
  负责单模块 RTL + L1a TB + L1a run record。
  默认只允许修改本模块 RTL/TB/相关文档。

integration_verifier:
  负责 L1b 数据通路闭环和 L1c 全系统仿真。
  默认不允许修改子模块 RTL。
  发现疑似 DUT bug 时，必须创建 ISS issue 并交回 module_owner。

rtl_reviewer:
  负责 L0 静态审查和疑难 bug 深度审查。

vivado_integrator:
  负责 L2-L4。

hardware_validator:
  负责 L5-L6。

process_owner:
  负责复盘、规则沉淀和 AWP 自身修正。
```

---

### G4：失败升级规则

```text
L1b/L1c 失败时：
1. integration_verifier 必须创建或更新 ISS issue；
2. issue 必须包含失败 case、时间戳、关键波形信号、expected/observed、根因假设；
3. issue 必须指定 suspected module_owner；
4. module_owner 修复后必须重跑 L1a 自证；
5. integration_verifier 再重跑对应 L1b/L1c；
6. 同一 issue 超过 3 轮往返仍未解决，必须 blocked 并请求 human_owner；
7. 不允许通过反复修改 TB 绕过疑似 DUT bug。
```

---

### G5：验证门禁规则

```text
验证层级必须遵守：
L0 → L1a → L1b → L1c → L2 → L3 → L4 → L5 → L6 → L7。

禁止跳过 L1b 直接进入 L1c。
禁止跳过 L1c 直接进入 Vivado。
禁止跳过 L4 直接进入 board validation。

模块 task 只有在相关 L1b 和 L1c 均通过后才能 done。
```

---

### G6：Scope 规则

```text
integration_verifier 默认不允许修改子模块 RTL。
如需修改，必须由 human_owner 授权，并创建 emergency patch 记录。
所有跨 scope 修改必须记录 issue、patch note、required rerun。
```

---

## 7. 推荐 validate_awp.py 新增检查项

建议增加如下检查：

```text
1. task.agent enum 中包含 module_owner / integration_verifier；
2. tb_verifier 用于 L1a 时给出 deprecated warning；
3. 模块 task 如果 L1a=pass 但 L1b/L1c=pending，不得 status=done；
4. 顶层 L1c task 如果存在 L1b GAP，必须 blocked；
5. L2-L7 task 如果 L1c 未 pass，必须 blocked；
6. integration_verifier task 的 allowed_edit_paths 不得包含 rtl/ 子模块路径，除非 task 标记 emergency_patch=true；
7. 每个 L1b/L1c fail 必须有关联 issue_id；
8. issue.round_count > max_rounds 时，必须阻断自动继续；
9. open/blocking issue 存在时，相关 task 不得 done；
10. make status 应显示 L1b GAP、open issues、blocked gates。
```

---

## 8. 推荐当前 E001 的下一步动作

当前不建议继续修 L1c testbench，也不建议直接让 integration_verifier 尝试 workaround。

建议立即执行：

```text
1. 暂停 TASK-E001-008 的 L1c 推进；
2. 实施 Patch 1，引入 module_owner 和新的 integration_verifier；
3. 实施 Patch 2，创建 L1b-WRITE / L1b-READ / L1b-CONTROL；
4. 让 integration_verifier 先跑 L1b-WRITE；
5. 若 L1b fail，创建 ISS issue 并交回对应 module_owner；
6. module_owner 修复后重跑 L1a；
7. L1b 重验；
8. 所有 L1b pass 后再恢复 L1c。
```

---

## 9. 最终建议摘要

建议采纳：

```text
1. module_owner = RTL + L1a 自证；
2. integration_verifier = L1b/L1c 定位和报告；
3. L1b 必须成为 L1c 前置门禁；
4. 集成失败必须回到 module_owner；
5. 同一失败最多 3 轮自动迭代；
6. 超过上限创建 issue 并请求 human_owner。
```

建议修正：

```text
1. integration_verifier 默认不得修改子模块 RTL；
2. L1b 以数据通路切片触发，而不是以模块数量触发；
3. 失败迭代必须绑定 ISS issue；
4. pre-spawn guard 只阻断越级推进，不阻断修复和建 task；
5. task status 与 validation_status 必须分离；
6. SendMessage 只能作为优化，不能作为 AWP 持久化基础。
```

最终推荐架构：

```text
orchestrator
  ├── module_owner
  │     ├── RTL
  │     ├── L1a TB
  │     └── L1a run record
  │
  ├── integration_verifier
  │     ├── L1b datapath TB
  │     ├── L1c system TB
  │     └── failure report / issue creation
  │
  ├── rtl_reviewer
  │     └── L0 review / difficult bug deep review
  │
  ├── vivado_integrator
  │     └── L2-L4
  │
  ├── hardware_validator
  │     └── L5-L6
  │
  └── process_owner
        └── retrospective / AWP rule updates
```

一句话结论：

```text
v0.2 的核心方向应当采纳，但必须把“角色分工”进一步升级为“责任闭环”：
每个模块有 owner；
每个验证层有 gate；
每个失败有 issue；
每次修复有 L1a 自证；
每次集成都可追溯。
```
