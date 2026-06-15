---
skill_id: SKILL-FPGA-SKILL-NAVIGATOR
name: fpga-skill-navigator
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-15"
owner: human_owner
---

# FPGA Skill 导航器

> **触发（强制）**：模型在 FPGA 开发中遇到任何不确定"该用哪个 skill"的情况时，必须先查此导航器。
> 也适用于 orchestrator 分配 task 给子 agent 前——确认子 agent 应该引用哪些 skill。

## 按症状索引

> "我看到 X 现象 → 应该用这些 skill"

### 仿真/验证问题

| 现象 | 主要 Skill | 辅助 Skill |
|------|-----------|-----------|
| 仿真失败，不确定是 DUT bug 还是 TB bug | `fpga-integration-failure-debug` | `fpga-sim-verification` |
| 需要写 testbench | `fpga-sim-verification` | `fpga-module-owner-l1a` |
| L1b/L1c 失败需要定位模块 | `fpga-integration-failure-debug` | `fpga-l1b-datapath-verify` |
| 控制 FSM 死锁/卡死 | `fpga-formal-sanity` | `fpga-integration-failure-debug` |
| 连续多帧数据错位 | `fpga-sim-verification`（R3 规则） | `fpga-integration-failure-debug` |

### Vivado 工具链问题

| 现象 | 主要 Skill | 辅助 Skill |
|------|-----------|-----------|
| 综合报 CRITICAL WARNING | `fpga-vivado-log-analysis` | `fpga-vivado-methodology` |
| 时序不收敛 | `fpga-vivado-methodology` | `fpga-vivado-log-analysis` |
| 资源超限 | `fpga-vivado-methodology` | `fpga-project-acceptance` |
| 不确定能不能开始综合 | `fpga-vivado-preflight` | `fpga-iteration-economics` |
| CW 分类看不懂 | `fpga-vivado-log-analysis` | `fpga-vivado-preflight` |

### 上板/硬件问题

| 现象 | 主要 Skill | 辅助 Skill |
|------|-----------|-----------|
| ILA 检测不到 (debug hub not detected) | `fpga-bd-debug-clock` | `fpga-zynq-debug-toolchain` |
| ILA 触发不工作 | `fpga-zynq-debug-toolchain` | `fpga-bd-debug-clock` |
| JTAG 连不上 | `fpga-board-validation`（CAT-HW） | `fpga-validation-levels` |
| 比特流加载失败 | `fpga-board-validation`（CAT-BS） | `fpga-vivado-methodology` |
| DMA 数据传输异常 | `fpga-zynq-debug-toolchain` | `fpga-board-validation` |
| 寄存器读写异常 | `fpga-axi-lite-review` | `fpga-board-validation`（CAT-AX） |
| 上板数据与仿真不一致 | `fpga-board-validation`（L6） | `fpga-integration-failure-debug` |

### PS/软件问题

| 现象 | 主要 Skill | 辅助 Skill |
|------|-----------|-----------|
| BSP/C 代码编译不过 | `fpga-vitis-cli-build` | `fpga-official-doc-first` |
| XAxiDma API 不知道怎么调 | `fpga-official-doc-first` | `fpga-vitis-cli-build` |
| XSCT dow 失败 | `fpga-vitis-cli-build` | `fpga-zynq-debug-toolchain` |
| DMA 中断不触发 | `fpga-zynq-debug-toolchain` | `fpga-vitis-cli-build` |
| 不确定工具链版本 | `fpga-software-env-profile` | `fpga-vivado-preflight` |

### RTL 设计/审查问题

| 现象 | 主要 Skill | 辅助 Skill |
|------|-----------|-----------|
| 开始写新模块 | `fpga-module-owner-l1a` | `fpga-rtl-style` |
| 代码审查怎么查 | `fpga-rtl-review` | `fpga-rtl-style` |
| AXI-Stream 接口怎么设计 | `fpga-axis-review` | `fpga-rtl-style` |
| AXI-Lite 寄存器怎么设计 | `fpga-axi-lite-review` | `fpga-rtl-style` |
| 多时钟域怎么处理 | `fpga-cdc-review` | `fpga-rtl-review` |
| 命名风格不一致 | `fpga-rtl-style` | — |

### 项目管理问题

| 现象 | 主要 Skill | 辅助 Skill |
|------|-----------|-----------|
| 新项目启动 | `fpga-project-charter` | `fpga-project-acceptance` |
| 不确定验收标准 | `fpga-project-acceptance` | `fpga-validation-levels` |
| 平台冻结 | `fpga-platform-freeze` | `fpga-project-acceptance` |
| 不知道该不该跳级 | `fpga-validation-levels` | `fpga-iteration-economics` |

### 决策/方法论问题

| 现象 | 主要 Skill | 辅助 Skill |
|------|-----------|-----------|
| 不确定"试一下"的成本 | `fpga-iteration-economics` | — |
| 想猜引脚号/API/参数 | `fpga-official-doc-first` | `fpga-hw-pin-verify` |
| 不知道该用哪个 skill | **本 skill** | — |

## 按角色索引

> "我是 X 角色 → 开展工作前必须先读这些 skill"

| 角色 | 必读 Skills | 建议读 |
|------|-----------|--------|
| **rtl_implementer** | `fpga-module-owner-l1a`, `fpga-rtl-style`, `fpga-iteration-economics` | `fpga-sim-verification`, `fpga-axi-lite-review`, `fpga-axis-review`, `fpga-cdc-review` |
| **rtl_reviewer** | `fpga-rtl-review`, `fpga-rtl-style` | `fpga-axi-lite-review`, `fpga-axis-review`, `fpga-cdc-review` |
| **integration_verifier** | `fpga-integration-failure-debug`, `fpga-l1b-datapath-verify`, `fpga-sim-verification` | `fpga-validation-levels`, `fpga-axi-lite-review`, `fpga-axis-review` |
| **vivado_integrator** | `fpga-vivado-methodology`, `fpga-vivado-preflight`, `fpga-vivado-log-analysis` | `fpga-iteration-economics`, `fpga-platform-freeze` |
| **hardware_validator** | `fpga-board-validation`, `fpga-zynq-debug-toolchain`, `fpga-hw-pin-verify` | `fpga-bd-debug-clock`, `fpga-vitis-cli-build`, `fpga-iteration-economics` |
| **planner** | `fpga-project-charter`, `fpga-project-acceptance`, `fpga-validation-levels` | `fpga-platform-freeze`, `fpga-software-env-profile` |
| **orchestrator** | `fpga-iteration-economics`, `fpga-validation-levels`, `fpga-official-doc-first` | 全部 |

## 按验证阶段索引

> "项目在 L{X} 阶段 → 相关的 skill 是..."

| 阶段 | 主要 Skills |
|------|-----------|
| **L0** 静态审查 | `fpga-rtl-review`, `fpga-rtl-style`, `fpga-axi-lite-review`, `fpga-axis-review`, `fpga-cdc-review` |
| **L1a** 模块仿真 | `fpga-module-owner-l1a`, `fpga-sim-verification`, `fpga-formal-sanity` |
| **L1b** 数据通路闭环 | `fpga-l1b-datapath-verify`, `fpga-integration-failure-debug`, `fpga-sim-verification` |
| **L1c** 全系统仿真 | `fpga-integration-failure-debug`, `fpga-sim-verification`, `fpga-l1b-datapath-verify` |
| **L2-L4** 综合/实现/比特流 | `fpga-vivado-methodology`, `fpga-vivado-preflight`, `fpga-vivado-log-analysis`, `fpga-iteration-economics` |
| **L5-L6** 上板验证 | `fpga-board-validation`, `fpga-zynq-debug-toolchain`, `fpga-bd-debug-clock`, `fpga-hw-pin-verify`, `fpga-vitis-cli-build` |
| **L7** 资源/性能复盘 | `fpga-project-acceptance`, `fpga-vivado-methodology` |

## 通用护栏 Skills（所有阶段适用）

这些 skill 不是"怎么做"，而是"怎么做决策"——应在**每次技术决策前**优先参考：

| Skill | 何时触发 |
|-------|---------|
| `fpga-iteration-economics` | 任何会触发工具链操作的决策前 |
| `fpga-official-doc-first` | 任何需要引脚号/API/IP参数/器件特性的决策前 |
| `fpga-validation-levels` | 任何涉及验证级别推进/跳过的决策前 |
| **本 skill** | 任何"不知道该找哪个 skill"时 |

## 自动加载链路

当以下 skill 被调用时，orchestrator 应同时建议加载相关 skill：

```
fpga-module-owner-l1a → fpga-rtl-style, fpga-sim-verification, fpga-iteration-economics
fpga-board-validation → fpga-zynq-debug-toolchain, fpga-hw-pin-verify, fpga-bd-debug-clock
fpga-vivado-methodology → fpga-vivado-preflight, fpga-vivado-log-analysis, fpga-iteration-economics
fpga-vitis-cli-build → fpga-zynq-debug-toolchain, fpga-official-doc-first
fpga-integration-failure-debug → fpga-l1b-datapath-verify, fpga-sim-verification
```

## 语言策略

- 技能名/角色名：en
- 说明文字：zh
