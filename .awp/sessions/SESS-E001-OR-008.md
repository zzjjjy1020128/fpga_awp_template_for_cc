# Session 记录 — SESS-E001-OR-008

> 基于骨架 `SKELETON-2026-06-15-0f4b6ad9-117.md` 补全

## Session Goal

FPGA Skills 全局审计 + MCP-Skill 层级架构建立 + Vivado 全链路产物一致性验证（TASK-E001-030），通过 ISS-E001-011 实际 bug 修复驱动流程验证，建立主机环境检测机制。

## Tasks Worked

| Task ID | Agent | 状态变化 | 产出 |
|---------|-------|---------|------|
| TASK-E001-029 | rtl_implementer | `review → done` (sync 修正) | — |
| TASK-E001-028 | process_owner | perpetual | 技能审计报告 |
| TASK-E001-030 | vivado_integrator | `ready → in_progress → done` | RUN-E001-SYNTH/IMPL/BOARD-030, ISS-E001-013 |

## Files Read

- 全部 25 个 `.claude/skills/fpga-*/SKILL.md`
- `rtl/axis_output.sv`, `vivado/ip/axil_2d_shift_v1_0/src/axis_output.sv`
- `tb/tb_axis_output.sv`
- `.awp/schemas/review.schema.json`
- `.awp/schemas/task.schema.json`
- `.awp/templates/*`
- `scripts/validate_awp.py`
- `.awp/issues/ISS-E001-011.yaml`
- `CLAUDE.md`
- `vivado/shift_2d_ax7010_260608/design_1_wrapper.xsa`
- `.awp/platform/hw_base_ax7010_v1.0.yaml`

## Files Modified/Created

### Skills 审核与增强 (26 个 skill 全部触及)
- `.claude/skills/SKILL_INDEX.md` — 重写，25→26 个 skill，新增症状索引
- `.claude/skills/fpga-iteration-economics/SKILL.md` — **新建**
- `.claude/skills/fpga-official-doc-first/SKILL.md` — **新建**
- `.claude/skills/fpga-skill-navigator/SKILL.md` — **新建**
- `.claude/skills/fpga-host-env-detect/SKILL.md` — **新建**
- 全部 22 个已有 fpga-* skill — 补反模式、Related Skills、frontmatter
- `.awp/reviews/AUDIT-FPGA-SKILLS-001.md` — 审计报告

### MCP-Skill 层级架构
- `CLAUDE.md` — 新增 §3 MCP-Skill 层级关系 + §4.4 主机环境检测
- `fpga-board-validation/SKILL.md` — MCP gate 声明 + Zynq 流程
- `fpga-zynq-debug-toolchain/SKILL.md` — MCP gate + ltx 陷阱 + XSCT 路径
- `fpga-vivado-methodology/SKILL.md` — MCP gate 声明
- `fpga-vivado-preflight/SKILL.md` — 检查项 8→12（RTL 一致性、XSCT 路径、ltx、host_env）

### 主机环境检测
- `.awp/platform/host_env.yaml` — **新建** 主机环境描述符

### 产物一致性与验证机制
- `.awp/schemas/review.schema.json` — 修正 required 字段
- `scripts/validate_awp.py` — review validator 改为 schema 驱动
- `scripts/pre-commit` — 增加 auto-sync
- `.git/hooks/pre-commit` — 同步更新
- `scripts/install_pre_commit.py` — 消息更新

### Bug 修复 (ISS-E001-011)
- `rtl/axis_output.sv` — tlast 修正为 per-row
- `vivado/ip/axil_2d_shift_v1_0/src/axis_output.sv` — 同步修复
- `.awp/issues/ISS-E001-011.yaml` — 更新 fix details

### Vivado 全链路
- `.awp/runs/RUN-E001-SYNTH-030.md` — 综合记录
- `.awp/runs/RUN-E001-IMPL-030.md` — 实现+比特流+XSA 记录
- `.awp/runs/RUN-E001-BOARD-030.md` — 上板验证记录
- `.awp/issues/ISS-E001-012.yaml` — capture_en 缺陷
- `.awp/issues/ISS-E001-013.yaml` — 产物一致性问题汇总

### TASK YAML
- `.awp/tasks/TASK-E001-030.yaml` — 新建并执行完毕

## Commands Run

```text
python scripts/validate_awp.py --sync  (多次)
python scripts/validate_awp.py --gate-check
iverilog -t null -g2012 rtl/*.sv
iverilog -g2012 -o sim/tb_axis_output.vvp tb/tb_axis_output.sv rtl/axis_output.sv
vvp sim/tb_axis_output.vvp
mcp__vivado__start_session → open_project → run_synthesis → run_implementation
  → check_bitstream_readiness → generate_bitstream → write_hw_platform
mcp__vivado__start_session → open_hw_manager → program_device (首次，失败)
"G:/vivado2022.2/Vitis/2022.2/bin/xsct.bat" (PS init + FPGA programming)
mcp__vivado__start_session → connect_hw_server → get_hw_ilas → set_property PROBES.FILE → refresh
unzip design_1_wrapper.xsa ps7_init.tcl
xsdb connect attempt (failed — targets unavailable)
NoDefaultCurrentDirectoryInExePath registry check
```

## Key Decisions

1. **MCP = skills 的执行后端**：模型不得裸调 MCP 工具，必须经 skill gate
2. **主机环境描述符**：与 hw_base_*.yaml 对称，填补"主机端无描述符"的缺失
3. **per-row tlast**：axis_output tlast 从帧末改为每行末，兼容 SG DMA
4. **ltx probes file**：发现 debug_nets.ltx 不自动加载到 hw_device 的陷阱
5. **XSCT 路径**：XSCT 在 Vitis 目录，不在 Vivado/bin，记录到 host_env.yaml
6. **16 个 skill 从 candidate 升级到 local_adapted**（含项目实战反模式和互连）

## Issues Found

| Issue | 严重度 | 状态 |
|-------|:--:|:--:|
| review.schema.json required 字段包含 body 内容 | MEDIUM | 已修复 |
| pre-commit 不做 auto-sync | MEDIUM | 已修复 |
| 22 个 skill 中 17 个缺反模式节 | HIGH | 已修复 |
| 11 个 skill 缺 YAML frontmatter | MEDIUM | 已修复 |
| skill 互连缺失（孤岛） | HIGH | 已修复 |
| 主机环境无描述符 → XSCT 找不到 | CRITICAL | 已修复 |
| debug_nets.ltx 不自动关联 hw_device | HIGH | 已修复 |
| RTL 源歧义（rtl/ vs vivado/ip/） | HIGH | 已修复 |
| axis_output tlast 帧末→每行末 | MEDIUM | DUT 已修复, TB 定向测试待适配 |
| XSCT 需要 Vitis 安装（非 Vivado-only） | HIGH | 已记录到 host_env + preflight |

## Gate Check

- [x] `--gate-check` 退出码 0
- [x] 无 GATE GAP
- [x] TASK-E001-030: L2/L3/L4/L5 全部 pass

## Validation Status

| Level | Status | 备注 |
|-------|--------|------|
| L0: 静态审查 | skip | vivado_integrator task |
| L1a: 模块级单元仿真 | skip | |
| L1b: 数据通路闭环仿真 | skip | |
| L1c: 全系统集成仿真 | skip | |
| L2: 综合 | pass | 0 errors, 0 CW |
| L3: 实现与时序 | pass | WNS=+6.509ns |
| L4: 比特流生成 | pass | 2,083,852 B |
| L5: 板上冒烟测试 | pass | JTAG ✓, ILA 4 cores ✓ |
| L6: 板上数据正确性 | skip | |
| L7: 性能/资源复盘 | skip | |

- [x] `python scripts/validate_awp.py` 通过（退出码 0）

## Open Questions

- TB 定向测试 (TC01-TC11) 仍假设组合输出，需适配 DUT 输出寄存器延迟
- 完整的 DMA loopback test 需要编译 PS 软件 ELF（XSCT dow + ILA 捕获）
- rtl/ 与 vivado/ip/ 副本统一方案（删副本 vs 自动同步）

## Handoff
- Next Task：用户将在新 session 中启动实际项目 bug 修复（基于 ISS-E001-011/DMA loopback）
- Handoff File：见 Step 7
- Gate Status 已填写：是
