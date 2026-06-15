---
skill_id: SKILL-FPGA-L1B-DATAPATH-VERIFY
name: fpga-l1b-datapath-verify
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-011
validated_in_projects: []
last_reviewed: "2026-06-15"
owner: human_owner
---

# L1b 数据通路闭环验证

> 触发：用户要求创建或执行 L1b 验证、数据通路闭环仿真、跨模块集成测试。

## 概述

L1b 是 L1a（模块级单元仿真）到 L1c（全系统集成仿真）之间的关键 checkpoint。其目标是**在进入全系统前确认跨模块协议边界没有大问题**，而不是覆盖所有系统功能。

## 核心原则

1. **按数据通路切片，不按模块数量**：每个 L1b task 验证一个独立的跨模块协议边界。不要机械地按"每 N 个模块"触发。
2. **先隔离再全系统**：如果 L1c 失败，先确认每个 L1b 切片独立通过，再回到 L1c。
3. **跨帧是必测项**：任何 L1b 验证都必须包含连续多帧测试——这是最常见的 bug 来源。

## 数据通路切片方法

对于典型的数据流 FPGA 设计，识别以下三类通路：

### WRITE path（写通路）
数据从外部接口流入内部存储的路径。
```
外部接口 → 输入模块 → 存储控制器 → BRAM/FIFO
```
验证点：输入握手、写地址序列、帧边界、backpressure、连续多帧。

### READ path（读通路）
数据从内部存储流出到外部接口的路径。
```
BRAM/FIFO → 地址生成器 → 输出模块 → 外部接口
```
验证点：读地址序列、pipeline 延迟对齐、输出顺序、backpressure、padding 行为。

### CONTROL path（控制通路）
配置和状态机控制的路径。
```
配置接口 → 寄存器文件 → 控制状态机 → 使能信号分发
```
验证点：配置锁存、状态机跳转、使能信号时序、复位优先级、STATUS 互斥。

## 执行流程

1. 阅读架构文档，识别数据通路切片
2. 为每个切片创建独立的 L1b task（agent: `integration_verifier`）
3. 编写切片级 testbench：仅实例化该通路涉及的 2-3 个模块
4. 运行仿真，记录 pipeline 时序（周期级）
5. 全部 L1b pass 后再进入 L1c

## L1b testbench 要求

- 不实例化无关模块（减少信号空间，加速调试）
- 包含 golden model 用于数据正确性比对
- 记录关键信号的周期级时序（如 shift_en 有效后第 N 拍出现首个有效输出）
- 必须包含 ≥3 帧的连续测试
- 输出到 `.awp/runs/RUN-{exp}-L1B-{path}-{seq}.md`

## 反模式（禁止事项）

### ❌ "所有模块写完了再一次性跑 L1b"
```
等所有模块 ready 才做 L1b = 把 bug 堆积到最后。越早发现集成问题，
修复成本越低。3-4 个数据通路模块 ready 后立即启动 L1b。
```

### ❌ "L1b 跑通了就不用管 L1c"
```
L1b 验证的是切片（2-3 模块），L1c 验证全系统（所有接口同时工作）。
L1b pass 只是 L1c 的必要条件，不是充分条件。
```

### ❌ "L1b TB 可以复刻 L1c TB"
```
L1b 的优势正是精简——只实例化 2-3 个模块，信号空间小，调试快。
把整个系统塞进 L1b = 失去切片的诊断价值。
```

## 相关 Skills

- `fpga-sim-verification` — TB 架构、scoreboard、golden model
- `fpga-integration-failure-debug` — L1b 失败时的系统化调试
- `fpga-l1b-datapath-verify` — 数据通路切片方法

## 与 L1c 的关系

L1b 全部 pass 是 L1c 的硬前置条件。如果 L1c 仍然失败：
- 问题不在数据通路本身（已被 L1b 证明正确）
- 根因在顶层连接、全系统时序、或 TB 配置
- 参考 `integration-failure-debug` skill 进行系统化调试
