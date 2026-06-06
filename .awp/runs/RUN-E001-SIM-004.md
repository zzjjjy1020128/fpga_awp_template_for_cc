# RUN-E001-SIM-004: shift_addr_gen 2D Shift Address Generator Simulation

## Metadata

- **Task**: TASK-E001-005
- **Verification Level**: L1 (Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: 2026/06/06 巓鎗
- **Testbench**: tb/tb_shift_addr_gen.sv
- **DUT**: rtl/shift_addr_gen.sv

## Result

| Item | Value |
|------|-------|
| Status | **FAIL** |
| Assertions | 1233 |
| Passed | 1222 |
| Failed | 11 |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
| TC01 | NONE mode ！ raster scan address (row*cols+col) | FAIL |
| TC02 | UP wrap ！ shifted row address with modulo | FAIL |
| TC03 | DOWN wrap ！ shifted row address with modulo | FAIL |
| TC04 | LEFT wrap ！ shifted col address with modulo | FAIL |
| TC05 | RIGHT wrap ！ shifted col address with modulo | FAIL |
| TC06 | UP zero-fill ！ overflow rows produce zero_fill=1 | PASS |
| TC07 | DOWN zero-fill ！ underflow rows produce zero_fill=1 | PASS |
| TC08 | LEFT zero-fill ！ end-of-row columns produce zero_fill=1 | PASS |
| TC09 | RIGHT zero-fill ！ start-of-row columns produce zero_fill=1 | PASS |
| TC10 | step=0 ！ all modes equivalent to NONE | PASS |
| TC11 | step >= img_rows (wrap) ！ modulo operator correct | FAIL |
| TC12 | illegal dir (101-111) ！ treated as NONE | PASS |
| TC13 | shift_en=0 pause ！ counter unchanged, address frozen | PASS |
| TC14 | step dynamic switch ！ new step takes effect next cycle | FAIL |
| TC15 | Random mode+size+step, golden model comparison (1000 frames) | FAIL |

## Simulation Log (last 150 lines)

```
TC15 FAIL frame487 pix0: got=0 exp=12
TC15 FAIL frame488 pix0: got=0 exp=3
TC15 FAIL frame489 pix0: got=0 exp=3
TC15 FAIL frame490 pix0: got=0 exp=24
TC15 FAIL frame493 pix0: got=0 exp=6
TC15 FAIL frame497 pix0: got=0 exp=12
TC15 FAIL frame499 pix0: got=0 exp=16
TC15 FAIL frame500 pix0: got=0 exp=3
TC15 FAIL frame504 pix0: got=0 exp=7
TC15 FAIL frame506 pix0: got=0 exp=5
TC15 FAIL frame507 pix0: got=0 exp=30
TC15 FAIL frame514 pix0: got=0 exp=8
TC15 FAIL frame516 pix0: got=0 exp=3
TC15 FAIL frame522 pix0: got=0 exp=12
TC15 FAIL frame529 pix0: got=0 exp=8
TC15 FAIL frame530 pix0: got=0 exp=8
TC15 FAIL frame534 pix0: got=0 exp=18
TC15 FAIL frame536 pix0: got=0 exp=3
TC15 FAIL frame541 pix0: got=0 exp=6
TC15 FAIL frame546 pix0: got=0 exp=6
TC15 FAIL frame553 pix0: got=0 exp=4
TC15 FAIL frame555 pix0: got=0 exp=1
TC15 FAIL frame558 pix0: got=0 exp=20
TC15 FAIL frame563 pix0: got=0 exp=3
TC15 FAIL frame566 pix0: got=0 exp=18
TC15 FAIL frame571 pix0: got=0 exp=1
TC15 FAIL frame577 pix0: got=0 exp=4
TC15 FAIL frame582 pix0: got=0 exp=2
TC15 FAIL frame583 pix0: got=0 exp=18
TC15 FAIL frame585 pix0: got=0 exp=2
TC15 FAIL frame586 pix0: got=0 exp=1
TC15 FAIL frame587 pix0: got=0 exp=8
TC15 FAIL frame590 pix0: got=0 exp=1
TC15 FAIL frame591 pix0: got=0 exp=2
TC15 FAIL frame592 pix0: got=0 exp=20
TC15 FAIL frame595 pix0: got=0 exp=4
TC15 FAIL frame596 pix0: got=0 exp=15
TC15 FAIL frame598 pix0: got=0 exp=12
TC15 FAIL frame602 pix0: got=0 exp=3
TC15 FAIL frame609 pix0: got=0 exp=2
TC15 FAIL frame611 pix0: got=0 exp=15
TC15 FAIL frame615 pix0: got=0 exp=16
TC15 FAIL frame616 pix0: got=0 exp=48
TC15 FAIL frame617 pix0: got=0 exp=4
TC15 FAIL frame618 pix0: got=0 exp=25
TC15 FAIL frame624 pix0: got=0 exp=2
TC15 FAIL frame627 pix0: got=0 exp=14
TC15 FAIL frame628 pix0: got=0 exp=4
TC15 FAIL frame630 pix0: got=0 exp=1
TC15 FAIL frame632 pix0: got=0 exp=3
TC15 FAIL frame634 pix0: got=0 exp=6
TC15 FAIL frame636 pix0: got=0 exp=3
TC15 FAIL frame640 pix0: got=0 exp=2
TC15 FAIL frame643 pix0: got=0 exp=6
TC15 FAIL frame648 pix0: got=0 exp=6
TC15 FAIL frame656 pix0: got=0 exp=12
TC15 FAIL frame665 pix0: got=0 exp=1
TC15 FAIL frame671 pix0: got=0 exp=4
TC15 FAIL frame672 pix0: got=0 exp=1
TC15 FAIL frame674 pix0: got=0 exp=8
TC15 FAIL frame676 pix0: got=0 exp=15
TC15 FAIL frame679 pix0: got=0 exp=6
TC15 FAIL frame680 pix0: got=0 exp=1
TC15 FAIL frame684 pix0: got=0 exp=20
TC15 FAIL frame687 pix0: got=0 exp=3
TC15 FAIL frame688 pix0: got=0 exp=7
TC15 FAIL frame691 pix0: got=0 exp=56
TC15 FAIL frame694 pix0: got=0 exp=10
TC15 FAIL frame697 pix0: got=0 exp=10
TC15 FAIL frame706 pix0: got=0 exp=5
TC15 FAIL frame715 pix0: got=0 exp=15
TC15 FAIL frame716 pix0: got=0 exp=2
TC15 FAIL frame718 pix0: got=0 exp=3
TC15 FAIL frame721 pix0: got=0 exp=3
TC15 FAIL frame722 pix0: got=0 exp=3
TC15 FAIL frame723 pix0: got=0 exp=7
TC15 FAIL frame730 pix0: got=0 exp=24
TC15 FAIL frame734 pix0: got=0 exp=1
TC15 FAIL frame738 pix0: got=0 exp=1
TC15 FAIL frame741 pix0: got=0 exp=15
TC15 FAIL frame742 pix0: got=0 exp=5
TC15 FAIL frame747 pix0: got=0 exp=6
TC15 FAIL frame750 pix0: got=0 exp=4
TC15 FAIL frame754 pix0: got=0 exp=5
TC15 FAIL frame758 pix0: got=0 exp=36
TC15 FAIL frame766 pix0: got=0 exp=4
TC15 FAIL frame767 pix0: got=0 exp=32
TC15 FAIL frame769 pix0: got=0 exp=8
TC15 FAIL frame778 pix0: got=0 exp=5
TC15 FAIL frame780 pix0: got=0 exp=12
TC15 FAIL frame783 pix0: got=0 exp=1
TC15 FAIL frame784 pix0: got=0 exp=12
TC15 FAIL frame795 pix0: got=0 exp=2
TC15 FAIL frame796 pix0: got=0 exp=1
TC15 FAIL frame798 pix0: got=0 exp=1
TC15 FAIL frame802 pix0: got=0 exp=28
TC15 FAIL frame805 pix0: got=0 exp=1
TC15 FAIL frame808 pix0: got=0 exp=1
TC15 FAIL frame817 pix0: got=0 exp=4
TC15 FAIL frame824 pix0: got=0 exp=3
TC15 FAIL frame826 pix0: got=0 exp=4
TC15 FAIL frame833 pix0: got=0 exp=12
TC15 FAIL frame834 pix0: got=0 exp=4
TC15 FAIL frame850 pix0: got=0 exp=4
TC15 FAIL frame852 pix0: got=0 exp=5
TC15 FAIL frame860 pix0: got=0 exp=1
TC15 FAIL frame867 pix0: got=0 exp=3
TC15 FAIL frame868 pix0: got=0 exp=21
TC15 FAIL frame871 pix0: got=0 exp=5
TC15 FAIL frame878 pix0: got=0 exp=10
TC15 FAIL frame881 pix0: got=0 exp=10
TC15 FAIL frame882 pix0: got=0 exp=7
TC15 FAIL frame883 pix0: got=0 exp=12
TC15 FAIL frame891 pix0: got=0 exp=4
TC15 FAIL frame892 pix0: got=0 exp=8
TC15 FAIL frame897 pix0: got=0 exp=6
TC15 FAIL frame898 pix0: got=0 exp=4
TC15 FAIL frame901 pix0: got=0 exp=3
TC15 FAIL frame903 pix0: got=0 exp=4
TC15 FAIL frame906 pix0: got=0 exp=3
TC15 FAIL frame913 pix0: got=0 exp=4
TC15 FAIL frame950 pix0: got=0 exp=2
TC15 FAIL frame952 pix0: got=0 exp=8
TC15 FAIL frame953 pix0: got=0 exp=2
TC15 FAIL frame957 pix0: got=0 exp=1
TC15 FAIL frame962 pix0: got=0 exp=4
TC15 FAIL frame963 pix0: got=0 exp=1
TC15 FAIL frame965 pix0: got=0 exp=1
TC15 FAIL frame968 pix0: got=0 exp=6
TC15 FAIL frame970 pix0: got=0 exp=5
TC15 FAIL frame973 pix0: got=0 exp=24
TC15 FAIL frame979 pix0: got=0 exp=6
TC15 FAIL frame983 pix0: got=0 exp=4
TC15 FAIL frame984 pix0: got=0 exp=1
TC15 FAIL frame986 pix0: got=0 exp=14
TC15 FAIL frame988 pix0: got=0 exp=32
TC15 FAIL frame989 pix0: got=0 exp=1
TC15 FAIL frame990 pix0: got=0 exp=7
  TC15: 49036 checks, 280 errors
  FAIL [15] TC15 random 1000 frames no errors

============================================================
  Simulation Summary
============================================================
  Passed: 1222
  Failed: 11
  Total : 1233
------------------------------------------------------------
  SOME TESTS FAILED  <<<
============================================================
```

## Waveform

VCD file saved to: `sim/tb_shift_addr_gen.vcd`

Open with: `gtkwave sim/tb_shift_addr_gen.vcd`

## Checksum

- Report generated: 2026/06/06 巓鎗
