# Skill: fpga-rtl-review

## When to use
审查 FPGA RTL 代码时使用。适用于 Verilog / SystemVerilog 模块的代码审查。

## Input files
- RTL 设计文件（`rtl/*.v` / `rtl/*.sv`）
- `docs/architecture.md`

## Checklist
- [ ] 模块接口与架构文档一致
- [ ] 时序逻辑正确（阻塞/非阻塞赋值）
- [ ] 复位策略合理
- [ ] 状态机完整（无死锁、无孤立状态）
- [ ] 跨时钟域信号处理正确（如适用）
- [ ] 代码风格一致，可读性好
- [ ] 参数化适当（无硬编码 Magic Number）

## Required output
- `.awp/reviews/REV-{exp}-{task_seq}-RTL-{seq}.md`（格式见 `.awp/registry/namespaces.yaml`）

## Language policy
- 审查报告：zh
- 代码标识符：en
