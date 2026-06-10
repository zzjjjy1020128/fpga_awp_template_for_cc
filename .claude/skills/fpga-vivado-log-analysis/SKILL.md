# Skill: vivado-log-analysis

## When to use
分析 Vivado 综合/实现/时序报告和日志时使用。

## Input files
- Vivado 日志文件（`vivado/*.log`）
- 时序报告（`vivado/*.rpt`）
- 资源利用率报告

## Checklist
- [ ] 综合警告/错误已归类
- [ ] 时序违例（WNS/WHS/TNS/THS）已分析
- [ ] 资源利用率（LUT/FF/BRAM/DSP）在合理范围
- [ ] 关键路径已识别
- [ ] 时钟约束覆盖完整
- [ ] 未约束路径已处理

## Required output
- 分析报告（Markdown，包含关键发现和建议）

## Language policy
- 分析报告：zh
- 工具输出引用：en（保持原样）
