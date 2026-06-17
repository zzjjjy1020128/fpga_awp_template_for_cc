# 编排指南 —— Session 协议、调度规则与边界检查

> **角色定义和生命周期模型见 `METHODOLOGY.md`。** 本文档是操作层面的补充：Session 协议细节、工具链边界检查、G1-G9 调度规则。

---

## 1. Session 协议

### 启动（每次新 session）

1. SessionStart hook 自动运行 gate-check + 生成 session 骨架（`SKELETON-*.md`）
2. 检查 `.awp/handoffs/` 最新 handoff → 恢复上下文（已完成/未完成 task、关键文件、已知问题）
3. 检查 `.awp/platform/` 加载已冻结平台 → 打印可用平台摘要（器件、频率、验证状态）
4. **主机环境检测**：读取 `.awp/platform/host_env.yaml`。若不存在或 `status != active` → 触发 `fpga-host-env-detect` skill 生成/更新
5. **读 YAML，不信叙事**：以 task YAML 的 `validation_status` 为准做 gate re-validation → 若 handoff Gate Status 与 YAML 矛盾，以 YAML 为准
6. **Gate 硬阻断**：若 target 以下存在 `pending` level → 不得执行当前 task。先创建前置验证 task，设当前 task 为 `blocked`
7. 向用户汇报恢复结果

### 工作

1. spawn 子智能体前：task yaml 必须存在、gate gap 无阻断（`validate_awp.py --gate-check` exit 0）
2. **子智能体使用边界**：仅 spawn 做工具自动化/无状态探索/模板生成——不做跨模块决策（见 `METHODOLOGY.md` §3）
3. 子智能体返回后：`git diff` 审查所有改动（跨文件一致性、scope 外修改）
4. 每次 Edit/Write 后自动触发 `validate_awp.py --sync`
5. RTL 修改后触发对应级别审查（G3）

### 关闭

1. 补全 session 骨架 → 重命名为 `SESS-{exp}-OR-{seq}.md`
2. `python scripts/validate_awp.py` 退出码必须为 0
3. 判断是否需要 handoff（后续 task 未完成 → 创建 `HO-*.md`，含 Gate Status 表）
4. 提交（格式见 `.gitmessage`）

### 环境初始化 (B0)

1. 运行 `python -c "import yaml"` 检查 PyYAML
2. 如果 import 失败：`pip install -r requirements.txt`
3. 无 `make` 命令时，直接用 Python 替代运行校验和仪表盘命令

---

## 2. 调度规则 (G1-G9)

### G1: Spawn 决策

| 需求类别 | 执行方式 |
|---------|---------|
| 架构设计/模块接口定义 | orchestrator 自己做 |
| Bug 诊断与修复 | orchestrator 自己做 |
| 跨文件 RTL 修改 | orchestrator 自己做 |
| 代码审查最终判断 | orchestrator 自己做 |
| Vivado 综合/实现/比特流 | spawn `vivado_integrator`（工具自动化） |
| ILA 抓数/烧录 | spawn `hardware_validator`（工具自动化） |
| 搜索代码库/外部文档 | spawn explorer 子智能体（无状态探索） |
| 流程检查/复盘报告 | spawn `process_owner`（结构化汇总） |
| 重复性模板代码填充 | spawn `rtl_implementer`（模板生成） |
| 风格 checklist 扫描 | spawn `rtl_reviewer`（扫描器） |
| 集成仿真脚本生成 | spawn `integration_verifier`（脚本模板） |

**不确定时，orchestrator 自己做。** 子智能体的默认位置是"不用"，不是"用"。

### G2: Handoff 决策

- **同一 session 内**：orchestrator spawn 子智能体 A → 接收结果 → spawn 子智能体 B 时传入 A 的产出。**不需要 handoff**
- **Session 结束时**：后续 task 尚未完成 → 创建 handoff
- **Compact 触发时**：视为 session 边界，需要 handoff
- **所有 task 已完成**：不需要 handoff

### G3: Review 范围

| 文件类型 | Review | 执行者 |
|---------|:--:|------|
| 所有 RTL (`rtl/*.v` / `rtl/*.sv`) | 必须 | orchestrator 自己读 + spawn rtl_reviewer 做 checklist 扫描 |
| XDC 约束 | 必须 | orchestrator 审查 |
| architecture.md / verification_plan.md | 必须 | orchestrator 交叉审查 |
| 模块级 TB | 可选 | orchestrator 判断 |
| 集成 TB (L1b/L1c) | 必须 | orchestrator 交叉审查 |

### G4: 验证失败处理

**L1b/L1c 失败**：
```
创建 ISS issue → orchestrator 诊断根因 → RTL 修复 → L1a 回验 → 重跑
  round 1-2：正常往返
  round 3：深度审查
  round > 3：硬阻断 → human_owner 介入
```

**阻断规则**：
- 未创建 ISS issue 就反复修改 TB 重试 → 硬阻断
- 在 TB 中 workaround 绕过疑似 DUT bug → 硬阻断
- integration_verifier 擅自修改子模块 RTL → 硬阻断（除非 human_owner 授权）

**迭代刹车**：同一 ISS 连续 3 轮 WNS 改善 < 5% 且资源 > 75% → 阻断，orchestrator 写根因分析。

### G5: Task 粒度

- 默认：一个功能模块 = 一个 task
- 合并：强耦合的小模块 → 合并
- 上限：`required_outputs` ≤ 5 个文件
- L1b：按数据通路切片创建（Write/Read/Control）
- L1c：所有 L1b pass 后创建（`integration_scope: system`）

### G6: Scope 规则

| Agent | 允许编辑 | 禁止编辑 |
|-------|---------|---------|
| orchestrator | 全部文件 | — |
| rtl_implementer (template-fill) | 本模块 RTL + L1a TB | 其他模块、集成 TB、架构文档 |
| integration_verifier (script-gen) | L1b/L1c TB、run script | 子模块 RTL（除非 ≤5 行 + ISS 记录） |
| rtl_reviewer (scanner) | review report | 不直接改 RTL |
| vivado_integrator (tool) | vivado/、constraints/ | rtl/、tb/、docs/ |

### G7: Task 状态转换

| 转换 | 触发条件 |
|------|---------|
| `ready` → `in_progress` | orchestrator 开始执行 |
| `in_progress` → `review` | 模块 L1a pass，L1b/L1c 待集成确认 |
| `in_progress` → `blocked` | 依赖未完成 / GAP / 等待用户决策 |
| `review` → `done` | 全部 applicable level pass + acceptance 满足 + required_outputs 完整 |
| `review` → `in_progress` | 集成验证发现缺陷 → 回修 |

**done 准入条件**：
1. `acceptance` 全部通过
2. `required_outputs` 全部存在且完整
3. 所有 applicable level = pass
4. 无 open blocking issue
5. 模块 task L1b/L1c=pending → status 不得为 done（sync 自动修正为 review）

### G8: 项目完成

task_board 所有 task 均为 `done` 时：
1. orchestrator 主导 Phase 6 复盘
2. spawn process_owner 生成结构化复盘报告
3. 完成最终 session 记录和 handoff

### G9: 平台合同

- 平台冻结后 BD 不可修改，约束文件冻结
- accelerator IP 可独立迭代（RTL 变更 → BD 中 Upgrade IP）
- 基座升版需更新平台清单版本号 + CHANGELOG + ADR
- 同一 Vivado 工程不可同时被 GUI 和 MCP Tcl 打开

---

## 3. 工具链边界检查

FPGA 工具链是闭合环路。跨边界时必须执行检查。

### 边界 1：Vivado → Vitis

```
[ ] BD 完整性：ILA probe 悬空？Axi slot 连接？DMA→HP0 通路无断点？
[ ] XSA 新鲜度：晚于最后 BD/RTL 修改？用户确认"已重新生成"→ 丢弃所有旧 XSA
[ ] XSA ↔ bitstream 配套：从同一个 XSA 提取的 ps7_init.tcl 和 bitstream
```

### 边界 2：Vitis → 上板

```
[ ] PS 初始化仅用 XSCT（不用 Vivado Hardware Manager 的 program_hw_devices）
[ ] ILA 触发条件已设（不能是 eq*'hX don't-care）
[ ] 软件 Gate 可用（CPU 停 gate → arm ILA → 释放 gate → DMA 跑 → 捕获）
```

### 边界 3：用户声明"已重新生成"

最高优先级信号。立即：
1. 停止所有基于旧 XSA 的编译/测试
2. 从新 XSA 路径重建 BSP
3. 用新 XSA 的 ps7_init.tcl + bitstream 替换旧文件
4. 重新编译所有 C 代码
