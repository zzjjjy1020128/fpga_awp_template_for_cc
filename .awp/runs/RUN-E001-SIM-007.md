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
| Status | **FAIL** |
| Assertions | 242 |
| Passed | 10 |
| Failed | 232 |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
| TC01 | NONE passthrough 4x4 ！ verify output = input | FAIL |
| TC02 | UP wrap 6x4 step=2 ！ each column shifted up 2 rows with wrap | FAIL |
| TC03 | DOWN wrap 6x4 step=1 ！ each column shifted down with wrap | FAIL |
| TC04 | LEFT wrap 4x6 step=3 ！ each row shifted left with wrap | FAIL |
| TC05 | RIGHT wrap 4x6 step=2 ！ each row shifted right with wrap | FAIL |
| TC06 | UP zero-fill 5x4 step=2 ！ bottom rows zero-filled | FAIL |
| TC07 | LEFT zero-fill 3x5 step=2 ！ right columns zero-filled | FAIL |
| TC08 | Continuous two frames ！ UP wrap then DOWN zero-fill | NOT RUN |
| TC09 | SW_RESET during capture ！ verify return to IDLE | NOT RUN |
| TC10 | Register readback ！ verify register values before/after operation | FAIL |
| TC11 | Single row/column boundary ！ 1x5, 5x1, 1x1 cases | FAIL |

## Simulation Log (last 300 lines)

```
  DBG_RECV[3] cycle=254 tvalid=1 tdata=0x1 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=0 ao_row=1 rd_addr=0x1 rd_data=0x1 zero=0
  DBG_RECV[4] cycle=256 tvalid=1 tdata=0x2 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=2 ao_col=1 ao_row=1 rd_addr=0x2 rd_data=0x2 zero=0
  DBG [3] received, waiting done
  DBG [3] done detected, comparing
  FAIL [3-0] at (r=0, c=0): got 0x52, expected 0x51
  FAIL [3-1] at (r=0, c=1): got 0x53, expected 0x52
  FAIL [3-2] at (r=0, c=2): got 0x54, expected 0x53
  FAIL [3-3] at (r=0, c=3): got 0x1, expected 0x54
  FAIL [3-4] at (r=1, c=0): got 0x2, expected 0x1
  FAIL [3-5] at (r=1, c=1): got 0x3, expected 0x2
  FAIL [3-6] at (r=1, c=2): got 0x4, expected 0x3
  FAIL [3-7] at (r=1, c=3): got 0x11, expected 0x4
  FAIL [3-8] at (r=2, c=0): got 0x12, expected 0x11
  FAIL [3-9] at (r=2, c=1): got 0x13, expected 0x12
  FAIL [3-10] at (r=2, c=2): got 0x14, expected 0x13
  FAIL [3-11] at (r=2, c=3): got 0x21, expected 0x14
  FAIL [3-12] at (r=3, c=0): got 0x22, expected 0x21
  FAIL [3-13] at (r=3, c=1): got 0x23, expected 0x22
  FAIL [3-14] at (r=3, c=2): got 0x24, expected 0x23
  FAIL [3-15] at (r=3, c=3): got 0x31, expected 0x24
  FAIL [3-16] at (r=4, c=0): got 0x32, expected 0x31
  FAIL [3-17] at (r=4, c=1): got 0x33, expected 0x32
  FAIL [3-18] at (r=4, c=2): got 0x34, expected 0x33
  FAIL [3-19] at (r=4, c=3): got 0x41, expected 0x34
  FAIL [3-20] at (r=5, c=0): got 0x42, expected 0x41
  FAIL [3-21] at (r=5, c=1): got 0x43, expected 0x42
  FAIL [3-22] at (r=5, c=2): got 0x44, expected 0x43
  FAIL [3-23] at (r=5, c=3): got 0x51, expected 0x44
  FAIL [3] -- 24 mismatches
--- TC04: LEFT wrap 4x6 step=3 ---
  DBG [4] configured, starting capture
  DBG [4] sending frame
  DBG [4] frame sent, receiving output
  DBG_RECV[0] cycle=347 tvalid=1 tdata=0x5 tready=1 all_done=0 shift_en=1 sg_col=4 sg_row=0 ao_col=1 ao_row=0 rd_addr=0x5 rd_data=0x5 zero=0
  DBG_RECV[1] cycle=347 tvalid=1 tdata=0x6 tready=1 all_done=0 shift_en=1 sg_col=5 sg_row=0 ao_col=2 ao_row=0 rd_addr=0x0 rd_data=0x6 zero=0
  DBG_RECV[2] cycle=349 tvalid=1 tdata=0x1 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=3 ao_row=0 rd_addr=0x1 rd_data=0x1 zero=0
  DBG_RECV[3] cycle=349 tvalid=1 tdata=0x2 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=4 ao_row=0 rd_addr=0x2 rd_data=0x2 zero=0
  DBG_RECV[4] cycle=351 tvalid=1 tdata=0x3 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=5 ao_row=0 rd_addr=0x9 rd_data=0x3 zero=0
  DBG [4] received, waiting done
  DBG [4] done detected, comparing
  FAIL [4-0] at (r=0, c=0): got 0x5, expected 0x4
  FAIL [4-1] at (r=0, c=1): got 0x6, expected 0x5
  FAIL [4-2] at (r=0, c=2): got 0x1, expected 0x6
  FAIL [4-3] at (r=0, c=3): got 0x2, expected 0x1
  FAIL [4-4] at (r=0, c=4): got 0x3, expected 0x2
  FAIL [4-5] at (r=0, c=5): got 0x14, expected 0x3
  FAIL [4-6] at (r=1, c=0): got 0x15, expected 0x14
  FAIL [4-7] at (r=1, c=1): got 0x16, expected 0x15
  FAIL [4-8] at (r=1, c=2): got 0x11, expected 0x16
  FAIL [4-9] at (r=1, c=3): got 0x12, expected 0x11
  FAIL [4-10] at (r=1, c=4): got 0x13, expected 0x12
  FAIL [4-11] at (r=1, c=5): got 0x24, expected 0x13
  FAIL [4-12] at (r=2, c=0): got 0x25, expected 0x24
  FAIL [4-13] at (r=2, c=1): got 0x26, expected 0x25
  FAIL [4-14] at (r=2, c=2): got 0x21, expected 0x26
  FAIL [4-15] at (r=2, c=3): got 0x22, expected 0x21
  FAIL [4-16] at (r=2, c=4): got 0x23, expected 0x22
  FAIL [4-17] at (r=2, c=5): got 0x34, expected 0x23
  FAIL [4-18] at (r=3, c=0): got 0x35, expected 0x34
  FAIL [4-19] at (r=3, c=1): got 0x36, expected 0x35
  FAIL [4-20] at (r=3, c=2): got 0x31, expected 0x36
  FAIL [4-21] at (r=3, c=3): got 0x32, expected 0x31
  FAIL [4-22] at (r=3, c=4): got 0x33, expected 0x32
  FAIL [4-23] at (r=3, c=5): got 0x4, expected 0x33
  FAIL [4] -- 24 mismatches
--- TC05: RIGHT wrap 4x6 step=2 ---
  DBG [5] configured, starting capture
  DBG [5] sending frame
  DBG [5] frame sent, receiving output
  DBG_RECV[0] cycle=442 tvalid=1 tdata=0x6 tready=1 all_done=0 shift_en=1 sg_col=4 sg_row=0 ao_col=1 ao_row=0 rd_addr=0x0 rd_data=0x6 zero=0
  DBG_RECV[1] cycle=442 tvalid=1 tdata=0x1 tready=1 all_done=0 shift_en=1 sg_col=5 sg_row=0 ao_col=2 ao_row=0 rd_addr=0x1 rd_data=0x1 zero=0
  DBG_RECV[2] cycle=444 tvalid=1 tdata=0x2 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=3 ao_row=0 rd_addr=0x2 rd_data=0x2 zero=0
  DBG_RECV[3] cycle=444 tvalid=1 tdata=0x3 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=4 ao_row=0 rd_addr=0x3 rd_data=0x3 zero=0
  DBG_RECV[4] cycle=446 tvalid=1 tdata=0x4 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=5 ao_row=0 rd_addr=0xa rd_data=0x4 zero=0
  DBG [5] received, waiting done
  DBG [5] done detected, comparing
  FAIL [5-0] at (r=0, c=0): got 0x6, expected 0x5
  FAIL [5-1] at (r=0, c=1): got 0x1, expected 0x6
  FAIL [5-2] at (r=0, c=2): got 0x2, expected 0x1
  FAIL [5-3] at (r=0, c=3): got 0x3, expected 0x2
  FAIL [5-4] at (r=0, c=4): got 0x4, expected 0x3
  FAIL [5-5] at (r=0, c=5): got 0x15, expected 0x4
  FAIL [5-6] at (r=1, c=0): got 0x16, expected 0x15
  FAIL [5-7] at (r=1, c=1): got 0x11, expected 0x16
  FAIL [5-8] at (r=1, c=2): got 0x12, expected 0x11
  FAIL [5-9] at (r=1, c=3): got 0x13, expected 0x12
  FAIL [5-10] at (r=1, c=4): got 0x14, expected 0x13
  FAIL [5-11] at (r=1, c=5): got 0x25, expected 0x14
  FAIL [5-12] at (r=2, c=0): got 0x26, expected 0x25
  FAIL [5-13] at (r=2, c=1): got 0x21, expected 0x26
  FAIL [5-14] at (r=2, c=2): got 0x22, expected 0x21
  FAIL [5-15] at (r=2, c=3): got 0x23, expected 0x22
  FAIL [5-16] at (r=2, c=4): got 0x24, expected 0x23
  FAIL [5-17] at (r=2, c=5): got 0x35, expected 0x24
  FAIL [5-18] at (r=3, c=0): got 0x36, expected 0x35
  FAIL [5-19] at (r=3, c=1): got 0x31, expected 0x36
  FAIL [5-20] at (r=3, c=2): got 0x32, expected 0x31
  FAIL [5-21] at (r=3, c=3): got 0x33, expected 0x32
  FAIL [5-22] at (r=3, c=4): got 0x34, expected 0x33
  FAIL [5-23] at (r=3, c=5): got 0x5, expected 0x34
  FAIL [5] -- 24 mismatches
--- TC06: UP zero-fill 5x4 step=2 ---
  DBG [6] configured, starting capture
  DBG [6] sending frame
  DBG [6] frame sent, receiving output
  DBG_RECV[0] cycle=533 tvalid=1 tdata=0x22 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=1 ao_row=0 rd_addr=0xa rd_data=0x22 zero=0
  DBG_RECV[1] cycle=533 tvalid=1 tdata=0x23 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=2 ao_row=0 rd_addr=0xb rd_data=0x23 zero=0
  DBG_RECV[2] cycle=535 tvalid=1 tdata=0x24 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=3 ao_row=0 rd_addr=0xc rd_data=0x24 zero=0
  DBG_RECV[3] cycle=535 tvalid=1 tdata=0x31 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=0 ao_row=1 rd_addr=0xd rd_data=0x31 zero=0
  DBG_RECV[4] cycle=537 tvalid=1 tdata=0x32 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=2 ao_col=1 ao_row=1 rd_addr=0xe rd_data=0x32 zero=0
  DBG [6] received, waiting done
  DBG [6] done detected, comparing
  FAIL [6-0] at (r=0, c=0): got 0x22, expected 0x21
  FAIL [6-1] at (r=0, c=1): got 0x23, expected 0x22
  FAIL [6-2] at (r=0, c=2): got 0x24, expected 0x23
  FAIL [6-3] at (r=0, c=3): got 0x31, expected 0x24
  FAIL [6-4] at (r=1, c=0): got 0x32, expected 0x31
  FAIL [6-5] at (r=1, c=1): got 0x33, expected 0x32
  FAIL [6-6] at (r=1, c=2): got 0x34, expected 0x33
  FAIL [6-7] at (r=1, c=3): got 0x41, expected 0x34
  FAIL [6-8] at (r=2, c=0): got 0x42, expected 0x41
  FAIL [6-9] at (r=2, c=1): got 0x43, expected 0x42
  FAIL [6-10] at (r=2, c=2): got 0x44, expected 0x43
  FAIL [6-11] at (r=2, c=3): got 0x0, expected 0x44
  FAIL [6-19] at (r=4, c=3): got 0x21, expected 0x0
  FAIL [6] -- 13 mismatches
--- TC07: LEFT zero-fill 3x5 step=2 ---
  DBG [7] configured, starting capture
  DBG [7] sending frame
  DBG [7] frame sent, receiving output
  DBG_RECV[0] cycle=615 tvalid=1 tdata=0x4 tready=1 all_done=0 shift_en=1 sg_col=4 sg_row=0 ao_col=1 ao_row=0 rd_addr=0x4 rd_data=0x4 zero=0
  DBG_RECV[1] cycle=615 tvalid=1 tdata=0x5 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=2 ao_row=0 rd_addr=0x3 rd_data=0x5 zero=1
  DBG_RECV[2] cycle=617 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=3 ao_row=0 rd_addr=0x4 rd_data=0x4 zero=1
  DBG_RECV[3] cycle=617 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=4 ao_row=0 rd_addr=0x7 rd_data=0x5 zero=0
  DBG_RECV[4] cycle=619 tvalid=1 tdata=0x13 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=0 ao_row=1 rd_addr=0x8 rd_data=0x13 zero=0
  DBG [7] received, waiting done
  DBG [7] done detected, comparing
  FAIL [7-0] at (r=0, c=0): got 0x4, expected 0x3
  FAIL [7-1] at (r=0, c=1): got 0x5, expected 0x4
  FAIL [7-2] at (r=0, c=2): got 0x0, expected 0x5
  FAIL [7-4] at (r=0, c=4): got 0x13, expected 0x0
  FAIL [7-5] at (r=1, c=0): got 0x14, expected 0x13
  FAIL [7-6] at (r=1, c=1): got 0x15, expected 0x14
  FAIL [7-7] at (r=1, c=2): got 0x0, expected 0x15
  FAIL [7-9] at (r=1, c=4): got 0x23, expected 0x0
  FAIL [7-10] at (r=2, c=0): got 0x24, expected 0x23
  FAIL [7-11] at (r=2, c=1): got 0x25, expected 0x24
  FAIL [7-12] at (r=2, c=2): got 0x0, expected 0x25
  FAIL [7-14] at (r=2, c=4): got 0x3, expected 0x0
  FAIL [7] -- 12 mismatches
--- TC08: Continuous two frames ---
  Frame 1: UP wrap (step=1)
  DBG_RECV[0] cycle=673 tvalid=1 tdata=0x12 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=1 ao_row=0 rd_addr=0x6 rd_data=0x12 zero=0
  DBG_RECV[1] cycle=673 tvalid=1 tdata=0x13 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=2 ao_row=0 rd_addr=0x7 rd_data=0x13 zero=0
  DBG_RECV[2] cycle=675 tvalid=1 tdata=0x14 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=3 ao_row=0 rd_addr=0x8 rd_data=0x14 zero=0
  DBG_RECV[3] cycle=675 tvalid=1 tdata=0x21 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=0 ao_row=1 rd_addr=0x9 rd_data=0x21 zero=0
  DBG_RECV[4] cycle=677 tvalid=1 tdata=0x22 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=2 ao_col=1 ao_row=1 rd_addr=0xa rd_data=0x22 zero=0
  PASS [08] Frame1 STATUS.done
  FAIL [08-F1-0] idx 0: got 0x12 exp 0x11
  FAIL [08-F1-1] idx 1: got 0x13 exp 0x12
  FAIL [08-F1-2] idx 2: got 0x14 exp 0x13
  FAIL [08-F1-3] idx 3: got 0x21 exp 0x14
  FAIL [08-F1-4] idx 4: got 0x22 exp 0x21
  FAIL [08-F1-5] idx 5: got 0x23 exp 0x22
  FAIL [08-F1-6] idx 6: got 0x24 exp 0x23
  FAIL [08-F1-7] idx 7: got 0x31 exp 0x24
  FAIL [08-F1-8] idx 8: got 0x32 exp 0x31
  FAIL [08-F1-9] idx 9: got 0x33 exp 0x32
  FAIL [08-F1-10] idx 10: got 0x34 exp 0x33
  FAIL [08-F1-11] idx 11: got 0x41 exp 0x34
  FAIL [08-F1-12] idx 12: got 0x42 exp 0x41
  FAIL [08-F1-13] idx 13: got 0x43 exp 0x42
  FAIL [08-F1-14] idx 14: got 0x44 exp 0x43
  FAIL [08-F1-15] idx 15: got 0x1 exp 0x44
  FAIL [08-F1-16] idx 16: got 0x2 exp 0x1
  FAIL [08-F1-17] idx 17: got 0x3 exp 0x2
  FAIL [08-F1-18] idx 18: got 0x4 exp 0x3
  FAIL [08-F1-19] idx 19: got 0x11 exp 0x4
  Frame 2: DOWN zero-fill (step=2)
  DBG_RECV[0] cycle=739 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=1 ao_row=0 rd_addr=0x2 rd_data=0x2 zero=1
  DBG_RECV[1] cycle=739 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=2 ao_row=0 rd_addr=0x3 rd_data=0x3 zero=1
  DBG_RECV[2] cycle=741 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=3 ao_row=0 rd_addr=0x4 rd_data=0x4 zero=1
  DBG_RECV[3] cycle=741 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=0 ao_row=1 rd_addr=0x5 rd_data=0x11 zero=1
  DBG_RECV[4] cycle=743 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=2 ao_col=1 ao_row=1 rd_addr=0x6 rd_data=0x12 zero=1
  PASS [08] Frame2 STATUS.done
  FAIL [08-F2-7] idx 7: got 0x1 exp 0x0
  FAIL [08-F2-8] idx 8: got 0x2 exp 0x1
  FAIL [08-F2-9] idx 9: got 0x3 exp 0x2
  FAIL [08-F2-10] idx 10: got 0x4 exp 0x3
  FAIL [08-F2-11] idx 11: got 0x11 exp 0x4
  FAIL [08-F2-12] idx 12: got 0x12 exp 0x11
  FAIL [08-F2-13] idx 13: got 0x13 exp 0x12
  FAIL [08-F2-14] idx 14: got 0x14 exp 0x13
  FAIL [08-F2-15] idx 15: got 0x21 exp 0x14
  FAIL [08-F2-16] idx 16: got 0x22 exp 0x21
  FAIL [08-F2-17] idx 17: got 0x23 exp 0x22
  FAIL [08-F2-18] idx 18: got 0x24 exp 0x23
  FAIL [08-F2-19] idx 19: got 0x0 exp 0x24
  FAIL [08] Continuous two frames -- 33 failures
--- TC09: SW_RESET during capture ---
  Triggering sw_reset while capture in progress...
  PASS [09] STATUS.idle = 1 after sw_reset
  DBG_RECV[0] cycle=836 tvalid=1 tdata=0x12 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=1 ao_row=0 rd_addr=0x6 rd_data=0x12 zero=0
  DBG_RECV[1] cycle=836 tvalid=1 tdata=0x13 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=2 ao_row=0 rd_addr=0x7 rd_data=0x13 zero=0
  DBG_RECV[2] cycle=838 tvalid=1 tdata=0x14 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=3 ao_row=0 rd_addr=0x8 rd_data=0x14 zero=0
  DBG_RECV[3] cycle=838 tvalid=1 tdata=0x21 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=0 ao_row=1 rd_addr=0x9 rd_data=0x21 zero=0
  DBG_RECV[4] cycle=840 tvalid=1 tdata=0x22 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=2 ao_col=1 ao_row=1 rd_addr=0xa rd_data=0x22 zero=0
  FAIL [09-0] idx 0: got 0x12 exp 0x11
  FAIL [09-1] idx 1: got 0x13 exp 0x12
  FAIL [09-2] idx 2: got 0x14 exp 0x13
  FAIL [09-3] idx 3: got 0x21 exp 0x14
  FAIL [09-4] idx 4: got 0x22 exp 0x21
  FAIL [09-5] idx 5: got 0x23 exp 0x22
  FAIL [09-6] idx 6: got 0x24 exp 0x23
  FAIL [09-7] idx 7: got 0x31 exp 0x24
  FAIL [09-8] idx 8: got 0x32 exp 0x31
  FAIL [09-9] idx 9: got 0x33 exp 0x32
  FAIL [09-10] idx 10: got 0x34 exp 0x33
  FAIL [09-11] idx 11: got 0x41 exp 0x34
  FAIL [09-12] idx 12: got 0x42 exp 0x41
  FAIL [09-13] idx 13: got 0x43 exp 0x42
  FAIL [09-14] idx 14: got 0x44 exp 0x43
  FAIL [09-15] idx 15: got 0x51 exp 0x44
  FAIL [09-16] idx 16: got 0x52 exp 0x51
  FAIL [09-17] idx 17: got 0x53 exp 0x52
  FAIL [09-18] idx 18: got 0x54 exp 0x53
  FAIL [09-19] idx 19: got 0x1 exp 0x54
  FAIL [09-20] idx 20: got 0x2 exp 0x1
  FAIL [09-21] idx 21: got 0x3 exp 0x2
  FAIL [09-22] idx 22: got 0x4 exp 0x3
  FAIL [09-23] idx 23: got 0x11 exp 0x4
  FAIL [09] SW_RESET during capture -- 24 failures
--- TC10: Register readback ---
  PASS [10] Initial STATUS.idle = 1
  PASS [10] CFG readback OK
  PASS [10] IMG_ROWS readback OK
  PASS [10] IMG_COLS readback OK
  PASS [10] STATUS.busy_capture = 1
  DBG_RECV[0] cycle=928 tvalid=1 tdata=0x12 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=1 ao_col=1 ao_row=0 rd_addr=0x6 rd_data=0x12 zero=0
  DBG_RECV[1] cycle=928 tvalid=1 tdata=0x13 tready=1 all_done=0 shift_en=1 sg_col=1 sg_row=1 ao_col=2 ao_row=0 rd_addr=0x7 rd_data=0x13 zero=0
  DBG_RECV[2] cycle=930 tvalid=1 tdata=0x14 tready=1 all_done=0 shift_en=1 sg_col=2 sg_row=1 ao_col=3 ao_row=0 rd_addr=0x8 rd_data=0x14 zero=0
  DBG_RECV[3] cycle=930 tvalid=1 tdata=0x21 tready=1 all_done=0 shift_en=1 sg_col=3 sg_row=1 ao_col=0 ao_row=1 rd_addr=0x9 rd_data=0x21 zero=0
  DBG_RECV[4] cycle=932 tvalid=1 tdata=0x22 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=2 ao_col=1 ao_row=1 rd_addr=0xa rd_data=0x22 zero=0
  PASS [10] STATUS.done = 1 after completion
  FAIL [10-0] at (r=0, c=0): got 0x12, expected 0x11
  FAIL [10-1] at (r=0, c=1): got 0x13, expected 0x12
  FAIL [10-2] at (r=0, c=2): got 0x14, expected 0x13
  FAIL [10-3] at (r=0, c=3): got 0x21, expected 0x14
  FAIL [10-4] at (r=1, c=0): got 0x22, expected 0x21
  FAIL [10-5] at (r=1, c=1): got 0x23, expected 0x22
  FAIL [10-6] at (r=1, c=2): got 0x24, expected 0x23
  FAIL [10-7] at (r=1, c=3): got 0x31, expected 0x24
  FAIL [10-8] at (r=2, c=0): got 0x32, expected 0x31
  FAIL [10-9] at (r=2, c=1): got 0x33, expected 0x32
  FAIL [10-10] at (r=2, c=2): got 0x34, expected 0x33
  FAIL [10-11] at (r=2, c=3): got 0x1, expected 0x34
  FAIL [10-12] at (r=3, c=0): got 0x2, expected 0x1
  FAIL [10-13] at (r=3, c=1): got 0x3, expected 0x2
  FAIL [10-14] at (r=3, c=2): got 0x4, expected 0x3
  FAIL [10-15] at (r=3, c=3): got 0x11, expected 0x4
  FAIL [10] Register readback -- 16 failures
--- TC11: Single row / single column boundary ---
  Sub-test A: 1x5 single row, LEFT wrap step=1
  DBG_RECV[0] cycle=975 tvalid=1 tdata=0x3 tready=1 all_done=0 shift_en=1 sg_col=4 sg_row=0 ao_col=1 ao_row=0 rd_addr=0x3 rd_data=0x3 zero=0
  DBG_RECV[1] cycle=975 tvalid=1 tdata=0x4 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=0 ao_col=2 ao_row=0 rd_addr=0x4 rd_data=0x4 zero=0
  DBG_RECV[2] cycle=977 tvalid=1 tdata=0x5 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=0 ao_col=3 ao_row=0 rd_addr=0x0 rd_data=0x5 zero=0
  DBG_RECV[3] cycle=977 tvalid=1 tdata=0x1 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=0 ao_col=4 ao_row=0 rd_addr=0x1 rd_data=0x1 zero=0
  DBG_RECV[4] cycle=979 tvalid=1 tdata=0x2 tready=1 all_done=1 shift_en=1 sg_col=0 sg_row=0 ao_col=0 ao_row=0 rd_addr=0x1 rd_data=0x2 zero=0
  FAIL [11-A-0] idx 0: got 0x3 exp 0x2
  FAIL [11-A-1] idx 1: got 0x4 exp 0x3
  FAIL [11-A-2] idx 2: got 0x5 exp 0x4
  FAIL [11-A-3] idx 3: got 0x1 exp 0x5
  FAIL [11-A-4] idx 4: got 0x2 exp 0x1
  FAIL [11-A] 1x5: 5 mismatches
  Sub-test B: 5x1 single column, DOWN zero-fill step=2
  DBG_RECV[0] cycle=1008 tvalid=1 tdata=0x0 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=4 ao_col=0 ao_row=1 rd_addr=0x0 rd_data=0x11 zero=0
  DBG_RECV[1] cycle=1008 tvalid=1 tdata=0x1 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=0 ao_col=0 ao_row=2 rd_addr=0x1 rd_data=0x1 zero=0
  DBG_RECV[2] cycle=1010 tvalid=1 tdata=0x11 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=0 ao_col=0 ao_row=3 rd_addr=0x2 rd_data=0x11 zero=0
  DBG_RECV[3] cycle=1010 tvalid=1 tdata=0x21 tready=1 all_done=0 shift_en=1 sg_col=0 sg_row=0 ao_col=0 ao_row=4 rd_addr=0x0 rd_data=0x21 zero=1
  DBG_RECV[4] cycle=1012 tvalid=1 tdata=0x0 tready=1 all_done=1 shift_en=1 sg_col=0 sg_row=0 ao_col=0 ao_row=0 rd_addr=0x0 rd_data=0x1 zero=1
  FAIL [11-B-1] idx 1: got 0x1 exp 0x0
  FAIL [11-B-2] idx 2: got 0x11 exp 0x1
  FAIL [11-B-3] idx 3: got 0x21 exp 0x11
  FAIL [11-B-4] idx 4: got 0x0 exp 0x21
  FAIL [11-B] 5x1: 4 mismatches
  Sub-test C: 1x1 single pixel NONE
  DBG_RECV[0] cycle=1037 tvalid=1 tdata=0x1 tready=1 all_done=1 shift_en=1 sg_col=0 sg_row=0 ao_col=0 ao_row=0 rd_addr=0x0 rd_data=0x1 zero=0
  PASS [11-C] 1x1 OK
  FAIL [11] Single row/column boundary -- 9 failures

================================================================
  Simulation Summary
================================================================
  Total assertions  : 247
  Passed           : 28
  Failed           : 219

  SOME TESTS FAILED
================================================================

```

## Waveform

VCD file saved to: `sim/tb_axil_2d_shift.vcd`

Open with: `gtkwave sim/tb_axil_2d_shift.vcd`

## Checksum

- Report generated: 2026-06-06
