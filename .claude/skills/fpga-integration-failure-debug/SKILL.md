---
skill_id: SKILL-FPGA-INTEGRATION-FAILURE-DEBUG
name: fpga-integration-failure-debug
layer: FPGA-Method
status: local_adapted
source_basis:
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-15"
owner: human_owner
---

# 集成验证失败系统化调试

> 触发：L1b 或 L1c 仿真失败，需要定位根因并修复。

## 核心原则

**仿真失败可能是 DUT bug 而非 TB bug。不要在 TB 层面反复修补。** 这是 exp/E001 实验中最深刻的教训——旧架构在 TB 上花了大量时间 workaround，而真正的根因是两个子模块的计数器复位问题。

## 系统化调试流程

### 第一步：缩小范围（L1b 隔离）

如果 L1c 全系统仿真失败：
1. 识别失败涉及的数据通路（写？读？控制？）
2. 创建/运行对应切片的 L1b 验证（参考 `l1b-datapath-verify` skill）
3. 如果 L1b 通过 → 问题在顶层连接或全系统时序 → 跳到第三步
4. 如果 L1b 也失败 → 问题在该通路的子模块 → 进入第二步

### 第二步：定位故障模块

在 L1b 切片中，逐个检查：
1. **使能信号**：capture_en / shift_en 是否正确到达每个模块
2. **数据流**：从第一个模块的输出开始，逐级检查是否与预期一致
3. **计数器/状态机**：帧边界处是否正确复位
4. **pipeline 延迟**：跨模块信号是否在正确的周期对齐（BRAM 读延迟、寄存器延迟）

定位到具体模块后，创建 ISS issue（`.awp/issues/ISS-{exp}-{seq}.yaml`），包含：
- 失败 case 名称和时间戳
- 关键信号 expected vs observed
- 波形文件路径
- 根因假设
- suspected module

### 第三步：修复与回验

按 G6 分层规则决定修复策略：

| 情况 | 动作 |
|------|------|
| 修复明确且 ≤5 行（may-fix-with-record） | integration_verifier 直接修，创建 ISS 记录，触发 L1a 回验 + L1b 重验 |
| 修复不明确或涉及接口变更（must-report） | 创建 ISS，交 rtl_implementer |
| 无法定位根因（must-escalate） | ISS status=blocked，转 human_owner |

修复后的验证链：**L1a 回验 → L1b 重验 → L1c 重验（如涉及）**。不可跳过任何一级。

### 第四步：验证修复

- 重跑失败 case + 同一通路的其他 case（确保无 regression）
- 更新 ISS issue 的 `attempts` 记录
- 同一 issue 超过 3 轮仍未解决 → status=blocked，请求 human_owner

## 常见失败模式速查

| 症状 | 常见根因 | 检查 |
|------|---------|------|
| `tready stuck low` | capture_en 未到达 | ctrl_fsm 状态、顶层使能信号连接 |
| 首个输出像素位置错误 | 计数器帧间未复位 | `!shift_en` 时 row_cnt/col_cnt 是否归零 |
| `tdata=0xxx`（unknown） | BRAM 未写入或读地址错误 | 写通路独立验证 + 读地址起始值 |
| 数据正确但位置偏移 | pipeline 延迟对齐错误 | BRAM 读延迟 + zero_fill 寄存器级数 |
| 第二帧数据错误 | 跨帧状态残留 | 各模块在 done/shift_en 下降沿的复位逻辑 |

## 禁止事项

- ❌ 在未创建 ISS issue 的情况下反复修改 TB 重试
- ❌ 通过 TB workaround 绕过疑似 DUT bug（如跳过某些 case、修改预期值匹配错误输出）
- ❌ 跳过 L1a 回验直接跑 L1b（修改 RTL 后必须先自证模块级正确性）
- ❌ 同一 issue 超过 3 轮不升级

## 相关 Skills

- `fpga-l1b-datapath-verify` — 数据通路切片验证方法
- `fpga-sim-verification` — 仿真架构（scoreboard、golden model）
- `fpga-validation-levels` — L1b/L1c 门禁和失败升级规则
- `fpga-axi-lite-review` / `fpga-axis-review` — 接口协议级调试
- `fpga-rtl-style` — 常见跨模块 bug 模式（自清除脉冲等）
