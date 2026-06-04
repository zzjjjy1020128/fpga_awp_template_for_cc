# AWP 方法论复盘 —— 基于 E001 测试项目的系统性缺陷分析

> 日期: 2026-06-04 | 项目: E001 (AXI-Lite 2D Shift) | 触发事件: 集成仿真 3 次 attempt 全部失败

## 一、技术根因（DUT 层）

集成仿真失败的**直接原因**是 `shift_addr_gen.sv` 的一个设计缺陷：

```verilog
// shift_addr_gen.sv:56-72 — 缺陷代码
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        row_cnt <= '0;  col_cnt <= '0;
    end else if (shift_en) begin
        // ... 计数器推进逻辑 ...
        // 帧结束时 row/col 归零
    end
    // ← shift_en=0 时计数器完全保持，不归零！
end
```

同一个模块 `axis_output.sv:83-87` 正确处理了这个问题：
```verilog
if (!shift_en) begin
    row_cnt <= '0;  col_cnt <= '0;  all_done <= 1'b0;
end
```

两个协作者模块在相同场景（shift_en=0 时是否复位计数器）上**行为不一致**。单帧仿真碰巧正确，多帧场景立即暴露。

---

## 二、AWP 规范缺陷逐条追溯

以下按"对本次失败的贡献度"从高到低排序。

---

### P0 — 致命缺陷

#### 2.1 Agent 角色隔离导致"发现-修复"链路断裂

**涉及规范**：
- `.claude/agents/tb_verifier.md` 第 24 行：`"禁止修改 RTL 设计文件（rtl/）—— 发现 bug 应反馈给 rtl_implementer 或 orchestrator"`
- `CLAUDE.md` G1 表：仿真/测试 → `tb_verifier`、RTL 设计/修改 → `rtl_implementer`
- task 模板 `scope.forbidden_edit_paths`：所有 tb_verifier task 均将 `rtl/` 列入禁止路径

**问题**：规范定义了一条"反馈给 rtl_implementer 或 orchestrator"的路径，但这条路径**根本不存在**。整个 session 中没有一次成功从 tb_verifier 向 rtl_implementer 传递 bug 报告的实例。原因：

- tb_verifier agent 的指令中只说了"应该反馈"，但没有具体机制（写什么文件？发给谁？什么格式？）
- orchestrator 收到 tb_verifier 的"仿真失败"结果时，看到的只是汇总信息（"253 failures"），无法判断是 DUT bug 还是 TB bug
- 默认假设是 "DUT 已验证过（单元仿真全部通过），所以是 TB 问题" → 反复 spawn tb_verifier 修 TB
- 3 次 attempt 累计 120+ 分钟，没有一个 agent 被允许去读 DUT RTL 并发现计数器残留问题

**影响**：当 bug 跨 agent 边界时（验证 agent 发现设计 agent 的缺陷），没有任何机制让 bug 被正确路由到能修复它的人。

---

#### 2.2 L1 验证粒度缺失 —— 单元仿真与集成仿真未区分

**涉及规范**：`CLAUDE.md` L0-L7 验证级别定义

当前定义只有 8 个大级别（L0-L7），L1 = "仿真验证"，不区分：
- L1a：模块级单元仿真（当前 session 中全部通过，1850/1850）
- L1b：数据通路闭环仿真（axis_input + frame_buf_mgr + shift_addr_gen + axis_output）
- L1c：全系统集成仿真（当前 session 中 9/269 通过）

**问题**：L1a 全部通过后，orchestrator 按"低级别通过才进入高级别"规则直接推进到 L1c。但 L1a→L1c 的跳跃掩盖了跨模块状态持久性问题。如果存在中间的 L1b 级别，单帧+连续帧的数据通路闭环测试就会立即暴露计数器残留 bug，根本不需要走到全系统 11 个测试用例的 TB。

---

### P1 — 高优先级

#### 2.3 G4 失败升级规则假定"故障在同域内可修复"

**涉及规范**：`CLAUDE.md` G4 验证失败升级规则

```
1st fail → spawn 同一 agent 修复
2nd fail → spawn 同一 agent 修复 + 强调
3rd fail → STOP, 创建 ISS
```

**问题**：规则假定失败原因是 agent 执行不到位（需要"更强调"），而非 agent 选错了（应该换人）。本次 3 次 attempt 的实际轨迹：

| Attempt | Agent | 时间 | 失败数 | 实际做了什么 |
|---------|-------|------|--------|------------|
| 1 | tb_verifier | 1936s | 253 | 创建 TB + pipeline 补偿 hack |
| 2 | tb_verifier | 1186s | 264 | 增加 debug probe、cleanup 逻辑（更差）|
| 3 | tb_verifier | 4124s | 260 | 试图修改 pipeline 补偿顺序（未完成）|

3 次全部在错误方向上迭代。G4 的正确行为应该是：**第 2 次失败时切换 agent 类型**（如联合 spawn rtl_implementer 调查 DUT），而非继续 spawn 同一类型。

---

#### 2.4 tb_verifier agent 模型能力不足

**涉及规范**：`.claude/agents/tb_verifier.md` frontmatter

```yaml
model: deepseek-v4-flash
maxTurns: 60
```

对比其他 agent：
- planner: `deepseek-v4-pro`, maxTurns: 40
- rtl_implementer: 继承主 session 模型
- rtl_reviewer: 继承主 session 模型
- tb_verifier: **`deepseek-v4-flash`**, maxTurns: 60

**问题**：tb_verifier 被分配了最弱的模型。对于模块级 TB（简单的激励-检查模式）这或许够用，但对于集成仿真——需要理解 7 个模块的接口、BRAM 读延迟、流水线对齐、AXI 协议握手——`deepseek-v4-flash` 的能力严重不足。更致命的是，它拿到了 60 个 turns（其他 agent 的 1.5 倍），刚好够在错误方向上走得更远。

---

#### 2.5 缺少"集成验证"角色

**涉及规范**：`CLAUDE.md` G1 Spawn 决策表 + `.awp/orchestration_guide.md` 角色总览

当前角色表中，tb_verifier 的职责是 "编写 testbench 并运行仿真验证"，没有区分模块级和系统级。角色表中也没有"集成验证工程师"。

**问题**：模块级验证和系统级集成验证是两种完全不同技能的工作：
- 模块级：只需理解一个模块的接口，写定向+随机激励
- 集成级：需要理解所有模块的接口、跨模块时序、流水线对齐、状态持久性

把这两者交给同一个 agent 类型且使用同一个模型，相当于让单元测试工程师做系统集成测试。

---

### P2 — 中优先级

#### 2.6 架构文档未定义跨模块时序契约

**涉及规范**：架构规划无强制性内容清单

`docs/architecture.md` 提到了"BRAM 读延时：1 cycle"，但没有定义：
- 各计数器在 shift_en=0 时的行为（保持 vs 复位）
- FSM 状态转换的精确周期数（shift_done 到 shift_en=0 延迟）
- 跨帧操作时哪些状态需要保留/清除

**对比**：如果 architecture.md 中有一张"模块间时序契约表"：

| 信号/状态 | 条件 | 行为 |
|-----------|------|------|
| shift_addr_gen.row/col_cnt | shift_en=0 | 复位到 0 |
| axis_output.row/col_cnt | shift_en=0 | 复位到 0 |
| frame_buf_mgr.read_data | read_addr 变化后 | 1 cycle 后更新 |

这 3 行就足以让 rtl_implementer 和 rtl_reviewer 在实现/审查时发现 shift_addr_gen 的遗漏。

---

#### 2.7 L0 Review Checklist 缺少交叉一致性检查

**涉及规范**：`.awp/templates/review.template.md` 的 Checklist

当前 checklist：
```
- [ ] 接口兼容性
- [ ] 时序正确性
- [ ] 复位策略
- [ ] CDC 处理
- [ ] 代码风格
- [ ] 与 architecture.md 一致性
```

**缺失项**：
- `[ ] 同级模块间行为一致性`（两个模块处理相同场景的方式是否一致？）
- `[ ] 跨帧/跨事务状态持久性`（模块在多帧操作中状态是否正确复位？）

如果有这两项，REV-E001-005-RTL-001（shift_addr_gen 审查）就能发现它与 axis_output 在 shift_en=0 时的行为不一致。

---

#### 2.8 G5 粒度规则未考虑集成验证步骤

**涉及规范**：`CLAUDE.md` G5 任务粒度决策规则

G5 只规定了"一个模块 = 一个 task"，以及何时拆分/合并。但没有规定：
- 多少个模块完成后应插入一次集成验证
- 集成验证 task 的格式是什么

**后果**：7 个模块全部独立完成后才做集成，8 个模块（7子+1顶）中没有一个是"数据通路闭环验证"。如果规则中有"每 3-4 个数据通路模块完成后必须插入一次中间集成验证"，问题会在更早阶段暴露。

---

### P3 — 低优先级

#### 2.9 Handoff 缺少仿真失败上下文

**涉及规范**：`CLAUDE.md` G2 Handoff 决策规则

Handoff 文件记录了 task 状态和关键文件，但没有机制传递"仿真失败的具体调试信息"。当前 handoff 只能说"集成仿真有 260 个失败"，无法传递"DBG_RECV 显示 sg_col=3 而非预期的 0"这类关键线索。下一 session 的 orchestrator 需要从头分析仿真日志。

---

#### 2.10 子 agent 工作产品无强制交叉验证

**涉及规范**：`CLAUDE.md` 合规分层

orchestrator "负责"运行 validate-awp、更新 task_board、创建 session 记录，但**不对子 agent 技术产出的正确性负责**。实际上 orchestrator 也没有能力深度审查 947 行 TB 或 8 个 RTL 模块的正确性。

子 agent 的产出质量完全依赖两个机制：(1) rtl_reviewer 的 L0 审查，(2) tb_verifier 的 L1 仿真。如果这两个机制同时失效（reviewer 没发现计数器缺失，仿真在单帧场景下碰巧通过），缺陷就无阻碍地向下游传播。

---

## 三、修复提案

### 立即修复（当前项目）

| # | 问题 | 修复 | 改动 |
|---|------|------|------|
| F1 | shift_addr_gen 计数器跨帧残留 | 添加 `else begin row_cnt<='0; col_cnt<='0; end` | `rtl/shift_addr_gen.sv` 1 行 |
| F2 | 集成 TB 过度复杂 | 修复 DUT 后重写集成 TB，去掉 pipeline 补偿 hack | `tb/tb_axil_2d_shift.sv` |

### AWP 规范修改

| # | 优先级 | 规范 | 当前 | 改为 | 理由 |
|---|:--:|------|------|------|------|
| R1 | P0 | tb_verifier 禁止修改 RTL | 硬禁止 | **发现 DUT 嫌疑 bug 时允许修改，但需在报告中标注并通知 orchestrator** | 2.1 |
| R2 | P0 | L1 验证级别 | 单一 "仿真验证" | **拆分为 L1a(单元) / L1b(数据通路) / L1c(全系统)** | 2.2 |
| R3 | P1 | G4 失败升级 | 同 agent 重试 3 次 | **第 2 次失败时切换 agent 类型联合调查** | 2.3 |
| R4 | P1 | tb_verifier 模型 | `deepseek-v4-flash` | **集成仿真用 `deepseek-v4-pro`，模块级保持 flash** | 2.4 |
| R5 | P1 | 角色表 | 无集成验证角色 | **新增 `integration_verifier` 角色** | 2.5 |
| R6 | P2 | architecture.md 内容 | 自由格式 | **增加"模块间时序契约"章节** | 2.6 |
| R7 | P2 | review checklist | 6 项 | **增加"同级行为一致性"+"跨帧状态持久性"** | 2.7 |
| R8 | P2 | G5 粒度规则 | 仅模块拆分 | **增加"每 N 个数据通路模块后插入集成验证"** | 2.8 |
| R9 | P3 | task 合同模板 | 无集成维度 | **增加 `integration_scope: module \| datapath \| system`** | 2.8 |
| R10 | P3 | handoff 模板 | 自由文本 | **增加 "Known Simulation Issues" 结构化字段** | 2.9 |

---

## 四、方法论反思

### 4.1 核心矛盾

AWP 的设计哲学是**通过严格的角色分离和 scope 边界来保证工程纪律**——每个 agent 只做自己领域的事，不允许越界。这个设计在文档管理、状态更新、Git 提交等"软性"流程上运作良好。

但在 FPGA 设计的**硬性技术流**（RTL→仿真→综合→上板）中，严格的角色隔离反而制造了**信息断裂面**：

```
[设计缺陷] → [验证 agent 发现异常] → [验证 agent 无权修复]
                                    → [报告给 orchestrator]
                                    → [orchestrator 不懂 RTL 细节]
                                    → [判断为 TB bug]
                                    → [spawn 验证 agent 修 TB]
                                    → [循环]
```

这个断裂面在模块级仿真中被掩盖了（因为单帧场景下 bug 不触发），在集成仿真中才暴露——而此时修复成本（3 个 agent × 120 分钟 + 947 行 TB 膨胀）已经极高。

### 4.2 正确的信息流

```
[设计缺陷] → [验证 agent 发现异常]
           → [验证 agent 允许临时编辑 RTL 做诊断]
           → [确认是 DUT bug → 在仿真报告中标注 + 给出根因分析]
           → [orchestrator 看到报告 → spawn rtl_implementer 修复]
           → [修复完成 → 重新仿真验证]
```

关键改变：(1) 验证 agent 有诊断权限（不只是报告权限），(2) 有一条明确的"验证发现 → 设计修复"闭环路径。

### 4.3 缺陷本应在何时暴露？

在理想流程中，shift_addr_gen 的计数器残留 bug 应该在 **TASK-E001-005 的 L1 仿真**中就暴露——只需在已有的 15 个测试用例中加一个 TC16："连续两帧 NONE 模式，验证第二帧输出正确"。这个测试用例在 626 行的 `tb_shift_addr_gen.sv` 中只需约 20 行代码。

它没能暴露的原因不是 TB 写得不好，而是**测试计划中根本没有"跨帧"这个维度**。这个维度的缺失，根源是 architecture.md 没有定义跨帧行为，导致 tb_verifier 写 TB 时没有依据去设计跨帧测试。

### 4.4 结语

> **角色隔离是双刃剑。它在文档管理上建立秩序，却在技术调试中阻断信息流。FPGA 验证工程师必须有跨越边界诊断设计的权限，否则"仿真发现 bug → 反馈给设计者"这条路径只能是纸面上的空文。**

所有子模块独立验证 100% 通过（1850/1850 断言），却无法组装出一个通过集成测试的系统——这是任何 FPGA 方法论都不应该出现的结果。E001 成功暴露了这一矛盾，这正是它作为测试项目的价值所在。
