# FPGA-AWP Skill Index

## AWP-Core（工程治理技能）

| Skill | 状态 | 用途 |
|-------|:--:|------|
| `awp-task-bootstrap` | stable | 创建 AWP 任务合同 |
| `awp-session-close` | stable | Session 关闭协议 |
| `awp-state-audit` | stable | AWP 工作区状态审计 |
| `awp-retrospect` | stable | AWP 流程复盘 |

## FPGA-Method（领域技能）— 25 个

### 通用护栏（所有阶段/角色适用）

| Skill | 状态 | 反模式 | 用途 |
|-------|:--:|:--:|------|
| `fpga-host-env-detect` | candidate | ✓ | 主机环境检测——生成/维护 `host_env.yaml` |
| `fpga-iteration-economics` | candidate | ✓ | FPGA 迭代成本模型——每次工具链操作前的强制评估 |
| `fpga-official-doc-first` | candidate | ✓ | 官方文档优先——阻止猜测引脚/API/参数 |
| `fpga-skill-navigator` | candidate | — | 按症状/角色/阶段的 skill 导航器 |
| `fpga-validation-levels` | local_adapted | ✓ | L0-L7 验证级别定义、门禁规则和 skip 语义 |

### RTL 设计

| Skill | 状态 | 反模式 | 来源 | 用途 |
|-------|:--:|:--:|------|------|
| `fpga-rtl-style` | candidate | ✓ | SRC-FPGA-002, SRC-FPGA-003 | 统一 RTL 编码风格、命名、可综合写法 |
| `fpga-rtl-review` | candidate | ✓ | SRC-FPGA-002 | L0 静态审查：lint、CDC、架构合规 |
| `fpga-module-owner-l1a` | candidate | ✓ | SRC-FPGA-004, SRC-FPGA-009 | 模块 RTL 设计 + L1a 自证全流程 |

### 接口协议

| Skill | 状态 | 反模式 | 来源 | 用途 |
|-------|:--:|:--:|------|------|
| `fpga-axi-lite-review` | candidate | ✓ | SRC-FPGA-005, SRC-FPGA-011 | AXI-Lite 从机接口审查 |
| `fpga-axis-review` | candidate | ✓ | SRC-FPGA-005, SRC-FPGA-011 | AXI-Stream 接口审查 |
| `fpga-cdc-review` | candidate | ✓ | SRC-FPGA-011 | CDC + 复位跨域审查 |

### 验证

| Skill | 状态 | 反模式 | 来源 | 用途 |
|-------|:--:|:--:|------|------|
| `fpga-sim-verification` | candidate | ✓ | SRC-FPGA-004, SRC-FPGA-005, SRC-FPGA-006 | Testbench 架构、scoreboard、golden model |
| `fpga-l1b-datapath-verify` | candidate | ✓ | SRC-FPGA-011 | L1b 数据通路闭环验证 |
| `fpga-formal-sanity` | candidate | ✓ | SRC-FPGA-007 | 控制 FSM/握手协议轻量形式验证 |

### Vivado 工具链

| Skill | 状态 | 反模式 | 来源 | 用途 |
|-------|:--:|:--:|------|------|
| `fpga-vivado-methodology` | candidate | ✓ | SRC-FPGA-001, SRC-FPGA-010 | L2-L4：综合、实现、时序、资源方法论 |
| `fpga-vivado-log-analysis` | candidate | — | SRC-FPGA-001, SRC-FPGA-011 | Vivado log 解析与错误分类 |
| `fpga-vivado-preflight` | candidate | ✓ | SRC-FPGA-011 | Vivado 环境预检 |
| `fpga-bd-debug-clock` | local_adapted | ✓ | SRC-FPGA-011 | Block Design 时钟调试 + debug hub 诊断 |

### 上板验证

| Skill | 状态 | 反模式 | 来源 | 用途 |
|-------|:--:|:--:|------|------|
| `fpga-board-validation` | candidate | ✓ | SRC-FPGA-008, SRC-FPGA-011 | L5-L6：bitstream、ILA/VIO、golden compare |
| `fpga-hw-pin-verify` | local_adapted | ✓ | SRC-FPGA-011 | 硬件引脚验证——交叉核对官方手册 |
| `fpga-zynq-debug-toolchain` | local_adapted | ✓ | SRC-FPGA-011 | Zynq PS-PL 联合调试工具链 + ILA + XSCT |

### 平台与集成

| Skill | 状态 | 反模式 | 来源 | 用途 |
|-------|:--:|:--:|------|------|
| `fpga-platform-freeze` | candidate | ✓ | SRC-FPGA-011 | 平台基座冻结流程 |
| `fpga-integration-failure-debug` | local_adapted | ✓ | SRC-FPGA-011 | 集成验证失败系统化调试 |
| `fpga-vitis-cli-build` | local_adapted | ✓ | SRC-FPGA-011 | Vitis CLI 构建流程 + XSCT 下载 |

### 项目管理

| Skill | 状态 | 反模式 | 来源 | 用途 |
|-------|:--:|:--:|------|------|
| `fpga-project-acceptance` | candidate | ✓ | SRC-FPGA-011 | 项目验收合同模板 |
| `fpga-project-charter` | candidate | ✓ | SRC-FPGA-011 | 项目章程模板 |
| `fpga-software-env-profile` | candidate | ✓ | SRC-FPGA-011 | 软件环境配置模板 |

## 状态定义

| 状态 | 含义 |
|------|------|
| `candidate` | 从外部资料抽象而来，尚未项目验证 |
| `local_adapted` | 已按 AWP 改写，含项目实战反模式和互连 |
| `validated` | 已在多个项目中成功使用 |
| `stable` | 已在多个项目中复用，进入长期技能库 |

## 来源分级

| 等级 | 含义 |
|:--:|------|
| A | 权威方法论/官方文档/项目实战，可直接信任 |
| B | 开源参考实现/agent workflow，需筛选改写 |
| C | 社区资料/未经验证的 skills，需审慎评估 |

## 快速症状索引

> 不确定用哪个 skill？先查 `fpga-skill-navigator`。以下为高频入口：

| 症状/场景 | 主要 Skill |
|-----------|-----------|
| 仿真失败 | `fpga-integration-failure-debug` |
| 综合报 CW | `fpga-vivado-log-analysis` |
| 时序不收敛 | `fpga-vivado-methodology` |
| ILA 检测不到 | `fpga-bd-debug-clock` |
| ILA 触发不工作 | `fpga-zynq-debug-toolchain` |
| DMA 数据异常 | `fpga-zynq-debug-toolchain` |
| BSP 编译失败 | `fpga-vitis-cli-build` |
| 不知道该不该"试一下" | `fpga-iteration-economics` |
| 想猜引脚号/API | `fpga-official-doc-first` |
| 开始写新模块 | `fpga-module-owner-l1a` |
| 代码审查 | `fpga-rtl-review` |
| 上板验证 | `fpga-board-validation` |
| 不知道找哪个 skill | `fpga-skill-navigator` |
