# Session 记录

> Session ID: SESS-E001-OR-003
> 日期: 2026-06-07 ~ 2026-06-08
> 触发: 用户指定 / 从上一 session 断点继续

## Session Goal

从 IP 打包自动化出发，完成双硬件基座（ZCU102 + AX7010）的创建、验证与冻结，建立项目合同体系，
引入 `platform-freeze` 和 `vivado-preflight` 两个 skill，并进行阶段性复盘。
最终状态：L4 比特流就绪，双基座 frozen，准备 L5 上板冒烟测试。

## Tasks Worked

| Task ID | Agent | 状态变化 | 产出 |
|---------|-------|---------|------|
| TASK-E001-016 | planner | ready → done | `docs/hardware_base_spec.md`, `docs/project_contract.md` |
| TASK-E001-017 | vivado_integrator | ready → done | `vivado/ip/axil_2d_shift_v1_0/`, `RUN-E001-IP-PACK-001.md` |
| TASK-E001-015 | vivado_integrator | blocked → done | ZCU102 BD + synth + impl + bitstream + freeze |
| TASK-E001-018 | vivado_integrator | ready → done | AX7010 BD + 50MHz clock fix + synth + impl + bitstream + freeze |
| TASK-E001-005 | rtl_implementer | in_progress → done | (状态修复：L0/L1 全部 pass 但 status 未更新) |

## Key Decisions

1. **AWP-0001** : 平台层冻结策略 —— 稳定 BD shell + 标准插槽 + adapter 模式
2. **AWP-0002** : 硬件基座冻结协议 —— `.awp/platform/*.yaml` 作为 AWP 一等公民
3. **AWP-0003** : 项目合同自洽性分析 —— 识别 5 个缺口，修复 3 个，记录 6 个待改进
4. **AX7010 降频 50 MHz** : xc7z010-1 @100MHz 时序失败（shift_addr_gen DSP 路径 16-20 级组合逻辑超标），降频后 WNS +6.117 ns
5. **ILA 探针策略** : BD 中直连 ILA 探针到 AXI 接口个别信号会破坏 interface connection，正确做法是 RTL mark_debug + 综合后自动关联
6. **GUI/Tcl 互斥规则** : Vivado 不支持同一工程并发访问，保存顺序决定最终状态
7. **`make_wrapper` 可用** : SESS-E001-OR-002 的结论被证伪，两次调用均成功
8. **合同驱动模型** : 从"任务驱动"升级到"合同驱动"——Contract(平台+环境+验收) → Task → 验证

## Files Read

- `.awp/tasks/TASK-E001-001 ~ TASK-E001-018.yaml`
- `.awp/sessions/SESS-E001-OR-001.md`, `SESS-E001-OR-002.md`
- `.awp/handoffs/HO-E001-008-001.md`
- `rtl/axil_2d_shift.sv` + 全部 7 个子模块
- `docs/architecture_v2_block_design.md`, `docs/architecture.md`
- `.awp/decisions.md`, `.awp/workspace_manifest.json`
- `.awp/schemas/task.schema.json`, `workspace_manifest.schema.json`
- `scripts/validate_awp.py`, `scripts/install_pre_commit.py`
- `.claude/skills/awp-retrospect.md`（参考 skill 格式）

## Files Modified/Created

### 新建（项目级）
- `.awp/platform/hw_base_zcu102_v1.0.yaml` —— ZCU102 平台清单
- `.awp/platform/hw_base_ax7010_v1.0.yaml` —— AX7010 平台清单
- `docs/hardware_base_spec.md` —— 硬件基座规格书
- `docs/project_contract.md` —— 三份合同索引
- `docs/retrospective_ip_to_base.md` —— 阶段复盘报告
- `.awp/templates/software_env_profile.template.md`
- `.awp/templates/acceptance_contract.template.md`
- `.claude/skills/platform-freeze.md` —— 平台冻结 skill
- `.claude/skills/vivado-preflight.md` —— Vivado 环境预检 skill
- `constraints/base_timing.xdc`, `constraints/base_physical.xdc` —— ZCU102 约束
- `constraints/ax7010_base_timing.xdc`, `constraints/ax7010_base_physical.xdc` —— AX7010 约束
- `vivado/ip/axil_2d_shift_v1_0/` —— IP 打包输出
- `vivado/shift_2d_ax7010_260608/` —— AX7010 Vivado 工程
- `vivado/shift_2d_zcu102_260606/CHANGELOG.md`
- `vivado/shift_2d_zcu102_260606/bd_export/hw_base_bd.tcl`

### 修改
- `CLAUDE.md` —— 新增 G9（平台合同管理），更新 B1（平台加载）
- `.awp/workspace_manifest.json` —— `platform` → `platforms[]` 注册双基座
- `.awp/schemas/workspace_manifest.schema.json` —— 新增 `platforms` 字段
- `.awp/schemas/task.schema.json` —— 新增 `target_platform` 字段
- `.awp/templates/task.template.yaml` —— 新增 `target_platform`
- `.awp/decisions.md` —— 新增 AWP-0001, AWP-0002, AWP-0003
- `.awp/tasks/TASK-E001-005/015/016/018.yaml` —— 状态更新
- `docs/architecture_v2_block_design.md` —— 新增 §0 平台分层策略

## Commands Run

```text
python scripts/validate_awp.py --sync (多次)
python scripts/validate_awp.py (多次)
python scripts/validate_awp.py --gate-check (多次)
python scripts/install_pre_commit.py
python -c "import yaml" (环境检查)

MCP Vivado:
  start_session (多次, tcl mode)
  open_project → open_bd_design → validate_bd_design
  create_bd_cell (ILA) → connect_bd_net → save_bd_design
  make_wrapper → add_files (wrapper + constraints)
  launch_runs synth_1 → launch_runs impl_1
  write_bitstream
  ipx::package_project (IP 打包)
  write_bd_tcl (BD 导出)
  get_timing_report, get_critical_warnings
```

## Gate Check

- [x] `--gate-check` 退出码 0
- [x] 当前 task 的 target 以下无 pending level
- [x] 所有 GATE GAP 已修复（TASK-E001-015 L2/L3/L4 更新为 pass）

## Validation Status

| Level | Status | 备注 |
|-------|--------|------|
| L0: 静态审查 | pass | 架构文档 + RTL review |
| L1a: 模块级单元仿真 | pass | 全部 7 模块 |
| L1b: 数据通路闭环仿真 | pass | WRITE/READ/CONTROL |
| L1c: 全系统集成仿真 | pass | 247/247 assertions |
| L2: 综合 | pass | ZCU102 + AX7010 双平台 |
| L3: 实现与时序 | pass | ZCU102 WNS +5.636ns, AX7010 WNS +6.117ns |
| L4: 比特流生成 | pass | ZCU102 26.5MB + AX7010 2.0MB |
| L5: 板上冒烟测试 | pending | 下一阶段 |
| L6: 板上数据正确性 | pending | |
| L7: 性能/资源复盘 | pending | |

- [x] `python scripts/validate_awp.py` 通过（退出码 0）

## Issues Found

1. **GUI/Tcl 并发冲突** : Vivado GUI 保存覆盖了 MCP Tcl 的 ILA 修改，需重做。确立单写者规则。
2. **AX7010 100MHz 时序失败** : xc7z010-1 上 shift_addr_gen DSP 路径超标，降频 50MHz 解决。
3. **PS7 时钟属性命名差异** : Zynq-7000 用 `PCW_FPGA0_PERIPHERAL_FREQMHZ`，UltraScale+ 用不同属性名。
4. **ILA 探针 BD 直连破坏接口** : `connect_bd_net` 到 AXI 接口个别 pin 会导致 interface connection 被 override。
5. **GBK 编码残留** : workspace_manifest.json 和 ax7010 manifest 的 YAML read 触发 GBK 解码错误（ISS-E001-001 已知问题，validate_awp.py 有 fallback）。

## Handoff

- Next Task：L5 上板冒烟测试（AX7010 主力平台）
- Handoff File：`.awp/handoffs/HO-E001-018-001.md`（待创建）
- Gate Status 已填写：是
- 备注：双基座均已 frozen。软件环境合同 frozen。验收合同 L0-L4 pass，待 L5-L7。
