---
skill_id: SKILL-FPGA-ITERATION-ECONOMICS
name: fpga-iteration-economics
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-15"
owner: human_owner
---

# FPGA 迭代经济学

> **触发**：模型做出任何会触发 FPGA 工具链（综合/实现/比特流生成/上板）的决策时，必须首先评估本 skill 中的成本模型。
> 也适用于模型在遇到问题后选择"修改代码试试"之前。

## 核心原则

**FPGA 不是软件。反馈循环以分钟计，不是秒。**

软件工程师的习惯——"改一行、跑一下、看结果、再改"——在 FPGA 开发中是灾难性的。每次综合需要 5-15 分钟，实现需要 10-30 分钟。不做验证就"试试"可能浪费数十分钟甚至数小时。

## 操作成本表

| 操作 | 典型耗时 | 可并行？ | 失败成本 |
|------|:--:|:--:|------|
| RTL 修改（1 行） | 30s | — | — |
| iverilog 编译检查 | 3-5s | ✓ | 几乎为零 |
| verible lint | 2-3s | ✓ | 几乎为零 |
| xdc_lint | 1s | ✓ | 几乎为零 |
| L1a 仿真（iverilog） | 5-30s | ✓ | 很低 |
| Vivado 综合（小型设计） | 5-15min | ✗ | 中等 |
| Vivado 实现（布局布线） | 10-30min | ✗ | 高 |
| 比特流生成 | 3-5min | ✗ | 低（但浪费前面的时间） |
| 上板验证（单次） | 5-15min | ✗ | 很高（可能烧坏板卡） |
| 全流程（RTL→上板） | 30-90min | ✗ | 极高 |

## 决策成本矩阵

当你想做某件事时，先查这个表：

| 你要做的事 | 最快验证方式 | 成本 | 何时做 |
|-----------|------------|:--:|------|
| 验证语法正确 | `iverilog -t null` | 3s | **每次 RTL 修改后立即** |
| 验证风格合规 | `verible-verilog-lint` | 2s | 每次 RTL 修改后 |
| 验证功能正确 | L1a 仿真 | 30s | 修改 ≥ 5 行或修改关键逻辑后 |
| 验证约束正确 | `xdc_lint` | 1s | 修改 XDC 后立即 |
| 验证可综合性 | Vivado 综合 | 15min | **仿真通过 + lint 通过后** |
| 验证时序 | Vivado 实现 | 30min | 综合通过后 |

## 批量化原则

**能一次综合验证的不分两次综合。**

- 如果你有 3 个 RTL 修改要验证 → **全部改完、仿真全过、一次综合**
- 如果你不确定哪个修改导致了问题 → **先用仿真隔离，不要把综合当成调试器**
- 如果综合失败了 → **先修所有 CW，再综合**

## 反模式（禁止事项）

### ❌ "改一行跑一次综合"
```
修改 RTL 1行 → 综合(15min) → 失败 → 修改 1行 → 综合(15min) → ...
```
累计耗时 30min+，而同样的修改用仿真验证只需 2×30s。

**正解**：修改 → iverilog 编译检查(3s) → 仿真(30s) → 确认通过 → 综合。

### ❌ "用综合当语法检查器"
Vivado 综合需要 10+ 分钟。iverilog 编译检查只需要 3 秒。不要在 Vivado 里发现分号忘写。

**正解**：`iverilog -t null -g2012 rtl/*.sv`（不产生可执行文件，只做 parse+elaboration）。

### ❌ "先上板再看对不对"
比特流生成 + 烧录 = 10+ 分钟。如果仿真没跑过，上板大概率也是错的。

**正解**：L1a 仿真通过 → L1b/L1c 仿真通过 → 综合 → 实现 → 上板。不可跳级。

### ❌ "加个 xil_printf 看看变量值"
在 FPGA 调试中，加 printf 需要：改 C 代码 → 编译 → 下载 ELF → 运行 → 看 UART。这个过程 3-5 分钟。而 ILA 已经在硬件上连着，直接看波形只需 30 秒。

**正解**：ILA > AXI-Lite 寄存器 dump > DMA 寄存器 dump > C 代码调试输出。

### ❌ "不知道这个引脚号，猜一个试试"
猜错的代价：综合(15min) → 实现(20min) → 比特流(5min) → 上板发现不工作(5min) = 45min。

**正解**：查板卡官方手册（2min）→ 交叉验证（1min）。耗时 3min，正确率 100%。

## 快速检查武器库

在发起任何耗时操作前，按此顺序使用快速检查：

```
1. iverilog -t null -g2012 rtl/*.sv     # 3s  — 语法+连接性
2. verible-verilog-lint rtl/foo.sv      # 2s  — 风格+可综合性
3. xdc_lint                              # 1s  — 约束冲突
4. iverilog -g2012 -o simv tb/*.sv rtl/*.sv && vvp simv  # 30s — 功能
5. Vivado 综合                           # 15min — 只有前 4 步全过才做
```

## 例外：何时"快速试一下"是可接受的

| 场景 | 理由 |
|------|------|
| 修改约束文件中的 1 个引脚号（已查手册确认） | 不需要重新仿真 |
| 修改 XDC 中的时钟周期 | xdc_lint + 综合即可 |
| ILA 触发条件微调 | 仅影响 Hardware Manager，不重新综合 |
| XSCT 脚本修改 | 不涉及 PL，秒级反馈 |
| 修改 C 代码中的测试参数 | 编译+下载 < 1min |

## 与 AWP 验证门禁的关系

本 skill 的成本模型是验证门禁（L0→L7）的经济学基础。跳级的真正代价不是"违反了规则"，而是**浪费了不可回收的时间**。

- L0 不 pass 就 L1a → TB 可能基于错误语法，仿真白跑
- L1a 不 pass 就综合 → 综合基于错误逻辑，15min 白花
- 无 xdc_lint 就实现 → 布局基于错误约束，30min 白花
- 无 preflight 就开 Vivado → "跑一半发现 license 过期"

## 相关 Skills

- `fpga-official-doc-first` — 查文档 vs 猜的决策经济学
- `fpga-vivado-preflight` — 开机前的成本确认
- `fpga-vivado-methodology` — 综合/实现的实际时间投入
- `fpga-module-owner-l1a` — 设计迭代的最小验证闭环
- `fpga-board-validation` — 上板验证的时间成本
- `fpga-zynq-debug-toolchain` — ILA vs printf 的调试成本对比

## 语言策略

- 原则说明：zh
- 命令/工具名：en
