# Skill: zynq-debug-toolchain

## When to use

Zynq-7000 / MPSoC 上板调试的 CLI 自动化。UG908 标准流：XSCT(Vitis) 主导 PS，Vivado ILA 观察 PL。

## 架构：hw_server 守护进程 + 双客户端

```
hw_server -d -p3121          ← 单一 JTAG 主控
  ├── XSCT: connect -url tcp:localhost:3121  (Active Controller)
  │     职责: fpga -f, ps7_init, dow, con, stop, breakpoints
  └── Vivado MCP: connect_hw_server -url TCP:localhost:3121  (Passive Observer)
        职责: arm ILA, upload data, write .ila
```

两客户端**同时**连接同一 hw_server，无 JTAG 冲突。UG908 标准流即此模型。

## XSCT `dow` 关键：target CPU 核

`targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}` — CPU 核，非 APU。
用 APU target 导致 `dow` 报 TCF Code 16 "Invalid context"。

## ILA 捕获：ALWAYS 模式限制

BD 中 System ILA v1.1 的 SLOT 探针*不支持* BASIC/ADVANCED 触发模式
(`IS_BASIC_CAPTURE_MODE_SUPPORTED=0`)。仅 ALWAYS 模式可用。

ALWAYS 模式 buffer 深度 1024 samples @ 50MHz = 20.48μs 窗口。
需软件 gate 机制实现 CPU-ILA 同步：
1. C 代码在 DMA 前进入 `while(*GATE==0)` 等待循环
2. Vivado MCP 武装 ILA
3. XSCT `mwr GATE=1` 释放 CPU
4. CPU 立即启动 DMA，ILA 捕获

**限制**：步骤 2→3 的 Bash/MCP 延迟（~1-2s）远超 ILA 窗口（20μs）。
闭合需 PS-PL Cross-Trigger（ISS-E001-008）或 RTL ILA。

## 标准 PS-PL 联合调试方法

| 层级 | 工具 | 用途 |
|------|------|------|
| 数据级 | XSCT + C 代码 | 寄存器读写、DMA 状态、golden 比对 |
| 时序级 | Vivado ILA | AXI 总线波形、pipeline 行为 |
| 同步 | PS-PL Cross-Trigger | 断点触发 ILA 捕获 (待实现) |

C 代码和 ILA 互相印证：数据异常→ILA 查找信号根因；波形异常→C 代码确认数据影响。

## 已知限制 (open issues)

- ISS-E001-008: System ILA BD 模式无 BASIC 触发
- ISS-E001-009: DMA HP0 端口阻塞，需 FSBL/XSA 重新导出

## 语言策略

- 工具链操作/脚本：en
- 原则说明：zh
