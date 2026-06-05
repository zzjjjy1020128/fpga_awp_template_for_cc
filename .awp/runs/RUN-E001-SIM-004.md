# RUN-E001-SIM-004: shift_addr_gen 2D Shift Address Generator Simulation

## Metadata

- **Task**: TASK-E001-005
- **Verification Level**: L1 (Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: 2026/06/05 巓励
- **Testbench**: tb/tb_shift_addr_gen.sv
- **DUT**: rtl/shift_addr_gen.sv

## Result

| Item | Value |
|------|-------|
| Status | **FAIL** |
| Assertions | 1233 |
| Passed | 1227 |
| Failed | 6 |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
| TC01 | NONE mode ！ raster scan address (row*cols+col) | FAIL |
| TC02 | UP wrap ！ shifted row address with modulo | PASS |
| TC03 | DOWN wrap ！ shifted row address with modulo | PASS |
| TC04 | LEFT wrap ！ shifted col address with modulo | PASS |
| TC05 | RIGHT wrap ！ shifted col address with modulo | PASS |
| TC06 | UP zero-fill ！ overflow rows produce zero_fill=1 | PASS |
| TC07 | DOWN zero-fill ！ underflow rows produce zero_fill=1 | PASS |
| TC08 | LEFT zero-fill ！ end-of-row columns produce zero_fill=1 | PASS |
| TC09 | RIGHT zero-fill ！ start-of-row columns produce zero_fill=1 | PASS |
| TC10 | step=0 ！ all modes equivalent to NONE | PASS |
| TC11 | step >= img_rows (wrap) ！ modulo operator correct | PASS |
| TC12 | illegal dir (101-111) ！ treated as NONE | PASS |
| TC13 | shift_en=0 pause ！ counter unchanged, address frozen | FAIL |
| TC14 | step dynamic switch ！ new step takes effect next cycle | PASS |
| TC15 | Random mode+size+step, golden model comparison (1000 frames) | PASS |

## Simulation Log (last 150 lines)

```
  PASS [11] TC11_RIGHT pix5 addr
  PASS [11] TC11_RIGHT pix5 zero
  PASS [11] TC11_RIGHT pix6 addr
  PASS [11] TC11_RIGHT pix6 zero
  PASS [11] TC11_RIGHT pix7 addr
  PASS [11] TC11_RIGHT pix7 zero
  PASS [11] TC11_RIGHT pix8 addr
  PASS [11] TC11_RIGHT pix8 zero
  PASS [11] TC11_RIGHT pix9 addr
  PASS [11] TC11_RIGHT pix9 zero
  PASS [11] TC11_RIGHT pix10 addr
  PASS [11] TC11_RIGHT pix10 zero
  PASS [11] TC11_RIGHT pix11 addr
  PASS [11] TC11_RIGHT pix11 zero
  PASS [11] TC11_RIGHT pix12 addr
  PASS [11] TC11_RIGHT pix12 zero
  PASS [11] TC11_RIGHT pix13 addr
  PASS [11] TC11_RIGHT pix13 zero
  PASS [11] TC11_RIGHT pix14 addr
  PASS [11] TC11_RIGHT pix14 zero
  PASS [11] TC11_RIGHT pix15 addr
  PASS [11] TC11_RIGHT pix15 zero
  PASS [11] TC11_RIGHT pix16 addr
  PASS [11] TC11_RIGHT pix16 zero
  PASS [11] TC11_RIGHT pix17 addr
  PASS [11] TC11_RIGHT pix17 zero
  PASS [11] TC11_RIGHT pix18 addr
  PASS [11] TC11_RIGHT pix18 zero
  PASS [11] TC11_RIGHT pix19 addr
  PASS [11] TC11_RIGHT pix19 zero
  PASS [11] TC11_RIGHT pix20 addr
  PASS [11] TC11_RIGHT pix20 zero
  PASS [11] TC11_RIGHT pix21 addr
  PASS [11] TC11_RIGHT pix21 zero
  PASS [11] TC11_RIGHT pix22 addr
  PASS [11] TC11_RIGHT pix22 zero
  PASS [11] TC11_RIGHT pix23 addr
  PASS [11] TC11_RIGHT pix23 zero
  PASS [11] TC11_RIGHT pix24 addr
  PASS [11] TC11_RIGHT pix24 zero
  PASS [11] TC11_RIGHT pix25 addr
  PASS [11] TC11_RIGHT pix25 zero
  PASS [11] TC11_RIGHT pix26 addr
  PASS [11] TC11_RIGHT pix26 zero
  PASS [11] TC11_RIGHT pix27 addr
  PASS [11] TC11_RIGHT pix27 zero
  PASS [11] TC11_RIGHT pix28 addr
  PASS [11] TC11_RIGHT pix28 zero
  PASS [11] TC11_RIGHT pix29 addr
  PASS [11] TC11_RIGHT pix29 zero
--- TC12: illegal dir (101,110,111 -> NONE) ---
  PASS [12] TC12 dir=101 pix0 addr
  PASS [12] TC12 dir=101 pix0 zero
  PASS [12] TC12 dir=101 pix1 addr
  PASS [12] TC12 dir=101 pix1 zero
  PASS [12] TC12 dir=101 pix2 addr
  PASS [12] TC12 dir=101 pix2 zero
  PASS [12] TC12 dir=101 pix3 addr
  PASS [12] TC12 dir=101 pix3 zero
  PASS [12] TC12 dir=101 pix4 addr
  PASS [12] TC12 dir=101 pix4 zero
  PASS [12] TC12 dir=110 pix0 addr
  PASS [12] TC12 dir=110 pix0 zero
  PASS [12] TC12 dir=110 pix1 addr
  PASS [12] TC12 dir=110 pix1 zero
  PASS [12] TC12 dir=110 pix2 addr
  PASS [12] TC12 dir=110 pix2 zero
  PASS [12] TC12 dir=110 pix3 addr
  PASS [12] TC12 dir=110 pix3 zero
  PASS [12] TC12 dir=110 pix4 addr
  PASS [12] TC12 dir=110 pix4 zero
  PASS [12] TC12 dir=111 pix0 addr
  PASS [12] TC12 dir=111 pix0 zero
  PASS [12] TC12 dir=111 pix1 addr
  PASS [12] TC12 dir=111 pix1 zero
  PASS [12] TC12 dir=111 pix2 addr
  PASS [12] TC12 dir=111 pix2 zero
  PASS [12] TC12 dir=111 pix3 addr
  PASS [12] TC12 dir=111 pix3 zero
  PASS [12] TC12 dir=111 pix4 addr
  PASS [12] TC12 dir=111 pix4 zero
--- TC13: shift_en=0 pause ---
  PASS [13] TC13 running pix0 addr
  PASS [13] TC13 running pix0 zero
  PASS [13] TC13 running pix1 addr
  PASS [13] TC13 running pix1 zero
  PASS [13] TC13 running pix2 addr
  PASS [13] TC13 running pix2 zero
  PASS [13] TC13 running pix3 addr
  PASS [13] TC13 running pix3 zero
  PASS [13] TC13 running pix4 addr
  PASS [13] TC13 running pix4 zero
  FAIL [13] TC13 pause cycle0 addr frozen
  PASS [13] TC13 pause cycle0 zero frozen
  FAIL [13] TC13 pause cycle1 addr frozen
  PASS [13] TC13 pause cycle1 zero frozen
  FAIL [13] TC13 pause cycle2 addr frozen
  PASS [13] TC13 pause cycle2 zero frozen
  FAIL [13] TC13 pause cycle3 addr frozen
  PASS [13] TC13 pause cycle3 zero frozen
  FAIL [13] TC13 pause cycle4 addr frozen
  PASS [13] TC13 pause cycle4 zero frozen
  FAIL [13] TC13 resume addr=5
  PASS [13] TC13 resume zero=0
--- TC14: step dynamic switch (1->3 mid-frame) ---
  PASS [14] TC14 step1 pix0 addr
  PASS [14] TC14 step1 pix0 zero
  PASS [14] TC14 step1 pix1 addr
  PASS [14] TC14 step1 pix1 zero
  PASS [14] TC14 step1 pix2 addr
  PASS [14] TC14 step1 pix2 zero
  PASS [14] TC14 step1 pix3 addr
  PASS [14] TC14 step1 pix3 zero
  PASS [14] TC14 step1 pix4 addr
  PASS [14] TC14 step1 pix4 zero
  PASS [14] TC14 step1 pix5 addr
  PASS [14] TC14 step1 pix5 zero
  PASS [14] TC14 step1 pix6 addr
  PASS [14] TC14 step1 pix6 zero
  PASS [14] TC14 step1 pix7 addr
  PASS [14] TC14 step1 pix7 zero
  PASS [14] TC14 step3 pix8 addr
  PASS [14] TC14 step3 pix8 zero
  PASS [14] TC14 step3 pix9 addr
  PASS [14] TC14 step3 pix9 zero
  PASS [14] TC14 step3 pix10 addr
  PASS [14] TC14 step3 pix10 zero
  PASS [14] TC14 step3 pix11 addr
  PASS [14] TC14 step3 pix11 zero
  PASS [14] TC14 step3 pix12 addr
  PASS [14] TC14 step3 pix12 zero
  PASS [14] TC14 step3 pix13 addr
  PASS [14] TC14 step3 pix13 zero
  PASS [14] TC14 step3 pix14 addr
  PASS [14] TC14 step3 pix14 zero
  PASS [14] TC14 step3 pix15 addr
  PASS [14] TC14 step3 pix15 zero
--- TC15: Random 1000 frames with golden model ---
  TC15: 49036 checks, 0 errors
  PASS [15] TC15 random 1000 frames no errors

============================================================
  Simulation Summary
============================================================
  Passed: 1227
  Failed: 6
  Total : 1233
------------------------------------------------------------
  SOME TESTS FAILED  <<<
============================================================
```

## Waveform

VCD file saved to: `sim/tb_shift_addr_gen.vcd`

Open with: `gtkwave sim/tb_shift_addr_gen.vcd`

## Checksum

- Report generated: 2026/06/05 巓励
