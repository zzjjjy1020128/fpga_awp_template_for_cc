# RUN-E001-SYNTH-002.md - axil_2d_shift L2 综合报告（第二次）

## 基本信息

| 项目 | 内容 |
|------|------|
| 任务 | TASK-E001-012 |
| 验证级别 | L2 (综合) |
| 顶层模块 | axil_2d_shift |
| 器件 | xc7z020clg400-1 |
| 时钟约束 | 100 MHz (周期 10.000 ns) |
| 综合工具 | Vivado v2022.2 (64-bit) Build 3671981 |
| 综合日期 | Sat Jun 6 11:57:20 ~ 11:58:15, 2026 |
| 综合耗时 | ~55 s |
| 工程文件 | `vivado/axil_2d_shift.xpr` |
| 约束文件 | `constraints/timing.xdc` |
| Tcl 脚本 | `vivado/run_full_flow.tcl` |

### 自上次综合的变更

shift_addr_gen 中插入了 2 级流水线：
- 第 1 级：在 CASE 输出后寄存 calc_row/calc_col/is_zero
- 第 2 级：在乘加运算后寄存 read_addr/zero_fill

## 综合状态

**PASS** — `synth_design completed successfully`

- 0 Errors
- 0 Critical Warnings
- 14 Warnings (含 Synth 信息类警告)
- 14 Infos

## 资源利用率

| 资源类型 | 本次 | 上次 | 变化 |
|---------|:----:|:----:|:----:|
| Slice LUTs | 1084 | 1086 | -2 |
| LUT as Logic | 1084 | 1086 | -2 |
| Slice Registers | **233** | 197 | **+36** |
| Block RAM Tile | 1 | 1 | 0 |
| DSP48E1 | 2 | 2 | 0 |
| BUFGCTRL | 1 | 1 | 0 |
| Bonded IOB | 102 | 102 | 0 |

**寄存器增加分析**：Slice Registers 从 197 增加到 233，增长 +36（约 18.3%）。
- shift_addr_gen 新增流水线寄存器：calc_row_r (10), calc_col_r (10), is_zero_r (1), pipe_valid_d (2) = 23 个
- 其余 13 个寄存器增长来自综合工具优化（冗余寄存器合并/重组）

### Cell 详细统计

| Cell 类型 | 数量 |
|----------|:----:|
| BUFG | 1 |
| CARRY4 | 176 |
| DSP48E1 | 2 |
| FDCE (异步清零) | 68 |
| FDRE (同步使能) | 163 |
| FDSE (同步置位) | 2 |
| IBUF | 49 |
| OBUF | 53 |
| LUT1 | 16 |
| LUT2 | 140 |
| LUT3 | 460 |
| LUT4 | 143 |
| LUT5 | 148 |
| LUT6 | 260 |
| RAMB36E1 | 1 |

## 时序预估（综合后，未做物理优化）

| 指标 | 值 | 状态 |
|------|:--:|:----:|
| WNS (Worst Negative Slack) | **-25.908 ns** | **FAIL** |
| TNS (Total Negative Slack) | **-513.596 ns** | **FAIL** |
| 时序违反端点 | 46 / 497 | — |
| WHS (Worst Hold Slack) | 0.132 ns | PASS |
| THS (Total Hold Slack) | 0.000 ns | PASS |
| WPWS (Worst Pulse Width Slack) | 4.500 ns | PASS |
| TPWS (Total Pulse Width Slack) | 0.000 ns | PASS |

### 与上次综合对比

| 指标 | 上次 (无流水线) | 本次 (2 级流水线) | 改善 |
|------|:--------------:|:----------------:|:----:|
| WNS | -31.682 ns | **-25.908 ns** | +5.774 ns (18.2%) |
| TNS | -398.678 ns | -513.596 ns | -114.918 ns (恶化) |
| Failing Endpoints | 38 | 46 | +8 |
| Logic Levels (worst) | 64 | 65 | +1 |

### 最差 Setup 路径

- 起点: `u_regs_top/img_cols_r_reg[3]/C` (FDRE, regs_top 模块)
- 终点: `u_shift_addr_gen/calc_col_r_reg[9]/D` (FDCE, shift_addr_gen 模块)
- 路径延迟: 35.772 ns (Logic 43.85%, Route 56.15%)
- 逻辑级数: **65 级** (CARRY4=36, LUT2=2, LUT3=12, LUT5=2, LUT6=13)
- Slack: **-25.908 ns**

### 最差路径分析

关键路径从 `regs_top/img_cols_r_reg` 经过 shift_addr_gen 的 CASE 语句（取模运算 `(col_cnt + step) % img_cols`）到第 1 级流水线寄存器 `calc_col_r_reg`。

**流水线未解决根因**：2 级流水线寄存器位于 CASE 输出之后，但 CARRY4 链密集型取模运算在 CASE 内部，路径为 `regs_top → CASE 取模逻辑 → calc_col_r_reg`。第 1 级流水线未能在取模运算中间打断 CARRY4 链。

## 综合结论

| 检查项 | 结果 | 说明 |
|--------|:----:|------|
| Synthesis (synth_design) | **PASS** | 综合完成，0 error, 0 critical warning |
| Resource Utilization | PASS | LUT 2.04%, FF 0.22%, BRAM 0.71%, DSP 0.91% |
| Timing (post-synth) | **FAIL** | WNS = -25.908 ns，65 级逻辑 |
| Check Timing | PASS | 0 unconstrained endpoint, 0 loop |

## 与预期差距分析

预设流水线应将 54 级逻辑拆分为 30+级 + 15+级，但实际最差路径仍为 65 级。原因：
1. **CASE 内部取模运算的 CARRY4 链是主瓶颈**。流水线第 1 级在 CASE 输出之后，但 CARRY4 链在 CASE 内部 (`calc_col = (col_cnt + step) % img_cols`)。
2. **img_cols/img_rows 来自 regs_top 全局寄存器**，到 shift_addr_gen CASE 逻辑的距离和扇出增加了布线延迟。
3. **补零模式的越界比较也贡献 CARRY4 链**（`col_cnt + step >= img_cols`）。

## 修复方向

1. **将流水线插入取模运算内部**：将 `(col_cnt + step) % img_cols` 拆为多周期计算（先加再比较取模）
2. **使用 BRAM 输出寄存器**：frame_buf_mgr BRAM 输出增加一级流水线
3. **采用查找表取代实时取模**：如果 img_cols 固定较小（<=64），可用预先计算的映射表
4. **放宽时钟频率**：当前路径延迟 35.772 ns，需要约 28 MHz
