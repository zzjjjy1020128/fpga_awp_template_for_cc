# 阶段复盘：IP 封装 → 双基座冻结

> 复盘范围：TASK-E001-016 ~ TASK-E001-018
> 阶段：L4 比特流就绪，L5 上板冒烟前
> Session：2026-06-07 ~ 2026-06-08
> 复盘类型：阶段性方法论复盘（非项目终期复盘）

---

## 1. 阶段概览

本阶段从"如何把 RTL 模块放进 Block Design"出发，最终建立了双基座（ZCU102 + AX7010）的冻结平台体系，并引入了三份合同的项目契约模型。

### 时间线

```
06-07 上午: TASK-E001-017 IP打包 → 全自动成功
06-07 中午: TASK-E001-016 硬件基座规格 → docs/hardware_base_spec.md
06-07 下午: ZCU102 BD 搭建(GUI) → ILA自动化 → make_wrapper → 综合 → 实现 → 比特流
06-07 傍晚: 平台冻结机制设计 → AWP-0001, AWP-0002 → .awp/platform/ 体系
06-07 晚间: 软件环境 + 验收合同体系 → docs/project_contract.md
06-08 上午: 项目合同自洽性分析 → AWP-0003 → 多平台 schema
06-08 中午: AX7010 基座创建 → 100MHz 时序失败 → 50MHz 收敛 → 双基座冻结
```

### 关键数字

| 指标 | ZCU102 | AX7010 |
|------|--------|--------|
| 综合时间 | ~39s | ~33s |
| 实现时间 | ~6min | ~2.3min |
| 比特流大小 | 26.5 MB | 2.0 MB |
| Setup WNS | +5.636 ns | +6.117 ns |
| 从零到冻结 | ~3 小时 | ~1 小时 |

---

## 2. 关键发现与教训

### 2.1 IP 打包：`ipx::package_project` 完全可自动化

**发现**：`ipx::package_project` 对 `.sv` 顶层文件给出 WARNING 但不影响功能。三个总线接口（s_axil/aximm, s_axis/axis, m_axis/axis）全部自动推断正确，包括 ASSOCIATED_BUSIF 和 ASSOCIATED_RESET 自动关联。

**教训**：之前对"Vivado Tcl 自动化不可靠"的认知过于泛化。`ipx::package_project` 是可靠的自动化路径；不可靠的是 `make_wrapper` 对含 PS 的 BD（**但本次 session 中 make_wrapper 也成功了**——见 2.3）。

### 2.2 ILA 探针连接：BD 层面直连会破坏接口

**发现**：在 BD 中使用 `connect_bd_net` 连接 ILA 探针到 AXI-Stream 接口的个别信号，会导致 Vivado 将 pin-level 连接视为 interface connection 的 override，从而破坏接口级连接。`validate_bd_design` 报 CRITICAL WARNING：`s_axis_tdata, s_axis_tvalid, s_axis_tlast` 等信号"not connected"。

**正确做法**：
- BD 层面：ILA 核保留、接入时钟、探针悬空（Vivado 自动 tie-to-0）
- RTL 层面：用 `(* mark_debug = "true" *)` 标记目标信号
- 综合后：Vivado "Set Up Debug" wizard 自动将 mark_debug 信号连接到 ILA 探针

**教训**：**BD 中的接口是原子单位**——不能部分连接。这条规则应该明确写入基座搭建指南。

### 2.3 `make_wrapper` 实际可用

**发现**：SESS-E001-OR-002 记录的"`make_wrapper` + `validate_bd_design` 对含 PS 的 BD 一致失败"——在这个 session 中被证伪。两次 `make_wrapper`（ZCU102 + AX7010）均成功，产物正确。

**推测原因**：SESS-E001-OR-002 的失败可能由于：
1. BD 中有未修复的 IP 配置错误
2. IP 目录缺失（`.gen/` 下 .xci 文件不存在）
3. Vivado 版本或环境特定问题

**教训**：**历史 session 的负面结论应该标记为"需复验"而非"已确认"**。AWP 的 handoff 机制应该区分"已验证的事实"和"观察到的现象"。

### 2.4 器件-时序的硬约束

**发现**：同一份 RTL（shift_addr_gen）在 xczu9eg-2 @100MHz 和 xc7z010-1 @100MHz 上表现完全不同：
- xczu9eg：时序收敛（WNS +5.636 ns）
- xc7z010-1：时序失败（WNS -0.980 ns，DSP 路径 16-20 级组合逻辑）

根因是 xc7z010-1 在更小 die 上路由延迟更差，DSP 乘法器组合路径无法在 10ns 内完成。

**教训**：**基座冻结时必须记录已验证的时钟频率**。平台清单的 `clock_reset` 字段中应明确标注"已验证的最高频率"和"降频原因"。

### 2.5 PS IP 时钟管理策略因器件而异

**发现**：
- PS8 (UltraScale+)：`CONFIG.PCW_FCLK0_PERIPHERAL_FREQ` 可 Tcl 设置
- PS7 (Zynq-7000)：`CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ` + 需同时调整 DIVISOR 分频比
- PS7 的某些属性（如 `PCW_FCLK0_PERIPHERAL_DIVISOR0`）设为"disabled"无法 Tcl 修改，但 Vivado 会自动重算 DIVISOR1

**教训**：**基座 Tcl 自动化脚本需要按 PS 类型分支**。不能假设 PS7 和 PS8 的属性名相同。

### 2.6 GUI vs Tcl 并发冲突

**发现**：Vivado GUI 和 MCP Tcl session 同时打开同一工程时，Tcl 的修改写入磁盘但 GUI 不会自动刷新；GUI 保存时会用内存中的旧状态覆盖 Tcl 的修改。本 session 中丢失了一次 ILA 核添加。

**教训**：这是 Vivado 的基本限制，不是 MCP 的问题。协作协议必须明确：**同一工程同一时间只允许一种访问模式**。

### 2.7 双基座场景暴露了 AWP 的单平台假设

**发现**：`workspace_manifest.json` 原本的 `platform` 是单数对象，无法表达"有两个已冻结基座"的事实。Task YAML 缺少 `target_platform` 字段来声明任务在哪个基座上执行。
AWP-0003 记录了 5 个仍然存在的自洽性缺口。

---

## 3. AWP 协议进化路径

### 本阶段新增的 AWP 资产

| 资产 | 引入原因 | 状态 |
|------|---------|:--:|
| `.awp/platform/` 目录 | 硬件基座独立于 task 管理 | **已实现** |
| `hw_base_*.yaml` 平台清单 | 机器可读的冻结基座描述 | **已实现** |
| `workspace_manifest.json#platforms[]` | 多基座注册 | **已实现** |
| `docs/project_contract.md` | 三份合同统一索引 | **已实现** |
| `software_env_profile.template.md` | 工具链状态模板 | **已实现** |
| `acceptance_contract.template.md` | 验收标准模板 | **已实现** |
| `decisions.md` ADR 体系 | AWP-0001, AWP-0002, AWP-0003 | **已实现** |
| `vivado/*/CHANGELOG.md` | 基座变更日志 | **已实现** |

### 从"任务驱动"到"合同驱动"

```
旧模型:  Task → Task → Task → 模糊的"做完"
新模型:  Contract (平台 + 环境 + 验收) → Task 在合同框架内推进 → 明确的门禁
```

合同驱动的关键行为变化：
- Session 开始：先检查合同状态 → 确认平台/工具/验收标准 → 再执行 task
- 平台变更：基座冻结后，BD 不随意修改；新平台需注册到 `platforms[]`
- 验收一致：所有 task 共享同一份验收标准，不各自定义

---

## 4. 当下应执行的 AWP 改进

以下按投入产出比排序，前三项高优先级。

### 4.1 [高] 补充 CLAUDE.md 平台合同管理章节

**现状**：CLAUDE.md 完全没有 "platform" "contract" "基座" 相关指令。
**影响**：下个 session 的 orchestrator 不知道要读 `workspace_manifest.json` → `platforms[]` → 加载平台上下文。
**做法**：在 CLAUDE.md 的 Session 恢复协议（B1）中增加平台加载步骤；新增 G9 "平台合同管理" 章节。

### 4.2 [高] Task YAML 增加 `target_platform` 字段

**现状**：TASK-E001-018 手动写了 `target_platform` 但 schema 不支持，validate 不校验。
**影响**：多基座场景下 task 不知道在哪个板子上执行，可能跑错基座。
**做法**：
1. `task.schema.json` 增加可选的 `target_platform` 字段
2. `validate_awp.py` 校验 target_platform 值是否在 `workspace_manifest.json#platforms[].id` 中存在
3. 更新 `task.template.yaml`

### 4.3 [高] `validate_awp.py` 增加 `--check-platform` 选项

**现状**：validate 不检查 `.awp/platform/*.yaml` 的存在性和内容完整性。
**影响**：平台清单损坏不会被发现。
**做法**：
1. 新增 `--check-platform` flag
2. 检查 `workspace_manifest.json#platforms[]` 引用的 manifest 文件是否存在
3. 检查 manifest 必需字段（id, status, target.part, vivado_project.path, frozen_ip, slots）
4. 可合并到默认 validate 流程或作为独立检查

### 4.4 [中] SessionStart hook 打印平台状态

**现状**：SessionStart hook 不提及平台。
**影响**：新 session 启动时 orchestrator 对平台状态无感知。
**做法**：修改 `scripts/session_skeleton.py` 或 hook 配置，在 SessionStart 输出中增加：
```
[AWP-GUARD] Platforms:
  HW_BASE_AX7010_v1.0  [FROZEN] xc7z010 @ 50MHz — 主力
  HW_BASE_ZCU102_v1.0  [FROZEN] xczu9eg @ 100MHz — 备选
```

### 4.5 [中] 平台级 Vivado 操作 SOP

**现状**：GUI vs Tcl 冲突、PS7 vs PS8 属性差异、ILA 探针策略等知识只存在于 session 上下文中。
**影响**：下次搭建新基座时可能重蹈覆辙。
**做法**：在 `docs/hardware_base_spec.md` 中增加 §11 "平台操作经验库"，记录：
- GUI/Tcl 互斥规则
- ILA 探针正确连接方法
- PS7 vs PS8 时钟配置差异
- 器件-频率匹配表

### 4.6 [低] Handoff 的 Gate Status 格式强制

**现状**：HO-E001-008-001 缺少 Gate Status 表，Guard 每次启动都报 WARNING。
**影响**：handoff 恢复时信息不完整。
**做法**：
1. `validate_awp.py` 的 handoff 检查中，Gate Status 缺失从 WARNING 提升为 ERROR（阻断 handoff close）
2. `handoff.template.md` 中 Gate Status 表标记为 required

### 4.7 [低] 合同状态机与 task 状态联动

**现状**：`project_contract.md` 的验收状态表需手动维护。
**影响**：task YAML 说 L4=pass 但合同说 L4=pending 可能发生。
**做法**：`validate_awp.py --sync` 时从所有 task YAML 的 validation_status 自动聚合到合同（中期改进，不阻塞）。

---

## 5. 经验原则提炼

本阶段沉淀了以下可复用的工程原则，应内化到 AWP 工作流中：

| # | 原则 | 触发场景 |
|---|------|---------|
| 1 | **冻结比自动化更可靠** | BD 创建不要追求 Tcl 全自动，GUI 做一次冻结即可 |
| 2 | **接口是原子单位** | BD 中不要拆分 AXI 接口的个别信号 |
| 3 | **历史负面结论需复验** | 引用之前 session 的 "X 不工作" 前先跑一遍 |
| 4 | **器件-频率-时序是硬约束** | 换器件必重验时序，不假设"同 RTL 同频率能过" |
| 5 | **PS IP 属性因代际而异** | PS7/PS8 的 Tcl 操作不可互换 |
| 6 | **单写者原则** | 同一 Vivado 工程不可同时被 Tcl 和 GUI 打开 |
| 7 | **合同先于任务** | 进入新阶段前先检查三份合同是否支持 |

---

## 6. 后续行动清单

| # | 行动 | 优先级 | 负责 |
|---|------|:--:|------|
| 1 | CLAUDE.md 新增 G9 平台合同管理 | 高 | orchestrator（本次） |
| 2 | `task.schema.json` 新增 `target_platform` | 高 | orchestrator（本次） |
| 3 | `validate_awp.py --check-platform` | 高 | 下个 session |
| 4 | SessionStart hook 打印平台 | 中 | 下个 session |
| 5 | `docs/hardware_base_spec.md` §11 经验库 | 中 | 下个 session |
| 6 | Handoff Gate Status 强制 | 低 | 需要时 |
| 7 | 验收合同自动同步 | 低 | 长期 |

---

> 复盘完成。下一步：执行 §4.1 和 §4.2 的高优先级改进，然后上板冒烟测试（L5）。
