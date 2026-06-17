---
skill_id: SKILL-FPGA-ZYNQ-DEBUG-TOOLCHAIN
name: fpga-zynq-debug-toolchain
layer: FPGA-Method
status: local_adapted
source_basis:
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-15"
owner: human_owner
mcp_tools_gated:
  - mcp__vivado__run_hw_ila
  - mcp__vivado__get_hw_probes
  - mcp__vivado__program_device (Zynq 平台禁止，必须走 XSCT)
---

# Skill: zynq-debug-toolchain

> ⚠️ **MCP Gate**：本 skill 是所有 ILA 操作和 Zynq 烧录的唯一入口。
> 模型不得直接调用 `run_hw_ila` / `get_hw_probes` / `program_device`（Zynq），
> 必须先经过本 skill 的硬规则检查。

## When to use

Zynq-7000 PS-PL 联合调试，涉及 DMA 数据通路、AXI Stream 连通性、加速器行为诊断。

## 整体思维：工具链是一个闭合环路

```
Vivado BD  ──→  XSA  ──→  Vitis/BSP  ──→  C 代码  ──→  XSCT  ──→  硬件
    ↑                                                            │
    └──────────── ILA 观察 / 反馈 ←──────────────────────────────┘
```

**任何一个环节的断裂都会导致下游全部白费**。AWP 当前最大的缺口就是缺乏环节间的检查点。

## 环节 0：进入 Vitis 前的强制前置检查

> **在执行任何 Vitis/BSP/C 代码工作之前，必须逐项确认。跳过即白忙。**

### 检查点 A：BD 完整性

```
[ ] ILA probe 无悬空 — 每个 System ILA SLOT 是否连接到了正确的 AXI 接口？
[ ] Accelerator IP 端口连接完整 — s_axis / m_axis / s_axil 是否都连上？
[ ] DMA 到 Interconnect 到 HP0 的 AXI 通路无断点
[ ] validate_bd_design 通过
```

**为什么**：如果 BD 中 ILA probe 悬空或 stream 连接断开，后面在 Vitis 里写再多 C 代码也是基于错误硬件。

### 检查点 B：XSA ↔ Vivado 工程同步

```
[ ] 用户最近一次 export XSA 的时间戳？是否晚于最后 BD 修改？
[ ] 当前 Vitis 使用的 XSA 和 Vivado 工程生成的是同一个文件吗？
[ ] bitstream 和 XSA 是否配套（同一次 export hardware 产出）？
[ ] ps7_init.tcl 是从同一个 XSA 中提取的吗？
```

**为什么**：XSA 不一致会导致 BSP 的 xparameters.h 地址错误、ps7_init 不匹配、bitstream 和 BSP 不配套。

### 检查点 C：用户声明优先

```
[ ] 用户是否明确说了 "我已经重新 generate BD → bitstream → export XSA"？
      如果是 → 立即丢弃旧 XSA 和工作区，从新 XSA 开始
[ ] 用户是否提到了 BD 中的手动修改？
      如果是 → 先看 BD 确认修改内容
```

**为什么**：用户对 BD 的修改（如手动连接 ILA probe）不会自动同步到我之前的认知中。用户说"已重新导出"意味着旧的 XSA 和平台都是废的，必须从零重建。

## 核心原则：先诊断，后修复

**诊断优先链**：ILA 波形 > AXI-Lite 寄存器 dump > 改 C 代码加 debug 输出

ILA 能直接回答"这根线上有没有数据"——是硬件调试最快的手段。
不要用 C 代码里的 `R[ri++]` 手工寄存器 dump 替代 ILA。ILA 已经在 hw_server 上连着，直接用。

## 架构：hw_server 守护进程 + 双客户端

```
hw_server -d -p3121          ← 单一 JTAG 主控
  ├── XSCT: connect -url tcp:localhost:3121  (PS 控制者)
  │     职责: ps7_init, fpga -f, dow, con, mwr gate
  └── Vivado MCP: connect_hw_server -url TCP:localhost:3121  (PL 观察者)
        职责: 配置 ILA 触发, arm, upload, 导出 CSV
```

两者**同时**连接同一 hw_server，无冲突。

## 标准 XSCT 下载流程

> ⚠️ **XSCT 路径**：从 `.awp/platform/host_env.yaml#toolchain.vitis.xsct` 读取。
> 典型位置：`<vivado_base>/Vitis/<version>/bin/xsct.bat`（不在 Vivado/bin！）
> 当前主机 XSCT：`G:/vivado2022.2/Vitis/2022.2/bin/xsct.bat`

```tcl
# 1. 连接 + PS 初始化
connect -url tcp:localhost:3121
targets -set -filter {name =~ "APU"}
catch {rst -system}
after 1000
source <xsa_extracted>/ps7_init.tcl
ps7_init; ps7_post_config

# 2. 烧录 PL (XSCT 烧录, 不用 Vivado Hardware Manager!)
fpga -f design_1_wrapper.bit

# 3. 下载 + 运行
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
dow app.elf
con
```

## 硬规则

### 1. 永远不用 Vivado Hardware Manager 烧录 FPGA

`program_hw_devices` 只烧 PL，不初始化 PS。后果：
- **ILA 不可见**：ILA 时钟来自 PS FCLK_CLK0，PS 未初始化 → FCLK 未运行 → ILA 不工作 → Vivado 报告 "ILAs found: 0"
- **DDR 不可用**：DDR 控制器需要 PS 初始化
- **覆盖 PS 状态**：如果 PS 已被 XSCT 初始化，Vivado 烧录会覆盖

**必须的流程**（Zynq PS-PL 联调）：
```tcl
# XSCT 端（全程管理 PS 和 PL）
connect -url tcp:localhost:3121
targets -set -filter {name =~ "APU"}
source ps7_init.tcl
ps7_init; ps7_post_config         # 先初始化 PS（启动 FCLK）
targets -set -filter {name =~ "FPGA"}
fpga -f design_1_wrapper.bit     # 再烧录 PL（Vivado 端 refresh_hw_device 即可看到 ILA）
```

> ⚠️ **TASK-E001-030 实战陷阱**：先用 Vivado `program_hw_devices` 烧录 PL，结果 ILA 完全看不到。
> 尝试 `refresh_hw_device` / `disconnect_hw_server` 都无效——根因是 PS 未初始化，FCLK 没有时钟输出。
> Vivado 端 `program_hw_devices` 只对纯 PL 设计有效。Zynq 必须 XSCT 先初始化 PS。

### 3. ILA 探针命名规则

**ILA 探针名 ≠ 信号名**。在 BD 中添加 ILA 时，探针的显示名称取决于连接方式：

| 连接方式 | 探针名称 | 可读性 |
|---------|---------|-------|
| 直连 wrapper 顶层端口 | `wrapper_2d_shift_0_m_axis_tlast` | 清晰 |
| 通过 interface net 间接连 | 取决于 BD 网表展开，可能丢失原名 | 差 |
| RTL 实例化 ILA（OOC） | `<const0>` / `<const1>` | 不可读 |

**规则**：NATIVE probe 必须直连 wrapper 的顶层单端端口（如 `m_axis_tdata[7:0]`），不经过 interface net。

### 4. BD ILA 创建（已验证的自动化方案）

不要用 `system_ila`（INTERFACE 模式在 Tcl 中对 AXIS 无效），用 `xilinx.com:ip:ila:6.2`：

```tcl
create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_accel
set_property -dict [list CONFIG.C_NUM_OF_PROBES {5} \
  CONFIG.C_PROBE0_WIDTH {32} CONFIG.C_PROBE1_WIDTH {8} \
  CONFIG.C_PROBE2_WIDTH {1} CONFIG.C_PROBE3_WIDTH {1} \
  CONFIG.C_PROBE4_WIDTH {1}] [get_bd_cells ila_accel]
connect_bd_net [get_bd_pins wrapper_2d_shift_0/dbg_port] [get_bd_pins ila_accel/probe0]
connect_bd_net [get_bd_pins wrapper_2d_shift_0/m_axis_tlast] [get_bd_pins ila_accel/probe3]
# ... 其余 probe
save_bd_design
generate_target all [get_files design_1.bd] -force  ;# 关键：生成嵌套 IP 的 .dcp
```

### 5. ILA Arm 时机（Zynq 平台关键）

**Zynq 的 CAPTURE 阶段可长达 51k+ cycle**（DMA 传输 + 延迟循环），ILA 环形缓冲仅 1024 sample。如果在 gate 释放前 arm ILA，CAPTURE 的空闲周期会把缓冲填满并覆盖，SHIFT 阶段的有效数据完全丢失。

**正确时序**：
```
1. CPU 运行到 gate（停止等待）
2. 释放 gate → CPU 启动 accelerator → CAPTURE 开始
3. 等待 CAPTURE 完成 + SHIFT 开始（约 51k cycles）
4. 然后 arm ILA（SHIFT 阶段有效数据开始到来）
5. ILA 触发 → 捕获 SHIFT 数据
```

**替代方案**（推荐）：使用 `dma_gated.c` 的软件 gate 机制，ILA trigger 设为 tlast=1。
ILA 在整个 CAPTURE 期间保持 armed（不触发，因为 tlast=0），SHIFT 开始后首次 tlast 触发捕获。

**关键反模式**：
- ❌ 先 arm ILA，再释放 gate → CAPTURE 覆盖缓冲
- ❌ 用 `-trigger_now` 抓"当前状态" → 99% 概率抓到 CAPTURE 空闲

### 2. ILA 触发条件配置

**标准 MCP Tcl 流程**（System ILA BASIC_ONLY）:
```tcl
# 设置触发: tvalid==1 AND tready==1 (AXI Stream handshake)
set_property TRIGGER_COMPARE_VALUE {eq1'b1} [lsearch -inline [get_hw_probes -of $ila] {*tvalid*}]
set_property TRIGGER_COMPARE_VALUE {eq1'b1} [lsearch -inline [get_hw_probes -of $ila] {*tready*}]
# 设置触发窗口位置（捕获更多 post-trigger 数据）
set_property CONTROL.TRIGGER_POSITION 16 $ila
# Arm ILA — 注意：不能加 -trigger 标志（被解释为 -trigger_now！）
run_hw_ila $ila
```

**TRIGGER_COMPARE_VALUE 位宽规则**：
compare_value 的位宽必须与 probe WIDTH 严格匹配，否则 Vivado 报错 "wrong bit count"。

| Probe 位宽 | 正确写法 | 错误写法 |
|-----------|---------|---------|
| 1-bit | `eq1'b1` / `eq1'b0` / `eq1'bX` | `eq32'bX` |
| 8-bit | `eq8'hXX` | `eq1'bX` |
| 32-bit | `eq32'hXXXXXXXX` | `eq1'bX` |

```tcl
# 检查 probe 位宽
get_property WIDTH [get_hw_probes -of $ila -filter {NAME =~ "*tdata*"}]

# 常见错误：给 1-bit tvalid 设 eq32'h00000001
# ✗ set_property TRIGGER_COMPARE_VALUE {eq32'h00000001} $tvalid_probe
# ✓ set_property TRIGGER_COMPARE_VALUE {eq1'b1} $tvalid_probe
```

**关键陷阱 — `-trigger` = `-trigger_now`**：
Vivado Tcl 支持部分标志匹配。`run_hw_ila` 的唯一以 `trigger` 开头的标志是 `-trigger_now`（立即触发，忽略所有触发条件）。`run_hw_ila $ila -trigger` 实际执行的是 `run_hw_ila $ila -trigger_now`，导致 ILA 在 arm 瞬间立即触发。

```tcl
# ✗ 错误：-trigger 被部分匹配为 -trigger_now
run_hw_ila $ila -trigger

# ✓ 正确：不加标志，等待触发条件满足
run_hw_ila $ila
```

**don't_care 格式**：
```tcl
# ✗ 无效：don't_care 静默失败
# ✓ 正确：
set_property TRIGGER_COMPARE_VALUE {eq1'bX} $probe          # 单bit
set_property TRIGGER_COMPARE_VALUE {eq32'hXXXX_XXXX} $probe  # 32bit
```

**TRIG_IN_ONLY 模式**（RTL ILA，参考 `board/ila_cross_trigger.tcl`）：
```tcl
set_property CONTROL.TRIGGER_MODE TRIG_IN_ONLY $ila
run_hw_ila $ila
# PL anchor event → dbg_trigger_hub → ILA TRIG_IN
```

### 3. 软件 Gate 实现 CPU-ILA 同步
```c
// C 代码: CPU 在 gate 处无限等待
*GATE = 0;
Xil_DCacheFlushRange((UINTPTR)GATE, 4);
while (*GATE == 0) {
    Xil_DCacheInvalidateRange((UINTPTR)GATE, 4);
}
// gate 释放后才启动 DMA
```

```tcl
# Tcl 侧: arm ILA → 释放 gate → DMA 精准捕获
# 1. XSCT: dow gate_test.elf; con → CPU 跑到 gate 停下, stop CPU
# 2. Vivado MCP: 配置 ILA → run_hw_ila → WAITING FOR TRIGGER
# 3. XSCT: mwr GATE=1; con  ← 必须先 con 恢复 CPU! CPU 在 step 1 末尾处于 debug halt
```

**Gate 释放 Tcl 脚本的正确写法**：
```tcl
connect -url tcp:localhost:3121
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
mwr -force 0x00300100 1           # 写 GATE=1 到 DDR
con                                # 恢复 CPU（Phase 1 末尾 stop 导致 CPU 处于 debug halt）
after 35000                        # 等待 DMA 测试完成
catch {stop}                       # CPU 可能已自行停止（测试结束），用 catch 避免脚本中断
# 读结果寄存器...
```

**为什么 `con` 必不可少**：Phase 1 末尾 `stop` 使 CPU 进入 debug halt 状态。`mwr` 只写 DDR 内存，CPU 不执行指令，无法看到 GATE 变化。必须先 `con` 恢复执行，CPU 才能跳出 while 循环。

Gate 机制弥补了 ILA 深度不足（1024 @ 50MHz = 20μs）的问题。CPU 可以等任意长时间，ILA 只在 DMA 活跃的瞬间触发。

### 4. DMA 复位：硬件自清除，不能手写 0
```c
// 正确: 只写 RESET=1, 等硬件清除
*(volatile u32*)(DMA_BASE) = 4;  // RESET bit
while (!(*(volatile u32*)(DMA_BASE + 4) & 1));  // 等待 Halted=1

// 错误: 写 4 后立即写 0 — 打断硬件复位时序
```

## Vitis 工程标准流程

### 从 XSA 生成 BSP
```tcl
hsi open_hw_design design_1_wrapper.xsa
hsi generate_bsp -dir bsp_dir -proc ps7_cortexa9_0 -os standalone -compile
```

### 提取 ps7_init + bitstream
```bash
unzip design_1_wrapper.xsa "ps7_init.tcl" "design_1_wrapper.bit"
```

### 编译 DMA 测试
```bash
arm-none-eabi-gcc -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard \
  -I<bsp>/include -c -o test.o test.c
arm-none-eabi-gcc ... -nostartfiles -T lscript.ld \
  -L<bsp>/lib -o test.elf test.o stubs.o \
  -Wl,--start-group,-lxil,-lc,-lgcc,--end-group
```

stubs.c 需要提供 `_init` 和 `_fini` 空函数解决链接依赖。

### 使用 XAxiDma 驱动
标准 XAxiDma API（非裸机 poke）：
```c
XAxiDma_CfgInitialize(&dma, cfg);          // 2 参数, 不是 3
XAxiDma_Reset(&dma);                       // void 返回, 不是 int
while (!XAxiDma_ResetIsDone(&dma));
XAxiDma_SimpleTransfer(&dma, buf, len, XAXIDMA_DEVICE_TO_DMA);
XAxiDma_IntrGetIrq(&dma, XAXIDMA_DEVICE_TO_DMA);  // 不是 IntrGetStatus
XAxiDma_IntrAckIrq(&dma, s, XAXIDMA_DEVICE_TO_DMA); // 不是 IntrClear
```

不同 BSP 版本 API 有差异，**以 `<bsp>/include/xaxidma.h` 声明为准**。

## 常见死胡同（不要重蹈覆辙）

| 死胡同 | 为什么是死胡同 | 正解 |
|--------|--------------|------|
| 追 AFI 寄存器 (0xF8000860) | Zynq-7000 上只读, ps7_init 不配是设计行为 | 不是 DMA 不通的根因 |
| Vivado 烧录 PS | 覆盖 PS 状态, PL 时钟丢失 | XSCT 全程管理 |
| 反复改 C 代码加 dump | 手工 dump 不如 ILA 直接看波形 | 先用 ILA 定位, 再改代码 |
| 假设 Vitis GUI 能通 | 未经验证的前提 | 先在 CLI 跑通, 再对比 |
| 裸机寄存器 poke DMA | 复位时序、状态机容易出错 | 用标准 XAxiDma 驱动 |

## 调试优先级

1. **ILA 看 stream** → 确认数据是否到达 (tvalid/tready/tdata/tlast)
2. **ILA 看两侧** → 输入侧和输出侧分别触发，确认断点在哪
3. **AXI-Lite 读 STATUS** → 确认 FSM 状态
4. **DMA 寄存器 dump** → 确认 DMASR/IOC 状态
5. **改 C 代码** → 最后的诊断手段

## ILA 数据分析要点

- 触发前样本 (pre-trigger): IDLE 状态，验证初始条件
- 触发点 (TRIGGER=1): 握手发生的精确时刻
- 触发后样本: 有效数据流，关注 tdata 值、tlast 位置、tkeep 完整性
- ILA 深度有限 (1024 @ 50MHz = 20μs)，长传输用 gate 截取关键窗口

## Vivado HW Manager ↔ XSDB JTAG 调度

hw_server 同时接受 Vivado 和 XSDB 连接，但以下操作需要显式刷新：

```
# Vivado 侧——每次 XSDB fpga -f 之后必须：
close_hw_target
open_hw_target
refresh_hw_device [get_hw_devices]
# 此时 ILA 才会重新出现

# 如果 ILA 消失（Xicom 50-38 错误）：
disconnect_hw_server
connect_hw_server -url localhost:3121
open_hw_target
refresh_hw_device [get_hw_devices]
```

### ILA 探针文件 (.ltx) 陷阱 ⚠️

**TASK-E001-030 实战发现**：实现生成 `debug_nets.ltx`（ILA probe 定义文件）后，
Vivado Hardware Manager **不会自动加载**。即使 bitstream 已烧录且 ILA 核存在于硬件中，
没有 probes file 关联 → `get_hw_ilas` 返回 0。

```tcl
# ✗ 错误：烧录后不关联 ltx → ILA 不可见
program_hw_devices $fpga_dev
get_hw_ilas  # 返回 0 或 4（不匹配）

# ✓ 正确：烧录后关联 ltx 并刷新
set_property PROBES.FILE {<impl_dir>/debug_nets.ltx} $fpga_dev
refresh_hw_device $fpga_dev
get_hw_ilas  # 返回 4，probes 完整
```

**根本原因**：`debug_nets.ltx` 在综合/实现时生成，包含 ILA probe 的名称、宽度和
与硬件信号的映射。没有它，Vivado 只能看到 ILA 核的存在（"4 ILA core(s)"），
但不知道探针名称和信号对应关系，因此无法交互。

**检查清单**：
- [ ] 确认 `debug_nets.ltx` 与 bitstream 来自同一次实现（`impl_1/` 目录）
- [ ] XSCT 烧录 FPGA 后，Vivado 端执行 `refresh_hw_device` + 关联 `PROBES.FILE`
- [ ] `get_hw_ilas` 返回非零且 `get_hw_probes` 包含预期信号名

## 相关 Skills

- `fpga-vitis-cli-build` — Vitis CLI 编译和 XSCT 下载
- `fpga-bd-debug-clock` — ILA 时钟域和 debug hub 诊断
- `fpga-board-validation` — L5/L6 上板验证流程
- `fpga-iteration-economics` — 理解"先看 ILA vs 改代码"的成本差异
- `fpga-official-doc-first` — BSP API 和 IP 文档查阅规则
- `fpga-hw-pin-verify` — 引脚交叉验证

## 语言策略

- 工具链操作/脚本：en
- 原则说明：zh
