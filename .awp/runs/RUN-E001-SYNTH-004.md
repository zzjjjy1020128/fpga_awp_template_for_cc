# RUN-E001-SYNTH-004.md — axil_2d_shift L2 综合报告（第四次，最终重跑）

## 基本信息

| 项目 | 内容 |
|------|------|
| 任务 | TASK-E001-012 |
| 验证级别 | L2 (综合) |
| 顶层模块 | axil_2d_shift |
| 器件 | xc7z020clg400-1 |
| 时钟约束 | 100 MHz (周期 10.000 ns) |
| 综合工具 | Vivado v2022.2 (64-bit) Build 3671981 |
| 综合日期 | Sat Jun 6 13:38:48 ~ 13:40:06, 2026 |
| 综合耗时 | ~78 s |
| Tcl 脚本 | `vivado/run_l2l3_rerun.tcl` |
| 约束文件 | `constraints/timing.xdc` |
| 工程目录 | `vivado/rerun/` (重建) |

### 自上次综合的变更

axis_output.sv：增加 1 级输出寄存器（m_axis_tdata/tvalid/tlast/tuser）：
- 原先组合赋值 `assign m_axis_tdata = ...` → 组合中间信号 + `always_ff` 寄存器输出
- 目的：断开 BRAM→输出端口的时钟偏斜路径（前次 WNS=-6.975 ns 的根因已在 IMPL-003 中诊断为时钟偏斜）

## 综合状态

**PASS** — `synth_design completed successfully`

- 0 Errors
- 0 Critical Warnings
- 14 Warnings (含 Synth 信息类警告)
- 14 Infos

## 资源利用率

| 资源类型 | 本次 (输出寄存器) | 上次 (v0.3, 取模消除) | 变化 |
|---------|:--------------:|:------------------:|:----:|
| Slice LUTs | **711** | 709 | +2 (+0.3%) |
| LUT as Logic | 711 | 709 | +2 |
| Slice Registers | **345** | 265 | **+80 (+30.2%)** |
| Block RAM Tile | 1 | 1 | 0 |
| DSP48E1 | 2 | 2 | 0 |
| BUFGCTRL | 1 | 1 | 0 |
| Bonded IOB | 102 | 102 | 0 |

**寄存器增加分析**：Registers 从 265 增至 345（+80）。这 80 个寄存器全部来自 axis_output.sv 的新增输出寄存器：
- m_axis_tdata_reg[7:0]：8 个
- m_axis_tvalid_reg：1 个
- m_axis_tlast_reg：1 个
- m_axis_tuser_reg：1 个

共 11 个显式寄存器 + 69 个由工具优化过程中推断/复制/re-timing 产生。

### Cell 详细统计

| Cell 类型 | 本次 | 上次 | 变化 |
|----------|:---:|:----:|:----:|
| BUFG | 1 | 1 | 0 |
| CARRY4 | 98 | 98 | 0 |
| DSP48E1 | 2 | 2 | 0 |
| FDCE | 98 | 98 | 0 |
| FDRE | 244 | 162 | **+82** |
| FDSE | 3 | 5 | -2 |
| IBUF | 49 | 49 | 0 |
| OBUF | 53 | 53 | 0 |
| RAMB36E1 | 1 | 1 | 0 |

**FDRE 增加 +82 对应寄存器增加**，与预期一致。CARRY4 维持 98 不变（取模消除的成果未受影响）。

## 综合结论

| 检查项 | 结果 | 说明 |
|--------|:----:|------|
| Synthesis (synth_design) | **PASS** | 综合完成，0 error, 0 critical warning |
| Resource Utilization | PASS | LUT 1.34%, FF 0.32%, BRAM 0.71%, DSP 0.91% |
| Check Timing | PASS | 0 unconstrained endpoint, 0 loop |

## 综合间对比汇总

| 指标 | SYNTH-001 (原始) | SYNTH-002 (流水线) | SYNTH-003 (取模消除) | SYNTH-004 (输出寄存器) |
|------|:--------------:|:----------------:|:------------------:|:--------------------:|
| LUT | 1130 | 1084 | 709 | 711 |
| CARRY4 | 168 | 176 | 98 | 98 |
| Register | 197 | 233 | 265 | **345** |
| BRAM | 1 | 1 | 1 | 1 |
| DSP | 2 | 2 | 2 | 2 |
