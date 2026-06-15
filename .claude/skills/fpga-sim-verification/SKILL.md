---
skill_id: SKILL-FPGA-SIM-VERIFICATION
name: fpga-sim-verification
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-004
  - SRC-FPGA-005
  - SRC-FPGA-006
validated_in_projects: []
last_reviewed: "2026-06-10"
owner: human_owner
---

# 仿真验证方法论（L1a/L1b/L1c）

## 适用场景
- 编写模块级（L1a）、数据通路闭环（L1b）、全系统（L1c）testbench
- 设计 scoreboard、golden model、random stimulus
- 判定仿真是否"真正通过"（非波形看起来正确）

## Testbench 架构模式

### 组件
- [ ] **DUT 实例化**：正确连接所有端口，未连接端口显式接地/上拉
- [ ] **Clock generator**：`always #(CLK_PERIOD/2) clk = ~clk`
- [ ] **Reset sequence**：上电后至少 10 周期复位，复位释放后至少 5 周期等待
- [ ] **BFM (Bus Functional Model)**：AXI-Lite master、AXIS source/sink
- [ ] **Scoreboard**：期望值 vs 实际值比对
- [ ] **Monitor**：被动采样总线事务，不驱动信号

### Golden Model
- [ ] 对数据通路模块（如 2D shift、DMA），创建软件 reference model
- [ ] 同一输入激励同时送入 DUT 和 golden model
- [ ] Scoreboard 逐周期/逐帧比对 DUT 输出与 golden model 输出

### Random Stimulus
- [ ] 对 AXI-Stream source：随机化 `tready` backpressure（概率 20%-80%）
- [ ] 对配置接口：随机化寄存器写入顺序和值
- [ ] 对帧尺寸：随机化在 [1, MAX_SIZE] 范围
- [ ] 对延迟：随机化事务间隔（0-20 周期）

## 仿真通过标准

### L1a（模块级）
- [ ] 所有定向测试 case 通过
- [ ] reset + basic + boundary + backpressure 全部覆盖
- [ ] 0 个 `$error` / `$fatal`
- [ ] 波形关键信号在预期范围内

### L1b（数据通路闭环）
- [ ] ≥3 帧连续传输无错位
- [ ] 跨帧状态无残留（帧 2 输出不含帧 1 数据）
- [ ] backpressure 随机化下数据完整
- [ ] Scoreboard 全部比对通过

### L1c（全系统）
- [ ] 所有接口同时工作无死锁
- [ ] 配置通道和数据通路并发操作正确
- [ ] ≥10 帧随机参数组合通过
- [ ] Golden model 比对 100% 一致

### R3: TB 必须与 DUT 的输出寄存器级数同步

当 DUT 的输出端口经过寄存器（如为了时序闭合添加的 output register），testbench 的采样时序必须相应延迟。否则 TB 会在错误的时间窗口检查信号，导致系统性 FAIL。

**违反案例（E001）**：`tb_axis_output.sv` 假设 `m_axis_tvalid/tdata/tuser/tlast` 是组合输出（在 `#1` 后立即检查），但 `axis_output.sv` 在输出端加了 1 级寄存器（断开 BRAM→port 长路径）。TB 应在 `@(posedge clk)` 后检查（而非之前），以等待寄存器更新。

**正确检查模式**（针对有输出寄存器的 DUT）：
```verilog
// 错误：在 posedge 前检查（期望组合输出）
drive_beat(data, 0, 1);
#1;
check("tdata", m_axis_tdata == expected);  // 看到的是旧值！
@(posedge clk);

// 正确：在 posedge 后检查（等待寄存器更新）
drive_beat(data, 0, 1);
@(posedge clk);
#1;
check("tdata", m_axis_tdata == expected);  // 看到已更新的值
```

**禁止行为**：
- DUT 增加输出寄存器后不同步更新 TB —— 会导致 TB 失效（系统性假阳性或假阴性）
- 在 TB 注释中声称信号是"组合输出"但实际上 DUT 已改为寄存器输出

## 运行命令（iverilog）
```bash
iverilog -g2012 -o simv tb/<tb_file>.sv rtl/*.sv
vvp simv
# 检查 exit code 和 stdout 中的 PASS/FAIL
```

## 反模式（禁止事项）

### ❌ "仿真失败了，在 TB 里改一下预期值应该就能过"
```
这是最危险的模式。在 TB 中 workaround 疑似 DUT bug 会导致：
- bug 被掩盖到集成阶段才暴露（成本 10x）
- TB 变成"验证 DUT 的错误行为符合预期"而非"验证 DUT 正确"
- 后续修改 RTL 时 TB 产生假阳性
```
**正解**：仿真失败 → 先确认是 DUT bug 还是 TB bug → DUT bug 修 RTL，TB bug 修 TB。
参考 `fpga-integration-failure-debug`。

### ❌ "DUT 加了输出寄存器，TB 不用改"
```
DUT 输出端增加寄存器（如为了时序闭合）后，输出信号延迟 1 拍。
TB 如果在错误的时间窗口采样 → 系统性 FAIL（假阳性）或 PASS（假阴性）。
```
**正解**：DUT 输出延迟变化 → 同步更新 TB 的采样时序。
见本 skill §"R3: TB 必须与 DUT 的输出寄存器级数同步"。

### ❌ "用 $display 看结果就够了，不需要 scoreboard"
```
$display 在波形窗口和 log 中容易被淹没。长仿真中几百行 display，
眼睛不可能逐行比对正确性。缺少自动化判定 = 无法可靠地检测退化。
```
**正解**：scoreboard 自动比对 `expected == actual`，$error/$fatal 标注失败。

### ❌ "先跑 1 帧看看，能过就算 pass"
```
单帧通过 ≠ 模块正确。最常见的 bug：连续帧间状态残留、
backpressure 下数据处理错位、配置动态切换后状态混乱。
```
**正解**：≥3 帧连续 + random backpressure + 配置切换 + 边界尺寸。

### ❌ "Golden model 太复杂，不需要"
```
对于数据通路模块（shift、DMA、filter），没有 golden model 就无法
可靠验证正确性。肉眼比对输入输出 = 发现不了系统性偏移和细微错误。
```
**正解**：至少对数据通路模块创建软件 reference model（Python/C）。

## 相关 Skills

- `fpga-module-owner-l1a` — L1a 设计流程和 testbench checklist
- `fpga-integration-failure-debug` — 仿真失败时的系统化调试
- `fpga-l1b-datapath-verify` — 数据通路闭环验证方法
- `fpga-formal-sanity` — 控制 FSM/握手协议的轻量形式验证
- `fpga-axis-review` / `fpga-axi-lite-review` — 接口协议级测试要求
- `fpga-iteration-economics` — 理解仿真 vs 综合的成本差异

## 输出格式
- `.awp/runs/RUN-{exp}-SIM-{seq}.md`
- 包含：测试 case 列表、每个 case 的 PASS/FAIL、波形路径、未覆盖项
