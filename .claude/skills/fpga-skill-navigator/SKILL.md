---
skill_id: SKILL-FPGA-SKILL-NAVIGATOR
name: fpga-skill-navigator
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-16"
owner: human_owner
---

# FPGA Skill 导航器

> **触发（强制）**：模型在 FPGA 开发中遇到任何不确定"该用哪个 skill"的情况时，先查此导航器。

完整生命周期定义见 `METHODOLOGY.md` §2。

## 按 Phase 索引（推荐首选）

> "项目在哪个 Phase → 有哪些可用 skill"

### Phase 0: 项目启动
`fpga-project-charter`、`fpga-project-acceptance`

### Phase 1: 架构设计
`fpga-validation-levels`、`fpga-software-env-profile`

### Phase 2: RTL 设计与单元验证
**设计**：`fpga-module-owner-l1a`、`fpga-rtl-style`
**审查**：`fpga-rtl-review`、`fpga-cdc-review`、`fpga-axi-lite-review`、`fpga-axis-review`
**验证**：`fpga-sim-verification`、`fpga-formal-sanity`

### Phase 3: 集成验证
`fpga-l1b-datapath-verify`、`fpga-integration-failure-debug`

### Phase 4: 硬件实现
`fpga-vivado-preflight`（操作前必调）、`fpga-vivado-methodology`、`fpga-vivado-log-analysis`、`fpga-platform-freeze`、`fpga-bd-debug-clock`、`fpga-host-env-detect`

### Phase 5: 上板验证
`fpga-board-validation`（烧录前必调）、`fpga-zynq-debug-toolchain`（ILA 前必调）、`fpga-hw-pin-verify`、`fpga-vitis-cli-build`

### Phase 6: 收尾复盘
`fpga-iteration-economics`、`awp-retrospect`、`fpga-project-acceptance`

### 横向（跨 Phase 通用）
`fpga-host-env-detect`、`fpga-official-doc-first`、`fpga-skill-navigator`（本 skill）、`fpga-validation-levels`

### 治理（AWP-Core）
`awp-task-bootstrap`、`awp-session-close`、`awp-state-audit`、`awp-retrospect`

---

## 按症状索引

> "我看到 X 现象 → 应该用这些 skill"

### 仿真/验证问题

| 现象 | 主要 Skill | 辅助 Skill |
|------|-----------|-----------|
| 仿真失败，不确定是 DUT bug 还是 TB bug | `fpga-integration-failure-debug` | `fpga-sim-verification` |
| 需要写 testbench | `fpga-sim-verification` | `fpga-module-owner-l1a` |
| L1b/L1c 失败需要定位模块 | `fpga-integration-failure-debug` | `fpga-l1b-datapath-verify` |
| 控制 FSM 死锁/卡死 | `fpga-formal-sanity` | `fpga-integration-failure-debug` |

### Vivado 工具链问题

| 现象 | 主要 Skill | 辅助 Skill |
|------|-----------|-----------|
| 综合报 CRITICAL WARNING | `fpga-vivado-log-analysis` | `fpga-vivado-methodology` |
| 时序不收敛 | `fpga-vivado-methodology` | `fpga-vivado-log-analysis` |
| 不确定能不能开始综合 | `fpga-vivado-preflight` | `fpga-iteration-economics` |

### 上板/硬件问题

| 现象 | 主要 Skill | 辅助 Skill |
|------|-----------|-----------|
| ILA 检测不到 | `fpga-bd-debug-clock` | `fpga-zynq-debug-toolchain` |
| ILA 触发不工作 | `fpga-zynq-debug-toolchain` | `fpga-bd-debug-clock` |
| JTAG 连不上 | `fpga-board-validation`（CAT-HW） | `fpga-validation-levels` |
| 比特流加载失败 | `fpga-board-validation`（CAT-BS） | `fpga-vivado-methodology` |
| DMA 数据传输异常 | `fpga-zynq-debug-toolchain` | `fpga-board-validation` |
| 寄存器读写异常 | `fpga-axi-lite-review` | `fpga-board-validation`（CAT-AX） |

### PS/软件问题

| 现象 | 主要 Skill | 辅助 Skill |
|------|-----------|-----------|
| BSP/C 代码编译不过 | `fpga-vitis-cli-build` | `fpga-official-doc-first` |
| XSCT dow 失败 | `fpga-vitis-cli-build` | `fpga-zynq-debug-toolchain` |
| 不确定工具链版本 | `fpga-software-env-profile` | `fpga-vivado-preflight` |

### RTL 设计/审查问题

| 现象 | 主要 Skill | 辅助 Skill |
|------|-----------|-----------|
| 开始写新模块 | `fpga-module-owner-l1a` | `fpga-rtl-style` |
| 代码审查怎么查 | `fpga-rtl-review` | `fpga-rtl-style` |
| AXI-Stream 接口怎么设计 | `fpga-axis-review` | `fpga-rtl-style` |
| AXI-Lite 寄存器怎么设计 | `fpga-axi-lite-review` | `fpga-rtl-style` |
| 多时钟域怎么处理 | `fpga-cdc-review` | `fpga-rtl-review` |

### 项目管理问题

| 现象 | 主要 Skill | 辅助 Skill |
|------|-----------|-----------|
| 新项目启动 | `fpga-project-charter` | `fpga-project-acceptance` |
| 不确定验收标准 | `fpga-project-acceptance` | `fpga-validation-levels` |
| 平台冻结 | `fpga-platform-freeze` | `fpga-project-acceptance` |
| 不知道该不该跳级 | `fpga-validation-levels` | `fpga-iteration-economics` |

---

## 按执行者索引

> "我是 X → 开展工作前必读这些 skill"

| 执行者 | 必读 Skills | 说明 |
|--------|-----------|------|
| **orchestrator**（全视野执行者） | `fpga-iteration-economics`、`fpga-validation-levels`、`fpga-official-doc-first` | 自己做所有跨模块决策；skill 用于指导判断而非替代判断 |
| **vivado_integrator**（工具执行者） | `fpga-vivado-methodology`、`fpga-vivado-preflight`、`fpga-vivado-log-analysis` | 接受工程路径，执行综合/实现/比特流 |
| **hardware_validator**（工具执行者） | `fpga-board-validation`、`fpga-zynq-debug-toolchain`、`fpga-hw-pin-verify` | 接受比特流路径，执行烧录/ILA |
| **rtl_implementer**（模板生成） | `fpga-module-owner-l1a`、`fpga-rtl-style` | 接受接口规格，填充 RTL 模板 |
| **rtl_reviewer**（扫描器） | `fpga-rtl-review`、`fpga-rtl-style`、`fpga-cdc-review` | 接受 RTL + checklist，产出扫描报告 |
| **integration_verifier**（脚本生成） | `fpga-l1b-datapath-verify`、`fpga-integration-failure-debug` | 接受模块列表，生成仿真脚本 |
| **planner**（浏览器） | `fpga-project-charter`、`fpga-validation-levels` | 接受需求，产出架构文档草稿 |
| **process_owner**（浏览器） | `fpga-iteration-economics`、`awp-retrospect` | 接受项目状态，产出复盘报告 |

---

## 通用护栏 Skills（所有阶段适用）

这些 skill 不是"怎么做"，而是"怎么做决策"——应在每次技术决策前优先参考：

| Skill | 何时触发 |
|-------|---------|
| `fpga-iteration-economics` | 任何会触发工具链操作的决策前 |
| `fpga-official-doc-first` | 任何需要引脚号/API/IP参数/器件特性的决策前 |
| `fpga-validation-levels` | 任何涉及验证级别推进/跳过的决策前 |
| **本 skill** | 任何"不知道该找哪个 skill"时 |

## 自动加载链路

当以下 skill 被调用时，orchestrator 应同时加载相关 skill：

```
fpga-module-owner-l1a → fpga-rtl-style, fpga-sim-verification, fpga-iteration-economics
fpga-board-validation → fpga-zynq-debug-toolchain, fpga-hw-pin-verify, fpga-bd-debug-clock
fpga-vivado-methodology → fpga-vivado-preflight, fpga-vivado-log-analysis, fpga-iteration-economics
fpga-vitis-cli-build → fpga-zynq-debug-toolchain, fpga-official-doc-first
fpga-integration-failure-debug → fpga-l1b-datapath-verify, fpga-sim-verification
```
