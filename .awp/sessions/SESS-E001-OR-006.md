---
session_id: "SESS-E001-OR-006"
date: "2026-06-09"
status: "completed"
---

# Session: Zynq PS-PL 联合调试方法论建立 + DMA 数据通路诊断

## Session Goal

完成 TASK-E001-027 (cross-trigger L0-L4)，诊断 TASK-E001-024 (L6 DMA HP0) 阻塞根因，建立正确的 PS-PL 联合调试方法论。

## Tasks Worked

| Task ID | Agent | 状态变化 | 产出 |
|---------|-------|---------|------|
| TASK-E001-027 | rtl_implementer + rtl_reviewer | ready → review | dbg_trigger_hub.sv, axil_2d_shift.sv ILA例化修复, debug.xdc, ila_cross_trigger.tcl, REV-E001-027-RTL-001/002, RUN-E001-BOARD-006 |
| ISS-E001-008 | — | open → resolved | System ILA BASIC trigger 澄清 + 软件 gate 方法论 |
| ISS-E001-009 | — | open (根因转移) | DMA+HP0 确认正常 → 根因跟踪到加速器 capture_done |

## Key Decisions

1. **AFI 寄存器是死胡同**：Zynq-7000 上只读，ps7_init 不配是设计行为，非 DMA 不通的根因
2. **DMA + HP0 通路正常**：ILA 波形确认 1024 字节增量数据完整经过 DMA→Interconnect→HP0→DDR
3. **根因在加速器内部**：axis_input 收到全部数据但 capture_done 不触发，FSM 卡在 CAPTURE
4. **System ILA 支持 BASIC trigger**：运行时可通过 `set_property TRIGGER_COMPARE_VALUE {eq1'b1}` 设置 handshake 触发
5. **软件 Gate + ILA handshake 触发 = 完美捕获**：无需 RTL ILA cross-trigger

## Issues Found

- **方法论缺陷**：4 小时脚本自动化在死胡同里迭代，3 次用户介入后立即突破
- **ILA 被闲置**：诊断过程中始终可用但未主动使用
- **触发条件错误**：默认 don't-care 导致 ILA 立即填满 IDLE 数据

## Files Modified

- `.claude/skills/zynq-debug-toolchain/SKILL.md` — 完全重写，沉淀正确方法论
- `rtl/dbg_trigger_hub.sv` — NUM_ILA 参数语法修复
- `rtl/axil_2d_shift.sv` — probe1 位宽修复 (20'd0→19'd0)
- `constraints/debug.xdc` — v3.0 头部更新
- `board/run_dma_afi.tcl` — AFI patch 脚本（已确认不必要，保留供参考）
- `board/vitis_flow.tcl` — 追加 AFI patch（同上）
- `board/run_vitis_test.tcl` — 标准 Vitis 测试脚本
- `board/run_fsbl_dma.tcl` — FSBL 流程尝试（未成功，保留供参考）
- `board/ps_dma_test/src/afi_patch.h` — C 代码 AFI 补丁（已确认不必要）
- `board/ps_dma_test/src/hp0_test.c` — 零依赖裸机 DMA 测试
- `board/ps_dma_test/src/dma_xaxidma_test.c` — XAxiDma 驱动标准测试
- `board/ps_dma_test/src/dma_gated.c` — 软件 gate + ILA 同步测试
- `board/create_bsp.tcl` — HSI BSP 生成脚本
- `board/vitis_bsp/` — 从新 XSA 生成的完整 BSP
- `.awp/issues/ISS-E001-008.yaml` — resolved
- `.awp/issues/ISS-E001-009.yaml` — 根因更新
- `.awp/reviews/REV-E001-027-RTL-001.md` — 初始审查 (fail)
- `.awp/reviews/REV-E001-027-RTL-002.md` — 跟进审查 (pass)
- `.awp/runs/RUN-E001-BOARD-006.md` — ILA cross-trigger 上板验证占位
- `.awp/runs/ila1_triggered.csv` — ILA 捕获数据
- `.awp/runs/ila_stream_in.csv` / `ila_stream_out.csv` — 早期 ILA 数据

## Validation Status

| Level | Status | 备注 |
|-------|--------|------|
| L0: 静态审查 | pass | REV-E001-027-RTL-002 |
| L1a-L1c | pending | 加速器 IP 内部 issue，待 rtl_implementer 修复 |
| L2: 综合 | pass | Vivado 2022.2, 0 errors 0 CW, 52s |
| L3: 实现与时序 | pass | WNS +6.086ns, WHS +0.031ns |
| L4: 比特流生成 | pass | design_1_wrapper.bit |
| L5: 板上冒烟测试 | pending | — |
| L6: 板上数据正确性 | pending | 阻塞于加速器 capture_done bug |
| L7: 性能/资源复盘 | pending | — |

## Gate Check

- `python scripts/validate_awp.py` — PASS
- ISS-E001-008 — resolved
- ISS-E001-009 — 根因已定位到加速器 axis_input，待修复

## Handoff

- Next Task: TASK-E001-024（加速器 capture_done 修复后继续 L6 验证）
- 或: 创建新 task 交 rtl_implementer 修复 axis_input/capture_done
