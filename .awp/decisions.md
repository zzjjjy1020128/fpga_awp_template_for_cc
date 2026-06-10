# Architecture Decision Record (ADR)

本文件记录项目中的架构决策。每条决策标注所属层（L1=治理, L2=领域, L3=运行时）。

## 已有决策

| ID | 标题 | 层 |
|----|------|:--:|
| AWP-0001 | Platform freeze + BD shell/adapter pattern | L1 |
| AWP-0002 | Hardware base freeze protocol | L1 |
| AWP-0003 | Project contract self-consistency analysis | L1 |

## 决策格式

```text
Decision ID：AWP-NNNN
Date：YYYY-MM-DD
Context：决策背景和问题描述
Decision：做出的决策
Alternatives：考虑过的替代方案及为何未采用
Consequences：决策带来的影响（正面和负面）
Follow-up：后续需要关注的事项
```

---

## 决策列表

## AWP-0001: 平台层冻结策略 —— BD Shell + Adapter 模式

Decision ID：AWP-0001
Date：2026-06-07
Context：当前 architecture_v2_block_design.md 描述了完整的 Zynq BD 创建流程（PS7 + AXI Interconnect + DMA + ILA + axil_2d_shift），但缺少对"BD 稳定性"的明确立场。如果每次 custom IP 变化都让 Agent 自动修改 BD，会引入不可靠性和意外的平台级回归。

Decision：采用**稳定平台 BD + accelerator_shell 标准插槽 + wrapper/adapter 适配**的分层策略：

```
┌────────────────────────────────────┐
│  稳定平台 BD (frozen shell)         │  ← 仅平台级需求变化时修改
│  PS7 + Interconnect + DMA + ILA    │
│  提供标准插槽:                       │
│   - S_AXI (AXI-Lite, 32-bit)       │
│   - S_AXIS (AXI-Stream, 8-bit)     │
│   - M_AXIS (AXI-Stream, 8-bit)     │
├────────────────────────────────────┤
│  accelerator_shell 外部接口         │  ← 稳定，不随 custom IP 变化
│  (wrapper 模块的对外端口)            │
├────────────────────────────────────┤
│  custom IP (axil_2d_shift 等)      │  ← 快速迭代，内部随意改
│  通过 wrapper/adapter 适配插槽      │
└────────────────────────────────────┘
```

核心原则：
- 平台 BD 是冻结的、可复现的通用 shell，不是每次迭代的对象
- 平台的"通用性"不是自动适配所有 custom IP，而是提供标准插槽
- Custom IP 通过 wrapper/adapter 适配插槽，差异在 adapter 层消化
- BD 仅在平台级需求变化时修改（如新增 PS 外设、改变 DMA 位宽、调整时钟方案）

Alternatives：
- "每次让 Agent 自动改 BD"：不可靠，Agent 可能引入意外的连接错误或 IP 配置漂移
- "每个 custom IP 一个 BD"：维护成本高，平台级改进需要同步 N 个 BD

Consequences：
- 正面：BD 回归风险降至零；adapter 层隔离了平台稳定性和 IP 迭代速度；新 accelerator 接入只需写 adapter
- 负面：引入一层 adapter 间接性；adapter 本身需要维护
- 对当前项目：architecture_v2_block_design.md 中描述的 BD 即平台 BD；axil_2d_shift 直接适配标准插槽无需额外 adapter（接口天然匹配）

Follow-up：
- TASK-E001-014 产出的 architecture 文档应体现此分层
- TASK-E001-015 创建 BD 后应标记为"平台 BD v1.0"，后续 custom IP 变更不触发 BD 重建
- 如需第二个 accelerator，写 wrapper 而非修改 BD

---

## AWP-0002: 硬件基座冻结协议 —— AWP 协议感知

Decision ID：AWP-0002
Date：2026-06-07
Context：AWP-0001 确立了平台 BD 冻结策略，但 AWP 协议本身缺少"识别已冻结基座"的机制。后续 session 重新启动时，如果没有协议层面的记录，orchestrator 可能意识不到基座已冻结、重复 BD 修改或重新创建。

Decision：引入 AWP 平台清单（Platform Manifest）作为协议的一等公民。

具体措施：
1. `.awp/platform/hw_base_v1.0.yaml` —— 冻结基座的机器可读清单，包含：
   - 基座身份（版本、器件、状态）
   - Vivado 工程路径
   - 冻结 IP 清单
   - Accelerator 插槽定义
   - 约束文件清单（冻结/可修改分类）
   - 验证状态（综合/实现/时序/比特流）
   - 冻结规则（什么可改、什么不可改、怎么改）
2. `workspace_manifest.json` 新增 `platform` 字段，指向平台清单
3. Session 恢复时，orchestrator 读取 `workspace_manifest.json` → 检测 `platform.status == "frozen"` → 自动加载平台上下文
4. 未来 `validate_awp.py` 可扩展基座完整性检查（BD 文件存在性、约束文件存在性、IP repo 存在性）

Alternatives：
- 仅在 CLAUDE.md 中写死：不可靠，CLAUDE.md 是行为指令而非状态记录
- 仅在 decisions.md 中记录：机器不可读，无法自动化校验

Consequences：
- 正面：AWP 协议正式支持"基座已冻结"状态；后续 session 自动感知；基座变更可审计
- 负面：增加了一个需要维护的 YAML 文件；validate_awp.py 未来需要扩展

Follow-up：
- 扩展 `validate_awp.py` 增加 `--check-platform` 选项，校验基座文件完整性
- SessionStart hook 应考虑加载平台清单并打印基座状态
- 基座升版时同步更新平台清单

---

## AWP-0003: 项目合同自洽性分析 —— 已修复与未修复缺口

Decision ID：AWP-0003
Date：2026-06-08
Context：AWP-0002 引入了硬件基座合同，随后补全了软件环境合同和验收合同，形成三份合同的"项目合同"体系。在此基础上分析了 AWP 协议与合同体系的自洽性。

### 已修复的缺口

| # | 缺口 | 修复 |
|---|------|------|
| 1 | `workspace_manifest.schema.json` 不支持 `platforms` 字段 | 已添加 `platforms` 数组字段定义，支持多基座 |
| 2 | 单一 `platform` 对象无法支持多板卡 | 改为 `platforms[]` 数组，每个基座独立注册 |
| 3 | 平台清单 `hw_base_v1.0.yaml` 命名无板卡区分 | 重命名为 `hw_base_zcu102_v1.0.yaml` |

### 仍存在的缺口（已知，待后续解决）

| # | 缺口 | 影响 | 建议方案 |
|---|------|------|---------|
| 4 | **Task YAML 无 `target_platform` 字段** | 多平台时 task 不知道在哪个基座上执行 | 在 task.schema.json 中新增可选 `target_platform` 字段（TASK-E001-018 已手动添加作为先行试验） |
| 5 | **`validate_awp.py` 不检查平台清单** | 平台 YAML 文件缺失/损坏不会被发现 | 新增 `--check-platform` 选项：校验 platforms[] 引用的 manifest 文件存在性、平台必需字段完整性 |
| 6 | **SessionStart hook 不加载平台上下文** | 新 session 启动时不自动显示"当前有 N 个已冻结基座" | 在 SessionStart hook 中增加读取 `workspace_manifest.json` → `platforms[]` → 打印摘要 |
| 7 | **CLAUDE.md 无平台相关指令** | orchestrator 不知道何时创建平台清单、如何冻结 | CLAUDE.md 新增 "平台合同管理" 章节：冻结流程、多平台选择规则、基座修改纪律 |
| 8 | **合同状态机无自动化** | 三份合同的 `unknown→draft→candidate→frozen→revised` 状态转换依赖人工记忆 | 长期：合同状态由 `validate_awp.py --check-contracts` 审计；短期：在 SessionStart 中提醒当前状态 |
| 9 | **验收合同与 task validation_status 不同步** | `project_contract.md` 的验收状态表需手动维护，与 task YAML 中的 `validation_status` 可能不一致 | 中期：`validate_awp.py --sync` 自动从 task YAML 聚合验收状态到合同 |

### 设计原则

上述缺口按影响程度分三层处理：
- **阻断级**（#4, #5）：多基座场景必需，下个 session 前修复
- **体验级**（#6, #7, #8）：不影响正确性但影响可用性，逐步修复
- **增强级**（#9）：自动化同步，可在流程稳定后实施

Consequences：
- #4（target_platform）在 TASK-E001-018 中先行试验，验证可行后正式加入 schema
- 当前双基座场景（ZCU102 + AX7010）可通过 task notes 和命名约定手动区分，不阻塞工作
- 每次 session 启动时打印"当前可用基座"可大幅改善 orchestrator 的上下文恢复效率
