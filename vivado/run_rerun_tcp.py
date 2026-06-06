"""Run L2+L3 rerun via Vivado TCP."""
import sys, time
sys.path.insert(0, "vivado")
from run_via_tcp import send_tcl

script_path = r"D:\AGENT_WORK_SPACE_FOR_CLAUDE\fpga_awp_template\vivado\run_l2l3_rerun_tcp.tcl"
abs_path = script_path.replace("\\", "/")

print("Starting L2+L3 rerun via TCP...")
print(f"Script: {abs_path}")
print(f"Started at: {time.strftime('%Y-%m-%d %H:%M:%S')}")

result = send_tcl(f"source {{{abs_path}}}", timeout=1200)

print("")
print(f"Finished at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
print(result)
