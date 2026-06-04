#!/usr/bin/env python3
"""
run_axis_input_sim.py
======================
Compile and simulate tb_axis_input.sv with Icarus Verilog.
Report pass/fail status.

Usage:
    python sim/run_axis_input_sim.py        # run simulation
    python sim/run_axis_input_sim.py clean  # clean build artefacts
"""

import os
import subprocess
import sys
from pathlib import Path

PROJ_ROOT = Path(__file__).resolve().parent.parent
SIM_DIR   = PROJ_ROOT / "sim"
RTL_DIR   = PROJ_ROOT / "rtl"
TB_DIR    = PROJ_ROOT / "tb"
RUNS_DIR  = PROJ_ROOT / ".awp" / "runs"

# Tool paths
IVERILOG = "iverilog"
VVP      = "vvp"

# Source files
RTL_FILES = [
    RTL_DIR / "axis_input.sv",
]
TB_FILES = [
    TB_DIR / "tb_axis_input.sv",
]

SIMV = SIM_DIR / "simv_axis_input"
VCD  = SIM_DIR / "tb_axis_input.vcd"
LOG  = SIM_DIR / "sim_axis_input.log"


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
    report_path = RUNS_DIR / "RUN-E001-SIM-003.md"
    status = "PASS" if all_pass else "FAIL"

    # Determine date string
    if os.name == 'nt':
        try:
            date_str = subprocess.check_output(['date', '/T'], shell=True, text=True).strip()
        except Exception:
            date_str = "2025-01-01"
    else:
        try:
            date_str = subprocess.check_output(['date', '+%Y-%m-%d'], text=True).strip()
        except Exception:
            date_str = "2025-01-01"

    # Check which test cases appear in the log
    tc_status = {}
    tc_descs = {
        1:  "Basic capture 4x4, verify write_addr sequence",
        2:  "tuser frame start reset mid-frame",
        3:  "tlast row end: col resets, row+1",
        4:  "capture_done pulse at frame completion",
        5:  "capture_en=0: tready=0, counters unchanged",
        6:  "Single row (img_rows=1): tlast triggers capture_done",
        7:  "Single column (img_cols=1): tuser+tlast handling",
        8:  "Single pixel (1x1): tuser+tlast, capture_done",
        9:  "Dynamic img_rows/img_cols switching",
        10: "capture_en mid-cancel and resume",
        11: "Random frame size and random data, verify raster scan",
    }
    for tid, desc in tc_descs.items():
        # Check if any FAIL for this TC
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

    report_text = f"""# RUN-E001-SIM-003: axis_input AXI4-Stream Input Interface Simulation

## Metadata

- **Task**: TASK-E001-004
- **Verification Level**: L1 (Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: {date_str}
- **Testbench**: tb/tb_axis_input.sv
- **DUT**: rtl/axis_input.sv

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

    report_text += f"""
## Simulation Log (last 100 lines)

```
{chr(10).join((log_text or '').splitlines()[-100:])}
```

## Waveform

VCD file saved to: `sim/tb_axis_input.vcd`

Open with: `gtkwave sim/tb_axis_input.vcd`

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
    print("  axis_input Simulation (tb_axis_input)")
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
        print(log_text)

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
