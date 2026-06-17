# Acceptance & Constraints Contract

> 状态: `unknown | draft | candidate | frozen | revised`
> 冻结日期: `<YYYY-MM-DD>`
> 关联项目合同: `docs/project_contract.md`

## 1. 全局验收标准

| 验证级别 | 通过标准 | 证据要求 |
|---------|---------|---------|
| L0 | `<static review criteria>` | `<review report>` |
| L1a | `<unit sim criteria>` | `<sim log + run record>` |
| L1b | `<datapath sim criteria>` | `<sim log + run record>` |
| L1c | `<system sim criteria>` | `<sim log + run record>` |
| L2 | `<synthesis criteria>` | `<synth report + CW audit>` |
| L3 | `<implementation criteria>` | `<timing report + CW audit>` |
| L4 | `<bitstream criteria>` | `<.bit file>` |
| L5 | `<smoke test criteria>` | `<board run record>` |
| L6 | `<data correctness criteria>` | `<ILA capture / UART log>` |
| L7 | `<retrospective criteria>` | `<retro doc>` |

## 2. 时序目标

| 指标 | 目标值 | 备注 |
|------|--------|------|
| 主时钟频率 | `<MHz>` | |
| Setup WNS 最低要求 | `>= 0 ns` | |
| Hold WHS 最低要求 | `>= 0 ns` | |
| 时序模型 | `<post-synth estimate / post-route final>` | |

## 3. 资源预算

| 资源 | 预算 | 上限 | 备注 |
|------|------|------|------|
| LUT | `<N>` | `<max>` | |
| FF | `<N>` | `<max>` | |
| BRAM | `<N>` | `<max>` | |
| DSP | `<N>` | `<max>` | |
| IOB | `<N>` | `<max>` | |

## 4. 接口契约

### 4.1 基座接口（accelerator 必须遵守）

| 接口 | 协议 | 位宽 | 方向 | 备注 |
|------|------|------|------|------|
| SLOT_AXIL | `<protocol>` | `<width>` | — | |
| SLOT_AXIS_I | `<protocol>` | `<width>` | — | |
| SLOT_AXIS_O | `<protocol>` | `<width>` | — | |

### 4.2 AXI-Stream 语义约定

| 信号 | 语义 | 备注 |
|------|------|------|
| TLAST | `<row end / frame end / ...>` | |
| TUSER | `<frame start / ...>` | |
| TREADY/TVALID | `<standard backpressure>` | |

## 5. 失败处理规则

| 失败阶段 | 回退目标 | 负责人 | 最大重试 |
|---------|---------|--------|:--:|
| L1a fail | RTL 修复 | module_owner | 3 轮 |
| L1b/L1c fail | RTL 修复 → TB 修复 | module_owner → integration_verifier | 3 轮 |
| L2 fail | RTL 修复 / 约束调整 | rtl_implementer / vivado_integrator | 2 轮 |
| L3 fail | RTL 修复 / 约束调整 / 策略调整 | rtl_implementer / vivado_integrator | 3 轮 |
| L5/L6 fail | RTL / 基座 / 工具链 / 板卡排查 | hardware_validator → module_owner | 2 轮 |

## 6. 明确的 Out-of-Scope

- `<不在范围内的事项 1>`
- `<不在范围内的事项 2>`

## 7. 验收状态总览（自动/手动维护）

| 级别 | 状态 | 通过日期 | 证据 |
|------|:--:|------|------|
| L0 | pending | — | — |
| L1a | pending | — | — |
| L1b | pending | — | — |
| L1c | pending | — | — |
| L2 | pending | — | — |
| L3 | pending | — | — |
| L4 | pending | — | — |
| L5 | pending | — | — |
| L6 | pending | — | — |
| L7 | pending | — | — |
