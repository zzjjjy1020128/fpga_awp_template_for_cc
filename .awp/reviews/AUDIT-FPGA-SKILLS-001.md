---
task_id: "TASK-E001-028"
reviewer: "orchestrator"
result: "pass_with_notes"
date: "2026-06-15"
audit_id: "AUDIT-FPGA-SKILLS-001"
scope: "全部 25 个 fpga-* skills + 工作流 + 调用架构"
---

# FPGA Skills 全局审计报告

## 1. 执行摘要

22 个 fpga-* skill 整体质量参差。少数几个（`fpga-zynq-debug-toolchain`、`fpga-bd-debug-clock`、`fpga-integration-failure-debug`）已达到 `validated` 水平的内容密度，但多数仍是 checklist 骨架。**核心问题不是某个 skill 写得好不好，而是 skill 体系存在 6 类结构性缺陷**，导致模型在 skill 覆盖不到的决策分支上自行其是——绕过官方工具、忽略 FPGA 迭代成本、用软件思维替代硬件调试。

### 关键数字

| 指标 | 数值 |
|------|:--:|
| 总数 | 22 |
| 有完整 frontmatter 的 | 11 (50%) |
| 有显式调用触发条件的 | 7 (32%) |
| 含反模式/死胡同警告的 | 5 (23%) |
| 引用官方文档的 | 3 (14%) |
| 有跨 skill 引用的 | 2 (9%) |
| 内容密度达 validated 水平 | 4 (18%) |

## 2. 六类结构性缺陷

### 2.1 调用触发缺失（CRITICAL）

**症状**：大部分 skill 没有机器可检测的触发条件。模型需要在没有任何外部提示的情况下"想起"调用某个 skill。这在实践中失败率极高——模型倾向于用通用推理替代专用 skill。

**现状**：
- `fpga-vitis-cli-build` — "When to use: 在 CLI 环境下编译 Zynq baremetal C 代码"（太宽泛）
- `fpga-vivado-methodology` — "适用场景: vivado_integrator 执行 L2"（只有角色匹配，无场景触发）
- `fpga-hw-pin-verify` — "必须在写入 XDC 之前执行"（但模型写 XDC 时不会自动想起它）

**需要的触发机制**：
```
错误模式 → skill 自动匹配
"Vitis GUI 跑不通" → fpga-vitis-cli-build
"DMA 传输没数据" → fpga-zynq-debug-toolchain
"ILA 检测不到"  → fpga-bd-debug-clock
"综合报 CRITICAL WARNING" → fpga-vivado-log-analysis
"仿真结果不对" → fpga-integration-failure-debug
```

### 2.2 反模式/死胡同覆盖不足（CRITICAL）

**症状**：用户反馈的核心问题——"模型倾向于自己造轮子绕过问题"——根因在于 skill 没有明确列出"不要做什么"。模型在遇到阻力时，会调用其庞大的软件工程知识库，而这些知识在 FPGA 场景下往往是反模式。

**已做对的 skill（应推广）**：
- `fpga-zynq-debug-toolchain` §"常见死胡同" — 5 条，每条含"为什么是死胡同"和"正解"
- `fpga-bd-debug-clock` §"反模式" — `create_generated_clock` 不能替代物理连接
- `fpga-integration-failure-debug` §"禁止事项" — 4 条
- `fpga-rtl-style` §"禁止自清除脉冲"

**缺失反模式的 skill**：
- `fpga-vitis-cli-build` — 缺少"不要用裸机寄存器 poke 替代 XAxiDma 驱动"
- `fpga-board-validation` — 缺少"不要反复改 C 代码而不先看 ILA"
- `fpga-vivado-methodology` — 缺少"不要在 CW 未清零时进入实现"
- `fpga-sim-verification` — 缺少"不要在 TB 中 workaround DUT bug"

### 2.3 FPGA 领域特有约束缺失（HIGH）

**症状**：来自软件工程的模型不理解 FPGA 开发的几个关键约束，而 skill 体系没有系统性地传达这些约束。

**缺失的约束传达**：

| 约束 | 软件工程师的默认行为 | FPGA 正确行为 | 应在哪些 skill 强调 |
|------|-------------------|-------------|-------------------|
| 综合/实现耗时 10-30min | "改一行跑一次" | 批量修改、充分验证后再综合 | vivado-methodology, module-owner-l1a |
| 硬件调试工具（ILA）是主要手段 | "加 printf 定位" | 先用 ILA 看波形，C 代码是最后手段 | zynq-debug-toolchain, board-validation |
| 比特流一次生成成本高 | "CI/CD 自动部署" | 确认所有前置检查通过再生成 | vivado-methodology |
| 文档查证优先于试错 | "写代码试试看" | 查官方手册、确认引脚/寄存器地址 | hw-pin-verify, vitis-cli-build |
| 修改 RTL 需要全链回验 | "hotfix 上线" | L1a→L1b→L1c 全链重跑 | integration-failure-debug, validation-levels |

### 2.4 Skill 间互连缺失（HIGH）

**症状**：Skill 是 22 个孤岛。执行一个 skill 时，模型不知道有哪些相关 skill 应该同时参考。没有"如果你在 X，也应该看 Y 和 Z"的导航。

**需要建立的互连网络**：

```
fpga-module-owner-l1a
├── 必须引用: fpga-rtl-style, fpga-sim-verification
├── 建议引用: fpga-axi-lite-review, fpga-axis-review, fpga-cdc-review
└── 失败时引用: fpga-integration-failure-debug

fpga-board-validation
├── 必须引用: fpga-hw-pin-verify, fpga-zynq-debug-toolchain, fpga-bd-debug-clock
├── 建议引用: fpga-vitis-cli-build
└── 失败时引用: fpga-vivado-log-analysis（如果是 bitstream 问题）

fpga-vivado-methodology
├── 必须引用: fpga-vivado-preflight, fpga-vivado-log-analysis
├── 建议引用: fpga-rtl-style（综合前 lint）
└── 资源超限时引用: fpga-project-acceptance（检查合同阈值）

fpga-vitis-cli-build
├── 必须引用: fpga-zynq-debug-toolchain
├── 建议引用: fpga-software-env-profile
└── 编译失败时引用: 官方 BSP 文档（非写汇编）
```

### 2.5 决策分支缺失（MEDIUM）

**症状**：Skill 主要覆盖"正常路径"（checklist、步骤、命令），但在关键决策点缺少"如果 A 则 B，否则 C"的分支引导。这导致模型在异常情况下自由发挥。

**典型缺失决策点**：

| 决策点 | 应该有的分支 | 实际 skill 内容 |
|--------|------------|---------------|
| 仿真失败 → | DUT bug? TB bug? pipeline 对齐? → 不同路径 | 只有"不要 workaround" |
| CW 出现 → | 按 CW 类型分诊，不同 CW 不同动作 | vivado-log-analysis 有分类表，但后继动作未连接 |
| 上板失败 → | CAT-* 分诊表已定义（validation-levels），但 skill 间未连线 | board-validation 有 checklist 但无分诊决策树 |
| 编译失败 → | BSP 版本? API 变化? 链接顺序? 缺少 stub? | vitis-cli-build 有 API 差异说明但不够系统化 |
| ILA 无波形 → | 时钟? 触发条件? probe 连接? JTAG? | bd-debug-clock 覆盖了时钟诊断，但其他分支分散在不同 skill |

### 2.6 结构不一致（MEDIUM）

**症状**：22 个 skill 的文件结构和内容格式不统一，增加模型的认知负担。

| 结构元素 | 有多少 skill 有 |
|----------|:--:|
| YAML frontmatter（skill_id, status, source_basis） | 11/22 |
| "适用场景/When to use" 节 | 17/22 |
| Checklist（含 checkbox） | 13/22 |
| 代码/Tcl 示例 | 10/22 |
| 反模式/禁止事项 | 5/22 |
| 输出格式说明 | 10/22 |
| 语言规范 | 9/22 |
| 引用其他 skill | 2/22 |
| 引用官方文档 | 3/22 |

### 2.7 调用架构缺陷（CRITICAL）

当前三层调用路径全部依赖"人/模型记得调用"：

```
用户显式输入 /skill-name     → skill 被加载
orchestrator 决定 spawn agent  → agent 定义中的 skill 提示被注入
sub-agent 自行判断             → 当前上下文中的 skill 列表可见
```

**缺失的调用机制**：
1. **错误模式匹配**：当模型输出中出现特定错误模式（如 "xil_printf not found"、"ILA not detected"），应自动触发相关 skill
2. **Pre-action gate**：执行高风险操作前（如 `generate_bitstream`、`fpga -f`），应强制检查前置 skill（如 preflight）
3. **Post-action audit**：模型做出来源不明的技术决策时（如手写汇编替代 BSP API），应触发 skill 合规检查
4. **Skill chain**：一个 skill 执行完毕后，应自动建议/加载下一个相关 skill

## 3. 缺失的 Skills（7 个缺口）

### 3.1 `fpga-iteration-economics`（NEW — HIGH）
**目的**：让模型在做出任何技术决策之前，理解 FPGA 开发的成本模型。
**核心内容**：
- 各类操作的时间成本表（改 RTL 1min → 仿真 30s → 综合 10min → 实现 20min → 比特流 5min → 上板 5min）
- "小步快跑"策略在 FPGA 开发中的适用边界
- 什么时候"试一下"的成本可接受，什么时候必须"确认无误再动手"
- 批量化原则：能一次改完的不分两次综合

### 3.2 `fpga-official-doc-first`（NEW — HIGH）
**目的**：阻止模型在遇到未知 API/引脚/配置时的"自行猜测"行为。
**核心内容**：
- 强制规则：遇到以下情况必须先查官方文档，禁止猜测
  - 引脚号/IOSTANDARD
  - BSP API 函数签名和参数
  - IP 配置参数含义
  - 器件特性（如 Zynq-7000 AFI 寄存器只读）
- 文档查找路径（UGxxx, DSxxx, PGxxx, readthedocs, BSP include）
- 反模式：不查文档直接写代码/改配置/改约束

### 3.3 `fpga-vitis-bsp-troubleshoot`（NEW — MEDIUM）
**目的**：Vitis/BSP 编译和链接问题的系统化诊断。
**核心内容**：
- BSP 版本与 API 兼容性表
- 常见链接错误诊断（undefined reference, multiple definition）
- stub 函数最小集
- xaxidma.h API 版本差异速查
- 替代 Vitis GUI 的 CLI 工作流

### 3.4 `fpga-dma-debug`（NEW — MEDIUM）
**目的**：AXI DMA 数据通路问题的专项诊断。
**核心内容**：
- DMA 寄存器状态解读（DMASR, DMACR）
- Simple vs SG 模式差异
- 常见 DMA 问题速查表（tlast 不触发、MM2S 不发数据、S2MM 不收数据）
- DMA 复位序列验证
- Cache 一致性问题（DDR write → DMA read）

### 3.5 `fpga-register-map-verify`（NEW — MEDIUM）
**目的**：跨检查 C 代码中的寄存器地址与 RTL 地址译码器是否一致。
**核心内容**：
- 从 RTL `axil_slave_if` / `regs_top` 提取地址映射
- 从 C 代码 `#define` / BSP `xparameters.h` 提取地址
- 交叉比对自动化方法
- 常见地址映射错误模式（偏移量错误、位域定义不一致）

### 3.6 `fpga-pre-synth-checklist`（NEW — LOW）
**目的**：综合前的最后一道闸——确认所有可以快速检查的东西都检查过了。
**核心内容**：
- iverilog/verible 快速语法检查通过
- xdc_lint 无 CRITICAL
- 所有 RTL 文件 declared in project
- TOP 设置正确
- 无悬空端口

### 3.7 `fpga-skill-navigator`（NEW — META）
**目的**：不是传统的"怎么做"skill，而是"应该用哪个 skill"的导航器。
**核心内容**：
- 按症状索引："我看到 X 现象 → 应该用 skill A、B、C"
- 按角色索引："我是 rtl_implementer → 应该了解 skill X、Y、Z"
- 按阶段索引："项目在 L1a 阶段 → 相关的 skill 是..."
- 自动加载链路

## 4. 优先级排序

### P0 — 立即修复（影响每次决策正确性）

1. **建立 skill 调用触发机制** — 错误模式→skill 自动匹配
2. **补齐反模式/死胡同覆盖** — 8 个 skill 缺反模式
3. **新建 `fpga-iteration-economics`** — 所有决策的基础约束
4. **新建 `fpga-official-doc-first`** — 阻止模型猜测

### P1 — 下一轮迭代

5. **建立 skill 互连网络** — 每个 skill 增加 "Related Skills" 节
6. **统一 skill 结构** — frontmatter + 适用场景 + checklist + 反模式 + 输出 + 互连
7. **补齐决策分支** — 5 个关键决策点

### P2 — 后续完善

8. **新建 5 个专业 skill**（vitis-bsp-troubleshoot, dma-debug, register-map-verify, pre-synth-checklist, skill-navigator）
9. **结构一致性整治** — 补齐 11 个 skill 的 frontmatter
10. **官方文档引用** — 17 个 skill 缺少 doc references

## 5. 推荐执行方案

我建议分 3 个 phase 推进，每个 phase 产出可独立验证的改进：

**Phase A — 防御性护栏（1-2 个 session）**
- 在所有 22 个 skill 中补充"反模式/死胡同"节
- 新建 `fpga-iteration-economics` 和 `fpga-official-doc-first`
- 这直接解决用户观察到的"模型倾向于造轮子绕过问题"

**Phase B — 调用架构（1 个 session）**
- 为每个 skill 定义显式的触发条件（错误模式匹配规则）
- 为每个 skill 增加 "Related Skills" 互连节
- 新建 `fpga-skill-navigator`
- 更新 `SKILL_INDEX.md` 增加症状索引

**Phase C — 结构一致性 + 补齐（1-2 个 session）**
- 统一 11 个 skill 的 frontmatter
- 补齐决策分支
- 新建 5 个专业 skill
