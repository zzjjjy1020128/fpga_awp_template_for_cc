# HW_BASE Changelog

## v1.0 (2026-06-07) — Initial Frozen Base

**Platform**: Zynq UltraScale+ MPSoC (xczu9eg-ffvb1156-2-e, ZCU102)

**BD Components**:
- PS8 (zynq_ultra_ps_e) — CPU, DDR, AXI infrastructure
- AXI Interconnect (1:2) — GP control bus
- AXI DMA (8-bit, Simple mode) — Stream ↔ DDR
- AXI SmartConnect (2:1, 64-bit) — HP data bus
- Processor System Reset
- ILA x2 (capture + shift monitors, 1024 depth)
- xlconcat (interrupt merge)

**Accelerator**: axil_2d_shift v1.0 (awp:user:axil_2d_shift:1.0)

**Validation**:
- Synthesis: PASS (0 errors, 1 CW — incremental checkpoint residue)
- Implementation: PASS (WNS +5.636 ns, WHS +0.010 ns)
- Bitstream: PASS (design_1_wrapper.bit, 26.5 MB)

**Known Issues**:
- ILA probes floating (need mark_debug in RTL to connect)
- Constraint CW resolved (removed redundant create_clock; PS IP auto-manages clock)
