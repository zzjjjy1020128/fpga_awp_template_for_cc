# Skill: axis-review

## When to use
审查 AXI-Stream 接口设计时使用。检查 valid-ready handshake（有效-就绪握手）协议合规性。

## Input files
- AXI-Stream 相关 RTL 文件
- 接口规范文档

## Checklist
- [ ] TVALID / TREADY 握手时序正确
- [ ] TDATA / TSTRB / TKEEP / TLAST 信号使用正确
- [ ] 背压（backpressure）处理正确
- [ ] TLAST 在 packet 边界正确置位
- [ ] 无组合逻辑环路在 valid-ready 链中
- [ ] 数据在 TVALID & TREADY 同时为高时稳定

## Required output
- `.awp/reviews/REV-{exp}-{task_seq}-AXIS-{seq}.md`（格式见 `.awp/registry/namespaces.yaml`）

## Language policy
- 审查报告：zh
- 信号名：en
