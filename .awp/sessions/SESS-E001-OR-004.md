# Session 记录 — SESS-E001-OR-004

> Session ID: `02def2da-f698-4ef3-accc-0e82e8fb1eb9`
> 日期: 2026-06-08

## Session Goal

上板验证子工作流搭建 + ILA CLI 自动化攻克 + AWP 自愈修复

## Tasks Worked

| Task ID | Agent | 状态变化 | 产出 |
|---------|-------|---------|------|
| TASK-E001-014 | planner | in_progress → done | docs/architecture_v2_block_design.md |
| TASK-E001-019 | hardware_validator | ready → done | constraints/debug.xdc, board/hw_arch_ax7010.md, RUN-E001-BOARD-001 |
| TASK-E001-020~026 | — | 新建 ready | 8 个上板验证 task YAML |
| TASK-E001-023 | hardware_validator | ready → done | board/ps_dma_test/src/*.{c,h}, ELF 编译通过 |
| TASK-E001-021 | hardware_validator | ready → in_progress | RUN-E001-BOARD-003.md (L5 smoke, partial) |
| TASK-E001-019→023→021 | — | 依赖链修正 | 023 不再依赖 021，改为 021 依赖 023 |

## Files Read

- CLAUDE.md, .awp/templates/*, .claude/skills/*, docs/project_contract.md
- .awp/platform/hw_base_ax7010_v1.0.yaml
- rtl/axil_2d_shift.sv, rtl/regs_top.sv, rtl/axil_slave_if.sv

## Files Modified

- `scripts/validate_awp.py` — handoff 自动 resolve + task 事实完成检测 + handoff Gate Status 强制校验
- `CLAUDE.md` — B-G4 上板迭代模型 + 上板门禁 + spawn 决策
- `.awp/templates/board_validation.template.md` — 证据采集/失败分类/迭代轮次
- `.awp/templates/handoff.template.md` — Gate Status 强制必填标注
- `.claude/skills/board-validation/SKILL.md` — L5/L6 分拆清单
- `docs/board_validation.md` — 完整上板验证计划
- `docs/project_contract.md` — L5/L6 标准 + B-G4 规则
- `.awp/platform/hw_base_ax7010_v1.0.yaml` — v1.1 升版 (ILA 独立时钟 K17)
- `.awp/workspace_manifest.json` — 平台版本更新
- `.awp/tasks/TASK-E001-014.yaml` — 状态 → done
- `.awp/tasks/TASK-E001-019~026.yaml` — 新建 8 个上板 task
- `.awp/tasks/TASK-E001-021.yaml` — depends_on 修正
- `.awp/tasks/TASK-E001-023.yaml` — scope/notes/depends_on 修正
- `board/hw_arch_ax7010.md` — AX7010 硬件操作手册
- `board/hw_arch_zcu102.md` — ZCU102 硬件操作手册
- `board/ps_dma_test/src/*.{c,h}` — Vitis C 代码 (8 文件)
- `board/ps_dma_test/README.md` — 构建部署说明
- `board/ps_init.tcl` — XSCT 初始化脚本
- `constraints/debug.xdc` — ILA MARK_DEBUG 探针 + dbg_hub 时钟约束
- `constraints/ax7010_base_timing.xdc` — 添加 clk_debug_50m 时钟定义
- `constraints/ax7010_base_physical.xdc` — 添加 K17 引脚约束
- `.awp/handoffs/HO-E001-008-001.md` — auto-resolved (status → resolved)
- `.awp/runs/RUN-E001-BOARD-001.md`, `RUN-E001-BOARD-003.md` — 上板运行记录

## Key Decisions

1. **上板验证子工作流 B0-B4**：B0(debug infra)→B1(L5 smoke)→B2(PS SW)→B3(L6 data)→B4(L7 retro)
2. **B-G4 迭代模型**：上板失败按 CAT-HW/BS/AX/IL/SW/DT/RT 7 类分诊，独立轮次上限
3. **AX7010 平台 v1.1**：System ILA 时钟源改为板载 K17 50MHz 晶振，dbg_hub 时钟通过 `connect_debug_port` 连接
4. **Vitis 编译 CLI 自动化**：通过 XSCT 的 arm-none-eabi-gcc 直接编译 C 代码 → ELF 274KB
5. **XSCT `rst` 命令会清除 PL 配置**（DONE=0）——已验证

## Issues Found

### 🔴 ILA CLI 自动化（未攻克，当前 session 最主要缺口）

**现象**：Vivado HW Manager 始终报 "debug hub core was not detected"

**已排除的假设**：
- [x] FCLK 未运行 → 已通过 XSCT ps7_init 启动
- [x] hw_server 多客户端冲突 → 已测试完全隔离三层 hw_server
- [x] XSCT `rst` 清除 PL → 已确认并避开
- [x] BSCAN mask 不匹配 → C_USER_SCAN_CHAIN=1，已设置
- [x] JTAG 频率过高 → 降至 3MHz 无效
- [x] `connect_debug_port dbg_hub/clk` 命令错误 → 命令本身正确但修改不存活过实现

**已知工作路径**：Vitis GUI Run → Vivado HW Manager ILA
**CLI 待解问题**：Vitis GUI 的启动上下文/连接参数与 XSCT CLI 存在差异，具体差异点未定位

### ⚠️ L5 冒烟测试（部分完成）
- ✅ JTAG 链检测 (xc7z010)
- ✅ 比特流下载 (DONE=HIGH)
- ✅ XSCT PS 初始化 + ELF 下载运行
- ❌ Vivado ILA 访问（关联上述缺口）

## Gate Check

- [x] `--gate-check` 退出码 0
- [x] 当前 task 的 target 以下无 pending level

## Validation Status

| Level | Status | 备注 |
|-------|--------|------|
| L0: 静态审查 | pass | |
| L1a: 模块级单元仿真 | pass | |
| L1b: 数据通路闭环仿真 | pass | |
| L1c: 全系统集成仿真 | pass | |
| L2: 综合 | pass | AX7010 + ZCU102 |
| L3: 实现与时序 | pass | |
| L4: 比特流生成 | pass | BD v1.1 独立时钟 |
| L5: 板上冒烟测试 | pending | 硬件部分确认，ILA 待攻克 |
| L6: 板上数据正确性 | pending | |
| L7: 性能/资源复盘 | pending | |

## Open Questions

1. Vitis GUI Run 与 XSCT CLI 的具体启动差异是什么？（TCF/XSDB 协议？hw_server 参数？target reset 策略？）
2. `connect_debug_port dbg_hub/clk` 修改如何存活过 `opt_design` 的 debug core 重建阶段？
3. Vivado 2022.2 cs_server "CseXsdb slave type: 0" 是否需要特定 register file？

## Handoff
- Next Task：TASK-E001-021 (L5 冒烟测试 — ILA 部分待 Vitis GUI)
- Handoff File：`.awp/handoffs/HO-E001-OR-004-001.md`
- Gate Status 已填写：是
- 备注：ILA CLI 自动化是当前最关键的未攻克缺口。硬件/bitstream/C 代码全部就绪，仅差 Vivado cs_server 识别 debug core 这一步
