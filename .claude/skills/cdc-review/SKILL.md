# Skill: cdc-review

## When to use
审查跨时钟域（CDC）设计时使用。适用于任何涉及多时钟域的信号传输。

## Input files
- 包含 CDC 逻辑的 RTL 文件
- 约束文件（`constraints/*.xdc`）

## Checklist
- [ ] 所有 CDC 路径已识别并记录
- [ ] 单 bit 信号使用 2+ 级同步器
- [ ] 多 bit 总线使用异步 FIFO 或握手协议
- [ ] 无直接跨时钟域组合逻辑
- [ ] CDC 约束（set_clock_groups, set_false_path 等）正确
- [ ] 复位同步器正确处理
- [ ] 准稳态（metastability）风险已评估

## Required output
- `.awp/reviews/REV-{exp}-{task_seq}-CDC-{seq}.md`（格式见 `.awp/registry/namespaces.yaml`）

## Language policy
- 审查报告：zh
- 信号名：en
