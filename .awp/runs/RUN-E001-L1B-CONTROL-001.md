# RUN-E001-L1B-CONTROL-001: L1b 控制通路集成仿真

## Metadata

- **Task**: TASK-E001-011
- **Verification Level**: L1b (Datapath Integration Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: 2026/06/05
- **Testbench**: tb/tb_l1b_control_path.sv
- **DUT**: rtl/axil_slave_if.sv + rtl/regs_top.sv + rtl/ctrl_fsm.sv
- **Integration Scope**: datapath (control: axil_slave_if -> regs_top -> ctrl_fsm)

## Result

| Item | Value |
|------|-------|
| Status | **PASS** |
| Assertions | 100 |
| Passed | 100 |
| Failed | 0 |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
| TC01 | Register config write/read-back — CFG/IMG_ROWS/IMG_COLS correct lock and read-back | PASS |
| TC02 | CTRL.start self-clear and ctrl_start pulse — verify 1-cycle pulse, STATUS.busy_capture | PASS |
| TC03 | capture_done -> SHIFT transition — shift_en=1, capture_en=0, STATUS.busy_shift | PASS |
| TC04 | shift_done -> DONE -> IDLE auto-return — status_done latched, auto IDLE | PASS |
| TC05 | Full flow IDLE->CAPTURE->SHIFT->DONE->IDLE with STATUS mutual exclusivity check | PASS |
| TC06 | Consecutive 2-start (back-to-back frames) — done clear, re-enter flow | PASS |
| TC07 | SW_RESET from CAPTURE — return to IDLE, capture_en=0 | PASS |
| TC08 | SW_RESET from SHIFT — return to IDLE, shift_en=0 | PASS |
| TC09 | SW_RESET from DONE — return to IDLE, done_latched preserved | PASS |
| TC10 | SW_RESET priority over ctrl_start — reset wins when both asserted | PASS |
| TC11 | Register stability during operation — config writes during CAPTURE/SHIFT | PASS |
| TC12 | Reserved and invalid address access — 0x14 returns 0, 0x40 returns SLVERR | PASS |
| TC13 | Three consecutive full flows — verify no state leakage across multiple starts | PASS |

## Pipeline Timing Analysis

### Control Path Timing (AXI-Lite Write -> regs_top -> ctrl_fsm)

```
Clock:                    T0              T1              T2              T3

AXI-Lite AW/W
  s_axil_awvalid          _____|~~~~~~~~~~~|
  s_axil_wvalid           _____|~~~~~~~~~~~|
  s_axil_awready          '''''''''''''''''|
  s_axil_wready           '''''''''''''''''|
  (both sampled at T0 posedge)

axil_slave_if
  wstate                  W_IDLE          W_RESP          W_IDLE
  wr_strobe[0]            0               1               0
  w_exec                  0               1               0

regs_top
  ctrl_r[0] (start)       0               1               0               0
  ctrl_start (combo)      0               1               0               0

ctrl_fsm
  state (registered)      IDLE            IDLE            CAPTURE         CAPTURE
  capture_en              0               0               1               1
```

Key observations:
1. AXI-Lite write takes 1 cycle from AW/W handshake to wr_strobe assertion.
2. regs_top locks ctrl_start at the same posedge as wr_strobe (T1).
3. ctrl_start is a 1-cycle pulse (self-clearing in regs_top).
4. ctrl_fsm transitions from IDLE to CAPTURE at the NEXT posedge (T2), 2 cycles after the AXI-Lite write.
5. capture_en goes high at T2 and stays high until capture_done is received.

### Capture -> Shift Transition

```
Clock:                    T0              T1              T2
state                     CAPTURE         CAPTURE         SHIFT
capture_en                1               1               0
shift_en                  0               0               1
mock_capture_done         0               1 (pulse)      0
```

### Shift -> Done -> IDLE Auto-Return

```
Clock:                    T0              T1              T2              T3
state                     SHIFT           SHIFT           DONE            IDLE
shift_en                  1               1               0               0
mock_shift_done           0               1 (pulse)      0               0
status_done (FSM)         0 (combo)       0               1               0
status_done (latched)     0               0               1               1
```

### STATUS Mutual Exclusivity

regs_top enforces: `status_idle_eff = status_idle && !status_busy_capture && !status_busy_shift && !done_latched`
- idle is only visible when NO other state is active
- When done_latched=1, idle reads as 0 (not both 1)
- When busy_capture=1, idle reads as 0


## Simulation Log (last 133 lines)

```
============================================================
  tb_l1b_control_path - Control Path Integration Simulation
  axil_slave_if -> regs_top -> ctrl_fsm
============================================================

VCD info: dumpfile tb_l1b_control_path.vcd opened for output.
--- TC1: Register config write/read-back ---
  PASS [1] IMG_ROWS == 6
  PASS [1] IMG_COLS == 4
  PASS [1] CFG.dir == UP(1)
  PASS [1] CFG.step == 2
  PASS [1] CFG.wrap_en == 1
  PASS [1] cfg_dir == 1 (UP)
  PASS [1] cfg_step == 2
  PASS [1] cfg_wrap_en == 1
  PASS [1] img_rows == 6
  PASS [1] img_cols == 4
--- TC2: CTRL.start self-clear and ctrl_start pulse ---
  PASS [2] CTRL read-back == 0 (self-cleared)
  PASS [2] STATUS.busy_capture == 1 after start
  PASS [2] STATUS.idle == 0 (mutex)
  PASS [2] capture_en == 1 in CAPTURE state
  PASS [2] shift_en == 0 in CAPTURE state
  PASS [2] ctrl_start (combo from regs_top) is now 0 (self-cleared)
  PASS [2] Back to IDLE after sw_reset
--- TC3: capture_done -> SHIFT transition ---
  PASS [3] In CAPTURE before capture_done
  PASS [3] shift_en == 1 after capture_done
  PASS [3] capture_en == 0 after capture_done
  PASS [3] STATUS.busy_shift == 1 after capture_done
  PASS [3] STATUS.busy_capture == 0
--- TC4: shift_done -> DONE -> IDLE auto-return ---
  PASS [4] In SHIFT before shift_done
  PASS [4] STATUS.done latched == 1 after auto-return
  PASS [4] STATUS.idle == 0 (done latched)
  PASS [4] idle and done not both 1 (mutex)
  PASS [4] capture_en == 0 (FSM in IDLE)
  PASS [4] shift_en == 0 (FSM in IDLE)
--- TC5: Full flow with STATUS mutual exclusivity ---
  [DBG] Pre-clear STATUS = 0x00000008
  PASS [5] STATUS.idle == 1 after done clear
  PASS [5] capture_en == 0 in IDLE
  PASS [5] shift_en == 0 in IDLE
  PASS [5] STATUS.busy_capture == 1
  PASS [5] STATUS.idle == 0 (mutex)
  PASS [5] STATUS.busy_shift == 0 (not SHIFT)
  PASS [5] STATUS.done == 0 (not done)
  PASS [5] capture_en == 1 in CAPTURE
  PASS [5] shift_en == 0 in CAPTURE
  PASS [5] STATUS.busy_shift == 1
  PASS [5] STATUS.busy_capture == 0 (mutex)
  PASS [5] STATUS.idle == 0 (mutex)
  PASS [5] STATUS.done == 0 (not done yet)
  PASS [5] shift_en == 1 in SHIFT
  PASS [5] capture_en == 0 in SHIFT
  PASS [5] STATUS.done == 1 in DONE
  PASS [5] STATUS.done latched == 1
  PASS [5] STATUS.idle == 0 (done latched)
  PASS [5] done and idle mutually exclusive in STATUS read
  PASS [5] capture_en == 0 final
  PASS [5] shift_en == 0 final
--- TC6: Consecutive 2-start (back-to-back frames) ---
  PASS [6] Clean IDLE before 2-start test
  PASS [6] FRAME1: In CAPTURE
  PASS [6] FRAME1: In SHIFT
  PASS [6] FRAME1: done latched == 1
  PASS [6] FRAME2: done cleared after start
  PASS [6] FRAME2: busy_capture == 1
  PASS [6] FRAME2: capture_en == 1
  PASS [6] FRAME2: shift_en == 0
  PASS [6] FRAME2: cfg_dir unchanged
  PASS [6] FRAME2: In SHIFT
  PASS [6] FRAME2: done latched == 1
  [INFO] Both frames completed successfully
--- TC7: SW_RESET from CAPTURE ---
  PASS [7] TC07: In CAPTURE before sw_reset
  PASS [7] TC07: STATUS.busy_capture == 1
  PASS [7] TC07: capture_en == 0 after sw_reset
  PASS [7] TC07: shift_en == 0 after sw_reset
  PASS [7] TC07: STATUS.idle == 1 after sw_reset
  PASS [7] TC07: STATUS.busy_capture == 0
--- TC8: SW_RESET from SHIFT ---
  PASS [8] TC08: In SHIFT before sw_reset
  PASS [8] TC08: STATUS.busy_shift == 1
  PASS [8] TC08: shift_en == 0 after sw_reset
  PASS [8] TC08: capture_en == 0 after sw_reset
  PASS [8] TC08: STATUS.idle == 1 after sw_reset
  PASS [8] TC08: STATUS.busy_shift == 0
--- TC9: SW_RESET from DONE ---
  PASS [9] TC09: capture_en == 0
  PASS [9] TC09: shift_en == 0
  PASS [9] TC09: STATUS.done still latched after sw_reset
--- TC10: SW_RESET priority over ctrl_start ---
  PASS [10] TC10: IDLE before test
  PASS [10] TC10: IDLE after sw_reset+start (sw_reset wins)
  PASS [10] TC10: capture_en == 0
  PASS [10] TC10: capture_en == 1 after subsequent start
--- TC11: Register stability during operation ---
  PASS [11] TC11: capture_en == 1 in CAPTURE
  PASS [11] TC11: capture_en still 1 after CFG write
  PASS [11] TC11: shift_en == 1 in SHIFT
  PASS [11] TC11: shift_en still 1 after IMG write
  PASS [11] TC11: done latched after operation
  [INFO] Register stability verified: no crash during operation
--- TC12: Reserved and invalid address access ---
  PASS [12] TC12: Reserved 0x14 read == 0
  PASS [12] TC12: Reserved 0x14 BRESP OKAY
  PASS [12] TC12: CFG unchanged after reserved write
  PASS [12] TC12: Invalid write BRESP == SLVERR
  PASS [12] TC12: Invalid read RRESP == SLVERR
  PASS [12] TC12: Invalid read data == 0
--- TC13: Three consecutive full flows ---
  PASS [13] TC13: IDLE before 3x flow
  PASS [13] F1: CAPTURE
  PASS [13] F1: SHIFT
  PASS [13] F1: done latched
  PASS [13] F2: CAPTURE
  PASS [13] F2: SHIFT
  PASS [13] F2: done latched
  PASS [13] F3: CAPTURE
  PASS [13] F3: SHIFT
  PASS [13] F3: done latched
  [INFO] 3 consecutive flows completed successfully

============================================================
  Simulation Summary
============================================================
  Passed: 100
  Failed: 0
  Total : 100
------------------------------------------------------------
  ALL TESTS PASSED
============================================================
```

## Waveform

VCD file saved to: `sim/tb_l1b_control_path.vcd`

Open with: `gtkwave sim/tb_l1b_control_path.vcd`

## Checksum

- Report generated: 2026/06/05
