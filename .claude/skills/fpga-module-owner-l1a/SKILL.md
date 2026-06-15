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

## 反模式（禁止事项）

### ❌ "写完 RTL 直接综合"
```
综合 = 15min。iverilog 编译检查 = 3s。
用综合当语法检查器浪费大量时间。
```
**正解**：`iverilog -t null -g2012 rtl/*.sv`（语法+连接性）→ verible lint（风格）→ 仿真 → 综合。

### ❌ "仿真看起来波形对，应该没问题"
```
"波形看起来对"不是验证标准。必须用 scoreboard 做精确比对——
期望值 vs 实际值，逐拍检查，不是肉眼扫一遍波形。
```
**正解**：testbench 中含 scoreboard，仿真结束时输出 PASS/FAIL 判定，不依赖波形目检。

### ❌ "只有一个模块，不需要 testbench"
```
即使最简单的模块（如 AXI-Lite 从机），也需要 TB 验证：
- reset 后寄存器初始值
- 读写正确性
- 非法地址返回错误
L0 审查无法发现功能错误。
```

### ❌ "边界条件太琐碎，跳过"
```
最常见的 bug 来源正是边界条件：
- 帧尺寸=1、最大帧尺寸
- backpressure 在帧首/帧尾/帧中
- 连续帧间状态残留
- 配置动态切换
跳过边界测试 = 把 bug 留给集成阶段。
```

### ❌ "模块接口以后还会变，现在不写文档"
```
模块完成时的接口描述是最准确的。以后再补 = 记忆衰减 + 细节丢失。
下游模块和集成验证依赖接口文档。
```
**正解**：在 task notes 中记录接口行为说明（端口列表、时序约定、已知限制）。

## 相关 Skills

- `fpga-rtl-style` — 编码风格规范（命名、可综合语法、握手协议）
- `fpga-sim-verification` — testbench 架构、scoreboard、golden model
- `fpga-iteration-economics` — 理解每次综合/仿真的时间成本
- `fpga-axi-lite-review` / `fpga-axis-review` / `fpga-cdc-review` — 协议审查
- `fpga-integration-failure-debug` — L1b/L1c 发现本模块 bug 时的修复流程

## 语言规范
- RTL 标识符：en
- Testbench 标识符：en
- 设计说明/报告：zh
