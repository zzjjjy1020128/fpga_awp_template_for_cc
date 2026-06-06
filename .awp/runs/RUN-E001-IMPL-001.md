# RUN-E001-IMPL-001.md - axil_2d_shift L3 实现报告

## 基本信息

| 项目 | 内容 |
|------|------|
| 任务 | TASK-E001-013 |
| 验证级别 | L3 (实现 + 时序) |
| 顶层模块 | axil_2d_shift |
| 器件 | xc7z020clg400-1 |
| 时钟约束 | 100 MHz (周期 10.000 ns) |
| 工具 | Vivado v2022.2 (64-bit) Build 3671981 |
| 实现日期 | Sat Jun 6 10:05:40 ~ 10:06:27, 2026 |
| 实现耗时 | 47 s |
| 工程文件 | `vivado/axil_2d_shift.xpr` |
| 综合 DCP | `vivado/axil_2d_shift.runs/synth_1/axil_2d_shift.dcp` |
| 布线后 DCP | `vivado/axil_2d_shift.runs/impl_1/axil_2d_shift_routed.dcp` |
| 实现 Tcl | `vivado/run_implementation.tcl` |

## 实现流程

| 步骤 | 状态 |
|------|:----:|
| opt_design | PASS |
| place_design | PASS |
| route_design | PASS |
| report_timing_summary | PASS |
| report_utilization | PASS |
| report_drc | PASS (0 violations) |

## 布线后资源利用率

| 资源类型 | 使用 | 可用 | 利用率 |
|---------|:----:|:---:|:-----:|
| Slice LUTs | 1102 | 53200 | 2.07% |
| LUT as Logic | 1102 | 53200 | 2.07% |
| LUT as Memory | 0 | 17400 | 0.00% |
| Slice Registers | 197 | 106400 | 0.19% |
| Register as Flip Flop | 197 | 106400 | 0.19% |
| F7 Muxes | 0 | 26600 | 0.00% |
| F8 Muxes | 0 | 13300 | 0.00% |
| Block RAM Tile | 1 | 140 | 0.71% |
| RAMB36E1 | 1 | 140 | 0.71% |
| DSP48E1 | 2 | 220 | 0.91% |
| BUFGCTRL | 1 | 32 | 3.13% |
| Bonded IOB | 102 | 125 | 81.60% |

**与综合后对比**：
- Slice LUTs: 1086 (合成) → 1102 (布线后)，增加 16 个 LUT（opt_design 插入的缓冲器/优化逻辑）
- Slice Registers: 197 (不变)
- 其他资源不变

## 时序结果

### 汇总

| 指标 | 值 | 状态 |
|------|:--:|:----:|
| WNS (Worst Negative Slack, setup) | **-28.321 ns** | **FAIL** |
| TNS (Total Negative Slack, setup) | **-565.214 ns** | **FAIL** |
| Failing Endpoints (setup) | 47 / 427 | — |
| WHS (Worst Hold Slack) | 0.138 ns | PASS |
| THS (Total Hold Slack) | 0.000 ns | PASS |
| WPWS (Worst Pulse Width Slack) | 4.500 ns | PASS |
| TPWS (Total Pulse Width Slack) | 0.000 ns | PASS |

### 与综合后时序对比

| 指标 | 综合后 | 布线后 | 改善量 |
|------|:-----:|:------:|:------:|
| WNS | -31.682 ns | -28.321 ns | +3.361 ns (10.6%) |
| TNS | -398.678 ns | -565.214 ns | -166.536 ns (恶化) |
| Failing Endpoints | 38 | 47 | +9 |
| Logic Levels (worst) | 64 | 54 | -10 |

**分析**：实现流程仅将 WNS 从 -31.682 ns 改善到 -28.321 ns（改善 10.6%），远低于综合后报告预估的 70%+。说明时序失败是**结构性**的，而不是布局布线问题。TNS 恶化说明有更多路径加入了时序违反。

### check_timing 结果

全部 12 项检查通过（0 异常），与综合后一致。48 个输入端口无 input_delay 约束（AXI-Lite/AXI-Stream 端口，正常）。

## 最差 Setup 路径 (Top 1)

| 字段 | 值 |
|------|:----:|
| Slack | **-28.321 ns** |
| 起点 | `u_regs_top/img_cols_r_reg[0]/C` (FDSE, regs_top 模块) |
| 终点 | `u_frame_buf_mgr/bram_reg/ADDRBWRADDR[5]` (RAMB36E1, frame_buf_mgr 模块) |
| 路径延迟 | 37.707 ns (Logic 43.1%, Route 56.9%) |
| 逻辑级数 | 54 级 |
| 路径组成 | CARRY4=31, DSP48E1=1, LUT2=2, LUT3=7, LUT4=2, LUT5=1, LUT6=10 |
| 时钟周期要求 | 10.000 ns |
| 需求超额 | 路径延迟是周期要求的 3.77 倍 |

### 路径详细分解

路径跨越三个模块的复杂组合逻辑链：

1. **regs_top 阶段** (~5.4 ns ~ 8.2 ns): `img_cols_r_reg[0]` 输出经过多级 LUT 和 CARRY4 链，生成 DI 信号
2. **shift_addr_gen 计算阶段** (~8.2 ns ~ 39.9 ns): 连续多组 CARRY4 链执行地址计算：
   - `calc_col2_inferred` → `i__carry_i_*` 链 (8.9 ns ~ 14.2 ns)
   - `calc_col1_inferred` → `calc_col0` 链 (14.2 ns ~ 22.3 ns)
   - `read_addr_i_*` 多级加法器树 (22.6 ns ~ 36.2 ns)
   - 最后经过 DSP48E1 乘法器 (39.9 ns ~ 41.7 ns)
3. **frame_buf_mgr 阶段** (~41.7 ns ~ 42.7 ns): BRAM 地址输入

### 最差 Hold 路径

WHS = 0.138 ns (PASS)，保持时间裕量充足。

## 时序失败根因分析

### 根因：shift_addr_gen 组合逻辑深度过大

关键路径经过 54 级逻辑（31 个 CARRY4 + 1 个 DSP48E1 + 21 个 LUT），路径延迟 37.707 ns，是 10 ns 时钟周期的 3.77 倍。

`shift_addr_gen` 模块在**一个时钟周期内**完成以下全组合逻辑计算：
- 当前像素坐标 (col, row) 的计算
- 三组偏移地址 (col0, col1, col2) 的并行加法
- 多级地址加法树（read_addr_i_* 系列加法器）
- DSP48E1 乘加运算

这些操作被实现为深度级联的 CARRY4 加法器链，产生了 54 级逻辑深度。

### 为什么实现未能大幅改善时序

与综合后预估的 "70%+ 改善" 不同，实际改善仅为 10.6%，这是因为：

1. **路径是逻辑深度约束的，不是布线约束的**：路径延迟 37.707 ns 中，Logic 占 43.1% (16.267 ns)，Route 占 56.9% (21.440 ns)。即使将布线延迟降到 0，仍有 16.267 ns 逻辑延迟，超过 10 ns 周期。
2. **CARRY4 链是串行的**：31 级 CARRY4 必须顺序执行，opt_design 无法并行化。
3. **DSP48E1 未流水线化**：DSP48E1 内置 3 级流水线寄存器，但当前未使用（P 输出直接连接 BRAM 地址）。

## QoR 建议

与综合报告一致，实现后无新建议：

| ID | 建议 | 描述 |
|----|------|------|
| RQS_TIMING-201 | BRAM/地址流水线 | `shift_addr_gen` 的地址计算需增加流水线寄存器 |
| RQS_XDC-1 | 超长路径优化 | 54 级逻辑必须通过 RTL 修改减少 |

## 实现结论

| 检查项 | 结果 | 说明 |
|--------|:----:|------|
| opt_design | PASS | 完成 |
| place_design | PASS | 完成 |
| route_design | PASS | 完成 |
| DRC | PASS | 0 违反 |
| Resource Utilization | PASS | LUT 2.07%, FF 0.19%, BRAM 0.71%, DSP 0.91% |
| **Timing (setup)** | **FAIL** | **WNS = -28.321 ns, 47/427 endpoints failing** |
| Timing (hold) | PASS | WHS = 0.138 ns |
| Timing (pulse width) | PASS | WPWS = 4.500 ns |
| Check Timing | PASS | 0 unconstrained endpoint |

## 后续建议

1. **创建 ISS issue** 将时序失败分配给 rtl_implementer，由 module_owner 在 shift_addr_gen 中增加流水线
2. **推荐修复方案**：
   - 在 `shift_addr_gen` 的地址计算链中插入 2-3 级流水线寄存器（在关键加法器树中间）
   - 利用 DSP48E1 的内置流水线寄存器（配置 AREG/BREG/PREG）
   - BRAM 输入地址寄存器化
3. 修复后重新运行 L1a → L1b → L1c → L2 → L3 验证链
4. 考虑降低时钟频率作为临时方案（当前路径延迟 37.707 ns，需要约 26 MHz 或更低）
