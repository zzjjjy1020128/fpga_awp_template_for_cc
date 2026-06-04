# RUN-E001-SIM-002: Ctrl FSM Simulation

## Metadata

- **Task**: TASK-E001-003
- **Verification Level**: L1 (Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: 2026/06/04 周四
- **Testbench**: tb/tb_ctrl_fsm.sv
- **DUT**: rtl/ctrl_fsm.sv

## Result

| Item | Value |
|------|-------|
| Status | **PASS** |
| Assertions | 52 |
| Passed | 52 |
| Failed | 0 |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
| TC01 | Reset -> IDLE, status_idle=1 | PASS |
| TC02 | start -> CAPTURE, capture_en=1 | PASS |
| TC03 | capture_done -> SHIFT, shift_en=1 | PASS |
| TC04 | shift_done -> DONE, status_done=1 | PASS |
| TC05 | DONE auto -> IDLE after 1 cycle | PASS |
| TC06 | sw_reset from CAPTURE -> IDLE | PASS |
| TC07 | sw_reset from SHIFT -> IDLE | PASS |
| TC08 | sw_reset from DONE -> IDLE | PASS |
| TC09 | Full normal flow (start->CAPTURE->SHIFT->DONE->IDLE) | PASS |
| TC10 | Stay in IDLE when start=0 (no false trigger) | PASS |
| TC11 | sw_reset priority over ctrl_start | PASS |

## Simulation Log (last 100 lines)

```
============================================================
  tb_ctrl_fsm - Starting Simulation
============================================================
VCD info: dumpfile tb_ctrl_fsm.vcd opened for output.
--- TC1: Reset -> IDLE ---
  PASS [1] status_idle=1 after reset
  PASS [1] status_busy_capture=0
  PASS [1] status_busy_shift=0
  PASS [1] status_done=0
  PASS [1] capture_en=0
  PASS [1] shift_en=0
--- TC10: Stay in IDLE (start=0) ---
  PASS [10] status_idle remains 1 (no false trigger)
  PASS [10] capture_en remains 0
  PASS [10] shift_en remains 0
--- TC2: start -> CAPTURE ---
  PASS [2] capture_en=1 after start
  PASS [2] status_busy_capture=1
  PASS [2] status_idle=0 (not IDLE)
  PASS [2] shift_en=0 (not SHIFT)
  PASS [2] status_done=0 (not DONE)
--- TC6: sw_reset from CAPTURE -> IDLE ---
  PASS [6] still in CAPTURE before sw_reset
  PASS [6] back to IDLE after sw_reset
  PASS [6] capture_en=0 after sw_reset
  PASS [6] status_busy_capture=0
--- TC3: capture_done -> SHIFT ---
  PASS [3] entered CAPTURE for TC03
  PASS [3] shift_en=1 after capture_done
  PASS [3] status_busy_shift=1
  PASS [3] capture_en=0 (left CAPTURE)
  PASS [3] status_idle=0
--- TC7: sw_reset from SHIFT -> IDLE ---
  PASS [7] still in SHIFT before sw_reset
  PASS [7] back to IDLE from SHIFT
  PASS [7] shift_en=0 after sw_reset
  PASS [7] status_busy_shift=0
--- TC4: shift_done -> DONE ---
  PASS [4] entered SHIFT for TC04
  PASS [4] status_done=1 after shift_done
  PASS [4] shift_en=0 (left SHIFT)
  PASS [4] capture_en=0
  PASS [4] status_idle=0 (not yet IDLE)
--- TC5: DONE -> auto IDLE ---
  PASS [5] auto returned to IDLE from DONE
  PASS [5] status_done=0 (left DONE)
  PASS [5] shift_en=0
  PASS [5] capture_en=0
--- TC8: sw_reset from DONE -> IDLE ---
  PASS [8] reached DONE for TC08
  PASS [8] IDLE after sw_reset from DONE
  PASS [8] status_done=0
--- TC9: Full normal flow ---
  PASS [9] F09: capture_en=1
  PASS [9] F09: status_busy_capture=1
  PASS [9] F09: status_idle=0
  PASS [9] F09: shift_en=1
  PASS [9] F09: status_busy_shift=1
  PASS [9] F09: capture_en=0
  PASS [9] F09: status_done=1
  PASS [9] F09: shift_en=0
  PASS [9] F09: status_idle=1 (auto return)
  PASS [9] F09: status_done=0
--- TC11: sw_reset priority over start ---
  PASS [11] TC11: still IDLE (sw_reset takes priority)
  PASS [11] TC11: capture_en=0 (start blocked by reset)
  PASS [11] TC11: start still works normally after priority test

============================================================
  Simulation Summary
============================================================
  Passed: 52
  Failed: 0
  Total : 52
------------------------------------------------------------
  ALL TESTS PASSED
============================================================
```

## Waveform

VCD file saved to: `sim/tb_ctrl_fsm.vcd`

Open with: `gtkwave sim/tb_ctrl_fsm.vcd`

## Checksum

- Report generated: 2026/06/04 周四
