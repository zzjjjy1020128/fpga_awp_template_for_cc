# Skill: board-validation

## When to use
执行或记录 FPGA 上板验证时使用。

## Input files
- Bitstream 文件（`.bit`）
- `docs/board_validation.md`
- 验证计划

## Checklist
- [ ] JTAG 连接正常，FPGA 可检测
- [ ] 电源和时钟正常
- [ ] Bitstream 下载成功
- [ ] ILA 触发条件已配置
- [ ] 基本 I/O 功能正常
- [ ] 测试数据注入和采集正常
- [ ] 数据正确性已验证（对比黄金参考）

## Required output
- `.awp/runs/RUN-{exp}-BOARD-{seq}.md`（格式见 `.awp/registry/namespaces.yaml`）
- ILA/VIO 截图或日志

## Language policy
- 验证记录：zh
- 信号名：en
