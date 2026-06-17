---
skill_id: SKILL-FPGA-RTL-STYLE
name: fpga-rtl-style
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-002
  - SRC-FPGA-003
validated_in_projects: []
last_reviewed: "2026-06-10"
owner: human_owner
---

# RTL 编码风格

## 适用场景
- 新建 RTL 模块时作为编码规范参考
- L0 静态审查时检查风格合规性
- 多人/多 agent 协作时统一代码风格

## 输入文件
- `rtl/*.sv` / `rtl/*.v` — 待检查的 RTL 文件

## 风格检查清单

### 命名
- [ ] 模块名、文件名一致（`module foo` ↔ `foo.sv`）
- [ ] 信号名 lowercase_snake_case，低电平有效用 `_n` 后缀
- [ ] 参数名 UPPER_SNAKE_CASE（`localparam`/`parameter`）
- [ ] 时钟信号命名为 `clk`，复位命名为 `rst_n`（异步）或 `rst`（同步）
- [ ] FSM 状态使用 `typedef enum` 或 `localparam`，不用裸 magic number
- [ ] AXI 接口信号命名遵循 ARM 前缀约定（`s_axis_*`, `m_axi_*`, `s_axil_*`）

### 可综合语法
- [ ] 组合逻辑使用 `always_comb`（非 `always @*`）
- [ ] 时序逻辑使用 `always_ff @(posedge clk ...)`
- [ ] 无 `initial` / `#delay` / `$display` 在可综合模块中
- [ ] 无异步复位 + 异步置位混用
- [ ] `case` 语句有 `default`（避免隐式 latch）
- [ ] 阻塞赋值 `=` 在 `always_comb`，非阻塞 `<=` 在 `always_ff`

### 结构
- [ ] 输出寄存器化（reg out，避免组合输出毛刺）
- [ ] 无组合逻辑环路（`a = f(b), b = f(a)`）
- [ ] 参数化 bit 宽度，无硬编码 magic number
- [ ] 模块端口按功能分组（clk/rst → config → data in → data out → status）
- [ ] 避免深度嵌套（> 3 级 if-else）

### 跨模块握手：禁止自清除脉冲

模块间 1 周期脉冲握手（如 `capture_done` → FSM 状态转移）中，生产者在同一 `always_ff` 内 self-clear + set 会导致消费者因 NBA 时序错过脉冲。

**违反案例（E001）**：`axis_input` 的 `capture_done` 自清除 → `ctrl_fsm` 永远卡在 CAPTURE。

```verilog
// 错误：自清除脉冲。消费者在同一 posedge 采样到旧值 0
always_ff @(posedge clk) begin
    done <= 1'b0;          // 自清除
    if (condition) done <= 1'b1;  // 脉冲——消费者可能看不到
end

// 正确：保持高电平直到消费者确认
always_ff @(posedge clk) begin
    if (!enable)     done <= 1'b0;  // 消费者拉低 enable 时清除
    else if (condition) done <= 1'b1;
end
```

- [ ] 跨模块握手脉冲不由生产者自清除，由消费者清除
- [ ] 需要 1 周期脉冲时，消费者用两级寄存器同步后再做边沿检测

### 工具检查
- [ ] 条件允许时运行 Verible linter：`verible-verilog-lint <file>.sv`
- [ ] 条件允许时运行 iverilog 编译检查：`iverilog -t null -g2012 <file>.sv`

## 输出格式
- `.awp/reviews/REV-{exp}-{task_seq}-STYLE-{seq}.md`
- 包含：违规项数、严重等级（BLOCK/WARN/INFO）、修复建议

## 相关 Skills

- `fpga-rtl-review` — L0 审查（风格检查是审查的一部分）
- `fpga-module-owner-l1a` — 模块设计流程（风格应用于设计阶段）
- `fpga-sim-verification` — TB 编写规范
- `fpga-cdc-review` — CDC 编码规范（同步器、复位桥）

## 语言规范
- 审查报告：zh
- RTL 标识符：en
