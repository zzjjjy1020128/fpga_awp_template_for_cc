# Skill: board-validation

## When to use
执行或记录 FPGA 上板验证时使用。覆盖 L5（冒烟测试）和 L6（数据正确性）两个级别。

## Input files
- Bitstream 文件（`.bit`）
- `docs/board_validation.md`（上板验证计划）
- 平台硬件操作手册 `board/hw_arch_*.md`
- 平台清单 `.awp/platform/hw_base_*.yaml`

## L5 — Board Smoke Test Checklist
- [ ] JTAG 连接正常，FPGA 可检测（`get_hw_targets` 返回目标器件）
- [ ] 电源正常（LED 指示、电压测量点确认）
- [ ] 时钟频率确认（ILA 捕获时钟周期测量）
- [ ] PS 启动完成（UART 终端有输出或 XSCT 可连接）
- [ ] Bitstream 下载成功（无 DONE 错误）
- [ ] 基本 I/O 功能正常（LED/按键，如适用）
- [ ] AXI-Lite 寄存器读回（ID 寄存器返回预期值）
- [ ] AXI-Lite 寄存器写+读验证（CTRL 寄存器写入后读回一致）
- [ ] ILA 触发条件已配置，测试捕获展示有效波形

## L6 — Board Data Correctness Checklist
- [ ] PS DMA 软件编译通过并部署到目标板
- [ ] DMA MM2S 传输测试图案到加速器输入
- [ ] 加速器处理后 DMA S2MM 读回数据
- [ ] 回读数据与仿真 golden 参考比对一致
- [ ] 多种移位方向（左/右/上/下）验证通过
- [ ] 多种步长（1, 2, half）验证通过
- [ ] 多种帧尺寸（含 odd 尺寸）验证通过
- [ ] 帧边界处理（wrapping/zero-fill）正确
- [ ] ILA 捕获展示 pipeline 时序与仿真一致
- [ ] 持续多帧传输无数据错位或丢失

## Hardware Evidence Collection (required for failures)
每次上板 session 发生失败时，必须一次性采集以下证据（标注在 RUN record 中）：
- [ ] ILA 波形捕获文件路径（`.cdc` 或 `.vcd`）
- [ ] PS 控制台完整日志（UART 输出）
- [ ] 失败类别标注（CAT-HW/BS/AX/IL/SW/DT/RT）
- [ ] 比特流版本标识（生成日期或 SHA256）
- [ ] 平台 ID（HW_BASE_xxx_vX.X）

## Required output
- `.awp/runs/RUN-{exp}-BOARD-{seq}.md`（格式见板卡验证模板）
- ILA/VIO 截图或日志文件

## Language policy
- 验证记录：zh
- 信号名：en
- 失败类别代码：en (CAT-*)
