# RUN-E001-SIM-003: axis_input AXI4-Stream Input Interface Simulation

## Metadata

- **Task**: TASK-E001-004
- **Verification Level**: L1 (Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: 2026/06/05 周五
- **Testbench**: tb/tb_axis_input.sv
- **DUT**: rtl/axis_input.sv

## Result

| Item | Value |
|------|-------|
| Status | **PASS** |
| Assertions | 126 |
| Passed | 126 |
| Failed | 0 |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
| TC01 | Basic capture 4x4, verify write_addr sequence | PASS |
| TC02 | tuser frame start reset mid-frame | PASS |
| TC03 | tlast row end: col resets, row+1 | PASS |
| TC04 | capture_done pulse at frame completion | PASS |
| TC05 | capture_en=0: tready=0, counters unchanged | PASS |
| TC06 | Single row (img_rows=1): tlast triggers capture_done | PASS |
| TC07 | Single column (img_cols=1): tuser+tlast handling | PASS |
| TC08 | Single pixel (1x1): tuser+tlast, capture_done | PASS |
| TC09 | Dynamic img_rows/img_cols switching | PASS |
| TC10 | capture_en mid-cancel and resume | PASS |
| TC11 | Random frame size and random data, verify raster scan | PASS |

## Simulation Log (last 100 lines)

```
--- TC8: Single pixel (1x1) ---
  PASS [8] write_addr == 0 for 1x1
  PASS [8] capture_done after 1x1
  PASS [8] write_addr == 0 after 1x1
  PASS [8] capture_done self-cleared
--- TC9: Dynamic img_rows/img_cols switching ---
  PASS [9] capture_done after 2x3
  PASS [9] capture_done after 3x2
  PASS [9] capture_done self-cleared
--- TC10: capture_en mid-cancel and resume ---
  PASS [10] after 3 beats: write_addr == 3
  PASS [10] tready=0 when paused
  PASS [10] write_en=0 during pause
  PASS [10] write_addr reset to 0 after capture_en=0
  PASS [10] write_en=1 after resume
  PASS [10] write_addr == 4 after row boundary
  PASS [10] capture_done after resumed frame
  PASS [10] write_addr == 0 after frame end
--- TC11: Multiple frame sizes ---
  Subtest 1: 3x4 frame (12 pixels)
  PASS [11] S0: initial write_addr == 0
  PASS [11] S0: beat 0 addr=0
  PASS [11] S0: beat 1 addr=1
  PASS [11] S0: beat 2 addr=2
  PASS [11] S0: beat 3 addr=3
  PASS [11] S0: beat 4 addr=4
  PASS [11] S0: beat 5 addr=5
  PASS [11] S0: beat 6 addr=6
  PASS [11] S0: beat 7 addr=7
  PASS [11] S0: beat 8 addr=8
  PASS [11] S0: beat 9 addr=9
  PASS [11] S0: beat 10 addr=10
  PASS [11] S0: beat 11 addr=11
  PASS [11] S0: capture_done
  PASS [11] S0: write_addr == 0 after done
  Subtest 2: 5x2 frame (10 pixels)
  PASS [11] S1: initial write_addr == 0
  PASS [11] S1: beat 0 addr=0
  PASS [11] S1: beat 1 addr=1
  PASS [11] S1: beat 2 addr=2
  PASS [11] S1: beat 3 addr=3
  PASS [11] S1: beat 4 addr=4
  PASS [11] S1: beat 5 addr=5
  PASS [11] S1: beat 6 addr=6
  PASS [11] S1: beat 7 addr=7
  PASS [11] S1: beat 8 addr=8
  PASS [11] S1: beat 9 addr=9
  PASS [11] S1: capture_done
  PASS [11] S1: write_addr == 0 after done
  Subtest 3: 7x3 frame (21 pixels)
  PASS [11] S2: initial write_addr == 0
  PASS [11] S2: beat 0 addr=0
  PASS [11] S2: beat 1 addr=1
  PASS [11] S2: beat 2 addr=2
  PASS [11] S2: beat 3 addr=3
  PASS [11] S2: beat 4 addr=4
  PASS [11] S2: beat 5 addr=5
  PASS [11] S2: beat 6 addr=6
  PASS [11] S2: beat 7 addr=7
  PASS [11] S2: beat 8 addr=8
  PASS [11] S2: beat 9 addr=9
  PASS [11] S2: beat 10 addr=10
  PASS [11] S2: beat 11 addr=11
  PASS [11] S2: beat 12 addr=12
  PASS [11] S2: beat 13 addr=13
  PASS [11] S2: beat 14 addr=14
  PASS [11] S2: beat 15 addr=15
  PASS [11] S2: beat 16 addr=16
  PASS [11] S2: beat 17 addr=17
  PASS [11] S2: beat 18 addr=18
  PASS [11] S2: beat 19 addr=19
  PASS [11] S2: beat 20 addr=20
  PASS [11] S2: capture_done
  PASS [11] S2: write_addr == 0 after done
  Subtest 4: 2x6 frame (12 pixels)
  PASS [11] S3: initial write_addr == 0
  PASS [11] S3: beat 0 addr=0
  PASS [11] S3: beat 1 addr=1
  PASS [11] S3: beat 2 addr=2
  PASS [11] S3: beat 3 addr=3
  PASS [11] S3: beat 4 addr=4
  PASS [11] S3: beat 5 addr=5
  PASS [11] S3: beat 6 addr=6
  PASS [11] S3: beat 7 addr=7
  PASS [11] S3: beat 8 addr=8
  PASS [11] S3: beat 9 addr=9
  PASS [11] S3: beat 10 addr=10
  PASS [11] S3: beat 11 addr=11
  PASS [11] S3: capture_done
  PASS [11] S3: write_addr == 0 after done

============================================================
  Simulation Summary
============================================================
  Passed: 126
  Failed: 0
  Total : 126
------------------------------------------------------------
  ALL TESTS PASSED
============================================================
```

## Waveform

VCD file saved to: `sim/tb_axis_input.vcd`

Open with: `gtkwave sim/tb_axis_input.vcd`

## Checksum

- Report generated: 2026/06/05 周五
