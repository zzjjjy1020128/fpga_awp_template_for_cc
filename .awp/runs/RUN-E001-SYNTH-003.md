# RUN-E001-SYNTH-003.md - axil_2d_shift L2 综合报告（第三次）

## 基本信息

| 项目 | 内容 |
|------|------|
| 任务 | TASK-E001-012 |
| 验证级别 | L2 (综合) |
| 顶层模块 | axil_2d_shift |
| 器件 | xc7z020clg400-1 |
| 时钟约束 | 100 MHz (周期 10.000 ns) |
| 综合工具 | Vivado v2022.2 (64-bit) Build 3671981 |
| 综合日期 | Sat Jun 6 13:24:46 ~ 13:26:19, 2026 |
| 综合耗时 | ~93 s |
| Tcl 脚本 | `vivado/run_l2l3_rerun.tcl` |
| 约束文件 | `constraints/timing.xdc` |

### 自上次综合的变更

shift_addr_gen.sv v0.3：消除所有 per-pixel `%` 取模运算符，替换为比较+条件加减：
- `(row + step) % img_rows` → `(row + step >= img_rows) ? (row + step - img_rows) : (row + step)`
- `(col + step) % img_cols` → `(col + step >= img_cols) ? (col + step - img_cols) : (col + step)`
- step_mod 路径仅保留 5-bit `%`（step 最大 31），不构成关键路径

## 综合状态

**PASS** — `synth_design completed successfully`

- 0 Errors
- 0 Critical Warnings
- 14 Warnings (含 Synth 信息类警告)
- 14 Infos

## 资源利用率

| 资源类型 | 本次 (v0.3) | 上次 (流水线) | 变化 |
|---------|:-----------:|:------------:|:----:|
| Slice LUTs | **709** | 1084 | **-375 (-34.6%)** |
| LUT as Logic | 709 | 1084 | -375 |
| Slice Registers | **265** | 233 | **+32 (+13.7%)** |
| Block RAM Tile | 1 | 1 | 0 |
| DSP48E1 | 2 | 2 | 0 |
| BUFGCTRL | 1 | 1 | 0 |
| Bonded IOB | 102 | 102 | 0 |

**LUT 减少分析**：LUT 从 1084 降至 709（-34.6%）。取模运算符消耗大量 LUT 用于除法器的 CARRY4 链逻辑，
替换为比较+条件加减后，每个方向的 CARRY4 链从 10-bit 除法器（约 10-15 CARRY4）降至加法+比较+条件MUX（约 5-6 CARRY4）。

**寄存器增加分析**：Registers 从 233 增至 265（+13.7%）。v0.3 在 shift_addr_gen 中增加了 2 级流水线
（calc_row_r/calc_col_r 各 10-bit，is_zero_r 1-bit，pipe_valid_d 2-bit = 23 个寄存器），其余增加来自工具优化。

### Cell 详细统计

| Cell 类型 | 数量 |
|----------|:----:|
| BUFG | 1 |
| CARRY4 | **98**（上次 176，-44.3%） |
| DSP48E1 | 2 |
| FDCE (异步清零) | 98 |
| FDRE (同步使能) | 162 |
| FDSE (同步置位) | 5 |
| IBUF | 49 |
| OBUF | 53 |
| LUT1 | 17 |
| LUT2 | 114 |
| LUT3 | 172 |
| LUT4 | 179 |
| LUT5 | 87 |
| LUT6 | 265 |
| RAMB36E1 | 1 |

**CARRY4 大幅减少**：从 176 降至 98（-44.3%）。取模运算符被消除后，对应的除法器 CARRY4 链
不再被推断，剩余的 CARRY4 主要用于加法/比较/减法/乘法运算。

## 时序预估（综合后，未做物理优化）

| 指标 | 值 | 状态 |
|------|:--:|:----:|
| WNS (综合后预估) | 未单独记录（见 IMPL-003 详细数据） | — |
| WHS | 未单独记录 | — |

**注**：本次综合作为全流程的一部分，未单独提取综合后时序数据。综合后时序以实现后（post-route）数据为准。

## 综合结论

| 检查项 | 结果 | 说明 |
|--------|:----:|------|
| Synthesis (synth_design) | **PASS** | 综合完成，0 error, 0 critical warning |
| Resource Utilization | PASS | LUT 1.33%, FF 0.25%, BRAM 0.71%, DSP 0.91% |
| Check Timing | PASS | 0 unconstrained endpoint, 0 loop |

## 与上次综合对比

| 指标 | 上次 (2 级流水线, 有%运算) | 本次 (v0.3, 消除%) | 改善 |
|------|:------------------------:|:-----------------:|:----:|
| LUT | 1084 | **709** | -375 (-34.6%) |
| CARRY4 | 176 | **98** | -78 (-44.3%) |
| Register | 233 | 265 | +32 (流水线) |
| 最差路径级数 (post-synth) | 65 (36 CARRY4) | 23 (11 CARRY4) | **-42 级** |
