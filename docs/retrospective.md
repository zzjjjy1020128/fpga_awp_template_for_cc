# FPGA-AWP v0.2 实验复盘

> 实验分支：exp/E001
> 日期：2026-06-04 ~ 2026-06-05
> 项目：AXI-Lite 2D Shift

## 一、验证结果总结

| 级别 | 描述 | 结果 |
|------|------|------|
| L0 | 静态审查 | pass |
| L1a | 模块级单元仿真（7 模块） | pass（含 2 模块回验） |
| L1b | 数据通路闭环（WRITE/READ/CONTROL） | pass（209 assertions, 0 failures） |
| L1c | 全系统集成仿真 | pass（247 assertions, 0 failures） |
| L2-L7 | 综合→上板→复盘 | 未执行 |

## 二、流程中发现的 8 个问题

### 问题 1：Handoff 叙事覆盖 YAML 事实

**现象**：HO-E001-008-001 写"L1c 集成仿真 FAIL，下一步调试"，orchestrator 直接按 narrative 行动，忽略了 YAML 中 `L1b: pending` 的事实。

**根因**：Handoff 没有 formal state 字段，纯 prose 叙事容易被扫读跳过。

**已修**：handoff template 加 Gate Status 必填表；B1 从段落改为 checklist；`--gate-check` 检测 target-gap。

**残留风险**：prose 和 structured data 的 divergence 是永恒问题——即使有了 Gate Status 表，orchestrator 仍可能只读 narrative 跳过表格。

---

### 问题 2：`skip` 语义被滥用

**现象**：6 个子模块 RTL task 的 L1b/L1c 全部标记为 `skip`，声明模块"不需要集成验证"。模块 L1a pass 直接 done，RTL 被 lock。L1c 失败时无法修改子模块，被迫 hack TB。

**根因**：`skip` 被解释为"不归我管"而非"此 task 类型确实不涉及此 level"。模块级 task 的 target=L1a 意味着只负责到 L1a，但 `L1b=skip` 给人以"集成验证不需要了"的错觉。

**已修**：validate_awp 检查 skip 滥用；`--sync` 自动 fix `skip → pending`；CLAUDE.md 明确 skip 语义。

**残留风险**：`skip` vs `pending` 的边界依赖 agent 类型判断，validate_awp 中硬编码了 agent 列表。如果新增 agent 类型，此检查可能遗漏。

---

### 问题 3：module_owner 设计但不可 spawn

**现象**：v0.2 架构核心是 module_owner 角色，但 `.claude/agents/module_owner.md` 创建后并未注册为可 spawn 的 agent 类型。L1a 回验时被迫使用 `rtl_implementer`，功能上等效但语义上不一致——`rtl_implementer` 被标记为 deprecated 但它仍然是唯一能执行模块级工作的 agent。

**根因**：AWP 的 agent 定义（`.claude/agents/*.md`）和 Claude Code 的 spawnable agent 列表是两套系统。模板中的 agent 定义文件是给 agent 看的 system prompt，但能否 spawn 取决于平台注册。我们只写了一半。

**待修**：要么将 module_owner 注册为 spawnable agent，要么重新设计——不要让 AWP 规范依赖不可 spawn 的 agent 类型。当前最务实的方案：保留 `rtl_implementer` 作为模块级工作的主 agent，把 module_owner 的能力描述（RTL + L1a TB + 自证）写入 `rtl_implementer` 的 system prompt，而不是新建一个无法 spawn 的角色。

---

### 问题 4：integration_verifier 违反 G6 scope 但修对了

**现象**：L1c 调试中，integration_verifier 直接修改了 `axis_input.sv`（计数器复位）和 `shift_addr_gen.sv`（proceed 端口连接、计数器复位），违反了 v0.2 G6"默认禁止修改子模块 RTL"的规则。但这些修改恰好是根因。

**根因**：v0.2 G6 画了一条严格的边界——integration_verifier 只报告不修复。但实际调试中，拥有全系统上下文的人（integration_verifier）是定位和修复 bug 的最佳人选。把修复交给 module_owner 意味着：创建 ISS → 等待 module_owner spawn → module_owner 重新加载上下文 → 理解 bug → 修复 → L1a 自证 → 返回。这个往返链条在实际执行中太慢了。

**待修**：G6 的严格性需要分层——
- **must-report**（不涉及子模块 RTL 修改的 bug）：走 ISS → module_owner 流程
- **may-fix-with-record**（integration_verifier 发现并修复，需标注）：允许 integration_verifier 修改子模块 RTL，但必须创建 ISS issue 记录每次修改，且修复后必须触发 module_owner 的 L1a 回验
- **must-escalate**（integration_verifier 无法确定修复方案）：创建 ISS，转 human_owner

---

### 问题 5：RTL 接口变更后 TB 未自动检测

**现象**：shift_addr_gen 在 L1c 修复中新增了 `proceed` 输入端口，但 L1a testbench 未同步更新——缺少 `.proceed(1'b1)` 连接。L1a 仿真中 proceed 悬空为 X，导致所有像素地址递增失败，但首个像素恰好为 0 掩盖了问题。直到 L1a 回验时才暴露。

**根因**：没有机制在 RTL 端口变更时自动检测依赖的 TB 是否需要更新。这在真实 FPGA 流程中通常由 lint 工具（如 Verilator --lint-only）或持续集成捕获，但当前 AWP 缺少这一层。

**待修**：validate_awp 可增加"端口一致性检查"——解析 RTL 模块的端口列表，与 TB 中的实例化端口列表比对，发现不匹配时报警。这不是完整的 formal verification，但能捕获明显的连接遗漏。

---

### 问题 6：PostToolUse sync 的副作用

**现象**：TASK-E001-009 的 L1b 从 pending 更新为 pass 后，`--sync` 检测到 L0=pending + target=L1b → GAP，自动将 status 改为 blocked。但 L0 对 integration_verifier 任务本应是 skip——集成 TB 不需要静态审查。

**根因**：sync 的 GAP 检测和 skip 滥用检测是两个独立逻辑。sync 先检测到 GAP（L0 pending 但 target 是 L1b），在 skip 检测之前就改了 status。更根本的问题是：integration_verifier task 的默认 validation_status 模板没有将 L0 设为 skip。

**待修**：
- task template 应按 agent 类型提供不同的默认 validation_status
- sync 执行顺序：先 fix skip 滥用，再检测 GAP
- 或在 GAP 检测中跳过对 agent 类型不适用 level 的检查

---

### 问题 7：验证状态变更的涟漪效应是手动的

**现象**：axis_input 和 shift_addr_gen 的 RTL 修改后，需要手动操作以下步骤：
1. 模块 task L1a: pass → pending, status: review → in_progress
2. 模块 task L1b: pass → pending
3. L1b 集成 task L1b: pass → pending, status: review → in_progress
4. L1c task L1b: pass → pending（如果已 pass）
5. 跑 L1a 回验 → 更新 L1a
6. 跑 L1b 回验 → 更新 L1b
7. 最终所有状态恢复

整个过程全靠人手动追踪依赖链。如果模块更多（真实项目可能有 20+ 模块），这会迅速失控。

**待修**：`--sync` 应有"依赖传播"模式——当某个 task 的 validation_status 回退时，自动检测所有 `depends_on` 它的 task，将它们对应的 level 也回退。例如 TASK-E001-004 (axis_input) L1a 回退到 pending → 自动将 TASK-E001-009 (L1b-WRITE) 的 L1b 回退到 pending → 自动将 TASK-E001-008 (L1c) 的 L1b 回退到 pending。

---

### 问题 8：L1b checkpoint 被正确执行，但触发方式是"规范要求"而非"自动阻断"

**现象**：v0.2 的三个 L1b task（WRITE/READ/CONTROL）被正确创建和执行，这是整个实验中 v0.2 架构最成功的部分。但触发方式仍然是 orchestrator 按规范手动创建——不是系统自动检测"3 个模块 ready 但无 L1b task"并强制阻断。

**根因**：validate_awp 和 pre-spawn guard 目前只检测 GAP（已有 task 的 level 不一致），不检测 MISSING（应该有但没有的 task）。

**待修**：pre-spawn guard 增加"L1b coverage check"——当满足以下条件时阻断 L1c/L2+ spawn：
- 存在 ≥2 个 module_owner task 的 L1a=pass 且 L1b=pending
- 不存在对应的 L1b integration_verifier task
- 意味着"有模块 ready for integration 但没有 integration task"

---

## 三、v0.2 架构中被验证为正确的设计

### 成功点 1：L1b 分级验证

将 L1b 按数据通路切片（WRITE/READ/CONTROL）而不是按模块数触发，证明是正确的。每个 L1b task 验证一个独立的协议边界，失败时能精准定位。三个 L1b 全部 pass 后，L1c 的 247 个断言一次性全部通过——说明 L1b 确实起到了"在进入全系统前消除跨模块协议问题"的作用。

### 成功点 2：从 L1c 失败回溯到子模块 bug 的链路

旧架构：L1c 失败 → 子模块 done 锁死 → TB 无限 hack。
新架构：L1c 失败 → 创建 ISS → 定位子模块 → 修复 → L1a 自证 → L1b 重验 → L1c 通过。

虽然 G6 scope 规则在实操中被违反，但整体闭环逻辑是正确的。

### 成功点 3：Guard/Sync 自动化

post-edit sync、pre-spawn guard、session-start 审计这一套自动触发机制多次捕获了状态漂移（skip 滥用、done 锁定、L0 pending GAP），证明自动化门禁比纯靠人记 checklist 有效。

### 成功点 4：Skip 语义明确化

将 `skip` 限定为"agent 类型确实不涉及此 level"，将子模块的 L1b/L1c 从 `skip` 改为 `pending`，从根本上改变了模块状态的心理模型——从"已完成"变为"等待集成确认"。

---

## 四、优化建议优先级

| 优先级 | 问题 | 建议 |
|:--:|------|------|
| P0 | module_owner 不可 spawn | 将 v0.2 能力描述合并到 `rtl_implementer` agent 定义，不依赖不可用的 agent 类型 |
| P0 | G6 太严格 | 分层：may-fix-with-record / must-report / must-escalate |
| P1 | 验证涟漪手动传播 | `--sync` 增加依赖传播模式 |
| P1 | TB 不随 RTL 更新 | validate_awp 增加端口一致性检查 |
| P2 | L1b coverage 检测 | pre-spawn guard 检测"有模块 ready 但无 L1b task" |
| P2 | PostToolUse sync 顺序 | 先 fix skip 再检测 GAP |
| P3 | Handoff prose vs data | 长期问题，持续加固 Gate Status 表 |

---

## 五、下一步行动

1. 实施 P0 修复：重写 `rtl_implementer` agent 定义，吸收 module_owner 能力
2. 实施 P0 修复：G6 分层规则写入 CLAUDE.md
3. 实施 P1 修复：`--sync --propagate` 依赖传播 + 端口检查
4. 进入 L2 综合阶段
