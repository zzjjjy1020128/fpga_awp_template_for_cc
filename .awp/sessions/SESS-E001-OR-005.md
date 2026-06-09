# Session 记录 — SESS-E001-OR-005

> Session ID: `5039b977-7b1f-4695-aba3-013301bfccb9`
> 日期: 2026-06-09
> 从 SESS-E001-OR-004 handoff 继续

## Session Goal

基于 TASK-E001-021 (L5 冒烟) 的 ILA CLI 自动化缺口，攻克从 CLI 路径完成完整 PS+PL 联合调试闭环。收敛 UG908 标准流程，建立 Agent 自动化板级 debug 方法论。

## Tasks Worked

| Task ID | Agent | 状态变化 | 产出 |
|---------|-------|---------|------|
| TASK-E001-021 | hardware_validator | in_progress → done (L5 pass) | RUN-E001-BOARD-003.md, BD v1.2, debug.xdc 修复 |
| TASK-E001-024 | hardware_validator | ready → in_progress | step1-7.c, RUN-E001-BOARD-005.md, ILA 数据文件 |
| TASK-E001-027 | rtl_implementer | 新建 → in_progress | dbg_trigger_hub.sv, axil_2d_shift.sv(修改), ila_cross_trigger.tcl |

额外：AWP 规范维护 (6 个 ISS issue, 3 个 skill 重写, Hook 修复)

## Files Read

- `CLAUDE.md`, `.awp/templates/*`, `.awp/sessions/SESS-E001-OR-004.md`
- `.awp/handoffs/HO-E001-OR-004-001.md`
- `.awp/platform/hw_base_ax7010_v1.0.yaml`
- `.awp/tasks/TASK-E001-021.yaml`, `TASK-E001-024.yaml`
- `rtl/axil_2d_shift.sv`, `rtl/ctrl_fsm.sv`, `rtl/axis_input.sv`, `rtl/regs_top.sv`
- `rtl/axil_slave_if.sv`, `rtl/shift_addr_gen.sv`, `rtl/axis_output.sv`, `rtl/frame_buf_mgr.sv`
- `board/ps_dma_test/src/*.{c,h}`, `board/hw_arch_ax7010.md`
- `constraints/debug.xdc`, `constraints/ax7010_base_*.xdc`
- `vivado/.../ps7_init.tcl`, `vivado/.../xparameters.h`

## Files Modified/Created

### 新建
- `rtl/dbg_trigger_hub.sv` —— ILA cross-trigger hub (anchor event → ILA trig_in)
- `board/dma_minimal.s` —— 最小 DMA ARM 汇编 (已弃用)
- `board/ps_dma_test/src/step{1-7}.c` —— C+step 逐步验证
- `board/ps_dma_test/src/xil_printf_stub.c` —— xil_printf 空桩
- `board/ps_dma_test/src/stubs.c` —— libc 桩函数
- `board/vitis_flow.tcl` —— XSCT 两阶段启动脚本
- `board/ila_cross_trigger.tcl` —— ILA TRIG_IN_ONLY 自动化
- `board/ps_init_xsdb.tcl` —— XSDB PS 初始化
- `board/boot_image.bif` / `BOOT.BIN` —— SD 卡自启动 (已弃用)
- `.awp/runs/RUN-E001-BOARD-005.md` —— L6 验证记录
- `.awp/runs/RUN-E001-BOARD-005_ila{1,2}.ila` —— ILA 数据文件
- `.awp/issues/ISS-E001-005.yaml` —— xil_printf 阻塞 (resolved)
- `.awp/issues/ISS-E001-006.yaml` —— dow target APU→CPU核 (resolved)
- `.awp/issues/ISS-E001-007.yaml` —— AFI WRCHAN 地址错 (resolved)
- `.awp/issues/ISS-E001-008.yaml` —— System ILA 无 BASIC 触发 (open)
- `.awp/issues/ISS-E001-009.yaml` —— DMA HP0 端口阻塞 (open)
- `.awp/issues/ISS-E001-010.yaml` —— Hook 工作目录 (resolved)
- `.awp/tasks/TASK-E001-027.yaml` —— ILA cross-trigger 新 task
- `vivado/.../ila_ctrl_cross/` —— RTL ILA IP (ctrl, 2048 depth, TRIG_IN)
- `vivado/.../ila_data_cross/` —— RTL ILA IP (data, 4096 depth, TRIG_IN)

### 修改
- `rtl/axil_2d_shift.sv` —— 新增 ILA+dbg_hub 例化, fsm_state 编码
- `constraints/debug.xdc` —— 移除无效 create_generated_clock
- `constraints/ax7010_base_physical.xdc` —— K17→U18 引脚纠正
- `constraints/ax7010_base_timing.xdc` —— K17→U18
- `vivado/.../design_1.bd` —— ILA clk U18→FCLK_CLK0 (v1.2)
- `.awp/platform/hw_base_ax7010_v1.0.yaml` —— v1.1→v1.2
- `.awp/workspace_manifest.json` —— 平台版本 v1.2
- `.awp/tasks/TASK-E001-021.yaml` —— L5 pass
- `.awp/tasks/TASK-E001-024.yaml` —— 更新 notes
- `.awp/sessions/SESS-E001-OR-004.md` —— 追加 6/9 进展
- `.claude/skills/vitis-cli-build/SKILL.md` —— 重写 (dow CPU核 + C step)
- `.claude/skills/zynq-debug-toolchain/SKILL.md` —— 重写 (hw_server daemon)
- `.claude/skills/bd-debug-clock/SKILL.md` —— 更新 (诊断链+反模式)
- `.claude/settings.json` —— 全部 hook 绝对路径, 移除 PostToolUse hooks

## Commands Run

```text
# Vivado MCP (大量)
open_project → open_bd_design → disconnect_bd_net → connect_bd_net → validate_bd_design
save_bd_design → make_wrapper → launch_runs synth_1 / impl_1 → write_bitstream
open_hw_manager → connect_hw_server → program_hw_devices → run_hw_ila
upload_hw_ila_data → write_hw_ila_data
create_ip (ila_ctrl_cross, ila_data_cross) → generate_target
write_hw_platform (XSA 导出)

# XSCT/XSDB (大量)
xsct -eval "connect; targets; fpga -f; ps7_init; dow; con; stop"
xsdb board/ps_init_xsdb.tcl
connect -url tcp:localhost:3121

# 编译
arm-none-eabi-gcc -c -mcpu=cortex-a9 ...
arm-none-eabi-as -march=armv7-a ...
arm-none-eabi-ld -T lscript.ld ...
arm-none-eabi-objcopy -O binary

# Bootgen
bootgen -image boot_image.bif -arch zynq -w -o BOOT.BIN

# AWP
python scripts/validate_awp.py --sync (多次)
python scripts/validate_awp.py --gate-check (多次)
```

## Key Decisions

1. **UG908 标准流**：XSCT 主导(HW 编程+PS Init+CPU 控制), Vivado 观察(ILA), hw_server 守护进程共享 JTAG
2. **dow target 必须是 CPU 核** (`ARM Cortex-A9 MPCore #0`), 非 APU — 这是官方文档要求
3. **C+step 逐步验证方法**：step1→7 逐步加回 BSP 功能, 定位崩溃点
4. **xil_printf 桩方案**：编译时用空桩替代, 不走 UART, 结果存 DDR
5. **ILA 触发架构**：PL anchor event (FSM边沿) → dbg_trigger_hub → 多 ILA TRIG_IN, 不依赖 PS 动作
6. **BD System ILA 限制**：SLOT 探针不支持 BASIC 触发模式 → 需 RTL ILA + TRIG_IN
7. **不再走汇编造轮子**：用 C+BSP 标准工具链, 只在必须时手工优化
8. **Hook 全部绝对路径**：移除 PostToolUse (性能), 保留 SessionStart/PreToolUse/Stop

## Issues Found

- 6 个新 ISS issue (ISS-E001-005~010), 3 resolved, 2 open, 1 hardware config
- 详见 `.awp/issues/`
- 关键 open:
  - ISS-E001-008: System ILA 无 BASIC 触发 (需 RTL ILA)
  - ISS-E001-009: DMA HP0 端口阻塞 (需 XSA 重导出+FSBL 重建)

## Gate Check

- [x] `--gate-check` 退出码 0
- [x] 当前 task 的 target 以下无 pending level

## Validation Status

| Level | Status | 备注 |
|-------|--------|------|
| L0: 静态审查 | pass | 架构+RTL review |
| L1a: 模块级单元仿真 | pass | |
| L1b: 数据通路闭环仿真 | pass | |
| L1c: 全系统集成仿真 | pass | |
| L2: 综合 | pass | BD v1.2 |
| L3: 实现与时序 | pass | WNS +6.086ns |
| L4: 比特流生成 | pass | |
| L5: 板上冒烟测试 | pass | TASK-E001-021 done |
| L6: 板上数据正确性 | pending | DMA HP0 阻塞, ILA 捕获 OK |
| L7: 性能/资源复盘 | pending | |

- [x] `python scripts/validate_awp.py` 通过（退出码 0）

## Open Questions

1. DMA HP0 端口阻塞：XSA 重导出+FSBL 重建是否能解决?
2. RTL ILA IP 打包：如何在 Vivado OOC 合成中解析 IP 级联的 ILA?
3. ILA TRIG_IN_ONLY 在硬件上是否能正常接收 dbg_trig_pulse?

## Handoff
- Next Task：TASK-E001-027 (ILA cross-trigger) + TASK-E001-024 (L6 数据)
- Handoff File：`.awp/handoffs/HO-E001-OR-005-001.md`
- Gate Status 已填写：是
- 备注：CLI 自动化核心链路已闭合 (dow+hw_server+ILA), 剩余 IP 打包/HP0 需 Vivado 工程操作
