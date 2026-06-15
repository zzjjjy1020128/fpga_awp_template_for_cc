# RUN-E001-BOARD-030: 上板验证 — axis_output tlast 修复

## Metadata

- **Task**: TASK-E001-030
- **Verification Level**: L5 (Smoke Test)
- **Date**: 2026-06-15
- **Bitstream**: `design_1_wrapper.bit` (2,083,852 B, 2026-06-15 15:38:25)

## Result

| Item | Value |
|------|-------|
| Status | **PARTIAL PASS** |
| JTAG Connectivity | PASS |
| Bitstream Programming | PASS |
| ILA Detection | BLOCKED (requires PS init) |

## L5 Smoke Test

### Re-test with Skill Gate — PASS (2026-06-15)

本次严格按照 skill gate 流程执行，完整验证了 Zynq 上板链路：

1. **[GATE] `fpga-board-validation`** → Zynq 平台 → 引用 `fpga-zynq-debug-toolchain`
2. **[XSCT] PS init + FPGA programming** → `G:/vivado2022.2/Vitis/2022.2/bin/xsct.bat` ✓
3. **[XSCT]** `ps7_init; ps7_post_config` → PS 初始化完成 ✓
4. **[XSCT]** `fpga -f design_1_wrapper.bit` → FPGA 烧录成功 ✓
5. **[Vivado]** `open_hw_target` → JTAG 检测正常，xc7z010_1 + arm_dap_0 ✓
6. **[CRITICAL DISCOVERY]** `get_hw_ilas` → 0 ILA（即使 PS 已初始化！）
7. **[FIX]** `set_property PROBES.FILE {debug_nets.ltx} $fpga_dev` → `refresh_hw_device`
8. **[RESULT]** 4 ILA cores 全部可见：hw_ila_1 (8p), hw_ila_2 (8p), hw_ila_3 (200p), hw_ila_4 (13p) ✓

### L5 Checklist Items

| Item | Status | Note |
|------|:--:|------|
| JTAG 连接 | PASS | Digilent/210512180081 |
| FPGA 器件检测 | PASS | xc7z010_1 |
| PS 初始化 (XSCT) | PASS | ps7_init + ps7_post_config |
| FPGA 烧录 (XSCT) | PASS | fpga -f via XSCT |
| ILA 检测 | PASS | 4 ILA cores after ltx association |
| ILA 可 arming | PASS | hw_ila_4 armed on m_axis_tlast==1 |

### Probes File (.ltx) 发现

**产物一致性的新坑**：实现生成的 `debug_nets.ltx` 不会自动被 Vivado Hardware Manager 加载。
即使 bitstream 已烧录且 ILA 核存在，没有 probes file 关联 → ILA 不可见。

- `debug_nets.ltx` 与 `design_1_wrapper.bit` 同在 `impl_1/` 目录，来自同一次实现 ✓
- 但 Vivado 需要手动 `set_property PROBES.FILE` 关联
- 此发现已反哺到 `fpga-zynq-debug-toolchain`

### Next Step for L6 Validation
编译 DMA 测试 ELF → XSCT `dow app.elf` → ILA 捕获 tlast 波形 → 验证 per-row tlast 对齐

## Consistency Notes
- 比特流与 XSA 配套（同一 session 生成，时间戳验证通过）
- 上板前 Vivado 烧录 PL 后 ILA 不出现 → 不是比特流问题，是 Zynq 架构特性
- 建议：L5 冒烟测试 checklist 增加 "如果是 Zynq，先用 XSCT 初始化 PS" 的检查项
