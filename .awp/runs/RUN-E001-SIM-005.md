# RUN-E001-SIM-005: axis_output AXI4-Stream Output Interface Simulation

## Metadata

- **Task**: TASK-E001-006
- **Verification Level**: L1 (Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: 2026/06/04 周四
- **Testbench**: tb/tb_axis_output.sv
- **DUT**: rtl/axis_output.sv

## Result

| Item | Value |
|------|-------|
| Status | **PASS** |
| Assertions | 228 |
| Passed | 228 |
| Failed | 0 |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
| TC01 | Basic 4x4 output: tdata/tuser/tlast/shift_done | PASS |
| TC02 | tuser only on first element | PASS |
| TC03 | tlast at each row end (col=img_cols-1) | PASS |
| TC04 | zero_fill forces m_axis_tdata=0 | PASS |
| TC05 | shift_done pulse: 1 cycle after last handshake | PASS |
| TC06 | Backpressure: tready=0 pauses counters, data held | PASS |
| TC07 | Backpressure release: resume from breakpoint | PASS |
| TC08 | shift_en=0: tvalid=0, no output; resume resets frame | PASS |
| TC09 | Single row (img_rows=1): tuser+tlast handling | PASS |
| TC10 | Single column (img_cols=1): every beat is tlast | PASS |
| TC11 | Single pixel (1x1): tuser+tlast+shift_done together | PASS |
| TC12 | Random frames + backpressure + zero_fill vs golden model | PASS |

## Simulation Log (last 100 lines)

```
--- TC7: Backpressure release and resume ---
  PASS [7] release tvalid = 1
  PASS [7] release tdata = 102
  PASS [7] release tlast = 0 (col=2 != 4)
  PASS [7] resume beat 3 tdata = 103
  PASS [7] resume beat 3 tlast = 0
  PASS [7] resume beat 4 tdata = 104
  PASS [7] resume beat 4 tlast = 1
  PASS [7] resume beat 5 tdata = 105
  PASS [7] resume beat 5 tlast = 0
  PASS [7] resume beat 6 tdata = 106
  PASS [7] resume beat 6 tlast = 0
  PASS [7] resume beat 7 tdata = 107
  PASS [7] resume beat 7 tlast = 0
  PASS [7] resume beat 8 tdata = 108
  PASS [7] resume beat 8 tlast = 0
  PASS [7] resume beat 9 tdata = 109
  PASS [7] resume beat 9 tlast = 1
  PASS [7] shift_done after resumed frame
--- TC8: shift_en=0 disables output ---
  PASS [8] disabled tvalid = 0
  PASS [8] disabled tlast = 0
  PASS [8] disabled tuser = 0
  PASS [8] disabled: no output, tvalid=0
  PASS [8] disabled: tdata follows read_data (combinatorial)
  PASS [8] enabled: tvalid = 1
  PASS [8] enabled: tdata = 99
  PASS [8] enabled: tuser = 1 (new frame)
  PASS [8] enabled beat 1 tdata
  PASS [8] enabled beat 2 tdata
  PASS [8] enabled beat 3 tdata
  PASS [8] enabled beat 4 tdata
  PASS [8] enabled beat 5 tdata
  PASS [8] enabled beat 6 tdata
  PASS [8] enabled beat 7 tdata
  PASS [8] enabled beat 8 tdata
  PASS [8] enabled beat 9 tdata
  PASS [8] enabled beat 10 tdata
  PASS [8] enabled beat 11 tdata
  PASS [8] enabled beat 12 tdata
  PASS [8] enabled beat 13 tdata
  PASS [8] enabled beat 14 tdata
  PASS [8] enabled beat 15 tdata
  PASS [8] shift_done after enable frame
--- TC9: Single row (img_rows=1) ---
  PASS [9] beat 0 tvalid
  PASS [9] beat 0 tuser = 1
  PASS [9] beat 0 tlast = 0 (single row)
  PASS [9] beat 1 tvalid
  PASS [9] beat 1 tuser = 0
  PASS [9] beat 1 tlast = 0 (single row)
  PASS [9] beat 2 tvalid
  PASS [9] beat 2 tuser = 0
  PASS [9] beat 2 tlast = 0 (single row)
  PASS [9] beat 3 tvalid
  PASS [9] beat 3 tuser = 0
  PASS [9] beat 3 tlast = 0 (single row)
  PASS [9] beat 4 tvalid
  PASS [9] beat 4 tuser = 0
  PASS [9] beat 4 tlast = 0 (single row)
  PASS [9] beat 5 tvalid
  PASS [9] beat 5 tuser = 0
  PASS [9] beat 5 tlast = 1 (single row)
  PASS [9] shift_done after single-row frame
--- TC10: Single column (img_cols=1) ---
  PASS [10] beat 0 tvalid
  PASS [10] beat 0 tuser = 1
  PASS [10] beat 0 tlast = 1 (single col)
  PASS [10] beat 1 tvalid
  PASS [10] beat 1 tuser = 0
  PASS [10] beat 1 tlast = 1 (single col)
  PASS [10] beat 2 tvalid
  PASS [10] beat 2 tuser = 0
  PASS [10] beat 2 tlast = 1 (single col)
  PASS [10] beat 3 tvalid
  PASS [10] beat 3 tuser = 0
  PASS [10] beat 3 tlast = 1 (single col)
  PASS [10] shift_done after single-col frame
--- TC11: Single pixel (1x1) ---
  PASS [11] 1x1 tvalid = 1
  PASS [11] 1x1 tdata = 77
  PASS [11] 1x1 tuser = 1
  PASS [11] 1x1 tlast = 1
  PASS [11] 1x1 shift_done = 1
  PASS [11] 1x1 tvalid = 0 after done
  PASS [11] 1x1 tuser = 0 after done
  PASS [11] 1x1 tlast = 0 after done
  PASS [11] 1x1 shift_done self-cleared
--- TC12: Random frames with golden model ---
  PASS [12] random test: 11176 checks, 0 errors

============================================================
  Simulation Summary
============================================================
  Passed: 11404
  Failed: 0
  Total : 11404
------------------------------------------------------------
  ALL TESTS PASSED
============================================================
```

## Waveform

VCD file saved to: `sim/tb_axis_output.vcd`

Open with: `gtkwave sim/tb_axis_output.vcd`

## Checksum

- Report generated: 2026/06/04 周四
