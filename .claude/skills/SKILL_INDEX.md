# FPGA-AWP Skill Index

## AWP-Core（工程治理技能）

| Skill | 状态 | 用途 |
|-------|:--:|------|
| `awp-task-bootstrap` | stable | 创建 AWP 任务合同 |
| `awp-session-close` | stable | Session 关闭协议 |
| `awp-state-audit` | stable | AWP 工作区状态审计 |
| `awp-retrospect` | stable | AWP 流程复盘 |

## FPGA-Method（领域技能）

### RTL 设计

| Skill | 状态 | 来源 | 用途 |
|-------|:--:|------|------|
| `fpga-rtl-style` | candidate | SRC-FPGA-002, SRC-FPGA-003 | 统一 RTL 编码风格、命名、可综合写法 |
| `fpga-rtl-review` | candidate | SRC-FPGA-002 | L0 静态审查：lint、CDC、架构合规 |
| `fpga-module-owner-l1a` | candidate | SRC-FPGA-004, SRC-FPGA-009 | 模块 RTL 设计 + L1a 自证全流程 |

### 接口协议

| Skill | 状态 | 来源 | 用途 |
|-------|:--:|------|------|
| `fpga-axi-lite-review` | candidate | SRC-FPGA-005, SRC-FPGA-011 | AXI-Lite 从机接口审查 |
| `fpga-axis-review` | candidate | SRC-FPGA-005, SRC-FPGA-011 | AXI-Stream 接口审查 |
| `fpga-cdc-review` | candidate | SRC-FPGA-011 | CDC + 复位跨域审查 |

### 验证

| Skill | 状态 | 来源 | 用途 |
|-------|:--:|------|------|
| `fpga-sim-verification` | candidate | SRC-FPGA-004, SRC-FPGA-005, SRC-FPGA-006 | Testbench 架构、scoreboard、golden model |
| `fpga-l1b-datapath-verify` | candidate | SRC-FPGA-011 | L1b 数据通路闭环验证 |
| `fpga-formal-sanity` | candidate | SRC-FPGA-007 | 控制 FSM/握手协议轻量形式验证 |
| `fpga-validation-levels` | candidate | SRC-FPGA-011 | L0-L7 验证级别定义与门禁规则 |

### Vivado 工具链

| Skill | 状态 | 来源 | 用途 |
|-------|:--:|------|------|
| `fpga-vivado-methodology` | candidate | SRC-FPGA-001, SRC-FPGA-010 | L2-L4：综合、实现、时序、资源方法论 |
| `fpga-vivado-log-analysis` | candidate | SRC-FPGA-001, SRC-FPGA-011 | Vivado log 解析与错误分类 |
| `fpga-vivado-preflight` | candidate | SRC-FPGA-011 | Vivado 环境预检 |
| `fpga-bd-debug-clock` | candidate | SRC-FPGA-011 | Block Design 时钟调试 |

### 上板验证

| Skill | 状态 | 来源 | 用途 |
|-------|:--:|------|------|
| `fpga-board-validation` | candidate | SRC-FPGA-008, SRC-FPGA-011 | L5-L6：bitstream、ILA/VIO、golden compare |
| `fpga-hw-pin-verify` | candidate | SRC-FPGA-011 | 硬件引脚验证 |
| `fpga-zynq-debug-toolchain` | candidate | SRC-FPGA-011 | Zynq PS-PL 联合调试工具链 |

### 平台与集成

| Skill | 状态 | 来源 | 用途 |
|-------|:--:|------|------|
| `fpga-platform-freeze` | candidate | SRC-FPGA-011 | 平台基座冻结流程 |
| `fpga-integration-failure-debug` | candidate | SRC-FPGA-011 | 集成验证失败系统化调试 |
| `fpga-vitis-cli-build` | candidate | SRC-FPGA-011 | Vitis CLI 构建流程 |

### 项目管理

| Skill | 状态 | 来源 | 用途 |
|-------|:--:|------|------|
| `fpga-project-acceptance` | candidate | SRC-FPGA-011 | 项目验收合同模板 |
| `fpga-project-charter` | candidate | SRC-FPGA-011 | 项目章程模板 |
| `fpga-software-env-profile` | candidate | SRC-FPGA-011 | 软件环境配置模板 |

## 状态定义

| 状态 | 含义 |
|------|------|
| `candidate` | 从外部资料抽象而来，尚未项目验证 |
| `local_adapted` | 已按 AWP 改写，但未完整实战 |
| `validated` | 已在至少一个项目中成功使用 |
| `stable` | 已在多个项目中复用，进入长期技能库 |

## 来源分级

| 等级 | 含义 |
|:--:|------|
| A | 权威方法论/官方文档/项目实战，可直接信任 |
| B | 开源参考实现/agent workflow，需筛选改写 |
| C | 社区资料/未经验证的 skills，需审慎评估 |
