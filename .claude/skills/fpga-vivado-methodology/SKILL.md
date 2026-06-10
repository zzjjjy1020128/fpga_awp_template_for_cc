---
skill_id: SKILL-FPGA-VIVADO-METHODOLOGY
name: fpga-vivado-methodology
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-001
  - SRC-FPGA-010
validated_in_projects: []
last_reviewed: "2026-06-10"
owner: human_owner
---

# Vivado 综合/实现方法论 (L2-L4)

## 适用场景
- vivado_integrator 执行 L2（综合）、L3（实现+时序）、L4（比特流生成）
- 综合/实现失败时定位根因
- 时序不收敛时系统化排查

## 前置条件
- Vivado 工程已打开或 Tcl 脚本已就绪
- 约束文件（`constraints/*.xdc`）已通过 `xdc_lint`
- RTL 已通过 L1a/L1b/L1c（至少目标级别）

## L2 — 综合检查清单

- [ ] 运行综合前执行 `xdc_lint`（检查 PIN_CONFLICT、MISSING_IOSTANDARD 等）
- [ ] 运行综合：`launch_runs synth_1 -jobs 4`，等待 `synth_1 Complete`
- [ ] 检查 CRITICAL WARNING：≥1 个 CW → 不准进入 L3，先排查
- [ ] 检查资源利用率（LUT/FF/BRAM/DSP/IOB 百分比）
  - > 90%：[CRITICAL] 后续布线可能拥塞
  - 70-90%：[WARN] 关注拥塞热点
- [ ] 检查 Methodology 报告（`report_methodology`）
- [ ] 综合通过后生成 post-synth DCP 用于后续实现

## L3 — 实现与时序检查清单

- [ ] 运行实现：`launch_runs impl_1 -jobs 4`，等待 `route_design Complete`
- [ ] 检查时序报告：`report_timing_summary`
  - WNS ≥ 0 ns → PASS
  - WNS < 0 ns → FAIL，需排查关键路径
- [ ] 检查 CRITICAL WARNING（route 阶段的 CW 比 synth 更严重）
- [ ] 时序违例排查顺序：
  1. 约束是否正确（时钟周期、false path、clock groups）
  2. 拥塞是否严重（utilization > 90%）
  3. 关键路径是否可优化（pipeline、retiming）
  4. 高扇出信号（> 1000 loads）是否需要复制
- [ ] 实现通过后，确保 IO 引脚报告与约束一致（`verify_io_placement_tool`）

## L4 — 比特流生成检查清单

- [ ] 运行 `check_bitstream_readiness` — 必须返回 READY
- [ ] 有 CW 时确认风险后使用 `force=True` 生成
- [ ] 生成后记录比特流版本（日期或 SHA256）
- [ ] 确认比特流文件存在且大小非零

## 常用 Tcl 命令速查

```tcl
# 综合
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# 实现
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# 时序报告
report_timing_summary -file timing.rpt

# 资源报告
report_utilization -file utilization.rpt

# IO 报告
report_io -file io.rpt
```

## 输出格式
- `.awp/runs/RUN-{exp}-SYNTH-{seq}.md` — 综合记录
- `.awp/runs/RUN-{exp}-IMPL-{seq}.md` — 实现记录
- 比特流版本必须记录在 run record 中
