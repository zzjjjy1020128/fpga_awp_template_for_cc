# RUN-E001-SIM-008: axil_2d_shift L1c Full-System Integration Simulation

## Metadata

- **Task**: TASK-E001-008
- **Verification Level**: L1c (Full-System Integration)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: 2026-06-05
- **Testbench**: tb/tb_axil_2d_shift.sv
- **DUT**: rtl/axil_2d_shift.sv (top-level, integrates 7 sub-modules)

## Result

| Item | Value |
|------|-------|
| Status | **PASS** |
| Assertions | 247 |
| Passed | 247 |
| Failed | 0 |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
| TC01 | NONE passthrough 4x4 | PASS |
| TC02 | UP wrap 6x4 step=2 | PASS |
| TC03 | DOWN wrap 6x4 step=1 | PASS |
| TC04 | LEFT wrap 4x6 step=3 | PASS |
| TC05 | RIGHT wrap 4x6 step=2 | PASS |
| TC06 | UP zero-fill 5x4 step=2 | PASS |
| TC07 | LEFT zero-fill 3x5 step=2 | PASS |
| TC08 | Continuous two frames (UP wrap then DOWN zero-fill) | PASS |
| TC09 | SW_RESET during capture | PASS |
| TC10 | Register readback | PASS |
| TC11 | Single row/column boundary (1x5, 5x1, 1x1) | PASS |

## Pipeline Timing Analysis

Based on measured DBG_RECV output at cycle-level granularity:

| Parameter | Value | Notes |
|-----------|-------|-------|
| Shift pipeline startup | 1 cycle (P1) | shift_en=1 at P0 (NBA), valid data at P1+delta |
| BRAM read latency | 1 cycle | read_data registered in frame_buf_mgr |
| zero_fill alignment | 1 cycle | zero_fill_d1 register in top-level |
| Row-to-row transition | 1 cycle stall | col wrap + row inc at same posedge |
| Frame completion | all_done_q | tvalid drops 1 cycle after all_done |

Key DBG_RECV observations from TC01 (NONE 4x4):
- P0: shift_en goes high (NBA), m_axis_tvalid=1 (combinatorial)
- P1: axis_output/shift_addr_gen process shift_en=1, counter advance
  - read_data loaded with bram[pre-advance_addr]
- P1+delta: first pixel valid (frame_out[0] = 0x1)
- Subsequent posedges: frame_out[i] = bram[i] for NONE mode

This 1-cycle pipeline delay is consistent across all 11 test cases.

## RTL Modifications Summary

Three fixes were applied to sub-module RTL files during this L1c integration verification. All were bugs that only manifest at the integration level:

### Fix 1: `rtl/axil_2d_shift.sv` — Missing .proceed port connection
- **Symptom**: shift_addr_gen's proceed port unconnected (floating X)
- **Root cause**: Initial top-level instantiation omitted `.proceed(m_axis_tready)`
- **Fix**: Added the port connection at line 300
- **Impact**: Without this, SAG counters freeze during shift phase if m_axis_tready is ever 0

### Fix 2: `rtl/shift_addr_gen.sv` — row_cnt/col_cnt not reset on !shift_en (lines 82-83)
- **Symptom**: SAG counters retained stale values across DONE->IDLE transition, causing frame alignment issues in multi-frame tests
- **Root cause**: The `!shift_en` branch only cleared `frame_done`, not `row_cnt`/`col_cnt`. Compare with `axis_output` which correctly resets all three counters on `!shift_en`
- **Fix**: Added `row_cnt <= '0; col_cnt <= '0;` to the `!shift_en` branch
- **Impact**: Without this, SAG counters could start from non-zero values after SW_RESET or frame boundary

### Fix 3: `rtl/axis_input.sv` — row_cnt/col_cnt not reset on !capture_en
- **Symptom**: After SW_RESET during partial capture, axis_input counters were left at (0,2). When re-capture started, the tuser=1 first pixel wrote to BRAM addr 2 instead of addr 0, corrupting the BRAM content
- **Root cause**: Axis_input had no counter reset when capture_en=0, so stale counter values persisted across SW_RESET. The tuser reset logic also used pre-NBA counters for write_addr calculation, causing the first pixel's write to go to the wrong BRAM address
- **Fix**: Added `if (!capture_en) begin row_cnt <= '0; col_cnt <= '0; end` in the always_ff block, ensuring counters reset to 0 when not actively capturing
- **Impact**: Without this, SW_RESET during capture corrupts subsequent frame writes

### Testbench Fix: `tb/tb_axil_2d_shift.sv`

1. **`receive_frame` pipeline delay**: Changed from 2-cycle to 1-cycle delay after m_axis_tvalid assertion. The pipeline timing analysis showed that valid first pixel data is available at P1 (1 cycle after shift_en), not P2.
2. **`reset_pipeline_counters` drain loop**: Changed from `wait(m_axis_tvalid || all_done)` to `while(!all_done)` to avoid premature unblocking when m_axis_tvalid goes high combinatorially before axis_output processes shift_en.

## BRAM Content Verification

Direct BRAM reads during TC09 comparison confirmed correct data:
- BRAM[0]=0x1 (frame_in[0]), BRAM[1]=0x2 (frame_in[1])
- BRAM[19]=0x44 (frame_in[19]), BRAM[23]=0x54 (frame_in[23])
- All 24 locations contained correct frame data

## Waveform

VCD file saved to: `sim/tb_axil_2d_shift.vcd`

Open with: `gtkwave sim/tb_axil_2d_shift.vcd`

## Checksum

- Report generated: 2026-06-05
