---
skill_id: SKILL-FPGA-AXIS-REVIEW
name: fpga-axis-review
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-005
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-10"
owner: human_owner
---

# AXI-Stream 接口审查

## 适用场景
- RTL review：审查含 AXI-Stream 接口的模块
- L1a：编写 AXI-Stream testbench 时的 check 清单
- L1b：数据通路闭环验证时的协议级检查
- Integration failure debug：AXI-Stream 数据错位/丢失归因

## 输入文件
- AXI-Stream 相关 RTL 文件（source/sink/data-path）
- 接口规范文档（TDATA 宽度、TUSER 定义、packet/frame 格式）

## 检查清单

### 握手协议
- [ ] TVALID 由 source 独立控制，不依赖 TREADY（无组合环路）
- [ ] TREADY 由 sink 独立控制，不依赖 TVALID（允许背压）
- [ ] TVALID & TREADY 同时为高时，数据传输被确认（一拍一个 beat）
- [ ] 无组合逻辑环路在 valid-ready 链中

### 数据完整性
- [ ] TDATA 在 (TVALID & TREADY) 不成立时保持稳定（数据不丢失）
- [ ] TSTRB 正确指示有效字节通道（窄位宽传输时尤其要查）
- [ ] TKEEP 正确指示当前 beat 中的有效字节（packet 末尾 pos）
- [ ] TLAST 在每个 packet/frame 的最后一个 beat 正确置位
- [ ] TUSER（如使用）在 frame 起始 beat 正确指示 side-band 信息

### 背压行为
- [ ] Sink 可以无限期保持 TREADY=0（不丢数据，不卡死状态机）
- [ ] Source 在 TREADY=0 时保持 TVALID=1 且 TDATA 不变
- [ ] Random backpressure 仿真通过（TREADY 概率 20%-80%）
- [ ] 背压释放后数据恢复传输，无丢失或重复

### 帧边界
- [ ] TLAST 置位后下一拍 TVALID 不应仍为高（同一帧）（除非下一帧立即开始）
- [ ] TLAST 置位后下一帧起始 beat 的 TUSER（如使用）位置正确
- [ ] 连续多帧间状态机无残留（第 N 帧数据不出现在第 N+1 帧输出）

### 常见错误模式
- [ ] 无 "TREADY 永远为 1" 假设（忽略背压能力）
- [ ] 无 "TVALID 永远有效" 假设（source 空闲时 TDATA 被误读）
- [ ] 无 TLAST 忘记置位（导致后续模块永远等待帧尾）
- [ ] 无 TKEEP 全 1 假设（忽略 packet 末尾窄 beat）

## 审查输出
- `.awp/reviews/REV-{exp}-{task_seq}-AXIS-{seq}.md`
- 含：每个 check item 的 pass/fail、协议违规项数、修复建议

## 语言规范
- 审查报告：zh
- 信号名：en
