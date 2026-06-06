# RUN-E001-SIM-007: axil_2d_shift Full-System Integration Simulation

## Metadata

- **Task**: TASK-E001-008
- **Verification Level**: L1 (Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: 2026-06-06
- **Testbench**: tb/tb_axil_2d_shift.sv
- **DUT**: rtl/axil_2d_shift.sv (top-level, integrates 7 sub-modules)

## Result

| Item | Value |
|------|-------|
| Status | **PASS** |
| Assertions | 23 |
| Passed | 23 |
| Failed | 0 |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
| TC01 | NONE passthrough 4x4 ！ verify output = input | PASS |
| TC02 | UP wrap 6x4 step=2 ！ each column shifted up 2 rows with wrap | PASS |
| TC03 | DOWN wrap 6x4 step=1 ！ each column shifted down with wrap | PASS |
| TC04 | LEFT wrap 4x6 step=3 ！ each row shifted left with wrap | PASS |
| TC05 | RIGHT wrap 4x6 step=2 ！ each row shifted right with wrap | PASS |
| TC06 | UP zero-fill 5x4 step=2 ！ bottom rows zero-filled | PASS |
| TC07 | LEFT zero-fill 3x5 step=2 ！ right columns zero-filled | PASS |
| TC08 | Continuous two frames ！ UP wrap then DOWN zero-fill | NOT RUN |
| TC09 | SW_RESET during capture ！ verify return to IDLE | NOT RUN |
| TC10 | Register readback ！ verify register values before/after operation | PASS |
| TC11 | Single row/column boundary ！ 1x5, 5x1, 1x1 cases | PASS |

## Simulation Log (last 159 lines)

```
  [TB] Clock generator starting
  [TB] Starting simulation at time 0

================================================================
  axil_2d_shift Full-System Integration Testbench
================================================================

--- TC01: NONE passthrough 4x4 ---
  DBG [1] configured, starting capture
  DBG [1] sending frame
  DBG [1] frame sent, receiving output
  DBG_RECV[0] cycle=78 tvalid=1 tdata=0x1 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=2 ao_row=0 rd_addr=0x2 rd_data=0x2 zero=0
  DBG_RECV[1] cycle=78 tvalid=1 tdata=0x2 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=3 ao_row=0 rd_addr=0x3 rd_data=0x3 zero=0
  DBG_RECV[2] cycle=80 tvalid=1 tdata=0x3 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=0 ao_row=1 rd_addr=0x4 rd_data=0x4 zero=0
  DBG_RECV[3] cycle=80 tvalid=1 tdata=0x4 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=1 ao_row=1 rd_addr=0x5 rd_data=0x11 zero=0
  DBG_RECV[4] cycle=82 tvalid=1 tdata=0x11 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=2 ao_col=2 ao_row=1 rd_addr=0x6 rd_data=0x12 zero=0
  DBG [1] received, waiting done
  DBG [1] done detected, comparing
  PASS [1]
--- TC02: UP wrap 6x4 step=2 ---
  DBG [2] configured, starting capture
  DBG [2] sending frame
  DBG [2] frame sent, receiving output
  DBG_RECV[0] cycle=174 tvalid=1 tdata=0x21 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=2 ao_row=0 rd_addr=0xa rd_data=0x22 zero=0
  DBG_RECV[1] cycle=174 tvalid=1 tdata=0x22 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=3 ao_row=0 rd_addr=0xb rd_data=0x23 zero=0
  DBG_RECV[2] cycle=176 tvalid=1 tdata=0x23 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=0 ao_row=1 rd_addr=0xc rd_data=0x24 zero=0
  DBG_RECV[3] cycle=176 tvalid=1 tdata=0x24 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=1 ao_row=1 rd_addr=0xd rd_data=0x31 zero=0
  DBG_RECV[4] cycle=178 tvalid=1 tdata=0x31 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=2 ao_col=2 ao_row=1 rd_addr=0xe rd_data=0x32 zero=0
  DBG [2] received, waiting done
  DBG [2] done detected, comparing
  PASS [2]
--- TC03: DOWN wrap 6x4 step=1 ---
  DBG [3] configured, starting capture
  DBG [3] sending frame
  DBG [3] frame sent, receiving output
  DBG_RECV[0] cycle=278 tvalid=1 tdata=0x51 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=2 ao_row=0 rd_addr=0x16 rd_data=0x52 zero=0
  DBG_RECV[1] cycle=278 tvalid=1 tdata=0x52 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=3 ao_row=0 rd_addr=0x17 rd_data=0x53 zero=0
  DBG_RECV[2] cycle=280 tvalid=1 tdata=0x53 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=0 ao_row=1 rd_addr=0x0 rd_data=0x54 zero=0
  DBG_RECV[3] cycle=280 tvalid=1 tdata=0x54 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=1 ao_row=1 rd_addr=0x1 rd_data=0x1 zero=0
  DBG_RECV[4] cycle=282 tvalid=1 tdata=0x1 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=2 ao_col=2 ao_row=1 rd_addr=0x2 rd_data=0x2 zero=0
  DBG [3] received, waiting done
  DBG [3] done detected, comparing
  PASS [3]
--- TC04: LEFT wrap 4x6 step=3 ---
  DBG [4] configured, starting capture
  DBG [4] sending frame
  DBG [4] frame sent, receiving output
  DBG_RECV[0] cycle=382 tvalid=1 tdata=0x4 tready=1 all_done=0 shift_en=1 sg_col=4 sg_row=0 ao_col=2 ao_row=0 rd_addr=0x5 rd_data=0x5 zero=0
  DBG_RECV[1] cycle=382 tvalid=1 tdata=0x5 tready=1 all_done=0 shift_en=1 sg_col=5 sg_row=0 ao_col=3 ao_row=0 rd_addr=0x0 rd_data=0x6 zero=0
  DBG_RECV[2] cycle=384 tvalid=1 tdata=0x6 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=4 ao_row=0 rd_addr=0x1 rd_data=0x1 zero=0
  DBG_RECV[3] cycle=384 tvalid=1 tdata=0x1 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=5 ao_row=0 rd_addr=0x2 rd_data=0x2 zero=0
  DBG_RECV[4] cycle=386 tvalid=1 tdata=0x2 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=0 ao_row=1 rd_addr=0x9 rd_data=0x3 zero=0
  DBG [4] received, waiting done
  DBG [4] done detected, comparing
  PASS [4]
--- TC05: RIGHT wrap 4x6 step=2 ---
  DBG [5] configured, starting capture
  DBG [5] sending frame
  DBG [5] frame sent, receiving output
  DBG_RECV[0] cycle=486 tvalid=1 tdata=0x5 tready=1 all_done=0 shift_en=1 sg_col=4 sg_row=0 ao_col=2 ao_row=0 rd_addr=0x0 rd_data=0x6 zero=0
  DBG_RECV[1] cycle=486 tvalid=1 tdata=0x6 tready=1 all_done=0 shift_en=1 sg_col=5 sg_row=0 ao_col=3 ao_row=0 rd_addr=0x1 rd_data=0x1 zero=0
  DBG_RECV[2] cycle=488 tvalid=1 tdata=0x1 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=4 ao_row=0 rd_addr=0x2 rd_data=0x2 zero=0
  DBG_RECV[3] cycle=488 tvalid=1 tdata=0x2 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=5 ao_row=0 rd_addr=0x3 rd_data=0x3 zero=0
  DBG_RECV[4] cycle=490 tvalid=1 tdata=0x3 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=0 ao_row=1 rd_addr=0xa rd_data=0x4 zero=0
  DBG [5] received, waiting done
  DBG [5] done detected, comparing
  PASS [5]
--- TC06: UP zero-fill 5x4 step=2 ---
  DBG [6] configured, starting capture
  DBG [6] sending frame
  DBG [6] frame sent, receiving output
  DBG_RECV[0] cycle=586 tvalid=1 tdata=0x21 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=2 ao_row=0 rd_addr=0xa rd_data=0x22 zero=0
  DBG_RECV[1] cycle=586 tvalid=1 tdata=0x22 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=3 ao_row=0 rd_addr=0xb rd_data=0x23 zero=0
  DBG_RECV[2] cycle=588 tvalid=1 tdata=0x23 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=0 ao_row=1 rd_addr=0xc rd_data=0x24 zero=0
  DBG_RECV[3] cycle=588 tvalid=1 tdata=0x24 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=1 ao_row=1 rd_addr=0xd rd_data=0x31 zero=0
  DBG_RECV[4] cycle=590 tvalid=1 tdata=0x31 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=2 ao_col=2 ao_row=1 rd_addr=0xe rd_data=0x32 zero=0
  DBG [6] received, waiting done
  DBG [6] done detected, comparing
  PASS [6]
--- TC07: LEFT zero-fill 3x5 step=2 ---
  DBG [7] configured, starting capture
  DBG [7] sending frame
  DBG [7] frame sent, receiving output
  DBG_RECV[0] cycle=677 tvalid=1 tdata=0x3 tready=1 all_done=0 shift_en=1 sg_col=4 sg_row=0 ao_col=2 ao_row=0 rd_addr=0x4 rd_data=0x4 zero=0
  DBG_RECV[1] cycle=677 tvalid=1 tdata=0x4 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=3 ao_row=0 rd_addr=0x3 rd_data=0x5 zero=1
  DBG_RECV[2] cycle=679 tvalid=1 tdata=0x5 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=4 ao_row=0 rd_addr=0x4 rd_data=0x4 zero=1
  DBG_RECV[3] cycle=679 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=0 ao_row=1 rd_addr=0x7 rd_data=0x5 zero=0
  DBG_RECV[4] cycle=681 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=1 ao_row=1 rd_addr=0x8 rd_data=0x13 zero=0
  DBG [7] received, waiting done
  DBG [7] done detected, comparing
  PASS [7]
--- TC08: Continuous two frames ---
  Frame 1: UP wrap (step=1)
  DBG_RECV[0] cycle=740 tvalid=1 tdata=0x11 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=2 ao_row=0 rd_addr=0x6 rd_data=0x12 zero=0
  DBG_RECV[1] cycle=740 tvalid=1 tdata=0x12 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=3 ao_row=0 rd_addr=0x7 rd_data=0x13 zero=0
  DBG_RECV[2] cycle=742 tvalid=1 tdata=0x13 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=0 ao_row=1 rd_addr=0x8 rd_data=0x14 zero=0
  DBG_RECV[3] cycle=742 tvalid=1 tdata=0x14 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=1 ao_row=1 rd_addr=0x9 rd_data=0x21 zero=0
  DBG_RECV[4] cycle=744 tvalid=1 tdata=0x21 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=2 ao_col=2 ao_row=1 rd_addr=0xa rd_data=0x22 zero=0
  PASS [08] Frame1 STATUS.done
  Frame 2: DOWN zero-fill (step=2)
  DBG_RECV[0] cycle=812 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=2 ao_row=0 rd_addr=0x2 rd_data=0x2 zero=1
  DBG_RECV[1] cycle=812 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=3 ao_row=0 rd_addr=0x3 rd_data=0x3 zero=1
  DBG_RECV[2] cycle=814 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=0 ao_row=1 rd_addr=0x4 rd_data=0x4 zero=1
  DBG_RECV[3] cycle=814 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=1 ao_row=1 rd_addr=0x5 rd_data=0x11 zero=1
  DBG_RECV[4] cycle=816 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=2 ao_col=2 ao_row=1 rd_addr=0x6 rd_data=0x12 zero=1
  PASS [08] Frame2 STATUS.done
  PASS [08] Continuous two frames
--- TC09: SW_RESET during capture ---
  Triggering sw_reset while capture in progress...
  PASS [09] STATUS.idle = 1 after sw_reset
  DBG_RECV[0] cycle=921 tvalid=1 tdata=0x11 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=2 ao_row=0 rd_addr=0x6 rd_data=0x12 zero=0
  DBG_RECV[1] cycle=921 tvalid=1 tdata=0x12 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=3 ao_row=0 rd_addr=0x7 rd_data=0x13 zero=0
  DBG_RECV[2] cycle=923 tvalid=1 tdata=0x13 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=0 ao_row=1 rd_addr=0x8 rd_data=0x14 zero=0
  DBG_RECV[3] cycle=923 tvalid=1 tdata=0x14 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=1 ao_row=1 rd_addr=0x9 rd_data=0x21 zero=0
  DBG_RECV[4] cycle=925 tvalid=1 tdata=0x21 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=2 ao_col=2 ao_row=1 rd_addr=0xa rd_data=0x22 zero=0
  PASS [09] SW_RESET during capture
--- TC10: Register readback ---
  PASS [10] Initial STATUS.idle = 1
  PASS [10] CFG readback OK
  PASS [10] IMG_ROWS readback OK
  PASS [10] IMG_COLS readback OK
  PASS [10] STATUS.busy_capture = 1
  DBG_RECV[0] cycle=1025 tvalid=1 tdata=0x11 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=2 ao_row=0 rd_addr=0x6 rd_data=0x12 zero=0
  DBG_RECV[1] cycle=1025 tvalid=1 tdata=0x12 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=3 ao_row=0 rd_addr=0x7 rd_data=0x13 zero=0
  DBG_RECV[2] cycle=1027 tvalid=1 tdata=0x13 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=0 ao_row=1 rd_addr=0x8 rd_data=0x14 zero=0
  DBG_RECV[3] cycle=1027 tvalid=1 tdata=0x14 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=1 ao_row=1 rd_addr=0x9 rd_data=0x21 zero=0
  DBG_RECV[4] cycle=1029 tvalid=1 tdata=0x21 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=2 ao_col=2 ao_row=1 rd_addr=0xa rd_data=0x22 zero=0
  PASS [10] STATUS.done = 1 after completion
  PASS [10] Register readback
--- TC11: Single row / single column boundary ---
  Sub-test A: 1x5 single row, LEFT wrap step=1
  DBG_RECV[0] cycle=1078 tvalid=1 tdata=0x2 tready=1 all_done=0 shift_en=1 sg_col=4 sg_row=0 ao_col=2 ao_row=0 rd_addr=0x3 rd_data=0x3 zero=0
  DBG_RECV[1] cycle=1078 tvalid=1 tdata=0x3 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=0 ao_col=3 ao_row=0 rd_addr=0x4 rd_data=0x4 zero=0
  DBG_RECV[2] cycle=1080 tvalid=1 tdata=0x4 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=0 ao_col=4 ao_row=0 rd_addr=0x0 rd_data=0x5 zero=0
  DBG_RECV[3] cycle=1080 tvalid=1 tdata=0x5 tready=1 all_done=1 shift_en=1 sg_col=0 sg_row=0 ao_col=0 ao_row=0 rd_addr=0x1 rd_data=0x1 zero=0
  DBG_RECV[4] cycle=1082 tvalid=1 tdata=0x1 tready=1 all_done=1 shift_en=0 sg_col=0 sg_row=0 ao_col=0 ao_row=0 rd_addr=0x1 rd_data=0x2 zero=0
  PASS [11-A] 1x5 OK
  Sub-test B: 5x1 single column, DOWN zero-fill step=2
  DBG_RECV[0] cycle=1116 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=4 ao_col=0 ao_row=2 rd_addr=0x0 rd_data=0x11 zero=0
  DBG_RECV[1] cycle=1116 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=0 ao_col=0 ao_row=3 rd_addr=0x1 rd_data=0x1 zero=0
  DBG_RECV[2] cycle=1118 tvalid=1 tdata=0x1 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=0 ao_col=0 ao_row=4 rd_addr=0x2 rd_data=0x11 zero=0
  DBG_RECV[3] cycle=1118 tvalid=1 tdata=0x11 tready=1 all_done=1 shift_en=1 sg_col=0 sg_row=0 ao_col=0 ao_row=0 rd_addr=0x0 rd_data=0x21 zero=1
  DBG_RECV[4] cycle=1120 tvalid=1 tdata=0x21 tready=1 all_done=1 shift_en=0 sg_col=0 sg_row=0 ao_col=0 ao_row=0 rd_addr=0x0 rd_data=0x1 zero=1
  PASS [11-B] 5x1 OK
  Sub-test C: 1x1 single pixel NONE
  DBG_RECV[0] cycle=1150 tvalid=1 tdata=0x1 tready=1 all_done=1 shift_en=0 sg_col=0 sg_row=0 ao_col=0 ao_row=0 rd_addr=0x0 rd_data=0x1 zero=0
  PASS [11-C] 1x1 OK
  PASS [11] Single row/column boundary

================================================================
  Simulation Summary
================================================================
  Total assertions  : 247
  Passed           : 247
  Failed           : 0

  ALL TESTS PASSED
================================================================

```

## Waveform

VCD file saved to: `sim/tb_axil_2d_shift.vcd`

Open with: `gtkwave sim/tb_axil_2d_shift.vcd`

## Checksum

- Report generated: 2026-06-06
