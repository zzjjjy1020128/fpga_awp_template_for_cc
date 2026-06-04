# RUN-E001-SIM-006: frame_buf_mgr Dual-Port BRAM Controller Simulation

## Metadata

- **Task**: TASK-E001-007
- **Verification Level**: L1 (Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: 2026/06/04
- **Testbench**: tb/tb_frame_buf_mgr.sv
- **DUT**: rtl/frame_buf_mgr.sv

## Result

| Item | Value |
|------|-------|
| Status | **PASS** |
| Assertions | 195 |
| Passed | 195 |
| Failed | 0 |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
| TC01 | Basic write-then-read ！ write addr=0 data=0xAA, read back verify | PASS |
| TC02 | Sequential write 0..127, read back verify each | PASS |
| TC03 | Random address write, shuffled read order | PASS |
| TC04 | Full depth write/read ！ all 4096 locations | PASS |
| TC05 | Simultaneous read/write different addresses ！ independence | PASS |
| TC06 | Simultaneous read/write same address ！ read-first behavior | PASS |
| TC07 | write_en=0 does not write ！ read back old value | PASS |
| TC08 | 1-cycle read latency verification | PASS |
| TC09 | Reset read_data=0 | PASS |

## Simulation Log (last 100 lines)

```
  PASS [2] seq addr=111 data=111
  PASS [2] seq addr=112 data=112
  PASS [2] seq addr=113 data=113
  PASS [2] seq addr=114 data=114
  PASS [2] seq addr=115 data=115
  PASS [2] seq addr=116 data=116
  PASS [2] seq addr=117 data=117
  PASS [2] seq addr=118 data=118
  PASS [2] seq addr=119 data=119
  PASS [2] seq addr=120 data=120
  PASS [2] seq addr=121 data=121
  PASS [2] seq addr=122 data=122
  PASS [2] seq addr=123 data=123
  PASS [2] seq addr=124 data=124
  PASS [2] seq addr=125 data=125
  PASS [2] seq addr=126 data=126
  PASS [2] seq addr=127 data=127
--- TC3: Random address write, shuffled read ---
  PASS [3] rand addr=2546 data=206
  PASS [3] rand addr=2553 data=198
  PASS [3] rand addr=3990 data=12
  PASS [3] rand addr=2571 data=113
  PASS [3] rand addr=2552 data=183
  PASS [3] rand addr=1316 data=129
  PASS [3] rand addr=3570 data=138
  PASS [3] rand addr=2792 data=197
  PASS [3] rand addr=3734 data=19
  PASS [3] rand addr=2762 data=60
  PASS [3] rand addr=1890 data=76
  PASS [3] rand addr=640 data=32
  PASS [3] rand addr=3778 data=200
  PASS [3] rand addr=1221 data=170
  PASS [3] rand addr=2339 data=10
  PASS [3] rand addr=3057 data=217
  PASS [3] rand addr=3563 data=182
  PASS [3] rand addr=3973 data=120
  PASS [3] rand addr=638 data=21
  PASS [3] rand addr=833 data=216
  PASS [3] rand addr=2834 data=126
  PASS [3] rand addr=769 data=13
  PASS [3] rand addr=59 data=58
  PASS [3] rand addr=3871 data=211
  PASS [3] rand addr=2829 data=141
  PASS [3] rand addr=1439 data=143
  PASS [3] rand addr=1695 data=92
  PASS [3] rand addr=2333 data=207
  PASS [3] rand addr=2502 data=174
  PASS [3] rand addr=2061 data=83
  PASS [3] rand addr=2021 data=119
  PASS [3] rand addr=2029 data=140
  PASS [3] rand addr=2562 data=174
  PASS [3] rand addr=2396 data=189
  PASS [3] rand addr=2093 data=101
  PASS [3] rand addr=888 data=137
  PASS [3] rand addr=374 data=61
  PASS [3] rand addr=365 data=57
  PASS [3] rand addr=389 data=79
  PASS [3] rand addr=91 data=137
  PASS [3] rand addr=1125 data=18
  PASS [3] rand addr=215 data=81
  PASS [3] rand addr=1554 data=143
  PASS [3] rand addr=700 data=42
  PASS [3] rand addr=2679 data=61
  PASS [3] rand addr=3435 data=213
  PASS [3] rand addr=1545 data=99
  PASS [3] rand addr=611 data=10
  PASS [3] rand addr=1450 data=157
  PASS [3] rand addr=585 data=208
  PASS [3] TC03 random shuffled read no errors
--- TC4: Full depth write/read (4096 words) ---
  PASS [4] full depth errs=0/4096
--- TC5: Simultaneous diff-addr write/read ---
  PASS [5] diff-addr: read addr 200 = 0x55
  PASS [5] diff-addr: addr 100 = 0xCD after write
  PASS [5] diff-addr: addr 200 still 0x55
--- TC6: Simultaneous same-addr write/read ---
  PASS [6] same-addr: write-first (new value 0xBB)
  PASS [6] same-addr: write took effect (now 0xBB)
--- TC7: write_en=0 preserves data ---
  PASS [7] write_en=0: initial addr 400 = 0x77
  PASS [7] write_en=0: addr 400 unchanged (0x77)
--- TC8: 1-cycle read latency ---
  PASS [8] latency: warmup read addr 500 = 0xA5
  PASS [8] latency: read_data = bram[501] = 0x5A
  PASS [8] latency: read_data = bram[500] = 0xA5
--- TC9: Reset read_data=0 ---
  PASS [9] reset: addr 600 = 0x99 before reset
  PASS [9] reset: read_data = 0 during reset
  PASS [9] reset: read_data still 0 during reset hold
  PASS [9] reset: after release read addr 600 = 0x99

============================================================
  Simulation Summary
============================================================
  Passed: 195
  Failed: 0
  Total : 195
------------------------------------------------------------
  ALL TESTS PASSED
============================================================
```

## Waveform

VCD file saved to: `sim/tb_frame_buf_mgr.vcd`

Open with: `gtkwave sim/tb_frame_buf_mgr.vcd`

## Checksum

- Report generated: 2026/06/04
