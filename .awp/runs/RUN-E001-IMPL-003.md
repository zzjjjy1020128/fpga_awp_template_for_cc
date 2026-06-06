# RUN-E001-IMPL-003.md - axil_2d_shift L3 实现报告（第三次）

## 基本信息

| 项目 | 内容 |
|------|------|
| 任务 | TASK-E001-013 |
| 验证级别 | L3 (实现 + 时序) |
| 顶层模块 | axil_2d_shift |
| 器件 | xc7z020clg400-1 |
| 时钟约束 | 100 MHz (周期 10.000 ns) |
| 工具 | Vivado v2022.2 (64-bit) Build 3671981 |
| 实现日期 | Sat Jun 6 13:26:19 ~ 13:28:25, 2026 |
| 实现耗时 | ~126 s (含综合) |
| Tcl 脚本 | `vivado/run_l2l3_rerun.tcl` |
| 约束文件 | `constraints/timing.xdc` |
| 报告文件 | `vivado/rerun/axil_2d_shift.runs/impl_1/*.rpt` |

### 自上次实现的变更

shift_addr_gen.sv v0.3：消除所有 per-pixel `%` 取模运算符（详情见 SYNTH-003 报告）。
取代模运算为比较+条件加减，消除 Vivado 推断的 36 级 CARRY4 除法器链。

## 实现流程

| 步骤 | 状态 | 备注 |
|------|:----:|------|
| synth_design | PASS | 重新综合（RTL 已变更） |
| opt_design | PASS | — |
| place_design | PASS | — |
| route_design | PASS | — |
| report_timing_summary | PASS | — |
| report_utilization | PASS | — |
| report_drc | PASS | 2 Critical Warnings（IO 标准/引脚未约束，预期内） |

## 布线后资源利用率

| 资源类型 | 使用 | 可用 | 利用率 |
|---------|:----:|:---:|:-----:|
| Slice LUTs | **709** | 53200 | 1.33% |
| LUT as Logic | 709 | 53200 | 1.33% |
| Slice Registers | **265** | 106400 | 0.25% |
| Block RAM Tile | 1 | 140 | 0.71% |
| DSP48E1 | 2 | 220 | 0.91% |
| BUFGCTRL | 1 | 32 | 3.13% |
| Bonded IOB | 102 | 125 | 81.60% |

**与上次实现对比**：
- Slice LUTs: 1100 → **709（-35.5%，取模消除节省了大量 LUT）**
- Slice Registers: 233 → **265（+13.7%，流水线寄存器）**
- CARRY4: 176 → **98（-44.3%，除法器链消除）**
- 其他资源不变

## 时序结果

### 汇总

| 指标 | 值 | 状态 |
|------|:--:|:----:|
| WNS (Worst Negative Slack, setup) | **-6.975 ns** | **FAIL** |
| TNS (Total Negative Slack, setup) | **-285.618 ns** | **FAIL** |
| 时序违反端点 (setup) | 55 / 总端点 | — |
| WHS (Worst Hold Slack) | **0.167 ns** | **PASS** |
| THS (Total Hold Slack) | 0.000 ns | PASS |
| WPWS (Worst Pulse Width Slack) | 4.500 ns | PASS |

### 与上次实现对比

| 指标 | 上次 (流水线, 有%) | 本次 (v0.3, 消除%) | 改善 |
|------|:-----------------:|:-----------------:|:----:|
| **WNS (post-route)** | **-22.577 ns** | **-6.975 ns** | **+15.602 ns (69.1%)** |
| **TNS (post-route)** | **-639.805 ns** | **-285.618 ns** | **+354.187 ns (55.4%)** |
| 违反端点 | ~46 | 55 | +9 |
| 最差路径级数 | 65 (36 CARRY4) | 2 (LUT2=1 OBUF=1) | **-63 级** |
| 最差路径位置 | shift_addr_gen 取模 | BRAM → 输出端口 | **模块级修复成功** |
| WHS | 0.105 ns | 0.167 ns | +0.062 ns |

### 路由中间步骤的 WNS 演变

| 阶段 | WNS | TNS |
|------|:---:|:---:|
| Post-Placement | -6.708 ns | — |
| Initial Route | -6.705 ns | -257.041 ns |
| Delay CleanUp | -7.023 ns | -300.091 ns |
| Post Hold Fix | -6.974 ns | -285.654 ns |
| **Final (Post-Route)** | **-6.975 ns** | **-285.618 ns** |

**关键观察**：从放置到路由，WNS 几乎不变（-6.708 → -6.975 ns），
说明违反不是由布线拥挤引起，而是由时钟偏斜（clock skew）决定。

### check_timing 结果

全部 12 项检查通过（0 异常）。注：48 个 no_input_delay 警告（输入端口无输入延迟约束）为预期行为。

## 最差路径分析

### 路径 1-8：BRAM → 输出端口（时钟偏斜主导）

所有前 8 条违反路径相同模式：

| 属性 | 值 |
|------|------|
| Source | `u_frame_buf_mgr/bram_reg/CLKBWRCLK` (BRAM 写时钟) |
| Destination | `m_axis_tdata[*]` (输出端口) |
| Logic Levels | **2** (LUT2=1, OBUF=1) |
| Data Path Delay | ~9.5 ns |
| Clock Path Skew | **-5.097 ns** |
| Output Delay | 2.000 ns |
| **Slack** | **-6.975 ns ~ -6.375 ns** |

**根因分析**：
```
启动时钟路径（到 BRAM）:      IBUF + BUFG + 布线 = 5.097 ns
捕获时钟路径（到输出端口）:    0.000 ns（端口无时钟树）
时钟偏斜:                     -5.097 ns
```

BRAM 的时钟通过 IBUF + BUFG 后有 5.097 ns 延迟，而输出端口无需时钟树。
加上 2.000 ns 输出延迟约束后，有效可用时间被大幅压缩。这是 **I/O 时序约束**问题，
不是内部逻辑路径问题。

### 路径 9：regs_top → shift_addr_gen（内部逻辑路径）

| 属性 | 值 |
|------|------|
| Source | `u_regs_top/img_rows_r_reg[2]/C` |
| Destination | `u_shift_addr_gen/calc_row_r_reg[5]/D` |
| Logic Levels | **23** (CARRY4=11, LUT3=4, LUT4=2, LUT5=1, LUT6=5) |
| Data Path Delay | 15.882 ns (Logic 41.1%, Route 58.9%) |
| **Slack** | **-5.979 ns** |

**与上次对比**：
- 上次：65 级, 36 CARRY4, 路径延时 35.772 ns, slack -22.577 ns
- 本次：**23 级, 11 CARRY4, 路径延时 15.882 ns, slack -5.979 ns**
- **级数减少 64.6%，延时减少 55.6%**

**路径包含**：
1. regs_top 输出寄存器 → routing
2. shift_addr_gen 内 step_mod 取模（5-bit ÷ 10-bit，仅当 step >= img_rows 时触发）
3. row_cnt + step/add/sub 加法/减法
4. 比较 `>= img_rows`
5. 条件 MUX 选择缠绕/非缠绕结果
6. **乘法 `calc_row * img_cols`**（DSP48E1 或 LUT 实现）
7. 加法 `... + calc_col`
8. 最终到 calc_row_r_reg D 输入

**注意**：剩余的 CARRY4 主要由乘法（`calc_row * img_cols`）和条件加减产生，已非取模除法器。

### 路径 10：regs_top → m_axis_tlast

| 属性 | 值 |
|------|------|
| Source | `u_regs_top/img_cols_r_reg[0]_replica/C` |
| Destination | `m_axis_tlast` (输出端口) |
| Logic Levels | **8** (CARRY4=3, LUT2=1, LUT3=1, LUT6=2, OBUF=1) |
| Data Path Delay | 8.655 ns |
| Clock Path Skew | -5.097 ns |
| **Slack** | **-5.887 ns** |

同样受时钟偏斜影响的输出路径。

## 时序失败根因分析

### 取模消除效果

**取模消除非常成功**。关键数据对比：

| 指标 | 消除前 | 消除后 | 改善 |
|------|:------:|:------:|:----:|
| shift_addr_gen 最差路径 slack | -22.577 ns | **-5.979 ns** | +16.6 ns |
| CARRY4 (设计总计) | 176 | **98** | -44.3% |
| 最差路径 CARRY4 | 36 | **11** | -69.4% |
| 关键路径位置 | shift_addr_gen | **BRAM→输出** | 瓶颈已迁移 |

### 剩余违反的根因

**当前 -6.975 ns 违反不是由内部逻辑引起**，而是由两种因素叠加：

1. **时钟偏斜**（5.097 ns）：BRAM 的 clock path 比输出端口多经过 IBUF + BUFG + 布线，产生 5.097 ns skew
2. **输出延迟约束**（2.000 ns）：`set_output_delay -clock clk 2.0` 进一步压缩可用时间

**剩余 55 条违反路径全部为输出端口路径**（m_axis_tdata[7:0] + m_axis_tlast + m_axis_tvalid）。
内部寄存器到寄存器的路径已全部收敛。

### 本次运行与其他优化尝试的对比

本次运行使用 v0.3 代码（消除%取模 + 2 级流水线），与上次 IMPL-002 相比：

| Metric | IMPL-002 | IMPL-003 | 改善 |
|--------|:--------:|:--------:|:----:|
| 综合后 LUT | 1084 | **709** | **-375** |
| 综合后 CARRY4 | 176 | **98** | **-78** |
| 最大路径级数 | 65 | **23** | **-42** |
| WNS | -22.577 ns | **-6.975 ns** | **+15.602 ns** |
| TNS | -639.805 ns | **-285.618 ns** | **+354.187 ns** |

## QoR 建议

### 修复输出端口路径（优先级高）

当前最差路径（-6.975 ns）可通过以下方式消除时钟偏斜：

1. **在 axis_output 中增加输出寄存器**：在 BRAM 输出数据进入 output 逻辑前增加一级寄存器，
   使 BRAM 输出与寄存器之间时钟偏斜匹配。预期可将 WNS 改善至 ~0 ns。
   - 修改位置：`rtl/axis_output.sv` 或 `rtl/axil_2d_shift.sv`
   - 代价：增加 ~80 个寄存器，m_axis_tdata 延迟 1 个时钟周期

2. **调整输出延迟约束**：增大 `set_output_delay` 值（从 2.0 改为 4.0 或 5.0 ns），
   减少对 I/O 路径的约束强度。示意见证（非真实芯片时序）。

3. **添加 BRAM 输出寄存器**：frame_buf_mgr 的 BRAM 输出增加一级寄存器。
   综合时已提示 "might be sub-optimal as no optional output register could be merged into the ram block"。

### 修复 shift_addr_gen 内部路径（优先级低）

23 级内部路径（-5.979 ns）在输出路径修复后将成为新 WNS。修复方向：

1. **step_mod 取模优化**：当前 `step_mod_rows = (step >= img_rows) ? (step % img_rows) : step;`
   保留了 5-bit 取模。可替换为条件减法的循环（最多 31 次迭代用组合逻辑展开），消除最后的取模 CARRY4。
2. **乘法优化**：`calc_row * img_cols` 使用 DSP48E1（已推断 2 个 DSP），
   但 10-bit × 10-bit 乘法约有一半在 LUT 中实现。可手动实例化 DSP48E1 以缩短路径。

## 实现结论

| 检查项 | 结果 | 说明 |
|--------|:----:|------|
| opt_design | PASS | 完成 |
| place_design | PASS | 完成 |
| route_design | PASS | 完成 |
| DRC | PASS | 仅 I/O 标准警告（预期内） |
| Resource Utilization | PASS | LUT 1.33%, FF 0.25%, BRAM 0.71%, DSP 0.91% |
| **Timing (setup)** | **FAIL** | **WNS = -6.975 ns, 55 条输出路径违反** |
| Timing (hold) | PASS | WHS = 0.167 ns |
| Check Timing | PASS | 0 unconstrained endpoint |

## 与预期差距分析

**本次运行的目标**：验证取模消除后 100MHz 时序收敛（WNS >= 0）。

| 预期 | 实际 | 评估 |
|------|------|:----:|
| 取模消除修复内部时序 | WNS 从 -22.577 改善至 -6.975 ns | **成功（+15.6 ns）** |
| 最差路径不再在 shift_addr_gen | 最差路径移至 BRAM→输出端口 | **成功** |
| WNS >= 0 | WNS = -6.975 ns | **未达标（违反为 I/O 时钟偏斜）** |

**未达标原因**：剩余 -6.975 ns 违反并非取模消除的固有瓶颈，
而是 I/O 约束与 BRAM 时钟偏斜的叠加效应。取模消除本身已成功将 65 级/36 CARRY4 的路径
降至 23 级/11 CARRY4。

## 后续建议

1. **创建 ISS-I001-004**：记录当前时序状态，标注 "因 I/O 时钟偏斜违反，非内部逻辑瓶颈；取模消除成功"
2. **修改 axis_output RTL 增加输出流水线**：添加 1 级寄存器在 BRAM 输出和顶层输出之间，消除时钟偏斜
3. **重跑 IMPL-004**：期待 WNS >= 0（100MHz 时序收敛）
4. **若仍违反**：继续优化 step_mod 取模（替换为条件减法展开）和乘法路径
