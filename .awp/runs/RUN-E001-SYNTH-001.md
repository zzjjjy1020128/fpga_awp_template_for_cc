# RUN-E001-SYNTH-001.md - axil_2d_shift L2 综合报告

## 基本信息

| 项目 | 内容 |
|------|------|
| 任务 | TASK-E001-012 |
| 验证级别 | L2 (综合) |
| 顶层模块 | axil_2d_shift |
| 器件 | xc7z020clg400-1 |
| 时钟约束 | 100 MHz (周期 10.000 ns) |
| 综合工具 | Vivado v2022.2 (64-bit) Build 3671981 |
| 综合日期 | Sat Jun 6 10:01:03 ~ 10:01:57, 2026 |
| 综合耗时 | 46 s (CPU: 27 s) |
| 主机 | laptop_zjy, 24 CPU cores, 16 GB RAM |
| 工程文件 | `vivado/axil_2d_shift.xpr` |
| 约束文件 | `constraints/timing.xdc` |
| Tcl 脚本 | `vivado/run_synthesis.tcl` |

## 综合状态

**PASS** — `synth_design completed successfully`

- 0 Errors
- 0 Critical Warnings
- 46 Warnings (含 Synth 信息类警告)
- 38 Infos

## 资源利用率

| 资源类型 | 使用 | 可用 | 利用率 |
|---------|:----:|:---:|:-----:|
| Slice LUTs | 1086 | 53200 | 2.04% |
| LUT as Logic | 1086 | 53200 | 2.04% |
| LUT as Memory | 0 | 17400 | 0.00% |
| Slice Registers | 197 | 106400 | 0.19% |
| Register as Flip Flop | 197 | 106400 | 0.19% |
| F7 Muxes | 0 | 26600 | 0.00% |
| F8 Muxes | 0 | 13300 | 0.00% |
| Block RAM Tile | 1 | 140 | 0.71% |
| RAMB36E1 | 1 | 140 | 0.71% |
| RAMB18 | 0 | 280 | 0.00% |
| DSP48E1 | 2 | 220 | 0.91% |
| BUFGCTRL | 1 | 32 | 3.13% |
| Bonded IOB | 102 | 125 | 81.60% |

### Cell 详细统计

| Cell 类型 | 数量 |
|----------|:----:|
| BUFG | 1 |
| CARRY4 | 176 |
| DSP48E1 | 2 |
| LUT1 | 16 |
| LUT2 | 140 |
| LUT3 | 456 |
| LUT4 | 141 |
| LUT5 | 148 |
| LUT6 | 266 |
| RAMB36E1 | 1 |
| FDCE (异步清零) | 64 |
| FDRE (同步使能) | 131 |
| FDSE (同步置位) | 2 |
| IBUF | 49 |
| OBUF | 53 |

### RTL Component 统计

| 组件 | 规格 | 数量 |
|------|------|:----:|
| Adder | 32-bit 2-input | 5 |
| Adder | 10-bit 2-input | 9 |
| Adder | 10-bit 3-input | 2 |
| Adder | 10-bit 4-input | 2 |
| Register | 32-bit | 8 |
| Register | 16-bit | 2 |
| Register | 10-bit | 9 |
| Register | 8-bit | 1 |
| Register | 4-bit | 2 |
| Register | 2-bit | 2 |
| Register | 1-bit | 8 |
| RAM | 4096 x 8 bit (32K) | 1 |
| Mux | 多种 | 72+ |

### DSP 映射

| 模块 | 模式 | A | B | C | P |
|------|------|---|---|---|---|
| shift_addr_gen | C+A*B | 10 | 10 | 10 | 12 |
| axis_input | C+A'*B | 10 | 10 | 10 | 12 |

### BRAM 映射

| 模块 | 对象 | 结构 | RAMB18 | RAMB36 |
|------|------|------|:------:|:------:|
| frame_buf_mgr | bram_reg | 4K x 8 Dual Port | 0 | 1 |

## 时序预估

### 综合后时序（未做物理优化）

| 指标 | 值 | 状态 |
|------|:--:|:----:|
| WNS (Worst Negative Slack) | **-31.682 ns** | **FAIL** |
| TNS (Total Negative Slack) | **-398.678 ns** | **FAIL** |
| 时序违反端点 | 38 / 630 | — |
| WHS (Worst Hold Slack) | 0.132 ns | PASS |
| THS (Total Hold Slack) | 0.000 ns | PASS |
| WPWS (Worst Pulse Width Slack) | 4.500 ns | PASS |
| TPWS (Total Pulse Width Slack) | 0.000 ns | PASS |

### 最差 Setup 路径

- 起点: `u_regs_top/img_rows_r_reg[4]/C` (FDRE, clk)
- 终点: `u_frame_buf_mgr/bram_reg/ADDRBWRADDR[10]` (RAMB36E1, clk)
- 路径延迟: 40.935 ns (Logic 47.4%, Route 52.6%)
- 逻辑级数: 64 级 (CARRY4=37, DSP48E1=1, LUT2=2, LUT3=11, LUT4=2, LUT5=2, LUT6=9)
- Slack: -31.682 ns

### 时钟概览

| 时钟 | 周期 | 频率 |
|:----:|:----:|:----:|
| clk | 10.000 ns | 100.000 MHz |

### check_timing 结果

全部 12 项检查通过（0 异常）：
- no_clock: 0
- constant_clock: 0
- pulse_width_clock: 0
- unconstrained_internal_endpoints: 0
- no_input_delay: 0
- no_output_delay: 0
- multiple_clock: 0
- generated_clocks: 0
- loops: 0
- partial_input_delay: 0
- partial_output_delay: 0
- latch_loops: 0

## Warning 摘要

### 重要 Warning

| ID | 描述 | 严重度 |
|----|------|:------:|
| Synth 8-7129 | regs_top 部分端口无负载 (wr_strobe[15:5,1], rd_strobe[15:5,0], wdata[31:16], wstrb[3:2], status_error) | 信息性 — 因 AXIL_DATA_WIDTH=32 但寄存器实际使用 16 位 |
| Synth 8-7080 | Parallel synthesis criteria not met | 信息性 — 不影响功能 |
| Synth 8-3917 | s_axil_rresp[0] driven by constant 0 | 信息性 — AXI-Lite bresp[0] 固定为 0 |
| Synth 8-7052 | BRAM (u_frame_buf_mgr/bram_reg) 无输出寄存器，时序可能次优 | 建议 — 可在 BRAM 输出端增加流水线寄存器 |
| Constraints 18-6211 | 修正后 clk 端口已从 input_delay 排除 | 已修复 |
| Synth 8-223 | default block is never used (ctrl_fsm.sv:66) | 信息性 |

### unconnected port 说明

`regs_top` 的以下端口无负载属正常现象：
- `wr_strobe[15:5,1]`: 32-bit AXI-Lite wstrb 映射到 16 位寄存器地址空间，高 bit 未使用
- `rd_strobe[15:5,0]`: 同上
- `wdata[31:16]`: 32-bit AXI-Lite 写数据，实际仅使用低 16 位
- `wstrb[3:2]`: wstrb 高两位未使用（寄存器数据宽度 ≤16-bit）
- `status_error`: 保留端口，外部固定为 0

## QoR 建议

| ID | 建议 | 描述 |
|----|------|------|
| RQS_TIMING-201 | BRAM 流水线化 | BRAM 实例 `u_frame_buf_mgr/bram_reg` 建议增加输出寄存器以改善时序 |
| RQS_XDC-1 | 超长路径优化 | 12 条路径超过 Max Net/LUT 预算，建议减少逻辑深度或增加流水线 |

## 时序失败根因分析

综合后 WNS = -31.682 ns (setup), 38 条路径违反时序。主要根因:

1. **shift_addr_gen 组合逻辑过深 (64 级)**: 从 `img_rows` 寄存器到 BRAM 读地址的计算路径经过大量 CARRY4 加法器链和 DSP48E1 乘法器，数据路径延迟达 40.935 ns
2. **BRAM 无输出流水线**: 综合工具提示 BRAM 无法合并输出寄存器
3. **无物理优化**: 综合阶段不做布局布线，所有路径显示为 unplaced，实际 route 延迟在实现阶段会显著改善

**预期**: 经实现 (placement + routing) + opt_design 优化后，关键路径通常可缩短 70%+，100 MHz 时序目标有望达成。

## 综合结论

| 检查项 | 结果 | 说明 |
|--------|:----:|------|
| Synthesis (synth_design) | **PASS** | 综合完成，0 error, 0 critical warning |
| Resource Utilization | PASS | LUT 2.04%, FF 0.19%, BRAM 0.71%, DSP 0.91% |
| Timing (post-synth) | **FAIL** | WNS = -31.682 ns，预期实现后改善 |
| IO Constraint | PASS | 102 IOB used (81.60%), 时钟约束正确加载 |
| Check Timing | PASS | 0 unconstrained endpoint, 0 loop |

## 下一步建议

1. 运行 `opt_design` + `place_design` + `route_design` 进行实现，观察时序改善程度
2. 如实现后仍有时序问题，可在 `shift_addr_gen` 中增加流水线级（乘法器 + 加法器链上插入寄存器）
3. BRAM 输出端口 (`frame_buf_mgr`) 可增加一级输出寄存器以改善 BRAM 到逻辑的时序
4. 实现后再运行 `report_timing_summary` 确认 100 MHz 时序闭合
