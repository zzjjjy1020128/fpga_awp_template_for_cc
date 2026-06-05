#!/usr/bin/env python3
"""
run_l1b_control_sim.py
======================
Compile and simulate tb_l1b_control_path.sv with Icarus Verilog.
L1b 控制通路闭环 —— axil_slave_if -> regs_top -> ctrl_fsm

Usage:
    python sim/run_l1b_control_sim.py        # run simulation
    python sim/run_l1b_control_sim.py clean  # clean build artefacts
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

# Source files: 控制通路包含 axil_slave_if + regs_top + ctrl_fsm
RTL_FILES = [
    RTL_DIR / "axil_slave_if.sv",
    RTL_DIR / "regs_top.sv",
    RTL_DIR / "ctrl_fsm.sv",
]
TB_FILES = [
    TB_DIR / "tb_l1b_control_path.sv",
]

SIMV = SIM_DIR / "simv_l1b_control_path"
LOG  = SIM_DIR / "sim_l1b_control_path.log"


def clean():
    """Remove simulation artefacts."""
    for f in [SIMV, LOG]:
        if f.exists():
            f.unlink()
    vcd_path = SIM_DIR / "tb_l1b_control_path.vcd"
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
    report_path = RUNS_DIR / "RUN-E001-L1B-CONTROL-001.md"
    status = "PASS" if all_pass else "FAIL"

    date_str = date.today().strftime("%Y/%m/%d")

    tc_descs = {
        1:  "Register config write/read-back — CFG/IMG_ROWS/IMG_COLS correct lock and read-back",
        2:  "CTRL.start self-clear and ctrl_start pulse — verify 1-cycle pulse, STATUS.busy_capture",
        3:  "capture_done -> SHIFT transition — shift_en=1, capture_en=0, STATUS.busy_shift",
        4:  "shift_done -> DONE -> IDLE auto-return — status_done latched, auto IDLE",
        5:  "Full flow IDLE->CAPTURE->SHIFT->DONE->IDLE with STATUS mutual exclusivity check",
        6:  "Consecutive 2-start (back-to-back frames) — done clear, re-enter flow",
        7:  "SW_RESET from CAPTURE — return to IDLE, capture_en=0",
        8:  "SW_RESET from SHIFT — return to IDLE, shift_en=0",
        9:  "SW_RESET from DONE — return to IDLE, done_latched preserved",
        10: "SW_RESET priority over ctrl_start — reset wins when both asserted",
        11: "Register stability during operation — config writes during CAPTURE/SHIFT",
        12: "Reserved and invalid address access — 0x14 returns 0, 0x40 returns SLVERR",
        13: "Three consecutive full flows — verify no state leakage across multiple starts",
    }

    # Determine per-test-case status from log
    tc_status = {}
    for tid, desc in tc_descs.items():
        fail_found = False
        pass_found = False
        for line in (log_text or '').splitlines():
            if f"FAIL [{tid}]" in line and "---" not in line:
                fail_found = True
            if f"PASS [{tid}]" in line and "---" not in line:
                pass_found = True
        if fail_found:
            tc_status[tid] = "FAIL"
        elif pass_found:
            tc_status[tid] = "PASS"
        else:
            tc_status[tid] = "NOT RUN"

    # Build report text
    report_text = f"""# RUN-E001-L1B-CONTROL-001: L1b 控制通路集成仿真

## Metadata

- **Task**: TASK-E001-011
- **Verification Level**: L1b (Datapath Integration Simulation)
- **Simulator**: Icarus Verilog (iverilog)
- **Date**: {date_str}
- **Testbench**: tb/tb_l1b_control_path.sv
- **DUT**: rtl/axil_slave_if.sv + rtl/regs_top.sv + rtl/ctrl_fsm.sv
- **Integration Scope**: datapath (control: axil_slave_if -> regs_top -> ctrl_fsm)

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

    # Pipeline timing analysis section
    report_text += """
## Pipeline Timing Analysis

### Control Path Timing (AXI-Lite Write -> regs_top -> ctrl_fsm)

```
Clock:                    T0              T1              T2              T3

AXI-Lite AW/W
  s_axil_awvalid          _____|~~~~~~~~~~~|
  s_axil_wvalid           _____|~~~~~~~~~~~|
  s_axil_awready          '''''''''''''''''|
  s_axil_wready           '''''''''''''''''|
  (both sampled at T0 posedge)

axil_slave_if
  wstate                  W_IDLE          W_RESP          W_IDLE
  wr_strobe[0]            0               1               0
  w_exec                  0               1               0

regs_top
  ctrl_r[0] (start)       0               1               0               0
  ctrl_start (combo)      0               1               0               0

ctrl_fsm
  state (registered)      IDLE            IDLE            CAPTURE         CAPTURE
  capture_en              0               0               1               1
```

Key observations:
1. AXI-Lite write takes 1 cycle from AW/W handshake to wr_strobe assertion.
2. regs_top locks ctrl_start at the same posedge as wr_strobe (T1).
3. ctrl_start is a 1-cycle pulse (self-clearing in regs_top).
4. ctrl_fsm transitions from IDLE to CAPTURE at the NEXT posedge (T2), 2 cycles after the AXI-Lite write.
5. capture_en goes high at T2 and stays high until capture_done is received.

### Capture -> Shift Transition

```
Clock:                    T0              T1              T2
state                     CAPTURE         CAPTURE         SHIFT
capture_en                1               1               0
shift_en                  0               0               1
mock_capture_done         0               1 (pulse)      0
```

### Shift -> Done -> IDLE Auto-Return

```
Clock:                    T0              T1              T2              T3
state                     SHIFT           SHIFT           DONE            IDLE
shift_en                  1               1               0               0
mock_shift_done           0               1 (pulse)      0               0
status_done (FSM)         0 (combo)       0               1               0
status_done (latched)     0               0               1               1
```

### STATUS Mutual Exclusivity

regs_top enforces: `status_idle_eff = status_idle && !status_busy_capture && !status_busy_shift && !done_latched`
- idle is only visible when NO other state is active
- When done_latched=1, idle reads as 0 (not both 1)
- When busy_capture=1, idle reads as 0

"""

    # Truncate log to last 200 lines for report
    log_lines = (log_text or '').splitlines()
    if len(log_lines) > 200:
        log_lines = log_lines[-200:]

    report_text += f"""
## Simulation Log (last {len(log_lines)} lines)

```
{chr(10).join(log_lines)}
```

## Waveform

VCD file saved to: `sim/tb_l1b_control_path.vcd`

Open with: `gtkwave sim/tb_l1b_control_path.vcd`

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
    print("  L1b Control Path Integration Simulation")
    print("  axil_slave_if -> regs_top -> ctrl_fsm")
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

    # Print test result summary
    if log_text:
        for line in log_text.splitlines():
            if "FAIL [" in line:
                print(f"  {line}")

    # Final status
    if all_pass:
        print("\n>>> ALL TESTS PASSED <<<")
    else:
        print(f"\n>>> SOME TESTS FAILED ({failed} failures) <<<")
        sys.exit(1)


if __name__ == "__main__":
    main()
