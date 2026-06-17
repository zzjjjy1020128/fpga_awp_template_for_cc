---
skill_id: SKILL-FPGA-VALIDATION-LEVELS
name: fpga-validation-levels
layer: FPGA-Method
status: local_adapted
source_basis:
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-15"
owner: human_owner
---

# FPGA 验证级别 L0-L7

## 级别定义

验证分 L0-L7 共 10 个级别（L1 拆分为 L1a/L1b/L1c 三个子级别），按严格程度递增：

| 级别 | 名称 | 含义 | 典型执行者 |
|------|------|------|-----------|
| **L0** | 静态审查 | 代码审查、lint 检查、CDC 审查、架构合规 | rtl_reviewer |
| **L1a** | 模块级单元仿真 | 单模块，单帧/单事务，定向测试 | rtl_implementer |
| **L1b** | 数据通路闭环仿真 | ≥2 个数据通路模块串联，含跨帧测试 | integration_verifier |
| **L1c** | 全系统集成仿真 | 完整系统，所有接口，多帧/多事务 | integration_verifier |
| **L2** | 综合 | Vivado synthesis 通过，无 CRITICAL WARNING | vivado_integrator |
| **L3** | 实现与时序 | 布局布线完成，时序收敛（WNS/WHS ≥ 0） | vivado_integrator |
| **L4** | 比特流生成 | bitstream 生成成功 | vivado_integrator |
| **L5** | 板上冒烟测试 | 比特流加载、时钟检测、基本 I/O 验证 | hardware_validator |
| **L6** | 板上数据正确性 | DMA 传输、golden 数据比对、ILA 证据 | hardware_validator |
| **L7** | 性能/资源复盘 | 资源占用、吞吐量、延迟、瓶颈分析 | process_owner |

## 门禁规则

### 递进要求

```
L0 → L1a → L1b → L1c → L2 → L3 → L4 → L5 → L6 → L7
```

低级别通过后才可进入高级别。**L1a → L1b → L1c 必须顺序通过**，不可跳过 L1b 直接进入 L1c。

### 数据通路闭环（L1b）时机

L1b 应在 3-4 个数据通路模块完成后立即进行，不可等所有模块完成才做。

L1b 按数据通路切片创建 task：
- **Write Path**: axis_input → frame_buf_mgr → (DDR write)
- **Read Path**: shift_addr_gen → frame_buf_mgr → axis_output
- **Control Path**: axil_slave_if+regs_top → ctrl_fsm → datapath stubs

### 阻断规则

| 门禁 | 阻断条件 | 阻断对象 |
|------|---------|---------|
| **L1b GAP** | 足够模块 ready 但无对应 L1b task | L1c/L2+ spawn、模块 task done |
| **L1c GAP** | L1b 未全部 pass | L2+ spawn |
| **L5 GAP** | B0 (debug infra) 未完成 → bitstream 无 ILA 探针 | L5/L6 spawn |
| **L6 GAP** | L5 未 pass 或 B2 (PS 软件) 未完成 | L6 spawn |
| **Cross-platform** | 主力平台 L5 未 pass | 备选平台 L5 spawn（WARN，不阻断） |

GAP 阻断**不阻止**：创建前置 task、执行 L1b 验证、module_owner 修复 issue、rtl_reviewer 审查、process_owner 流程修补。

### 上板门禁特性

- B0 (debug infra) 是 L5 前置，但 B0 自身不是独立验证级别
- 上板门禁是**平台作用域**的：L5 pass on AX7010 ≠ L5 pass on ZCU102
- 上板 task 的 L0-L4 统一为 `skip`，仅 L5/L6/L7 有效

## validation_status 字段

### 值语义

| 值 | 含义 |
|----|------|
| `pending` | 尚未验证 |
| `pass` | 已通过 |
| `fail` | 已失败（需关联 ISS issue） |
| `skip` | 对本 task 的 agent 类型不适用 |

### skip 规则

**合法 skip**：
- planner task：L1a+ 为 skip（架构师不做仿真/综合/上板）
- vivado_integrator task：L0-L1c 可为 skip（综合工程师不做前端验证）

**非法 skip（硬阻断）**：
- **rtl_implementer（module scope）+ L1b/L1c**：模块在数据通路闭环和全系统中的正确性尚未确认，`skip` 等于声称"不需要集成验证"。即模块级 L1a 已 pass，L1b/L1c 仍应为 `pending`，待更高级别 task 确认后由 orchestrator 更新为 `pass`。

### L1b/L1c 发现子模块 bug 时的回退规则

子模块 task 原本 status=done 且 L1a=pass，但 L1b/L1c 仿真暴露其缺陷时：
- 子模块 task 的 L1b 或 L1c 应设为 `fail`（标注失败级别），status 应从 `done` 回退到 `in_progress`
- **子模块 RTL 允许修改**——集成验证的目的就是发现单模块测试遗漏的 bug
- 修复后重新跑 L1a → L1b → L1c

## 反模式（禁止事项）

### ❌ "模块功能简单，L1b/L1c 设 skip"
```
rtl_implementer 的模块级 task 中 L1b/L1c 不得为 skip——模块在集成中的正确性尚未确认。
skip 仅适用于 planner/vivado_integrator 等非模块实现角色。
```
### ❌ "已经到 L3 了，前面应该都过了"
```
验证门禁不可跳级。即使 L3 实现通过，也必须确认 L0-L1c 全部 pass。
不做 gate check 就推进 = 基于未验证前提做决策。
```
### ❌ "上板失败 3 次了，再试一次"
```
各类别 CAT-* 有独立上限。超过上限 → 升级 human_owner，不继续无效迭代。
```

## 相关 Skills

- `fpga-iteration-economics` — 门禁的经济学基础（跳级的真实代价）
- `fpga-integration-failure-debug` — L1b/L1c 失败处理流程
- `fpga-board-validation` — L5/L6 上板失败分诊
- `fpga-project-acceptance` — 验收标准定义

## 验证失败升级规则

### 仿真验证（L1a/L1b/L1c）

```
integration_verifier 发现失败
  ├─ 1. 创建 ISS issue（.awp/issues/ISS-{exp}-{seq}.yaml）
  ├─ 2. orchestrator 分配给 suspected module_owner
  ├─ 3. module_owner 修复（优先排查 DUT）
  ├─ 4. integration_verifier 重验
  └─ 迭代控制：
       round 1-2：正常往返
       round 3：spawn rtl_reviewer 深度审查
       round > 3：停止迭代，status=blocked，请求 human_owner 介入
```

### 上板验证（L5/L6）

上板失败按类别分诊（各类别独立上限）：

| 类别 | 含义 | 上限 | 超限动作 |
|------|------|:--:|---------|
| **CAT-HW** | JTAG 链/电源/线缆/适配器物理问题 | 2 | → human_owner |
| **CAT-BS** | PS 启动失败/时钟异常/比特流加载失败 | 2 | → human_owner |
| **CAT-AX** | AXI-Lite 寄存器读写异常 | 2 | → vivado_integrator |
| **CAT-IL** | ILA 触发不工作/探针无信号/深度不足 | 2 | → vivado_integrator |
| **CAT-SW** | PS 软件 bug（DMA 描述符/buffer 对齐/cache） | 3 | → human_owner |
| **CAT-DT** | DMA 传输完成但数据异常 | 3 | → vivado_integrator 或 rtl_implementer |
| **CAT-RT** | ILA 证据确认的 RTL 逻辑 bug | 3 | → rtl_implementer（完整回修链） |

每次上板 session 失败必须一次性采集三类证据：**ILA 波形 + PS 日志 + 比特流版本**。缺少任意一项 → 不得关闭 session。

**CAT-RT 刹车**：CAT-RT 是最高成本路径，必须经 ILA 证据确认后才能发起 RTL 回修。未经 ILA 证实的 RTL 怀疑 → 硬阻断，human_owner 介入。
