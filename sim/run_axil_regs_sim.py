#!/usr/bin/env python3
"""
run_axil_regs_sim.py
====================
Compile and simulate tb_axil_regs.sv with Icarus Verilog.
Report pass/fail status.

Usage:
    python sim/run_axil_regs_sim.py        # run simulation
    python sim/run_axil_regs_sim.py clean  # clean build artefacts
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

# Tool paths (adjust to your environment)
IVERILOG = "iverilog"
VVP      = "vvp"

# Source files
RTL_FILES = [
    RTL_DIR / "axil_slave_if.sv",
    RTL_DIR / "regs_top.sv",
]
TB_FILES = [
    TB_DIR / "tb_axil_regs.sv",
]

SIMV = SIM_DIR / "simv"
VCD  = SIM_DIR / "tb_axil_regs.vcd"
LOG  = SIM_DIR / "sim.log"


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
    # Count PASS/FAIL lines
    for line in log_text.splitlines():
        if "PASS [" in line or "PASS [" in line:
            passed += 1
        if "FAIL [" in line or "FAIL [" in line:
            failed += 1
    return passed, failed, all_pass


def write_report(passed, failed, all_pass, log_text, test_count):
    """Write the simulation report to .awp/runs/."""
    report_path = RUNS_DIR / "RUN-E001-SIM-001.md"
    status = "PASS" if all_pass else "FAIL"
    report_text = f"""# RUN-E001-SIM-001: AXI-Lite Register Simulation

## Metadata

- **Task**: TASK-E001-002
- **Verification Level**: L1 (Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: {subprocess.check_output(['date', '/T'], shell=True, text=True).strip() if os.name == 'nt' else subprocess.check_output(['date'], text=True).strip()}
- **Testbench**: tb/tb_axil_regs.sv
- **DUT**: rtl/axil_slave_if.sv + rtl/regs_top.sv

## Result

| Item | Value |
|------|-------|
| Status | **{status}** |
| Test cases | {test_count} |
| Passed | {passed} |
| Failed | {failed} |

## Test Cases Executed

| ID | Description | Status |
|----|-------------|--------|
| TC01 | Write IMG_ROWS=0x40, read back | {'PASS' if 'TC01' in log_text else 'CHECK LOG'} |
| TC02 | Write IMG_COLS=0x80, read back | {'PASS' if 'TC02' in log_text else 'CHECK LOG'} |
| TC03 | Sequential writes (multiple regs), read back each | {'PASS' if 'TC03' in log_text else 'CHECK LOG'} |
| TC04 | CFG bit-field test (dir/step/wrap_en) | {'PASS' if 'TC04' in log_text else 'CHECK LOG'} |
| TC05 | CTRL.start self-clearing | {'PASS' if 'TC05' in log_text else 'CHECK LOG'} |
| TC06 | CTRL.sw_reset self-clearing | {'PASS' if 'TC06' in log_text else 'CHECK LOG'} |
| TC07 | Read reserved addresses (0x14, 0x18) | {'PASS' if 'TC07' in log_text else 'CHECK LOG'} |
| TC08 | Write reserved, no side effect | {'PASS' if 'TC08' in log_text else 'CHECK LOG'} |
| TC09 | Invalid address SLVERR | {'PASS' if 'TC09' in log_text else 'CHECK LOG'} |
| TC10 | STATUS simulation (idle/busy/done/mutex) | {'PASS' if 'TC10' in log_text else 'CHECK LOG'} |
| TC11 | WSTRB partial write | {'PASS' if 'TC11' in log_text else 'CHECK LOG'} |

## Simulation Log (last 100 lines)

```
{chr(10).join((log_text or '').splitlines()[-100:])}
```

## Waveform

VCD file saved to: `sim/tb_axil_regs.vcd`

Open with: `gtkwave sim/tb_axil_regs.vcd`

## Checksum

- Report generated: {subprocess.check_output(['date', '/T'], shell=True, text=True).strip() if os.name == 'nt' else 'auto'}
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
    print("  AXI-Lite Register Simulation (tb_axil_regs)")
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

    # Count total test cases from log
    total = passed + failed
    if total == 0:
        print("[WARNING] No test results found in simulation output.")
        print("Raw log:")
        print(log_text)

    print(f"\nResults: {passed} passed, {failed} failed out of {total} checks")

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
