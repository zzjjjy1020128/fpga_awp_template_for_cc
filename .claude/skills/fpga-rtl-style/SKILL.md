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

### 工具检查
- [ ] 条件允许时运行 Verible linter：`verible-verilog-lint <file>.sv`
- [ ] 条件允许时运行 iverilog 编译检查：`iverilog -t null -g2012 <file>.sv`

## 输出格式
- `.awp/reviews/REV-{exp}-{task_seq}-STYLE-{seq}.md`
- 包含：违规项数、严重等级（BLOCK/WARN/INFO）、修复建议

## 语言规范
- 审查报告：zh
- RTL 标识符：en
