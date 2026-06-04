#!/usr/bin/env python3
"""
run_axil_2d_shift_sim.py
==========================
Compile and simulate tb_axil_2d_shift.sv with Icarus Verilog.
Full-system integration testbench for axil_2d_shift.

Usage:
    python sim/run_axil_2d_shift_sim.py        # run simulation
    python sim/run_axil_2d_shift_sim.py clean  # clean build artefacts
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

# Source files — all RTL modules (7 submodules + top)
RTL_FILES = [
    RTL_DIR / "axil_slave_if.sv",
    RTL_DIR / "regs_top.sv",
    RTL_DIR / "ctrl_fsm.sv",
    RTL_DIR / "axis_input.sv",
    RTL_DIR / "axis_output.sv",
    RTL_DIR / "shift_addr_gen.sv",
    RTL_DIR / "frame_buf_mgr.sv",
    RTL_DIR / "axil_2d_shift.sv",
]

TB_FILES = [
    TB_DIR / "tb_axil_2d_shift.sv",
]

SIMV = SIM_DIR / "simv_axil_2d_shift"
VCD  = SIM_DIR / "tb_axil_2d_shift.vcd"
LOG  = SIM_DIR / "sim_axil_2d_shift.log"


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

    # Also check for per-pixel comparisons
    # The summary line says "Passed: N  Failed: M"
    for line in log_text.splitlines():
        if "Passed" in line and "Failed" in line:
            parts = line.split()
            for i, p in enumerate(parts):
                if p == "Passed":
                    try:
                        passed_from_summary = int(parts[i+1].rstrip(','))
                        # Use the higher count (pixel-level has more asserts)
                        if passed_from_summary > passed:
                            passed = passed_from_summary
                    except (ValueError, IndexError):
                        pass
                if p == "Failed":
                    try:
                        failed_from_summary = int(parts[i+1].rstrip(','))
                        if failed_from_summary > failed:
                            failed = failed_from_summary
                    except (ValueError, IndexError):
                        pass

    return passed, failed, all_pass


def write_report(passed, failed, all_pass, log_text, test_count):
    """Write the simulation report to .awp/runs/."""
    report_path = RUNS_DIR / "RUN-E001-SIM-007.md"
    status = "PASS" if all_pass else "FAIL"

    # Determine date string
    if os.name == 'nt':
        try:
            date_str = subprocess.check_output(
                ['powershell', '-Command', 'Get-Date -Format yyyy-MM-dd'],
                text=True
            ).strip()
        except Exception:
            date_str = "2026-06-04"
    else:
        try:
            date_str = subprocess.check_output(
                ['date', '+%Y-%m-%d'], text=True
            ).strip()
        except Exception:
            date_str = "2026-06-04"

    # Check which test cases appear in the log
    tc_descs = {
        1:  "NONE passthrough 4x4 — verify output = input",
        2:  "UP wrap 6x4 step=2 — each column shifted up 2 rows with wrap",
        3:  "DOWN wrap 6x4 step=1 — each column shifted down with wrap",
        4:  "LEFT wrap 4x6 step=3 — each row shifted left with wrap",
        5:  "RIGHT wrap 4x6 step=2 — each row shifted right with wrap",
        6:  "UP zero-fill 5x4 step=2 — bottom rows zero-filled",
        7:  "LEFT zero-fill 3x5 step=2 — right columns zero-filled",
        8:  "Continuous two frames — UP wrap then DOWN zero-fill",
        9:  "SW_RESET during capture — verify return to IDLE",
        10: "Register readback — verify register values before/after operation",
        11: "Single row/column boundary — 1x5, 5x1, 1x1 cases",
    }

    tc_status = {}
    for tid, desc in tc_descs.items():
        fail_found = False
        pass_found = False
        for line in (log_text or '').splitlines():
            # TCn patterns: "TC0n" or "TCnn" with PASS/FAIL
            # PASS/FAIL lines have format "  PASS [N] ..." or "  FAIL [N] ..."
            pass
        # More robust: just check for absence of fail markers per TC
        for tid2 in tc_descs:
            tc_status[tid2] = "NOT RUN"

    # Re-parse with TC-id awareness
    for line in (log_text or '').splitlines():
        for tid in tc_descs:
            tc_str = f"[{tid}]" if tid < 10 else f"[{tid}"
            if f"PASS [{tid}]" in line or f"PASS [{tid}-" in line:
                tc_status[tid] = "PASS"
            if f"FAIL [{tid}]" in line or f"FAIL [{tid}-" in line:
                tc_status[tid] = "FAIL"
            if f"FAIL [TIMEOUT" in line:
                pass  # handled elsewhere

    report_text = f"""# RUN-E001-SIM-007: axil_2d_shift Full-System Integration Simulation

## Metadata

- **Task**: TASK-E001-008
- **Verification Level**: L1 (Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: {date_str}
- **Testbench**: tb/tb_axil_2d_shift.sv
- **DUT**: rtl/axil_2d_shift.sv (top-level, integrates 7 sub-modules)

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

    # Truncate log to last 300 lines for report
    log_lines = (log_text or '').splitlines()
    if len(log_lines) > 300:
        log_lines = log_lines[-300:]

    report_text += f"""
## Simulation Log (last {len(log_lines)} lines)

```
{chr(10).join(log_lines)}
```

## Waveform

VCD file saved to: `sim/tb_axil_2d_shift.vcd`

Open with: `gtkwave sim/tb_axil_2d_shift.vcd`

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
    print("  axil_2d_shift Full-System Integration Simulation")
    print("  (TASK-E001-008)")
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
        # Print first 50 lines of log
        lines = (log_text or '').splitlines()
        for line in lines[:50]:
            print(line)
        if len(lines) > 50:
            print(f"... ({len(lines) - 50} more lines)")

    print(f"\nResults: {passed} passed, {failed} failed out of {total} assertions")

    # Write report
    report_path = write_report(passed, failed, all_pass, log_text, total)

    # Print result summary from log
    print("\n--- Test Result Summary ---")
    if log_text:
        for line in log_text.splitlines():
            if "PASS [" in line or "FAIL [" in line or "ALL TESTS" in line or "Simulation Summary" in line:
                print(f"  {line}")
            if "Passed" in line and "Failed" in line:
                print(f"  {line}")

    # Final status
    if all_pass:
        print("\n>>> ALL TESTS PASSED <<<")
    else:
        print(f"\n>>> SOME TESTS FAILED ({failed} failures) <<<")
        sys.exit(1)


if __name__ == "__main__":
    main()
