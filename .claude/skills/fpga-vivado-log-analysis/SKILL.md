---
skill_id: SKILL-FPGA-VIVADO-LOG-ANALYSIS
name: fpga-vivado-log-analysis
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-001
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-10"
owner: human_owner
---

# Vivado 日志分析

## 适用场景
- 综合/实现失败时诊断根因
- CRITICAL WARNING 分类与风险评估
- 时序违例的系统化排查
- 判断是否需要重新综合/重新约束

## 输入文件
- Vivado runme.log（`<proj>.runs/synth_1/runme.log` / `impl_1/runme.log`）
- 时序报告（`report_timing_summary` 输出）
- 资源利用率报告（`report_utilization` 输出）

## 日志分析流程

### 第一步：定位失败点
```bash
# 使用 vivado-log-analysis skill 或手动搜索
grep -E "ERROR|CRITICAL WARNING|FAIL" runme.log
```
- [ ] 是否有 `ERROR:` 前缀的行 → BLOCK 级，必须解决
- [ ] 是否有 `CRITICAL WARNING:` 前缀的行 → 分类评估
- [ ] 是否有非标错误（segfault, TclStackFree, FATAL） → 工具/Tcl 问题

### 第二步：CRITICAL WARNING 分类

| CW 模式 | 含义 | 动作 |
|---------|------|------|
| `[Synth 8-*]` | 综合类（black box、multi-driven、undriven） | 检查 RTL |
| `[Place 30-*]` | 布局类（I/O port 未放置） | 检查约束 |
| `[Route 35-*]` | 布线类（部分引脚未布线） | 检查约束 + 拥塞 |
| `[Timing 38-*]` | 时序类（no clock、unconstrained paths） | 检查时钟约束 |
| `[Power 33-*]` | 功耗类 | 通常不阻断，记录即可 |

- [ ] 每个 CW 标注是否需要阻断下一步
- [ ] sim_* 类型的非标错误 → 检查 `xsim/*.log`（非 runme.log）

### 第三步：时序违例分析
- [ ] WNS (Worst Negative Slack)：≥ 0 → PASS，< 0 → FAIL
- [ ] WHS (Worst Hold Slack)：≥ 0 → PASS，< 0 → FAIL
- [ ] TNS (Total Negative Slack)：累计负 slack，越大越严重
- [ ] 定位关键路径：`report_timing -max_paths 10 -nworst 5`
- [ ] 关键路径是否可优化（高扇出、长组合逻辑链、跨域路径未约束）

### 第四步：资源利用率评估
- [ ] LUT: > 90% → CRITICAL，70-90% → WARN
- [ ] FF: > 90% → CRITICAL，70-90% → WARN
- [ ] BRAM: > 90% → WARN
- [ ] DSP: > 90% → WARN
- [ ] IOB: > 80% → WARN（注意引脚分配空间）

## 常用诊断命令

```bash
# 使用 vivado-mcp 工具
get_critical_warnings  # 获取分类 CW 列表
get_timing_report       # 获取结构化时序报告
get_utilization_report  # 获取资源占用摘要
get_run_progress        # 查看运行进度
```

## 输出格式
- `.awp/runs/RUN-{exp}-SYNTH-{seq}.md` 或 `RUN-{exp}-IMPL-{seq}.md`
- 含：ERROR/CW 分类表、时序摘要（WNS/WHS/TNS）、资源占用%、结论（PASS/BLOCK/WARN）
