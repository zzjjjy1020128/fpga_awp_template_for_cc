---
skill_id: SKILL-FPGA-RTL-REVIEW
name: fpga-rtl-review
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-002
validated_in_projects: ["E001"]
last_reviewed: "2026-06-10"
owner: human_owner
---

# FPGA RTL 代码审查 (L0)

## 适用场景
- rtl_implementer 完成 L1a 自证后的 L0 静态审查
- RTL reviewer 的标准化检查流程
- 集成前确认每个模块的代码质量

## 输入文件
- RTL 设计文件（`rtl/*.sv` / `rtl/*.v`）
- `docs/architecture.md` — 接口与架构规范
- 模块 task 合同（`.awp/tasks/TASK-*.yaml`）

## L0 审查检查清单

### 架构合规
- [ ] 模块接口与架构文档一致（端口名、宽度、方向）
- [ ] 参数列表与 task 合同的接口规范一致
- [ ] 模块功能覆盖 task acceptance 中的所有要求
- [ ] 未越权实现 scope 外的功能

### 可综合性与风格
- [ ] 使用 `always_comb`/`always_ff`（非 `always @*`）
- [ ] 阻塞/非阻塞赋值正确（comb=阻塞, ff=非阻塞）
- [ ] 无 `initial`/`#delay`/`$display` 在可综合模块中
- [ ] 遵循 `fpga-rtl-style` 编码规范
- [ ] 参数化适当（无硬编码 magic number）

### 复位与时序
- [ ] 复位策略合理（同步/异步选择有明确理由）
- [ ] 所有寄存器在复位后有已知初始值
- [ ] 无异步复位 + 异步置位混用
- [ ] 无复位置位冲突（同一寄存器不同条件置位）

### 状态机完整性
- [ ] 所有状态有定义次态（无隐式死锁）
- [ ] reset 后进入已知状态（非 X 或随机）
- [ ] `case` 有 `default` 分支（避免隐式 latch）
- [ ] 单向状态有退出条件

### CDC 初步（如多时钟域）
- [ ] 跨域信号已标注
- [ ] 同步器/异步 FIFO 已实例化
- [ ] 无直接跨域组合逻辑
- [ ] 详细 CDC 审查委托给 `fpga-cdc-review`

### 代码质量
- [ ] 信号命名含义清晰，无单字母信号名（除 clk/rst）
- [ ] 模块体 < 300 行（过大则建议拆分子模块）
- [ ] 注释只写 WHY，不写 WHAT（代码自解释）

## 工具辅助检查
- [ ] 条件允许时运行 `verible-verilog-lint <file>.sv`
- [ ] 条件允许时运行 `iverilog -t null -g2012 <file>.sv` 快速语法检查

## 审查输出
- `.awp/reviews/REV-{exp}-{task_seq}-RTL-{seq}.md`
- 含：每个 check item 的 pass/fail、违规等级（BLOCK/WARN/INFO）、修复建议、重审要求

## 与 AWP-Core 的关系
- L0 pass 是 task 从 review → done 的前置条件（violation 时 task 回退）
- RTL review 是 G3 规则的强制项——所有 RTL 文件必须经过 review
