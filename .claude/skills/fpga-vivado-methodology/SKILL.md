---
skill_id: SKILL-FPGA-VIVADO-METHODOLOGY
name: fpga-vivado-methodology
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-001
  - SRC-FPGA-010
validated_in_projects: ["E001"]
last_reviewed: "2026-06-15"
owner: human_owner
mcp_tools_gated:
  - mcp__vivado__run_synthesis
  - mcp__vivado__run_implementation
  - mcp__vivado__generate_bitstream
  - mcp__vivado__check_bitstream_readiness
  - mcp__vivado__get_timing_report
  - mcp__vivado__get_utilization_report
---

# Vivado 综合/实现方法论 (L2-L4)

> ⚠️ **MCP Gate**：本 skill 是所有综合/实现/比特流操作的唯一入口。
> 模型不得直接调用 `run_synthesis` / `run_implementation` / `generate_bitstream`，
> 必须先经过本 skill 的 L2-L4 checklist 和前置条件审查。

## 适用场景
- vivado_integrator 执行 L2（综合）、L3（实现+时序）、L4（比特流生成）
- 综合/实现失败时定位根因
- 时序不收敛时系统化排查

## 前置条件
- Vivado 工程已打开或 Tcl 脚本已就绪
- 约束文件（`constraints/*.xdc`）已通过 `xdc_lint`
- RTL 已通过 L1a/L1b/L1c（至少目标级别）

## L2 — 综合检查清单

- [ ] 运行综合前执行 `xdc_lint`（检查 PIN_CONFLICT、MISSING_IOSTANDARD 等）
- [ ] 运行综合：`launch_runs synth_1 -jobs 4`，等待 `synth_1 Complete`
- [ ] 检查 CRITICAL WARNING：≥1 个 CW → 不准进入 L3，先排查
- [ ] 检查资源利用率（LUT/FF/BRAM/DSP/IOB 百分比）
  - > 90%：[CRITICAL] 后续布线可能拥塞
  - 70-90%：[WARN] 关注拥塞热点
- [ ] 检查 Methodology 报告（`report_methodology`）
- [ ] 综合通过后生成 post-synth DCP 用于后续实现

## L3 — 实现与时序检查清单

- [ ] 运行实现：`launch_runs impl_1 -jobs 4`，等待 `route_design Complete`
- [ ] 检查时序报告：`report_timing_summary`
  - WNS ≥ 0 ns → PASS
  - WNS < 0 ns → FAIL，需排查关键路径
- [ ] 检查 CRITICAL WARNING（route 阶段的 CW 比 synth 更严重）
- [ ] 时序违例排查顺序：
  1. 约束是否正确（时钟周期、false path、clock groups）
  2. 拥塞是否严重（utilization > 90%）
  3. 关键路径是否可优化（pipeline、retiming）
  4. 高扇出信号（> 1000 loads）是否需要复制
- [ ] 实现通过后，确保 IO 引脚报告与约束一致（`verify_io_placement_tool`）

## L4 — 比特流生成检查清单

- [ ] 运行 `check_bitstream_readiness` — 必须返回 READY
- [ ] 有 CW 时确认风险后使用 `force=True` 生成
- [ ] 生成后记录比特流版本（日期或 SHA256）
- [ ] 确认比特流文件存在且大小非零

## 反模式（禁止事项）

### ❌ "综合报 CW，但看起来不严重，先跑实现再说"
```
任何 CRITICAL WARNING 都可能在下游被放大。synth 阶段的 1 个 CW
可能在 route 阶段变成 50 个时序违例。CW 必须清零才能进入下一步。
```
**正解**：`get_critical_warnings` → 分类 → 修复 → 重新综合直到 0 CW。

### ❌ "改了一行 RTL，直接综合验证"
```
综合需要 10-15 分钟。iverilog 编译检查只需 3 秒。
用综合当语法检查器是极大的时间浪费。
```
**正解**：`iverilog -t null` → verible lint → 仿真 → 综合。参考 `fpga-iteration-economics`。

### ❌ "时序不收敛？加 set_false_path"
```
用 set_false_path 掩盖时序违例而不理解为什么违例，
可能在硬件上产生间歇性错误（最难的 bug）。
false path 只应标注物理上不可能发生的路径。
```
**正解**：先分析关键路径 → 确认是否真的不需要时序分析 → 再约束。

### ❌ "资源超 90% 但综合过了，应该没事"
```
LUT/FF > 90% → 布局布线拥塞概率极高 → 时序难以收敛。
BRAM > 90% → 几乎必然有模块无法获得 BRAM 资源。
```
**正解**：资源 > 90% 时重新审视架构（减少 ILA 探针数、优化存储方案、考虑外部 DDR）。

### ❌ "没运行 xdc_lint 就直接综合"
```
PIN_CONFLICT / MISSING_IOSTANDARD / DUPLICATE_PORT 等约束错误
xdc_lint 1 秒就能发现，等到实现阶段才报错 = 30 分钟浪费。
```
**正解**：每次修改 XDC 后立即 `xdc_lint`，通过后再综合。

### ❌ "用 RTL 实例化 ILA"（ila_ctrl_cross / ila_data_cross）
```
RTL 中直接 `ila_xxx u_ila(...)` → Vivado 自动创建 OOC IP run → 生成 .dcp 缓存
→ 外部信号名无法穿透 IP 边界 → ILA 探针名显示为 <const0>
→ probe 连接改为真实信号后综合不更新（缓存判定 "already up-to-date"）
```
**正解**：BD 中用 `xilinx.com:ip:ila:6.2`（非 `system_ila`）+ NATIVE probe 直连 wrapper 单端端口。详见 §"BD 中加 ILA"。

### ❌ "用 system_ila 的 INTERFACE 模式连 AXIS 网"
```
Tcl 创建 system_ila → SLOT_0_AXI 默认为 AXI 内存映射 → 连 AXIS 网时类型不匹配
→ connect_bd_intf_net 失败 → 级联损坏 BD
→ C_MON_TYPE/C_SLOT_0_INTF_TYPE 参数在 Tcl 中不生效
```
**正解**：用 `xilinx.com:ip:ila:6.2` NATIVE 模式 + probe 直连，不用 interface 网。

### ❌ "module_ref 混用 packaged IP"
```
BD 中同时存在 module_ref 和 packaged IP → IP catalog 目录被删 → XCI 找不到
→ "IP definition not found" → 综合阻塞 → BD 锁定
```
**正解**：选一条路线并保持干净。推荐 module_ref（`wrapper_2d_shift.v`）：直接 RTL，无缓存、无锁定。

### ❌ "git clean -fd 清理 Vivado 工程"
```
.gitignore 以外的生成文件（.dcp、_stub.v、gen_run.xml）被删
→ 工程数据库硬引用断裂 → Vivado 启动/综合崩溃 → 不可恢复
```
**正解**：Vivado 工程清理只用 Vivado 命令（`reset_run`、`reset_project`），不用 `git clean`。生成文件不在 git 中但不可删除。

### ❌ "改 RTL 后不检查 IP 源文件同步"
```
rtl/ 和 vivado/ip/.../src/ 各有一份 RTL→ 只改一处 → 综合用的仍是旧版本
```
**正解**：用 module_ref 消除二重性；如果用 IP，改完 rtl/ 后立即同步到 vivado/ip/。

## 相关 Skills

- `fpga-vivado-log-analysis` — CW 分类、时序报告解读
- `fpga-vivado-preflight` — 综合前环境检查（必须通过）
- `fpga-iteration-economics` — 理解综合/实现的真实时间成本
- `fpga-rtl-style` — 综合前 lint 检查
- `fpga-validation-levels` — L2/L3/L4 门禁规则
- `fpga-project-acceptance` — 时序/资源合同阈值

## BD 中加 ILA —— 唯一验证通过的自动化方案

### 核心发现

1. **不要用 `system_ila`**：它的 INTERFACE 模式在 Tcl 中无法自动适配 AXIS 网
2. **用 `xilinx.com:ip:ila:6.2`**：NATIVE probe 直连 wrapper 单端信号，可靠
3. **BD 修改后必须跑 `generate_target all [get_files design_1.bd] -force`**：否则嵌套 IP 的 .dcp 不生成，实现时黑盒报错
4. **BD 修改用一次性脚本**：增量 Tcl 修改的级联错误无法恢复

### 完整流程（已验证）

```tcl
# 1. 打开 BD
open_bd_design [get_files design_1.bd]

# 2. 创建 ILA（注意：是 ila:6.2，不是 system_ila）
create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_accel
set_property -dict [list \
  CONFIG.C_NUM_OF_PROBES {5} \
  CONFIG.C_PROBE0_WIDTH {32} \
  CONFIG.C_PROBE1_WIDTH {8} \
  CONFIG.C_PROBE2_WIDTH {1} \
  CONFIG.C_PROBE3_WIDTH {1} \
  CONFIG.C_PROBE4_WIDTH {1}] [get_bd_cells ila_accel]

# 3. 直连 wrapper 单端端口（非接口网！）
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins ila_accel/clk]
connect_bd_net [get_bd_pins wrapper_2d_shift_0/dbg_port]    [get_bd_pins ila_accel/probe0]
connect_bd_net [get_bd_pins wrapper_2d_shift_0/m_axis_tdata] [get_bd_pins ila_accel/probe1]
connect_bd_net [get_bd_pins wrapper_2d_shift_0/m_axis_tvalid] [get_bd_pins ila_accel/probe2]
connect_bd_net [get_bd_pins wrapper_2d_shift_0/m_axis_tlast] [get_bd_pins ila_accel/probe3]
connect_bd_net [get_bd_pins wrapper_2d_shift_0/m_axis_tuser] [get_bd_pins ila_accel/probe4]

# 4. 保存并生成所有嵌套 IP 输出产物（关键！缺此步 → 黑盒报错）
save_bd_design
generate_target all [get_files design_1.bd] -force

# 5. 综合 → 实现 → 比特流
make_wrapper -files [get_files design_1.bd] -top -force
add_files -norecurse <wrapper_path>/design_1_wrapper.v
launch_runs synth_1 -jobs 4; wait_on_run synth_1
launch_runs impl_1 -jobs 4; wait_on_run impl_1
write_bitstream -force <path>/design_1_wrapper.bit
write_debug_probes -force <path>/design_1_wrapper.ltx
```

### 为什么不能增量修改 BD

Vivado Tcl BD API 不是事务性的：
```
connect_bd_net 失败 → 错误残留 → 下一个命令返回空 → 级联误报
→ save_bd_design 写入半损坏 XML → 整个 BD 不可用 → 只能 kill 重来
```
- **一次性创建**（如上脚本）：成功率极高
- **增量修改**（加一个 cell）：每次试错前必须 `close_bd_design` + `open_bd_design` 重置状态

### ILA 探针命名

成功连接后，ILA 探针以 wrapper 端口名显示（如 `wrapper_2d_shift_0_m_axis_tlast`），而非 `<const0>`。关键在于：
- 信号必须是 wrapper 的**顶层端口**（interface pin override 会导致命名丢失）
- 不能通过 interface net 间接连接

## 常用 Tcl 命令速查

```tcl
# 综合
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# 实现
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# 时序报告
report_timing_summary -file timing.rpt

# 资源报告
report_utilization -file utilization.rpt

# IO 报告
report_io -file io.rpt
```

## 输出格式
- `.awp/runs/RUN-{exp}-SYNTH-{seq}.md` — 综合记录
- `.awp/runs/RUN-{exp}-IMPL-{seq}.md` — 实现记录
- 比特流版本必须记录在 run record 中
