# RUN-E001-SIM-001: AXI-Lite Register Simulation

## Metadata

- **Task**: TASK-E001-002
- **Verification Level**: L1 (Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: 2026/06/04 周四
- **Testbench**: tb/tb_axil_regs.sv
- **DUT**: rtl/axil_slave_if.sv + rtl/regs_top.sv

## Result

| Item | Value |
|------|-------|
| Status | **PASS** |
| Test cases | 48 |
| Passed | 48 |
| Failed | 0 |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
| TC01 | Write IMG_ROWS=0x40, read back | PASS |
| TC02 | Write IMG_COLS=0x80, read back | PASS |
| TC03 | Sequential writes (multiple regs), read back each | PASS |
| TC04 | CFG bit-field test (dir/step/wrap_en) | PASS |
| TC05 | CTRL.start self-clearing | PASS |
| TC06 | CTRL.sw_reset self-clearing | PASS |
| TC07 | Read reserved addresses (0x14, 0x18) | PASS |
| TC08 | Write reserved, no side effect | PASS |
| TC09 | Invalid address SLVERR | PASS |
| TC10 | STATUS simulation (idle/busy/done/mutex) | PASS |
| TC11 | WSTRB partial write | PASS |

## Simulation Log (last 100 lines)

```

=== Running all test cases ===

TC01: Write IMG_ROWS=0x40, read back
  PASS [1]: TC01: IMG_ROWS read response (response 00)
  PASS [1]: TC01: IMG_ROWS read data (0x00000040)
TC02: Write IMG_COLS=0x80, read back
  PASS [2]: TC02: IMG_COLS read response (response 00)
  PASS [2]: TC02: IMG_COLS read data (0x00000080)
TC03: Write CTRL, CFG, IMG_ROWS, IMG_COLS, read back each
  PASS [3]: TC03: CTRL read response (response 00)
  PASS [3]: TC03: CTRL read data (self-cleared) (0x00000000)
  PASS [3]: TC03: CFG read response (response 00)
  PASS [3]: TC03: CFG read data (0x00000105)
  PASS [3]: TC03: IMG_ROWS read response (response 00)
  PASS [3]: TC03: IMG_ROWS read data (0x00000040)
  PASS [3]: TC03: IMG_COLS read response (response 00)
  PASS [3]: TC03: IMG_COLS read data (0x00000080)
TC04: Write CFG with dir/step/wrap_en, verify bit fields
  PASS [4]: TC04: CFG read response (response 00)
  PASS [4]: TC04: CFG read data (0x00000129)
  PASS [4]: TC04 CFG.dir = 001
  PASS [4]: TC04 CFG.step = 00101
  PASS [4]: TC04 CFG.wrap_en = 1
TC05: Write CTRL.start=1, verify self-clearing on read
  PASS [5]: TC05: CTRL read response (response 00)
  PASS [5]: TC05: CTRL read (should be 0, self-cleared) (0x00000000)
TC06: Write CTRL.sw_reset=1, verify self-clearing on read
  PASS [6]: TC06: CTRL read response (response 00)
  PASS [6]: TC06: CTRL read (should be 0, self-cleared) (0x00000000)
TC07: Read reserved addresses 0x14, 0x18
  PASS [7]: TC07: Reserved 0x14 read response (response 00)
  PASS [7]: TC07: Reserved 0x14 read data (0x00000000)
  PASS [7]: TC07: Reserved 0x18 read response (response 00)
  PASS [7]: TC07: Reserved 0x18 read data (0x00000000)
TC08: Write reserved 0x14, verify CFG/IMG_ROWS unchanged
  PASS [8]: TC08: CFG read response after reserved write (response 00)
  PASS [8]: TC08: CFG unchanged after 0x14 write (0x00000123)
  PASS [8]: TC08: IMG_ROWS read response after reserved write (response 00)
  PASS [8]: TC08: IMG_ROWS unchanged after 0x14 write (0x000000aa)
TC09: Read/Write invalid address 0x40, verify SLVERR
  PASS [9]: TC09: Write 0x40 BRESP (SLVERR) (response 10)
  PASS [9]: TC09: Read 0x40 RRESP (SLVERR) (response 10)
TC10-A: STATUS idle=1
  PASS [10]: TC10-A: STATUS read response (response 00)
  PASS [10]: TC10-A: STATUS idle active (bit 0) (0x00000001)
TC10-B: STATUS busy_capture=1
  PASS [11]: TC10-B: STATUS read response (response 00)
  PASS [11]: TC10-B: STATUS busy_capture (bit 1) (0x00000002)
TC10-C: STATUS busy_shift=1
  PASS [12]: TC10-C: STATUS read response (response 00)
  PASS [12]: TC10-C: STATUS busy_shift (bit 2) (0x00000004)
TC10-D: STATUS done=1 (pulse), check done latched + idle cleared
  PASS [13]: TC10-D: STATUS read response (response 00)
  PASS [13]: TC10-D: STATUS done latched (bit 3), idle=0 (0x00000008)
TC10-E: Write CTRL.start=1 to clear done, check idle restored
  PASS [14]: TC10-E: STATUS read response (response 00)
  PASS [14]: TC10-E: STATUS idle restored (bit 0), done cleared (0x00000001)
TC10-F: Verify mutual exclusivity: busy_capture+idle -> busy takes priority
  PASS [15]: TC10-F: STATUS read response (response 00)
  PASS [15]: TC10-F: STATUS busy_capture (idle suppressed by mutex) (0x00000002)
TC11: WSTRB partial write to IMG_ROWS high byte
  PASS [16]: TC11: Initial IMG_ROWS read response (response 00)
  PASS [16]: TC11: Initial IMG_ROWS value (0x000000ff)
  PASS [16]: TC11: Partial write BRESP (OKAY) (response 00)
  PASS [16]: TC11: IMG_ROWS read response after partial write (response 00)
  PASS [16]: TC11: IMG_ROWS after WSTRB partial write (low=FF, high=10) (0x000010ff)

=== All test cases completed ===

============================================================
  AXI-Lite Register Simulation Summary
  Date:                 1270000
  Tests:   16
  Passed:  16
  Failed:  0
============================================================
  >>> ALL TESTS PASSED <<<
============================================================
```

## Waveform

VCD file saved to: `sim/tb_axil_regs.vcd`

Open with: `gtkwave sim/tb_axil_regs.vcd`

## Checksum

- Report generated: 2026/06/04 周四
