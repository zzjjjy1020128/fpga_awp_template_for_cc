---
skill_id: SKILL-FPGA-MODULE-OWNER-L1A
name: fpga-module-owner-l1a
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-004
  - SRC-FPGA-009
validated_in_projects: []
last_reviewed: "2026-06-10"
owner: human_owner
---

# 模块 RTL 设计 + L1a 自证

## 适用场景
- rtl_implementer 接手一个新模块 task
- 从零完成 RTL 设计、testbench 编写、仿真验证、自证报告

## 前置输入
- Task 合同（`.awp/tasks/TASK-*.yaml`）——明确 scope、接口、target level
- 架构文档（`docs/architecture.md`）——模块接口定义、数据流
- 相关协议 skill（如 `fpga-axis-review`、`fpga-axi-lite-review`）

## L1a 设计流程

### 阶段 1：接口定义
- [ ] 模块端口列表与架构文档一致
- [ ] 所有 input/output 方向正确
- [ ] 参数列表完备（数据宽度、帧尺寸、FIFO 深度）
- [ ] 时钟和复位策略明确（单时钟域/多时钟域）

### 阶段 2：功能实现
- [ ] 状态机完整（无死锁、无孤立状态、reset 后进入已知状态）
- [ ] 所有分支有明确行为（无隐式 latch）
- [ ] 边界条件处理（最大/最小时钟周期、最大帧尺寸、zero-length 传输）
- [ ] 错误条件处理（invalid config、overflow、underflow）

### 阶段 3：L1a Testbench
- [ ] 覆盖 reset 行为（复位后所有输出为已知值）
- [ ] 覆盖基本事务（单帧/单事务，最简路径）
- [ ] 覆盖参数边界（min/max 参数组合至少 3 组）
- [ ] 覆盖 invalid 输入（非法配置写、超范围地址）
- [ ] 覆盖 backpressure（如适用：TREADY 随机反压）
- [ ] 覆盖连续帧（至少 3 帧连续，检查帧间无状态残留）

### 阶段 4：仿真与自证
- [ ] 运行仿真：`iverilog -g2012 -o simv tb_*.sv rtl/*.sv && vvp simv`
- [ ] 检查波形关键节点（状态机跳转、握手完成、数据通路）
- [ ] 记录仿真通过证据到 `.awp/runs/RUN-{exp}-SIM-{seq}.md`
- [ ] 标注已知限制和未覆盖 case（如适用）

## 输出
- `rtl/<module>.sv` — RTL 设计文件
- `tb/tb_<module>.sv` — L1a testbench
- `sim/run_<module>_sim.py` — 仿真运行脚本
- `.awp/runs/RUN-{exp}-SIM-{seq}.md` — 仿真通过报告
- 接口行为说明（端口列表、时序约定、已知限制）——可写入 task notes

## 语言规范
- RTL 标识符：en
- Testbench 标识符：en
- 设计说明/报告：zh
