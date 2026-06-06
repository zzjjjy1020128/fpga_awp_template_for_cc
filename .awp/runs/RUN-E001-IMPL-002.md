# RUN-E001-IMPL-002.md - axil_2d_shift L3 实现报告（第二次）

## 基本信息

| 项目 | 内容 |
|------|------|
| 任务 | TASK-E001-013 |
| 验证级别 | L3 (实现 + 时序) |
| 顶层模块 | axil_2d_shift |
| 器件 | xc7z020clg400-1 |
| 时钟约束 | 100 MHz (周期 10.000 ns) |
| 工具 | Vivado v2022.2 (64-bit) Build 3671981 |
| 实现日期 | Sat Jun 6 11:58:15 ~ 11:59:21, 2026 |
| 实现耗时 | ~66 s |
| 工程文件 | `vivado/axil_2d_shift.xpr` |
| Tcl 脚本 | `vivado/run_full_flow.tcl` |

### 自上次实现的变更

shift_addr_gen 插入 2 级流水线（见 RUN-E001-SYNTH-002.md 详细说明）。

## 实现流程

| 步骤 | 状态 | 备注 |
|------|:----:|------|
| synth_design | PASS | 重新综合（RTL 已变更） |
| opt_design | PASS | — |
| place_design | PASS | — |
| route_design | PASS | — |
| report_timing_summary | PASS | — |
| report_utilization | PASS | — |
| report_drc | PASS | 0 violations |

## 布线后资源利用率

| 资源类型 | 使用 | 可用 | 利用率 |
|---------|:----:|:---:|:-----:|
| Slice LUTs | 1100 | 53200 | 2.07% |
| LUT as Logic | 1100 | 53200 | 2.07% |
| Slice Registers | 233 | 106400 | 0.22% |
| Block RAM Tile | 1 | 140 | 0.71% |
| DSP48E1 | 2 | 220 | 0.91% |
| BUFGCTRL | 1 | 32 | 3.13% |
| Bonded IOB | 102 | 125 | 81.60% |

**与上次实现对比**：
- Slice LUTs: 1102 → 1100（-2）
- Slice Registers: 197 → **233（+36，流水线寄存器）**
- 其他资源不变

## 时序结果

### 汇总

| 指标 | 值 | 状态 |
|------|:--:|:----:|
| WNS (Worst Negative Slack, setup) | **-22.577 ns** | **FAIL** |
| TNS (Total Negative Slack, setup) | **-639.805 ns** | **FAIL** |
| 时序违反端点 (setup) | 待 report_timing_summary 确认 | — |
| WHS (Worst Hold Slack) | 0.105 ns | PASS |
| THS (Total Hold Slack) | 0.000 ns | PASS |

### 与上次实现对比

| 指标 | 上次 (无流水线) | 本次 (2 级流水线) | 改善 |
|------|:--------------:|:----------------:|:----:|
| WNS (post-synth) | -31.682 ns | -25.908 ns | +5.774 ns (18.2%) |
| WNS (post-route) | **-28.321 ns** | **-22.577 ns** | **+5.744 ns (20.3%)** |
| TNS (post-route) | -565.214 ns | -639.805 ns | -74.591 ns (恶化) |
| WHS | 0.138 ns | 0.105 ns | -0.033 ns |
| Logic Levels (post-synth) | 64 | 65 | +1 |

### Post-Placement 时序

placement 完成后 WNS=-19.856 ns，比路由后略好（路由增加了走线延迟）。

### 路由中间步骤的 WNS 演变

| 阶段 | WNS | TNS |
|------|:---:|:---:|
| Post-Placement | -19.856 ns | — |
| Initial Route | -19.290 ns | -552.104 ns |
| Delay CleanUp | -22.577 ns | -658.838 ns |
| Post Hold Fix | -22.577 ns | -639.805 ns |
| **Final (Post-Route)** | **-22.577 ns** | **-639.805 ns** |

### check_timing 结果

全部 12 项检查通过（0 异常）。

## 最差 Setup 路径分析

Post-synthesis 最差路径：
- 起点: `u_regs_top/img_cols_r_reg[3]/C` (FDRE)
- 终点: `u_shift_addr_gen/calc_col_r_reg[9]/D` (FDCE)
- 路径延迟: 35.772 ns (Logic 43.85%, Route 56.15%)
- 逻辑级数: 65 级 (CARRY4=36, LUT2=2, LUT3=12, LUT5=2, LUT6=13)

**关键发现**：终点不是 BRAM 地址，而是 shift_addr_gen 的**第 1 级流水线寄存器** `calc_col_r_reg`。说明最差路径位于 CASE 取模运算到第 1 级寄存器的组合逻辑段，而非第 1 级到第 2 级之间的乘加运算。

## 时序失败根因分析

### 2 级流水线为什么不够

**流水线位置错误**：当前流水线划分为：
- 第 1 级：CASE 输出后 → 寄存器 `calc_row_r/calc_col_r/is_zero_r`
- 第 2 级：乘加 `read_addr = calc_row * img_cols + calc_col` 后 → 寄存器 `read_addr/zero_fill`

但最差路径为：
```
regs_top/img_cols_r_reg → shift_addr_gen CASE (取模运算 `(col_cnt + step) % img_cols`) → calc_col_r_reg
```

这条路径包含 **65 级逻辑（36 个 CARRY4）**，跨越了：
1. regs_top 输出 buffer（少量 LUT）
2. shift_addr_gen 内 col_cnt 加法（`col_cnt + step` 的 CARRY4 链）
3. `% img_cols` 取模运算的 CARRY4 链（最消耗级数）
4. 越界比较 `>= img_cols`（额外 CARRY4）
5. 最终 mux 到 `calc_col` → `calc_col_r_reg` D 输入

流线线未能打断**取模运算内部的 CARRY4 链**。

### 与上次对比

| 方面 | 上次 | 本次 | 分析 |
|------|:----:|:----:|:----:|
| WNS改善 | 基准 | +5.744 ns (20.3%) | 有改善但不够 |
| 改善来源 | — | 乘加路径被分流 | 第2级流水线消除了乘加路径的违例 |
| 仍违反路径 | — | `regs_top→calc_col_r` | CASE取模成为新关键路径 |
| 逻辑级数 | 54 | 65 | 工具优化策略变化导致统计差异 |

## QoR 建议

1. **取模运算流水线化**：将 `(row_cnt + step) % img_rows` 等取模运算拆分为多周期操作：
   - 周期 1: row_cnt + step（或 row_cnt - step）
   - 周期 2: 与 img_rows 比较决定是否减去 img_rows（实现取模）
   - 使每级 CARRY4 链控制在 15-20 级以内

2. **预计算 img_rows/img_cols 倒数**：如果 img_rows/img_cols 固定（配置寄存器写入后不变），在配置更新时预计算相关值。

3. **地址产生提前一拍**：在帧开始前提前计算所有地址存入 BRAM，读取时直接查表。

4. **降低时钟频率**：当前最差路径延迟 35.772 ns（post-synth），需要约 28 MHz。将约束改为 25-30 MHz 可通过时序。

## 实现结论

| 检查项 | 结果 | 说明 |
|--------|:----:|------|
| opt_design | PASS | 完成 |
| place_design | PASS | 完成 |
| route_design | PASS | 完成 |
| DRC | PASS | 0 违反 |
| Resource Utilization | PASS | LUT 2.07%, FF 0.22%, BRAM 0.71%, DSP 0.91% |
| **Timing (setup)** | **FAIL** | **WNS = -22.577 ns, 约束 100 MHz** |
| Timing (hold) | PASS | WHS = 0.105 ns |
| Check Timing | PASS | 0 unconstrained endpoint |

## 后续建议

1. **升级 ISS-E001-003**：记录 round 3 失败，添加"取模运算内流水线"为推荐方案
2. **回退 TASK-E001-005 给 rtl_implementer**：需要进一步修改 shift_addr_gen，在取模运算内部插入流水线寄存器
3. **重新设计方案**：考虑将模运算替换为减法比较循环（类似除法器的实现），用状态机在多周期完成取模
4. **调整时钟约束为临时权宜方案**：将时钟改为 25 MHz (40 ns 周期) 可立即通过时序
