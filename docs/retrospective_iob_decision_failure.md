# AWP 决策层缺陷复盘 —— IOB 81.6% 问题

> 触发事件：L2/L3 时序收敛 5 轮迭代优化了不该走外部 IOB 的路径
> 日期：2026-06-06
> 器件：xc7z020clg400-1 (Zynq-7000)

## 事件摘要

对 axil_2d_shift 设计进行 100MHz 时序收敛时，进行了 5 轮 RTL 优化迭代（消除取模、输出寄存器、IOB 打包、多周期路径、output_delay 调整），将 WNS 从 -28.3ns 改善到 +0.364ns。

**但根本问题是**：102 个信号（AXI-Lite 32-bit + AXI-Stream 8-bit + handshake signals）全部走外部 IOB，IOB 利用率 81.6%。xc7z020 是 Zynq-7000 器件，支持 PS AXI 口和内部 ILA 调试——不应有 102 个外部引脚。

5 轮迭代优化了一个架构方向错误的问题。正确的方向应该是 Block Design + PS AXI + ILA。

## 5 个决策层根因

### 根因 1：Task 模型把综合当作下游机械步骤

`TASK-E001-001 (planner)` 在 L0 之后状态=done，架构决策被"封闭"。`TASK-E001-012 (vivado_integrator)` 的 scope 限制它只能跑 Vivado 工具，不能质疑架构。综合/实现发现的问题（81.6% IOB）只能通过 ISS issue 回到 module_owner（RTL 修复），不能回到 planner（架构修正）。

**缺失的机制**：Task 之间没有"下游反馈上游"的路径。架构层面发现的问题无法向上流动。

### 根因 2：L2 之前无器件适配审查 gate

验证门禁 `L0→L1a→L1b→L1c→L2` 只管"低级通过才进高级"，没有任何 gate 问"这个设计适合目标器件吗"。如果进入 L2 前强制检查 IOB > 70%，5 轮迭代就不会发生。

**缺失的机制**：L2 入口应有器件适配检查——针对 IOB/BRAM/DSP 的资源报告。

### 根因 3：MCP 工具效率掩盖全局方向错误

MCP 使得"跑综合→看报告→改约束→重跑"的循环极其高效（每次 < 2 分钟）。每轮都有"局部进展"（WNS 改善 20%~69%），**局部进展的错觉掩盖了全局方向错误**。

**缺失的机制**：连续多轮针对同一问题类别（IOB timing）优化且改善递减时，应触发方向审查。

### 根因 4：Orchestrator 只看 WNS 不看 resource report

每次 L2/L3 跑完，orchestrator 只 grep "WNS"，不关注资源利用率报告。IOB 81.6% 从第一轮就存在，但从未被审视。

**缺失的机制**：orchestrator 接收 sub-agent 产出时，应审查资源报告中的关键指标。

### 根因 5：Orchestrator 没有"质疑方向"的职责定义

G1 定义了 orchestrator 的职责：任务拆分、进度汇报、gate 检查、合规归档。但没有"当执行结果与目标器件能力矛盾时，质疑当前方向并向 human_owner 提问"。

**缺失的机制**：orchestrator 的职责应包含"审核 sub-agent 产出是否与目标约束一致"。

## AWP 规范修复

| # | 问题 | 修复 | 位置 |
|---|------|------|------|
| 1 | 架构反馈路径缺失 | 无代码修改（需 Task 模型升级） | 记录为 v0.3 改进项 |
| 2 | L2 前无器件审查 | `validate_awp.py` 新增资源阈值检查 | 3b |
| 3 | 局部进展掩盖方向错误 | G4 迭代刹车规则 | 3c |
| 4 | Orchestrator 不审资源报告 | G1 职责扩展 | 3a |
| 5 | Orchestrator 不质疑方向 | G1 职责扩展 + pre-spawn guard | 3a + 3d |

## 经验沉淀

本次事件是 AWP 实验中第 5 次"执行中发现问题 → 分析根因 → 改进 AWP 规范"的循环。前 4 次：
1. B1 handoff 叙事覆盖 YAML → handoff Gate Status 表 + checklist
2. Skip 语义滥用 → skip 检查 + `--sync` auto-fix
3. G1 sub-agent 过度委托 → 跨文件接口变更规则
4. Issue 机制空转 → ISS coverage + detected_in_run 链接

因此次复盘本身也需要固化为 reusable skill（`awp-retrospect`），避免每次重新从零开始。
