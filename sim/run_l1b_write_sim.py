#!/usr/bin/env python3
"""
run_l1b_write_sim.py
=====================
Compile and simulate tb_l1b_write_path.sv with Icarus Verilog.
L1b 数据通路闭环 —— 写通路（axis_input -> frame_buf_mgr）

Usage:
    python sim/run_l1b_write_sim.py        # run simulation
    python sim/run_l1b_write_sim.py clean  # clean build artefacts
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

# Source files: 写通路包含 axis_input + frame_buf_mgr
RTL_FILES = [
    RTL_DIR / "axis_input.sv",
    RTL_DIR / "frame_buf_mgr.sv",
]
TB_FILES = [
    TB_DIR / "tb_l1b_write_path.sv",
]

SIMV = SIM_DIR / "simv_l1b_write_path"
VCD  = SIM_DIR / "tb_l1b_write_path.vcd"
LOG  = SIM_DIR / "sim_l1b_write_path.log"


def clean():
    """Remove simulation artefacts."""
    for f in [SIMV, VCD, LOG]:
        if f.exists():
            f.unlink()
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
    cmd = [VVP, str(SIMV), f"+vcd={VCD}"]
    ret, stdout = run_command(cmd, "SIMULATE", cwd=SIM_DIR)
    # Save log
    with open(LOG, "w") as f:
        f.write(stdout or "")
    return ret == 0, stdout


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
    report_path = RUNS_DIR / "RUN-E001-L1B-WRITE-001.md"
    status = "PASS" if all_pass else "FAIL"

    date_str = date.today().strftime("%Y/%m/%d")

    # Test case descriptions
    tc_descs = {
        1: "Basic 4x4 capture and read-back — verify write_en timing and BRAM data",
        2: "Multi-frame (3 frames) data overwrite — verify frame boundaries",
        3: "Backpressure via tvalid gaps — verify data not lost",
        4: "capture_en toggle mid-frame — verify freeze/resume integrity",
        5: "rstn mid-frame — verify axis_input reset, BRAM data preserved",
        6: "Edge cases — 1x1, 1x5, 5x1 capture and read-back",
        7: "Random data 10x8 — full random data verification",
        8: "Full BRAM depth (64x64) — sequential write and partial read-back",
    }

    # Determine per-test-case status from log
    tc_status = {}
    for tid, desc in tc_descs.items():
        fail_found = False
        pass_found = False
        for line in (log_text or '').splitlines():
            if f"FAIL [{tid}]" in line:
                fail_found = True
            if f"PASS [{tid}]" in line:
                pass_found = True
        if fail_found:
            tc_status[tid] = "FAIL"
        elif pass_found:
            tc_status[tid] = "PASS"
        else:
            tc_status[tid] = "NOT RUN"

    # Build report
    report_text = f"""# RUN-E001-L1B-WRITE-001: L1b 写通路集成仿真

## Metadata

- **Task**: TASK-E001-009
- **Verification Level**: L1b (Datapath Integration Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: {date_str}
- **Testbench**: tb/tb_l1b_write_path.sv
- **DUT**: rtl/axis_input.sv + rtl/frame_buf_mgr.sv
- **Integration Scope**: datapath (write: axis_input -> frame_buf_mgr)

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

    # Truncate log to last 150 lines for report
    log_lines = (log_text or '').splitlines()
    if len(log_lines) > 150:
        log_lines = log_lines[-150:]

    report_text += f"""
## Pipeline Timing Analysis

### Write Path Timing (axis_input -> frame_buf_mgr)

```
Clock cycle:            T0          T1          T2          T3
s_axis_tdata            D0          D1          D2          D3
s_axis_tvalid      _____|~~~|_____|~~~|_____|~~~|_____|~~~|
s_axis_tready      ''''''''''''''''''''''''''''''''''''''''' (capture_en)
write_en (comb)           ^           ^           ^           ^
write_data (comb)        D0          D1          D2          D3
write_addr (comb)        A0          A1          A2          A3
-> frame_buf_mgr: bram[A0]<=D0 at T0 posedge, bram[A1]<=D1 at T1, ...
```

Key observations:
- write_en is combinatorial from capture_en & tvalid & tready
- write_addr is combinatorial from row_cnt * img_cols + col_cnt
- BRAM write occurs on the same cycle as the AXI-Stream beat (zero-cycle latency)
- BRAM read (port B) has 1-cycle latency: read_data valid 1 cycle after read_addr change

## Simulation Log (last 150 lines)

```
{chr(10).join(log_lines)}
```

## Waveform

VCD file saved to: `sim/tb_l1b_write_path.vcd`

Open with: `gtkwave sim/tb_l1b_write_path.vcd`

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
    print("  L1b Write Path Integration Simulation")
    print("  axis_input -> frame_buf_mgr")
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
        print("Raw log:")
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
