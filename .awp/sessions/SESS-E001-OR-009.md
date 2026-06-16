# Session 记录

> SESS-E001-OR-009 | 2026-06-15 → 2026-06-16 | orchestrator

## Session Goal

继续 ISS-E001-011（axis_output tlast 修复）的上板验证，通过 ILA 捕获确认 tlast 逐行触发。期间清理废弃 packaged IP、重建 Vivado 工程为 module_ref、固化 ILA 自动化添加方案、反哺 skills 体系。

## Tasks Worked

| Task ID | Agent | 状态变化 | 产出 |
|---------|-------|---------|------|
| ISS-E001-011 | orchestrator + hardware_validator | in_progress → closed | ILA 捕获(24 tlast events)、DDR mismatch 36→1、RTL 修复确认 |
| (审计) skills | orchestrator | N/A | CLAUDE.md §3 重写、fpga-board-validation/fpga-zynq-debug-toolchain/fpga-vivado-methodology 更新 |
| (新建) Vivado 工程 | orchestrator | N/A | shift_2d_ax7010_260608_new（module_ref 路线） |

## Files Read

- `rtl/axis_output.sv` — tlast 修复逻辑验证
- `rtl/axil_2d_shift.sv` — ILA 实例化分析、dbg_port 添加
- `rtl/wrapper_2d_shift.v` — module_ref BD 端口对齐
- `rtl/shift_addr_gen.sv` — SAG 流水线分析
- `rtl/frame_buf_mgr.sv` — BRAM 深度检查
- `rtl/ctrl_fsm.sv` — FSM 状态分析
- `rtl/regs_top.sv` — 寄存器映射确认
- `rtl/dbg_trigger_hub.sv` — 调试架构理解
- `tb/tb_axis_output.sv` — 单元仿真
- `tb/tb_axil_2d_shift.sv` — 全系统仿真
- `tb/tb_l1b_read_path.sv` — L1b 读通路仿真
- `board/ps_dma_test/src/dma_gated.c` — 测试程序分析+修改
- `board/ps_dma_test/build/dma_gated.elf` — 测试 ELF
- `.awp/platform/host_env.yaml` — 主机环境
- `.awp/issues/ISS-E001-011.yaml` — Issue 状态更新
- `.awp/runs/ila*.csv` — 多轮 ILA 捕获数据分析

## Files Modified

- `rtl/axis_output.sv` — tlast 修复(col_cnt_q→col_cnt) + dbg_* 调试端口
- `rtl/axil_2d_shift.sv` — 移除 RTL ILA 实例化、添加 dbg_port、ao_dbg_* 连接
- `rtl/wrapper_2d_shift.v` — 精简为纯透传，dbg_port 端口
- `board/ps_dma_test/src/dma_gated.c` — 适配 1 字节输出寄存器偏移
- `CLAUDE.md` — §3 重写：矩阵→三 gate + Bash 等同 MCP + 违规根因分析
- `.awp/issues/ISS-E001-011.yaml` — closed
- `.claude/skills/fpga-board-validation/SKILL.md` — L5 probes 检查、XSCT 模板、16-bit 测试数据
- `.claude/skills/fpga-zynq-debug-toolchain/SKILL.md` — ILA arm 时机、trigger 位宽表、BD ILA 模板
- `.claude/skills/fpga-vivado-methodology/SKILL.md` — BD ILA 完整方案、5 个新反模式

## Commands Run

- `iverilog -g2012` — 编译全系统/L1b 仿真
- `vvp` — 运行仿真
- `xsct.bat xsct_rerun.tcl` — PS 初始化+FPGA 烧录+ELF 加载
- `xsct.bat xsct_release_gate.tcl` — 释放 gate+DDR 读取
- `git checkout` — 多次恢复 BD/RTL
- `python scripts/validate_awp.py` — 校验
- Vivado Tcl: `create_project`, `create_bd_cell ila:6.2`, `generate_target all`, `launch_runs synth_1/impl_1`, `write_bitstream`, `write_debug_probes`
- ILA 捕获: `run_hw_ila`, `upload_hw_ila_data`, `write_hw_ila_data`

## Key Decisions

1. **废弃 packaged IP，全面转 module_ref**：删除 `vivado/ip/axil_2d_shift_v1_0/`，新建纯 module_ref 工程
2. **BD ILA 用 `ila:6.2` 不用 `system_ila`**：INTERFACE 模式在 Tcl 中对 AXIS 无效，NATIVE probe 直连可靠
3. **BD 修改用一次性脚本不用增量 Tcl**：Vivado Tcl BD API 非事务性，增量修改的级联错误无法恢复
4. **tlast 修复确认有效后用 DDR+ILA 双重证据闭合 ISS**
5. **CLAUDE.md gate 规则从矩阵简化为三 gate + 自问检查点**

## Issues Found

1. `dma_gated.c` 的 `(u8)i` 在 i≥256 时截断→数据每 256 字节重复
2. `git clean -fd` 删除 Vivado 生成文件→工程不可恢复
3. Vivado Tcl BD API 非事务性→增量修改极不可靠
4. `system_ila` INTERFACE 模式的 C_MON_TYPE 参数在 Tcl 中不生效
5. ILA capture 窗口被 Zynq CAPTURE 空闲淹没
6. RTL ILA 的 OOC 缓存导致 probe 永远为 const0

## Gate Check

- [x] `--gate-check` 退出码 0
- [x] 当前 task 的 target 以下无 pending level

## Validation Status

| Level | Status | 备注 |
|-------|--------|------|
| L0: 静态审查 | pass | RTL review 完成 |
| L1a: 模块级单元仿真 | pass | tb_axis_output 仿真确认 tlast_comb 逻辑 |
| L1b: 数据通路闭环仿真 | pass | tb_l1b_read_path + tb_axil_2d_shift 全系统仿真 |
| L2: 综合 | pass | 0 error, 0 CW (新工程) |
| L3: 实现与时序 | pass | WNS=+6.593ns, WHS=+0.031ns |
| L4: 比特流生成 | pass | 0 error, 0 CW |
| L5: 板上冒烟测试 | pass | XSCT PS init + FPGA program + ELF load + ILA 1 core |
| L6: 板上数据正确性 | pass | ILA: 24 tlast events @32B intervals; DDR: mismatch byte 1 |

## Open Questions

- ELF 重编译需 Vitis IDE（ARM GCC 裸调缺 linker script + BSP 配置）
- BD ILA 的 `mark_debug` 替代方案未经测试（理论上更简单，不碰 BD）

## Handoff

- Next Task：TASK-E001-020 (ILA 探针配置与 debug 比特流，已部分完成) 或 TASK-E001-028 (FPGA Domain Pack 技能库维护)
- Handoff File：`.awp/handoffs/HO-E001-OR-009-001.md`
- Gate Status 已填写：是
