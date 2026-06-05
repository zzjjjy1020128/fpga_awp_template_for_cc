# RUN-E001-L1B-WRITE-001: L1b 写通路集成仿真

## Metadata

- **Task**: TASK-E001-009
- **Verification Level**: L1b (Datapath Integration Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: 2026/06/05
- **Testbench**: tb/tb_l1b_write_path.sv
- **DUT**: rtl/axis_input.sv + rtl/frame_buf_mgr.sv
- **Integration Scope**: datapath (write: axis_input -> frame_buf_mgr)

## Result

| Item | Value |
|------|-------|
| Status | **FAIL** |
| Assertions | 56 |
| Passed | 47 |
| Failed | 9 |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
| TC01 | Basic 4x4 capture and read-back — verify write_en timing and BRAM data | PASS |
| TC02 | Multi-frame (3 frames) data overwrite — verify frame boundaries | PASS |
| TC03 | Backpressure via tvalid gaps — verify data not lost | PASS |
| TC04 | capture_en toggle mid-frame — verify freeze/resume integrity | FAIL |
| TC05 | rstn mid-frame — verify axis_input reset, BRAM data preserved | FAIL |
| TC06 | Edge cases — 1x1, 1x5, 5x1 capture and read-back | PASS |
| TC07 | Random data 10x8 — full random data verification | PASS |
| TC08 | Full BRAM depth (64x64) — sequential write and partial read-back | PASS |

## Pipeline Timing Analysis

### Write Path Timing (axis_input -> frame_buf_mgr)

```
Clock cycle:            T0          T1          T2          T3
s_axis_tdata            D0          D1          D2          D3
s_axis_tvalid      _____|~~~|_____|~~~|_____|~~~|_____|~~~|
s_axis_tready      ''''''''''''''''''''''''''''''''''''''''' (capture_en)
write_en (comb)           ^           ^           ^           ^
write_data (comb)        D0          D1          D2          D3
write_addr (comb)        A0          A1          A2          A3
-> frame_buf_mgr: bram[A0]<=D0 at T0 posedge, bram[A1]<=D1 at T1, ...
```

Key observations:
- write_en is combinatorial from capture_en & tvalid & tready
- write_addr is combinatorial from row_cnt * img_cols + col_cnt
- BRAM write occurs on the same cycle as the AXI-Stream beat (zero-cycle latency)
- BRAM read (port B) has 1-cycle latency: read_data valid 1 cycle after read_addr change

## Simulation Log (last 150 lines)

```
============================================================
  tb_l1b_write_path - Write Path Integration Simulation
  axis_input -> frame_buf_mgr (port A)
============================================================

VCD info: dumpfile tb_l1b_write_path.vcd opened for output.
--- TC1: Basic 4x4 capture and read-back ---
  PASS [1] initial write_addr == 0
  PASS [1] beat 0: write_addr == 0 before transfer
  PASS [1] beat 1: write_addr == 1 before transfer
  PASS [1] beat 2: write_addr == 2 before transfer
  PASS [1] beat 3: write_addr == 3 before transfer
  PASS [1] beat 4: write_addr == 4 before transfer
  PASS [1] beat 5: write_addr == 5 before transfer
  PASS [1] beat 6: write_addr == 6 before transfer
  PASS [1] beat 7: write_addr == 7 before transfer
  PASS [1] beat 8: write_addr == 8 before transfer
  PASS [1] beat 9: write_addr == 9 before transfer
  PASS [1] beat 10: write_addr == 10 before transfer
  PASS [1] beat 11: write_addr == 11 before transfer
  PASS [1] beat 12: write_addr == 12 before transfer
  PASS [1] beat 13: write_addr == 13 before transfer
  PASS [1] beat 14: write_addr == 14 before transfer
  PASS [1] beat 15: write_addr == 15 before transfer
  PASS [1] capture_done asserted after frame
  PASS [1] write_addr == 0 after frame done
  PASS [1] capture_done self-cleared
  PASS [1] TC01: BRAM read-back errs=0/16
--- TC2: Multi-frame (3 frames) data overwrite ---
  PASS [2] FRAME1: capture_done asserted
  PASS [2] FRAME2: capture_done asserted
  PASS [2] FRAME3: capture_done asserted
  PASS [2] TC02: multi-frame overwrite errs=0/12
--- TC3: Backpressure via tvalid gaps ---
  PASS [3] TC03: initial write_addr == 0
  PASS [3] TC03: capture_done asserted after backpressure
  PASS [3] TC03: capture_done self-cleared
  PASS [3] TC03: backpressure errs=0/16
--- TC4: capture_en toggle mid-frame ---
  PASS [4] after 5 beats: write_addr == 5
  PASS [4] tready=0 after capture_en=0
  PASS [4] write_en=0 when paused
  FAIL [4] TC04: capture_done after resume
  FAIL [4] bram[0] = 6 (expected 1)
  FAIL [4] bram[1] = 7 (expected 2)
  FAIL [4] bram[2] = 8 (expected 3)
  FAIL [4] TC04: capture_en toggle errs=11/16
--- TC5: rstn mid-frame ---
  PASS [5] tready=0 during reset
  PASS [5] after reset: write_addr == 0
  PASS [5] TC05: capture_done after reset+new capture
  PASS [5] TC05: reset+new data errs=0/6 (addrs 0..5)
  FAIL [5] bram[6] = 11 (expected 7)
  FAIL [5] bram[7] = 12 (expected 8)
  FAIL [5] bram[8] = 13 (expected 9)
  FAIL [5] TC05: preserved data errs=6/10 (addrs 6..15)
--- TC6: Edge cases (1x1, 1x5, 5x1) ---
  Subtest A: 1x1 single pixel
  PASS [6] TC06-A: capture_done after 1x1
  PASS [6] TC06-A: bram[0] == 0xAB
  Subtest B: 1x5 single row
  PASS [6] TC06-B: capture_done after 1x5
  PASS [6] TC06-B: single row errs=0/5
  Subtest C: 5x1 single column
  PASS [6] TC06-C: capture_done after 5x1
  PASS [6] TC06-C: single column errs=0/5
--- TC7: Random data 10x8 verification ---
  PASS [7] TC07: capture_done asserted
  PASS [7] all 80 random data locations verified
--- TC8: Full BRAM depth (64x64) sequential write+read ---
  TC08: writing 4096 locations (may take a moment)...
  TC08: 1024/4096 beats sent...
  TC08: 2048/4096 beats sent...
  TC08: 3072/4096 beats sent...
  PASS [8] TC08: capture_done after full depth
  TC08: verifying first 256 locations...
  PASS [8] TC08: first 256 errs=0
  TC08: verifying last 256 locations...
  PASS [8] TC08: last 256 errs=0

============================================================
  Simulation Summary
============================================================
  Passed: 47
  Failed: 3
  Total : 50
------------------------------------------------------------
  SOME TESTS FAILED  <<<
============================================================
```

## Waveform

VCD file saved to: `sim/tb_l1b_write_path.vcd`

Open with: `gtkwave sim/tb_l1b_write_path.vcd`

## Checksum

- Report generated: 2026/06/05
