#!/usr/bin/env python3
"""
run_l1b_read_sim.py
====================
Compile and simulate tb_l1b_read_path.sv with Icarus Verilog.
L1b 数据通路闭环 —— 读通路 (shift_addr_gen -> frame_buf_mgr -> axis_output)

Usage:
    python sim/run_l1b_read_sim.py        # run simulation
    python sim/run_l1b_read_sim.py clean  # clean build artefacts
"""

import os
import subprocess
import sys
from pathlib import Path
from datetime import date

PROJ_ROOT = Path(__file__).resolve().parent.parent
SIM_DIR   = PROJ_ROOT / "sim"
RTL_DIR   = PROJ_ROOT / "rtl"
TB_DIR    = PROJ_ROOT / "tb"
RUNS_DIR  = PROJ_ROOT / ".awp" / "runs"

# Tool paths
IVERILOG = "iverilog"
VVP      = "vvp"

# Source files: 读通路包含 shift_addr_gen + frame_buf_mgr + axis_output
RTL_FILES = [
    RTL_DIR / "shift_addr_gen.sv",
    RTL_DIR / "frame_buf_mgr.sv",
    RTL_DIR / "axis_output.sv",
]
TB_FILES = [
    TB_DIR / "tb_l1b_read_path.sv",
]

SIMV = SIM_DIR / "simv_l1b_read_path"
LOG  = SIM_DIR / "sim_l1b_read_path.log"


def clean():
    """Remove simulation artefacts."""
    for f in [SIMV, LOG]:
        if f.exists():
            f.unlink()
    # VCD 在 sim/ 下, 由 iverilog 的 $dumpfile 创建
    vcd_path = SIM_DIR / "tb_l1b_read_path.vcd"
    if vcd_path.exists():
        vcd_path.unlink()
    print("[CLEAN] Removed simulation artefacts.")


def run_command(cmd, desc, cwd=None):
    """Run a command, print output, return (returncode, stdout)."""
    print(f"[{desc}] Running: {' '.join(str(c) for c in cmd)}")
    proc = subprocess.run(
        cmd,
        cwd=cwd or PROJ_ROOT,
        capture_output=True,
        text=True,
    )
    if proc.stdout:
        print(proc.stdout)
    if proc.stderr:
        print(proc.stderr, file=sys.stderr)
    if proc.returncode != 0:
        print(f"[{desc}] FAILED (return code {proc.returncode})")
    else:
        print(f"[{desc}] OK")
    return proc.returncode, proc.stdout


def compile_simulation():
    """Compile the design with iverilog."""
    cmd = [
        IVERILOG,
        "-g2012",                    # SystemVerilog support
        "-Wall",
        "-I", str(RTL_DIR),          # include path for RTL
        "-o", str(SIMV),             # output
    ] + [str(f) for f in RTL_FILES + TB_FILES]
    ret, _ = run_command(cmd, "COMPILE")
    return ret == 0


def run_simulation():
    """Run the compiled simulation with vvp."""
    cmd = [VVP, str(SIMV)]
    ret, stdout = run_command(cmd, "SIMULATE", cwd=SIM_DIR)
    # Save log
    with open(LOG, "w") as f:
        f.write(stdout or "")
    # Check for vvp error ret code
    if ret != 0:
        return False, stdout
    return True, stdout


def parse_results(log_text):
    """Extract pass/fail counts from simulation log."""
    if not log_text:
        return 0, 0, False
    passed = 0
    failed = 0
    all_pass = False
    for line in log_text.splitlines():
        if "ALL TESTS PASSED" in line:
            all_pass = True
        if "PASS [" in line:
            passed += 1
        if "FAIL [" in line:
            failed += 1
    return passed, failed, all_pass


def write_report(passed, failed, all_pass, log_text, test_count):
    """Write the simulation report to .awp/runs/."""
    report_path = RUNS_DIR / "RUN-E001-L1B-READ-001.md"
    status = "PASS" if all_pass else "FAIL"

    date_str = date.today().strftime("%Y/%m/%d")

    tc_descs = {
        1: "NONE 4x4 — basic read path pipeline, data correctness",
        2: "UP wrap 4x4 step=1 — vertical shift with wrap",
        3: "DOWN wrap 6x4 step=2 — vertical shift down with wrap",
        4: "LEFT wrap 4x6 step=3 — horizontal shift left with wrap",
        5: "RIGHT wrap 5x5 step=2 — horizontal shift right with wrap",
        6: "UP zero-fill 5x4 step=2 — overflow rows produce zero data",
        7: "LEFT zero-fill 3x5 step=2 — overflow columns produce zero data",
        8: "Multi-frame (3 frames) with inter-frame reset — state cleanup",
        9: "Backpressure — tready=0 mid-frame, data integrity after resume",
        10: "shift_en toggle — mid-frame disable/re-enable with reset",
        11: "Edge cases — 1x1, 1x5, 5x1 boundary conditions",
        12: "Partial frame — shift_en dropped mid-frame, resume without reset",
    }

    # Determine per-test-case status from log
    tc_status = {}
    for tid, desc in tc_descs.items():
        fail_found = False
        pass_found = False
        for line in (log_text or '').splitlines():
            s_tid = f"{tid:02d}"
            if f"FAIL [{s_tid}]" in line or f"FAIL [{tid}]" in line:
                if "---" not in line:
                    fail_found = True
            if f"PASS [{s_tid}]" in line or f"PASS [{tid}]" in line:
                if "---" not in line:
                    pass_found = True
        # More robust: look at section headers
        section_header = f"TC{tid:02d}"
        in_section = False
        section_fail = False
        section_pass = False
        for line in (log_text or '').splitlines():
            if f"--- TC{tid:02d}" in line or f"--- TC{tid}" in line:
                in_section = True
                continue
            if in_section and "--- TC" in line and f"TC{tid:02d}" not in line:
                break
            if in_section:
                if f"FAIL [{tid}]" in line or f"FAIL [{tid:02d}]" in line:
                    section_fail = True
                if f"PASS [{tid}]" in line or f"PASS [{tid:02d}]" in line:
                    section_pass = True

        if section_fail:
            tc_status[tid] = "FAIL"
        elif section_pass:
            tc_status[tid] = "PASS"
        else:
            tc_status[tid] = "NOT RUN"

    # Build report text
    report_text = f"""# RUN-E001-L1B-READ-001: L1b 读通路集成仿真

## Metadata

- **Task**: TASK-E001-010
- **Verification Level**: L1b (Datapath Integration Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: {date_str}
- **Testbench**: tb/tb_l1b_read_path.sv
- **DUT**: rtl/shift_addr_gen.sv + rtl/frame_buf_mgr.sv + rtl/axis_output.sv
- **Integration Scope**: datapath (read: shift_addr_gen -> frame_buf_mgr -> axis_output)

## Result

| Item | Value |
|------|-------|
| Status | **{status}** |
| Assertions | {test_count} |
| Passed | {passed} |
| Failed | {failed} |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
"""
    for tid in sorted(tc_status.keys()):
        report_text += f"| TC{tid:02d} | {tc_descs[tid]} | {tc_status[tid]} |\n"

    # Build pipeline timing analysis section
    report_text += """
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

"""
    # Truncate log to last 150 lines for report
    log_lines = (log_text or '').splitlines()
    if len(log_lines) > 150:
        log_lines = log_lines[-150:]

    report_text += f"""
## Simulation Log (last {len(log_lines)} lines)

```
{chr(10).join(log_lines)}
```

## Waveform

VCD file saved to: `sim/tb_l1b_read_path.vcd`

Open with: `gtkwave sim/tb_l1b_read_path.vcd`

## Checksum

- Report generated: {date_str}
"""
    with open(report_path, "w") as f:
        f.write(report_text)
    print(f"[REPORT] Written to {report_path}")
    return report_path


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "clean":
        clean()
        return

    print("=" * 60)
    print("  L1b Read Path Integration Simulation")
    print("  shift_addr_gen -> frame_buf_mgr -> axis_output")
    print("=" * 60)

    # Step 1: Clean previous artefacts
    clean()

    # Step 2: Compile
    print("\n--- Step 1/3: Compile ---")
    if not compile_simulation():
        print("[FATAL] Compilation failed. Aborting.")
        sys.exit(1)

    # Step 3: Run simulation
    print("\n--- Step 2/3: Simulate ---")
    sim_ok, log_text = run_simulation()
    if not sim_ok:
        print("[FATAL] Simulation failed to run. Aborting.")
        sys.exit(1)

    # Step 4: Parse and report
    print("\n--- Step 3/3: Parse Results ---")
    passed, failed, all_pass = parse_results(log_text)

    total = passed + failed
    if total == 0:
        print("[WARNING] No test results found in simulation output.")
        print("Raw log (first 2000 chars):")
        print(log_text[:2000])

    print(f"\nResults: {passed} passed, {failed} failed out of {total} assertions")

    # Write report
    report_path = write_report(passed, failed, all_pass, log_text, total)

    # Final status
    if all_pass:
        print("\n>>> ALL TESTS PASSED <<<")
    else:
        print(f"\n>>> SOME TESTS FAILED ({failed} failures) <<<")
        sys.exit(1)


if __name__ == "__main__":
    main()
