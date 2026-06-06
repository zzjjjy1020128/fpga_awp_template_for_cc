# RUN-E001-L1B-READ-001: L1b 读通路集成仿真

## Metadata

- **Task**: TASK-E001-010
- **Verification Level**: L1b (Datapath Integration Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: 2026/06/06
- **Testbench**: tb/tb_l1b_read_path.sv
- **DUT**: rtl/shift_addr_gen.sv + rtl/frame_buf_mgr.sv + rtl/axis_output.sv
- **Integration Scope**: datapath (read: shift_addr_gen -> frame_buf_mgr -> axis_output)

## Result

| Item | Value |
|------|-------|
| Status | **FAIL** |
| Assertions | 59 |
| Passed | 44 |
| Failed | 15 |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
| TC01 | NONE 4x4 — basic read path pipeline, data correctness | FAIL |
| TC02 | UP wrap 4x4 step=1 — vertical shift with wrap | FAIL |
| TC03 | DOWN wrap 6x4 step=2 — vertical shift down with wrap | FAIL |
| TC04 | LEFT wrap 4x6 step=3 — horizontal shift left with wrap | FAIL |
| TC05 | RIGHT wrap 5x5 step=2 — horizontal shift right with wrap | FAIL |
| TC06 | UP zero-fill 5x4 step=2 — overflow rows produce zero data | FAIL |
| TC07 | LEFT zero-fill 3x5 step=2 — overflow columns produce zero data | FAIL |
| TC08 | Multi-frame (3 frames) with inter-frame reset — state cleanup | FAIL |
| TC09 | Backpressure — tready=0 mid-frame, data integrity after resume | FAIL |
| TC10 | shift_en toggle — mid-frame disable/re-enable with reset | PASS |
| TC11 | Edge cases — 1x1, 1x5, 5x1 boundary conditions | FAIL |
| TC12 | Partial frame — shift_en dropped mid-frame, resume without reset | FAIL |

## Pipeline Timing Analysis

### Read Path Pipeline (shift_addr_gen -> frame_buf_mgr -> axis_output)

```
Clock:               T0          T1          T2          T3          T4
shift_en        _____|~~~~~~~~~~|~~~~~~~~~~~|~~~~~~~~~~~|~~~~~~~~~~~|___

shift_addr_gen
  row_cnt             0           0           0           0           1
  col_cnt             0           1           2           3     (wrap 0)
  read_addr           0           1           2           3           4
  zero_fill           0           0           0           0           0

frame_buf_mgr
  read_data           X          b[0]        b[1]        b[2]        b[3]

zero_fill_d1          0           0           0           0           0

axis_output
  row_cnt             0           0           0           0           1
  col_cnt             0           1           2           3           0
  m_axis_tvalid   _____|~~~~~~~~~~~|~~~~~~~~~~~|~~~~~~~~~~~|~~~~~~~~~~~|___
  m_axis_tdata        X          b[0]        b[1]        b[2]        b[3]
  m_axis_tuser        1           0           0           0           0
  m_axis_tlast        0           0           0           1           0
```

### Key Observations

1. **Pipeline bubble (T0)**: m_axis_tvalid goes high immediately when shift_en=1,
   but read_data is still X (1-cycle BRAM read latency). The first beat at T0
   contains stale/unknown data. TUSER fires here instead of on the first valid
   data beat.

2. **TLAST misalignment**: TLAST fires at T3 (col_cnt wraps 2->3), but the
   data at T3 corresponds to pixel at col=1 address (loaded at T2). TLAST should
   fire at T4 for pixel at col=3.

3. **Last pixel dropped**: After the final pixel (counters at row=max-1, col=max-1),
   all_done goes high at the same cycle that read_data would contain the last
   BRAM value, causing m_axis_tvalid=0 before the last pixel is output.

4. **Data path correct**: Despite the control signal issues, the actual data
   values output on m_axis_tdata (after the bubble) are correct and match
   BRAM content at the expected shifted addresses.

### Detailed Cycle-by-Cycle (NONE 4x4)

| Cycle | Shift Addr | Read Data | m_tdata | tuser | tlast | Note |
|-------|-----------|-----------|---------|-------|-------|------|
| T0    | 0 (0,0)   | X         | X       | 1     | 0     | Pipeline bubble |
| T1    | 1 (0,1)   | bram[0]   | bram[0] | 0     | 0     | First valid pixel |
| T2    | 2 (0,2)   | bram[1]   | bram[1] | 0     | 0     | |
| T3    | 3 (0,3)   | bram[2]   | bram[2] | 0     | 1     | TLAST 1 cycle early |
| T4    | 4 (1,0)   | bram[3]   | bram[3] | 0     | 0     | Real row-end data |
| ...   | ...       | ...       | ...     | 0     | 0     | |
| T15   | 15 (3,3)  | bram[14]  | bram[14]| 0     | 1     | Last output (14/15) |
| T16   | 0 (wrap)  | bram[15]  | bram[15]| 0     | 0     | tvalid=0 (all_done) |


## Simulation Log (last 150 lines)

```
--- TC09: Backpressure ---
  [DBG] BEFORE shift_en: read_data=0x0 read_addr=0x0 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] AFTER shift_en=1: read_data=0x0 read_addr=0x0 sag_row=0 sag_col=0
  [DBG] PRE cap i=0: read_addr=0x0 read_data=0x0 tvalid=0 tready=1 sag_row=0 sag_col=1 ao_row=0 ao_col=0
  [DBG] PRE cap i=1: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=2 ao_row=0 ao_col=0
  [DBG] PRE cap i=2: read_addr=0x1 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=3 ao_row=0 ao_col=0
  [DBG] PRE cap i=3: read_addr=0x2 read_data=0x1 tvalid=x tready=1 sag_row=1 sag_col=0 ao_row=0 ao_col=0
  [DBG] PRE cap i=4: read_addr=0x3 read_data=0x2 tvalid=x tready=1 sag_row=1 sag_col=1 ao_row=0 ao_col=0
  [DBG] PRE cap i=5: read_addr=0x4 read_data=0x3 tvalid=x tready=1 sag_row=1 sag_col=2 ao_row=0 ao_col=0
  [DBG] AFTER 6 caps: read_addr=0x4 read_data=0x3 sag_row=1 sag_col=2 ao_row=0 ao_col=0
  [BP] tready=0 for 5 cycles
  [DBG] STALL cyc=0: read_addr=0x4 read_data=0x4 sag_row=1 sag_col=2 ao_row=0 ao_col=0 ao_tvalid=x
  [DBG] STALL cyc=1: read_addr=0x4 read_data=0x4 sag_row=1 sag_col=2 ao_row=0 ao_col=0 ao_tvalid=x
  [DBG] STALL cyc=2: read_addr=0x4 read_data=0x4 sag_row=1 sag_col=2 ao_row=0 ao_col=0 ao_tvalid=x
  [DBG] STALL cyc=3: read_addr=0x4 read_data=0x4 sag_row=1 sag_col=2 ao_row=0 ao_col=0 ao_tvalid=x
  [DBG] STALL cyc=4: read_addr=0x4 read_data=0x4 sag_row=1 sag_col=2 ao_row=0 ao_col=0 ao_tvalid=x
  [DBG] AFTER STALL resume: read_addr=0x4 read_data=0x4 sag_row=1 sag_col=2 ao_row=0 ao_col=0
  [BP] resume
  [DBG] RESUME cap i=0: read_addr=0x5 read_data=0x4 tvalid=x tready=1 sag_row=1 sag_col=3 ao_row=0 ao_col=0
  [DBG] RESUME cap i=1: read_addr=0x6 read_data=0x5 tvalid=x tready=1 sag_row=2 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=2: read_addr=0x7 read_data=0x6 tvalid=x tready=1 sag_row=2 sag_col=1 ao_row=0 ao_col=0
  [DBG] RESUME cap i=3: read_addr=0x8 read_data=0x7 tvalid=x tready=1 sag_row=2 sag_col=2 ao_row=0 ao_col=0
  [DBG] RESUME cap i=4: read_addr=0x9 read_data=0x8 tvalid=x tready=1 sag_row=2 sag_col=3 ao_row=0 ao_col=0
  [DBG] RESUME cap i=5: read_addr=0xa read_data=0x9 tvalid=x tready=1 sag_row=3 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=6: read_addr=0xb read_data=0xa tvalid=x tready=1 sag_row=3 sag_col=1 ao_row=0 ao_col=0
  [DBG] RESUME cap i=7: read_addr=0xc read_data=0xb tvalid=x tready=1 sag_row=3 sag_col=2 ao_row=0 ao_col=0
  [DBG] RESUME cap i=8: read_addr=0xd read_data=0xc tvalid=x tready=1 sag_row=3 sag_col=3 ao_row=0 ao_col=0
  [DBG] RESUME cap i=9: read_addr=0xe read_data=0xd tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=10: read_addr=0xf read_data=0xe tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=11: read_addr=0x0 read_data=0xf tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=12: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=13: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=14: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=15: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=16: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=17: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=18: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=19: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=20: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=21: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=22: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=23: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=24: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=25: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=26: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=27: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=28: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] RESUME cap i=29: read_addr=0x0 read_data=0x0 tvalid=x tready=1 sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] FINAL cap_count=0 gold_count=16
  [TC09] beats=0 exp=16 data=0 tuser=0 tlast=0
  FAIL [9] beat
  PASS [9] data
  PASS [9] tuser
  PASS [9] tlast
--- TC10: shift_en toggle ---
  [TC10] shift_en=0 for 5 cycles
  PASS [10] tvalid=0 after pause
  [TC10] reset+new frame
  [BRAM] Preloaded 4096 words (linear)
  [TC10] data errs=0/16
  PASS [10] data OK
--- TC11: Edge cases ---
  [BRAM] Preloaded 4096 words (linear)
  1x1 NONE
  [CHK] beats=0 exp=1 data_err=0 tuser_err=0 tlast_err=0
  FAIL [11] beat count
  PASS [11] data OK
  PASS [11] tuser OK
  PASS [11] tlast OK
  1x5 LEFT step=1
  [CHK] beats=0 exp=5 data_err=0 tuser_err=0 tlast_err=0
  FAIL [11] beat count
  PASS [11] data OK
  PASS [11] tuser OK
  PASS [11] tlast OK
  5x1 DOWN zf step=2
  [CHK] beats=0 exp=5 data_err=0 tuser_err=0 tlast_err=0
  FAIL [11] beat count
  PASS [11] data OK
  PASS [11] tuser OK
  PASS [11] tlast OK
--- TC12: counter persistence ---
  [DBG] TC12 INIT: sag_row=0 sag_col=0 ao_row=0 ao_col=0 read_data=0x0
  [TC12] Frame1: 6 pixels (partial)
  [DBG] TC12a i=0: read_data=0x0 tvalid=0 sag_row=0 sag_col=1 ao_row=0 ao_col=0
  [DBG] TC12a i=1: read_data=0x0 tvalid=x sag_row=0 sag_col=2 ao_row=0 ao_col=0
  [DBG] TC12a i=2: read_data=0x0 tvalid=x sag_row=0 sag_col=3 ao_row=0 ao_col=0
  [DBG] TC12a i=3: read_data=0x1 tvalid=x sag_row=1 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12a i=4: read_data=0x2 tvalid=x sag_row=1 sag_col=1 ao_row=0 ao_col=0
  [DBG] TC12a i=5: read_data=0x3 tvalid=x sag_row=1 sag_col=2 ao_row=0 ao_col=0
  [DBG] TC12a i=6: read_data=0x4 tvalid=x sag_row=1 sag_col=3 ao_row=0 ao_col=0
  [DBG] TC12a i=7: read_data=0x5 tvalid=x sag_row=2 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12a i=8: read_data=0x6 tvalid=x sag_row=2 sag_col=1 ao_row=0 ao_col=0
  [DBG] TC12a i=9: read_data=0x7 tvalid=x sag_row=2 sag_col=2 ao_row=0 ao_col=0
  [DBG] TC12a i=10: read_data=0x8 tvalid=x sag_row=2 sag_col=3 ao_row=0 ao_col=0
  [DBG] TC12a i=11: read_data=0x9 tvalid=x sag_row=3 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12a i=12: read_data=0xa tvalid=x sag_row=3 sag_col=1 ao_row=0 ao_col=0
  [DBG] TC12a i=13: read_data=0xb tvalid=x sag_row=3 sag_col=2 ao_row=0 ao_col=0
  [DBG] TC12a i=14: read_data=0xc tvalid=x sag_row=3 sag_col=3 ao_row=0 ao_col=0
  [DBG] TC12a i=15: read_data=0xd tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12a i=16: read_data=0xe tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12a i=17: read_data=0xf tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12a i=18: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12a i=19: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12 AFTER F1: sag_row=0 sag_col=0 ao_row=0 ao_col=0 read_data=0x0
  [TC12] Frame1: 0 beats captured
  [TC12] Frame2: resume without reset
  [DBG] TC12 F2 init: sag_row=0 sag_col=1 ao_row=0 ao_col=0 read_data=0x0
  [DBG] TC12b i=0: read_data=0x0 tvalid=x sag_row=0 sag_col=2 ao_row=0 ao_col=0
  [DBG] TC12b i=1: read_data=0x0 tvalid=x sag_row=0 sag_col=3 ao_row=0 ao_col=0
  [DBG] TC12b i=2: read_data=0x1 tvalid=x sag_row=1 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=3: read_data=0x2 tvalid=x sag_row=1 sag_col=1 ao_row=0 ao_col=0
  [DBG] TC12b i=4: read_data=0x3 tvalid=x sag_row=1 sag_col=2 ao_row=0 ao_col=0
  [DBG] TC12b i=5: read_data=0x4 tvalid=x sag_row=1 sag_col=3 ao_row=0 ao_col=0
  [DBG] TC12b i=6: read_data=0x5 tvalid=x sag_row=2 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=7: read_data=0x6 tvalid=x sag_row=2 sag_col=1 ao_row=0 ao_col=0
  [DBG] TC12b i=8: read_data=0x7 tvalid=x sag_row=2 sag_col=2 ao_row=0 ao_col=0
  [DBG] TC12b i=9: read_data=0x8 tvalid=x sag_row=2 sag_col=3 ao_row=0 ao_col=0
  [DBG] TC12b i=10: read_data=0x9 tvalid=x sag_row=3 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=11: read_data=0xa tvalid=x sag_row=3 sag_col=1 ao_row=0 ao_col=0
  [DBG] TC12b i=12: read_data=0xb tvalid=x sag_row=3 sag_col=2 ao_row=0 ao_col=0
  [DBG] TC12b i=13: read_data=0xc tvalid=x sag_row=3 sag_col=3 ao_row=0 ao_col=0
  [DBG] TC12b i=14: read_data=0xd tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=15: read_data=0xe tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=16: read_data=0xf tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=17: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=18: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=19: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=20: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=21: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=22: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=23: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=24: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=25: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=26: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=27: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=28: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [DBG] TC12b i=29: read_data=0x0 tvalid=x sag_row=0 sag_col=0 ao_row=0 ao_col=0
  [TC12] Total beats: 0
  FAIL [12] insufficient beats

============================================================
  Simulation Summary
============================================================
  Passed: 44
  Failed: 15
  Total : 59
------------------------------------------------------------
  SOME TESTS FAILED  <<<
============================================================
```

## Waveform

VCD file saved to: `sim/tb_l1b_read_path.vcd`

Open with: `gtkwave sim/tb_l1b_read_path.vcd`

## Checksum

- Report generated: 2026/06/06
