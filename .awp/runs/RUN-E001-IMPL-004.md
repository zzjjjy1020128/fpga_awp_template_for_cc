# RUN-E001-IMPL-004.md — axil_2d_shift L3 实现报告（第四次，最终重跑）

## 基本信息

| 项目 | 内容 |
|------|------|
| 任务 | TASK-E001-013 |
| 验证级别 | L3 (实现 + 时序) |
| 顶层模块 | axil_2d_shift |
| 器件 | xc7z020clg400-1 |
| 时钟约束 | 100 MHz (周期 10.000 ns) |
| 工具 | Vivado v2022.2 (64-bit) Build 3671981 |
| 实现日期 | Sat Jun 6 13:40:06 ~ 13:41:13, 2026 |
| 实现耗时 | ~67 s (含综合 ~145 s 总计) |
| Tcl 脚本 | `vivado/run_l2l3_rerun.tcl` |
| 约束文件 | `constraints/timing.xdc` |
| 报告目录 | `vivado/rerun/axil_2d_shift.runs/impl_1/` |
| DCP 文件 | `vivado/rerun/axil_2d_shift.runs/impl_1/axil_2d_shift_routed.dcp` |

### 自上次实现的变更

axis_output.sv：增加 1 级输出寄存器（详见 SYNTH-004 报告）。
目的：消除 BRAM→输出端口的 5.097 ns 时钟偏斜（BRAM clock path 含 IBUF+BUFG
而输出端口无时钟树，导致前次 WNS=-6.975 ns 的根因）。

## 实现流程

| 步骤 | 状态 | 备注 |
|------|:----:|------|
| synth_design | PASS | 重新综合（轴输出寄存器已更改） |
| opt_design | PASS | — |
| place_design | PASS | — |
| route_design | PASS | — |
| report_timing_summary | PASS | — |
| report_utilization | PASS | — |
| report_drc | PASS | 2 Critical Warnings（IO 标准未约束，预期内） |

## 布线后资源利用率

| 资源类型 | 使用 | 可用 | 利用率 |
|---------|:----:|:---:|:-----:|
| Slice LUTs | **711** | 53200 | 1.34% |
| LUT as Logic | 711 | 53200 | 1.34% |
| Slice Registers | **345** | 106400 | 0.32% |
| Block RAM Tile | 1 | 140 | 0.71% |
| DSP48E1 | 2 | 220 | 0.91% |
| BUFGCTRL | 1 | 32 | 3.13% |
| Bonded IOB | 102 | 125 | 81.60% |

**与上次对比**：LUT +2 (711 vs 709)，Registers +80 (345 vs 265，输出寄存器)。

## 时序结果

### 汇总

| 指标 | 本次 (IMPL-004) | 上次 (IMPL-003) | 变化 |
|------|:--------------:|:--------------:|:----:|
| **WNS (setup)** | **-5.990 ns** | **-6.975 ns** | **+0.985 ns** |
| **TNS (setup)** | **-229.115 ns** | **-285.618 ns** | **+56.503 ns** |
| 违反端点 (setup) | **55** | **55** | 0 |
| WHS (hold) | 0.115 ns | 0.167 ns | -0.052 ns |
| THS (hold) | 0.000 ns | 0.000 ns | 0 |
| WPWS | 4.500 ns | 4.500 ns | 0 |

### 各阶段 WNS 演变

| 阶段 | WNS |
|------|:---:|
| Post-synthesis (预估) | 未记录 |
| Post-place | 未记录 |
| Post-route (final) | **-5.990 ns** |

## 最差路径详细分析

### 路径 1（WNS）：regs_top → shift_addr_gen 第一级流水线

| 属性 | 值 |
|------|------|
| Source | `u_regs_top/img_rows_r_reg[3]/C` (FDRE) |
| Destination | `u_shift_addr_gen/calc_row_r_reg[8]/D` (FDCE) |
| Path Type | Setup (reg-to-reg, internal) |
| Logic Levels | **27** (CARRY4=13, LUT3=6, LUT4=2, LUT5=2, LUT6=4) |
| Data Path Delay | **16.046 ns** (logic 43.1%, route 56.9%) |
| Clock Skew | **0.012 ns** (极小 — 同域内部路径) |
| Clock Uncertainty | 0.035 ns |
| **Slack** | **-5.990 ns** |

**路径组成**（从 img_rows_r_reg[3]/Q 到 calc_row_r_reg[8]/D）：

```
img_rows_r_reg[3]/Q
  → step_mod_rows0__9_carry__0_i_9 (LUT5+LUT3)
    → step_mod_rows0__9_carry (CARRY4 ×2)
      → step_mod_rows0__9_carry__1 (CARRY4 ×1)
        → i_carry_i_33 (CARRY4 ×1) [step_mod_row 结果进入 row logic]
          → i_carry_i_28 (CARRY4 ×1)
            → i_carry_i_27__0 (CARRY4 ×1)
              → i_carry_i_16__0 (CARRY4 ×1)
                → i_carry_i_22 (CARRY4 ×1)
                  → i_carry_i_15__0 (CARRY4 ×1)
                    → i_carry_i_10__2 (CARRY4 ×1)
                      → i_carry_i_21__0 (CARRY4 ×1)
                        → calc_row3_inferred__0/i_carry__1 (CARRY4 ×1) [乘法器前置逻辑]
                          → calc_row2_inferred__1/i_carry__0 (CARRY4 ×1)
                            → calc_row_r[8]_i_3 + calc_row_r[8]_i_1 (LUT6 ×2)
                              → calc_row_r_reg[8]/D
```

**根因**：路径从 `img_rows_r_reg` 出发，通过 `step_mod_rows` 计算（含条件 5-bit 除法 `step % img_rows`，仅在 `step >= img_rows` 时触发），然后经过多级 CARRY4 链完成行地址计算（比较+条件加减+乘法前置逻辑），最终到达 `calc_row_r_reg`（流水线第 1 级）。

CARRY4 总数 13 级由三部分叠加：
1. `step_mod_rows` 计算（约 3 级 CARRY4）
2. `row_cnt +/- step_mod_rows` 加法/减法逻辑（约 5 级 CARRY4）
3. `calc_row * img_cols` 乘法前置逻辑（约 5 级 CARRY4）

### 路径 2-10：同类 regs_top→shift_addr_gen 路径

slack 范围 -5.990 ns 至 -5.377 ns，均为 regs_top 寄存器输出到 shift_addr_gen 第一级流水线输入。具体模式：
- `img_rows_r_reg[*]` → `calc_row_r_reg[*]`：slack ≈ -5.99 ~ -5.70 ns（10 条路径）
- `cfg_r_reg[7]` → `calc_col_r_reg[*]`：slack ≈ -5.70 ~ -5.38 ns（10 条路径）

### 路径 11-35：内部寄存器 → AXI-Lite 读数据输出

slack 范围 -4.64 ns 至 -2.13 ns，路径为内部寄存器到 `s_axil_rdata[*]` 输出端口（I/O 延迟 + 时钟偏斜导致）。

### 路径 36-55：输出寄存器 → 顶层端口

| Endpoint | Slack | Logic Levels | 说明 |
|----------|:-----:|:------------:|------|
| m_axis_tdata[7:0] | -2.19 ~ -2.03 ns | 1 | 寄存器→端口，1 级 LUT+OBUF |
| m_axis_tvalid | -2.185 ns | 1 | 同上 |
| m_axis_tlast | -2.027 ns | 1 | 同上 |
| m_axis_tuser | -1.904 ns | 1 | 同上 |

这些都是 reg→port 的 I/O 路径，`set_output_delay -clock clk 2.0` 约束下时钟偏斜导致。

### BRAM→register 路径（新增输出寄存器的效果）

| Source | Destination | Slack | 说明 |
|--------|------------|:-----:|------|
| `bram_reg/CLKBWRCLK` | `m_axis_tdata_reg[*]/D` | **5.062 ~ 5.315 ns** | **PASS** — BRAM→输出寄存器路径 |
| `bram_reg/CLKBWRCLK` | `reg[*]/D` (previous) | **-6.975 ns** (IMPL-003) | 原来 BRAM→端口路径已被寄存器断开 |

**输出寄存器修复成功**：BRAM 到输出寄存器的路径 slack > 5 ns，不再为关键路径。

## check_timing 结果

全部 12 项检查通过。48 个 no_input_delay 警告（未约束输入延迟的输入端口）为预期行为。

## DRC 结果

2 Critical Warnings：
- IO 标准未约束（预期内，本设计为 RTL 验证用，未指定 IOSTANDARD）

## 本次运行与其他运行的对比

| Metric | IMPL-003 (取模消除, 无输出寄存器) | IMPL-004 (取模消除 + 输出寄存器) | 变化 |
|--------|:---------------------------:|:----------------------------:|:----:|
| LUT | 709 | 711 | +2 |
| Register | 265 | **345** | **+80** |
| CARRY4 | 98 | 98 | 0 |
| WNS (setup) | -6.975 ns (BRAM→port) | **-5.990 ns** (regs_top→SAG) | **+0.985 ns** |
| TNS | -285.618 ns | -229.115 ns | +56.503 ns |
| Worst path type | I/O 时钟偏斜 (BRAM→port) | **内部 reg-to-reg** | 瓶颈迁移 |
| Worst path levels | 2 (LUT2+OBUF) | 27 (13 CARRY4) | 路径类型变化 |
| BRAM→reg slack | N/A (直接到端口) | **5.06-5.32 ns PASS** | 修复成功 |

## 时序判定

| 检查项 | 结果 | 说明 |
|--------|:----:|------|
| synth_design | PASS | — |
| opt_design | PASS | — |
| place_design | PASS | — |
| route_design | PASS | — |
| DRC | PASS | 仅 IO 标准警告 |
| Resource Utilization | PASS | LUT 1.34%, FF 0.32%, BRAM 0.71%, DSP 0.91% |
| **Timing (setup)** | **FAIL** | **WNS = -5.990 ns, 55 条路径违反** |
| Timing (hold) | PASS | WHS = 0.115 ns |
| Check Timing | PASS | 0 unconstrained endpoint |

**WNS = -5.990 ns < 0 → 100 MHz 时序未收敛。**

## 根因分析

### 已修复的问题

**输出寄存器（axis_output.sv）—— 修复成功**

原本 BRAM→端口路径（WNS=-6.975 ns）的时钟偏斜已被消除。BRAM 输出现在进入 axis_output 的寄存器（slack 5.06-5.32 ns），寄存器到端口的路径仅有 1 级逻辑（slack -1.9~-2.2 ns，受 I/O 约束限制）。

### 剩余的问题

**regs_top → shift_addr_gen 第一级流水线（WNS=-5.990 ns）**

当输出端口问题被隔离后，真正的内部关键路径暴露出来。该路径从 regs_top 的输出寄存器（img_rows_r_reg）开始，通过 shift_addr_gen 的地址计算组合逻辑（step_mod_rows → add/compare/sub → CASE mux），到达第一级流水线寄存器（calc_row_r_reg）。

虽然 per-pixel 的 `%` 取模运算符已在 v0.3 中消除，但以下组合逻辑仍产生 27 级（13 CARRY4）的路径：

1. **`step_mod_rows` 计算**：`assign step_mod_rows = (step >= img_rows) ? (step % img_rows) : step;` — 保留了 5-bit 条件取模（仅在 step >= img_rows 时触发）。Vivado 仍需推断比较器和条件除法器。
2. **行/列地址计算**：`calc_row = (row_cnt + step_mod_rows >= img_rows) ? (row_cnt + step_mod_rows - img_rows) : (row_cnt + step_mod_rows);` — 加法 + 比较 + 条件减法，约需 5 级 CARRY4。
3. **乘法前置逻辑**：`calc_row * img_cols + calc_col` 虽然是流水线第 2 级之后的路由，但部分乘法控制/解码逻辑被工具前推到第 1 级之前。

## 后续修复方向

### 方案 A：将 step_mod_rows 寄存器化（推荐）

在 shift_addr_gen.sv 中增加一级寄存器锁存 step_mod_rows，将其与主计算路径分离：

```verilog
// 在 shift_addr_gen 中增加
logic [9:0] step_mod_rows_r;
always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) step_mod_rows_r <= '0;
    else if (shift_en && proceed) step_mod_rows_r <= step_mod_rows;
    else if (!shift_en) step_mod_rows_r <= '0;
end
```

将 `step_mod_rows` 替换为 `step_mod_rows_r` 用于计算。由于 step_mod_rows 只在配置寄存器写入时变化（非 per-pixel），寄存器化不会影响数据正确性，但可将路径拆分为 ~10 级 + ~17 级。

预期改善：WNS 从 -5.990 ns 提升至 ~+1~3 ns（100 MHz 可收敛）。

### 方案 B：完全消除 step_mod_rows 的 % 运算符

`step_mod_rows = (step >= img_rows) ? (step % img_rows) : step;` 中的 `%` 只在 `step >= img_rows` 时触发。可将取模替换为条件减法链：

```verilog
// step <= 31 (5-bit), img_rows >= 1
logic [9:0] step_mod_rows;
always_comb begin
    if (step >= img_rows) begin
        // 重复减法展开（最多 31 次迭代）
        if (step - img_rows >= img_rows)
            step_mod_rows = step - 2*img_rows;
        else
            step_mod_rows = step - img_rows;
        // 更激进的展开：最多 5 次 31-step/img_rows
    end else begin
        step_mod_rows = step;
    end
end
```

预期：消除 CARRY4 除法器，进一步减少 3-5 级逻辑。

### 方案 C：将 regs_top 输出与 SAG 输入之间的路径增加寄存器

在 axil_2d_shift.sv 顶层中，增加一级寄存器缓冲 img_rows/img_cols 的扇出（目前 fo=29）。

预期：减少绕线延迟（当前 route 占比 56.9%）。

## 结论

| 检查项 | 结果 |
|--------|:----:|
| 输出寄存器修复 BRAM→port 路径 | **成功** (slack 从 -6.975 改善至 5.062 ns) |
| regs_top→shift_addr_gen 内部路径 | **未达标** (WNS = -5.990 ns, 27 级逻辑) |
| 100 MHz 时序收敛 | **FAIL** (WNS = -5.990 ns) |
| TASK-E001-003 (ISS) | 更新：收斂进展但未完全解决 |
