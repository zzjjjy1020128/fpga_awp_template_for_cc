# 硬件基座规格书

> 版本：HW_BASE_v1.0-draft
> 日期：2026-06-07
> 目标器件：xc7z020clg400-1 (Zynq-7000)
> 关联决策：AWP-0001 平台层冻结策略
> 前置文档：`architecture_v2_block_design.md`

---

## 1. 设计哲学

硬件基座是一个**冻结的、可直接打开使用的 Vivado 工程**，不是一套"每次重新生成的 Tcl 脚本"。它提供标准加速器插槽，custom IP 通过插槽接入。

核心原则：

- **基座是 Vivado 工程目录**——`.xpr` + `.srcs/` + BD `.bd` 文件是主 artifact，可直接打开、综合、实现
- **Tcl 导出仅为参考**——用于版本 diff review 和灾难恢复，不作为自动化构建手段（Vivado 2022.2 对 PS7 BD 的 Tcl 重建不可靠，SESS-E001-OR-002 已验证）
- **约束与 BD 共同构成基座**——时钟、引脚、时序例外都属于基座
- **accelerator 通过标准插槽接入**——无需修改基座

---

## 2. 基座 Artifact 清单

```
vivado/hw_base/                          ← 基座 Vivado 工程（主 artifact）
  hw_base.xpr                            ← 工程文件
  hw_base.srcs/
    sources_1/bd/hw_base/hw_base.bd      ← Block Design（XML，权威）
    sources_1/bd/hw_base/hw_base_wrapper.v ← HDL Wrapper（自动生成）
    constrs_1/                           ← 约束文件引用
  hw_base.runs/                          ← 综合/实现 run 数据

vivado/hw_base/bd_export/                ← BD 导出（参考用）
  hw_base_bd.tcl                         ← write_bd_tcl 导出
  hw_base_bd.pdf                         ← BD 框图

vivado/ip/axil_2d_shift_v1_0/            ← accelerator IP（基座配套）
  component.xml

constraints/                             ← 约束文件（独立管理，可 diff review）
  base_timing.xdc                        ← [基座级] 时钟 + 基座内部时序例外
  base_physical.xdc                      ← [基座级] 可选 PL 外部引脚（当前为空）
  debug.xdc                              ← [调试] ILA probe + mark_debug
```

**哪部分是"基座"、哪部分是"项目"**：

| 文件 | 层级 | 冻结？ | 修改条件 |
|------|------|:--:|------|
| `vivado/hw_base/` 工程目录 | 基座 | 是 | 平台级需求变化 |
| `hw_base.bd` (BD) | 基座 | 是 | 平台级需求变化 |
| `hw_base_bd.tcl` (导出) | 基座 | 是 | 随 BD 更新 |
| `constraints/base_timing.xdc` | 基座 | 是 | 时钟方案变更 |
| `constraints/base_physical.xdc` | 基座 | 是 | 板级引脚变更 |
| `vivado/ip/axil_2d_shift_v1_0/` | accelerator | 否 | RTL 迭代时重新打包 |
| `constraints/debug.xdc` | 调试 | 否 | 调试需求变化 |
| `constraints/accel_timing.xdc` | 项目 | 否 | accelerator 特定需求 |

---

## 3. Accelerator 接口契约

基座提供 **4 个标准插槽**。任何 accelerator 只需匹配此接口即可接入。

### SLOT_AXIL —— AXI4-Lite Slave（控制总线）

| 属性 | 值 |
|------|-----|
| 协议 | AXI4-Lite (aximm:1.0) |
| 地址位宽 | 32 bit |
| 数据位宽 | 32 bit |
| 时钟 | FCLK_CLK0 (100 MHz) |
| 连接 | AXI Interconnect M00_AXI → accelerator S_AXI |

**accelerator 必须实现的端口**：

| 端口名 | 方向 (accel视角) | 位宽 |
|--------|:---:|------|
| s_axil_awaddr | input | [31:0] |
| s_axil_awvalid | input | 1 |
| s_axil_awready | output | 1 |
| s_axil_wdata | input | [31:0] |
| s_axil_wstrb | input | [3:0] |
| s_axil_wvalid | input | 1 |
| s_axil_wready | output | 1 |
| s_axil_bresp | output | [1:0] |
| s_axil_bvalid | output | 1 |
| s_axil_bready | input | 1 |
| s_axil_araddr | input | [31:0] |
| s_axil_arvalid | input | 1 |
| s_axil_arready | output | 1 |
| s_axil_rdata | output | [31:0] |
| s_axil_rresp | output | [1:0] |
| s_axil_rvalid | output | 1 |
| s_axil_rready | input | 1 |

### SLOT_AXIS_I —— AXI4-Stream Slave（数据输入）

| 属性 | 值 |
|------|-----|
| 协议 | AXI4-Stream (axis:1.0) |
| 数据位宽 | 8 bit |
| 时钟 | FCLK_CLK0 (100 MHz) |
| 来源 | AXI DMA M_AXIS_MM2S → accelerator S_AXIS |

**accelerator 必须实现的端口**：

| 端口名 | 方向 (accel视角) | 位宽 |
|--------|:---:|------|
| s_axis_tdata | input | [7:0] |
| s_axis_tvalid | input | 1 |
| s_axis_tready | output | 1 |
| s_axis_tlast | input | 1 |
| s_axis_tuser | input | 1 |

### SLOT_AXIS_O —— AXI4-Stream Master（数据输出）

| 属性 | 值 |
|------|-----|
| 协议 | AXI4-Stream (axis:1.0) |
| 数据位宽 | 8 bit |
| 时钟 | FCLK_CLK0 (100 MHz) |
| 连接 | accelerator M_AXIS → AXI DMA S_AXIS_S2MM |

**accelerator 必须实现的端口**：

| 端口名 | 方向 (accel视角) | 位宽 |
|--------|:---:|------|
| m_axis_tdata | output | [7:0] |
| m_axis_tvalid | output | 1 |
| m_axis_tready | input | 1 |
| m_axis_tlast | output | 1 |
| m_axis_tuser | output | 1 |

### SLOT_IRQ —— 中断信号

| 属性 | 值 |
|------|-----|
| 类型 | 单线，电平敏感，高有效 |
| 时钟 | FCLK_CLK0 (100 MHz) |
| 连接 | accelerator irq → PS IRQ_F2P[0] |

**当前连接**：AXI DMA s2mm_introut → PS IRQ_F2P[0]。若 accelerator 需要独立中断，可修改基座连接（属于平台级变更）。

### 时钟与复位（全局）

| 信号 | 来源 | 连接方式 |
|------|------|---------|
| clk (100 MHz) | PS7 FCLK_CLK0 | BD 内部自动分发（所有 IP 同一时钟域） |
| rstn (active low) | proc_sys_reset peripheral_aresetn | BD 内部自动分发 |

> accelerator 模块内部如需独立复位域，由 accelerator 自行处理；基座不提供额外的复位。

---

## 4. Block Design 拓扑

### 4.1 组件清单

| 序号 | IP 核 | VLNV | 数量 | 用途 |
|------|-------|------|:--:|------|
| 1 | Zynq7 Processing System | xilinx.com:ip:processing_system7:5.5 | 1 | PS 核心 |
| 2 | AXI Interconnect | xilinx.com:ip:axi_interconnect:2.1 | 1 | GP 控制总线 (1:2) |
| 3 | AXI SmartConnect | xilinx.com:ip:smartconnect:1.0 | 1 | HP 数据总线 (2:1) |
| 4 | AXI DMA | xilinx.com:ip:axi_dma:7.1 | 1 | Stream ↔ DDR 引擎 |
| 5 | Processor System Reset | xilinx.com:ip:proc_sys_reset:5.0 | 1 | 同步复位 |
| 6 | ILA | xilinx.com:ip:ila:6.2 | 2 | 调试核 |
| 7 | **axil_2d_shift_v1_0** | awp:user:axil_2d_shift:1.0 | 1 | **accelerator（本项目）** |

### 4.2 连接拓扑（信号流）

```
PS7
 ├─ M_AXI_GP0 ────→ AXI Interconnect S00_AXI
 │                   ├─ M00_AXI → SLOT_AXIL → accelerator s_axil
 │                   └─ M01_AXI → AXI DMA S_AXI_LITE
 │
 ├─ S_AXI_HP0 ←──── AXI SmartConnect M00_AXI
 │                   ├─ S00_AXI ← AXI DMA M_AXI_MM2S
 │                   └─ S01_AXI ← AXI DMA M_AXI_S2MM
 │
 ├─ FCLK_CLK0 ────→ 所有 IP 的时钟输入
 ├─ FCLK_RESET0_N → proc_sys_reset ext_reset_in
 │
 └─ IRQ_F2P[0] ←── AXI DMA s2mm_introut

AXI DMA
 ├─ M_AXIS_MM2S ──→ SLOT_AXIS_I → accelerator s_axis
 └─ S_AXIS_S2MM ←── SLOT_AXIS_O → accelerator m_axis

proc_sys_reset
 └─ peripheral_aresetn → 所有 IP 的复位（通过 BD 自动连接）
```

### 4.3 ILA 探针连接

| ILA 核 | 探针 | 宽度 | 信号 |
|--------|------|:--:|------|
| ila_capture | probe0-probe8 | 27 | 见 architecture_v2_block_design.md §5.2 |
| ila_shift | probe0-probe9 | 29 | 见 architecture_v2_block_design.md §5.3 |

ILA 探针通过 `mark_debug` 属性在 RTL 中标记，综合后自动连接。若使用 BD wrapper 方案，可直接在 BD 中连线。

### 4.4 地址映射

| 外设 | 基地址 | 范围 | 说明 |
|------|--------|------|------|
| axil_2d_shift (SLOT_AXIL) | 0x43C0_0000 | 64 KB | AXI Interconnect M00 → accelerator |
| AXI DMA S_AXI_LITE | 0x43C1_0000 | 64 KB | AXI Interconnect M01 → DMA |

> 地址由 Vivado Address Editor 自动分配。以上为典型值，以 `assign_bd_address` 实际结果为准。

---

## 5. 约束文件分层

### 5.1 base_timing.xdc（基座级，冻结）

```tcl
#==============================================================================
# base_timing.xdc —— 硬件基座 v1.0 时序约束
# 范围：基座级时钟定义 + 基座内部时序例外
# 修改条件：平台时钟方案变更
#==============================================================================

# --- 主时钟（来自 PS7 FCLK_CLK0） ---
create_clock -period 10.000 -name pl_clk0 [get_pins processing_system7_0/inst/FCLK_CLK0]

# --- 生成时钟（如有 MMCM/PLL 则在对应 IP 的自动约束中处理） ---
# 基座 v1.0 不使用 MMCM/PLL，所有逻辑运行在 FCLK_CLK0 域

# --- 基座内部时序例外 ---
# proc_sys_reset 异步复位 —— 不做 false_path，Vivado 自动处理 async reset 路径
# AXI Interconnect / SmartConnect 的 CDC 由 IP 内部自动处理

# --- 外部 I/O 约束 ---
# 本基座无外部 PL IOB，不需要 input/output delay
```

### 5.2 base_physical.xdc（基座级，冻结）

```tcl
#==============================================================================
# base_physical.xdc —— 硬件基座 v1.0 物理约束
# 当前为空（无 PL 外部引脚）。如有 LED/按钮需求在此添加。
#==============================================================================

# --- 全局 IO 标准（占位） ---
# 如需在特定板上引出调试信号，添加 PACKAGE_PIN + IOSTANDARD 约束
# 例：set_property PACKAGE_PIN W5 [get_ports debug_led]
#     set_property IOSTANDARD LVCMOS33 [get_ports debug_led]
```

### 5.3 debug.xdc（调试，可修改）

```tcl
#==============================================================================
# debug.xdc —— 调试约束（ILA + mark_debug）
# 范围：ILA 探针连接、mark_debug 属性
# 修改条件：调试需求变化
# 生产比特流：删除此文件即可移除所有调试逻辑
#==============================================================================

# ILA 核时钟连接（BD 中自动处理，此处仅做声明）
# mark_debug 属性在 RTL 中通过 (* mark_debug = "true" *) 标记

# 如需在约束文件中标记特定信号：
# set_property mark_debug true [get_nets {u_ctrl_fsm/state_reg[*]}]
```

### 5.4 约束文件组装规则

Vivado 工程中约束文件的处理顺序：

```
1. base_timing.xdc      ← 最先（时钟定义必须在其他约束之前）
2. base_physical.xdc    ← 其次（引脚约束）
3. accel_timing.xdc     ← accelerator 专属时序（如有）
4. debug.xdc            ← 最后（调试，不影响时序）
```

> Vivado 按文件列表顺序处理约束，后添加的约束可覆盖先前的。将 `base_timing.xdc` 放在最前面确保时钟先定义。

---

## 6. 基座创建流程

### 6.1 前置条件

- [ ] Vivado 2022.2 已安装
- [ ] 本 repo 已 clone，当前在 `exp/E001` 分支
- [ ] IP 打包已完成（TASK-E001-017 done，IP 在 `vivado/ip/axil_2d_shift_v1_0/`）

### 6.2 步骤

#### 第 1 步：创建 Vivado 工程

```
操作: File → New Project
  Project name: hw_base
  Project location: <repo_root>/vivado/hw_base
  Project type: RTL Project (勾选 "Do not specify sources at this time")
  Part: xc7z020clg400-1 (Zynq-7000, CLG400 package, speed -1)
```

完成后：关闭自动打开的 "Add Sources" 对话框。

#### 第 2 步：配置 IP Repository

```
操作: Tools → Settings → IP → Repository
  点击 "+" 添加路径: <repo_root>/vivado/ip
  点击 "Refresh All"
  确认 axil_2d_shift_v1_0 出现在 IP Catalog 中
```

#### 第 3 步：创建 Block Design

```
操作: Flow Navigator → IP Integrator → Create Block Design
  Design name: hw_base
  OK
```

#### 第 4 步：添加 Zynq7 Processing System

```
操作: 在 BD 画布中右键 → Add IP → 搜索 "zynq"
  双击 "ZYNQ7 Processing System" 添加
  点击画布上方绿色提示栏的 "Run Block Automation"
  在弹出的对话框中直接点击 OK（使用默认配置）
```

**双击 PS7 核，按以下配置修改**：

```
Page: PS-PL Configuration → AXI Non Secure Enablement → GP Master AXI Interface
  ☑ M AXI GP0 interface

Page: PS-PL Configuration → AXI Non Secure Enablement → HP Slave AXI Interface
  ☑ S AXI HP0 interface
  S AXI HP0 Data Width: 64-bit

Page: Clock Configuration → PL Fabric Clocks
  ☑ FCLK_CLK0
  Requested Frequency: 100.000 MHz

Page: Peripheral IO Pins
  ☑ UART 1 (MIO 48..49)

Page: Interrupts → Fabric Interrupts
  ☑ IRQ_F2P[0:0]

Page: DDR Configuration → DDR Controller Configuration
  Memory Part: MT41K256M16RE-15E (或兼容的 DDR3 器件)
  (通常在 Run Block Automation 时已自动配置)

点击 OK
```

#### 第 5 步：添加 AXI Interconnect（控制通路）

```
操作: Add IP → 搜索 "axi interconnect"
  双击 "AXI Interconnect" 添加

配置（双击 IP → 在 Block Properties 或 Re-customize 中修改）:
  Number of Slave Interfaces: 1
  Number of Master Interfaces: 2
    注意: 这是 S_AXI + M_AXI 的数量，不是 MI 端口数。
    在 Re-customize IP 窗口的 "Top Level Settings" 标签中设置 NUM_MI = 2, NUM_SI = 1
```

**连接**：

```
点击 PS7 的 M_AXI_GP0 端口 → 拖动到 AXI Interconnect 的 S00_AXI 端口
→ 选择 "Connect"
```

**连接时钟**：

```
将 PS7 的 FCLK_CLK0 连接到:
  - AXI Interconnect 的 ACLK 端口
  - AXI Interconnect 的 S00_ACLK 端口
  - AXI Interconnect 的 M00_ACLK 端口
  - AXI Interconnect 的 M01_ACLK 端口
  
(每个 ACLK 端口点击后连接到 FCLK_CLK0)
```

#### 第 6 步：添加 Processor System Reset

```
操作: Add IP → 搜索 "proc_sys_reset"
  双击 "Processor System Reset" 添加
  右键 IP → Run Connection Automation → 选择 proc_sys_reset_0 → OK
  (Vivado 自动连接 FCLK_CLK0 + ext_reset_in ← FCLK_RESET0_N)
```

#### 第 7 步：添加 AXI DMA

```
操作: Add IP → 搜索 "axi dma"
  双击 "AXI Direct Memory Access" 添加

配置 (Re-customize IP):
  ☑ Enable Read Channel
  ☑ Enable Write Channel
  Memory Map Data Width: 32
  Stream Data Width: 8 (for both MM2S and S2MM)
  Max Burst Size: 16
  Width of Buffer Length Register: 23
  ☐ Enable Scatter Gather (取消勾选)
  ☐ Enable Micro DMA (取消勾选)
  ☐ Enable Control/Status Stream (取消勾选)
```

**连接**：

```
AXI DMA 时钟:
  FCLK_CLK0 → axi_dma_0/s_axi_lite_aclk
  FCLK_CLK0 → axi_dma_0/m_axi_mm2s_aclk
  FCLK_CLK0 → axi_dma_0/m_axi_s2mm_aclk

AXI DMA 复位:
  proc_sys_reset/peripheral_aresetn → axi_dma_0/axi_resetn

控制接口:
  AXI Interconnect M01_AXI → axi_dma_0/S_AXI_LITE
  (右键 S_AXI_LITE → Connect → 选择 M01_AXI)

中断:
  axi_dma_0/s2mm_introut → PS7 IRQ_F2P[0:0]
```

#### 第 8 步：添加 AXI SmartConnect（数据通路）

```
操作: Add IP → 搜索 "smartconnect"
  双击 "AXI SmartConnect" 添加

配置 (Re-customize IP):
  Number of Slave Interfaces: 2
  Number of Master Interfaces: 1
```

**连接**：

```
SmartConnect 时钟:
  FCLK_CLK0 → axi_smc/aclk
  FCLK_CLK0 → axi_smc/S00_ACLK
  FCLK_CLK0 → axi_smc/S01_ACLK
  FCLK_CLK0 → axi_smc/M00_ACLK

数据通路连接:
  axi_dma_0/M_AXI_MM2S → axi_smc/S00_AXI
  axi_dma_0/M_AXI_S2MM → axi_smc/S01_AXI
  axi_smc/M00_AXI → PS7 S_AXI_HP0

SmartConnect 复位:
  proc_sys_reset/peripheral_aresetn → axi_smc/aresetn
```

#### 第 9 步：添加 axil_2d_shift accelerator IP

```
操作: Add IP → 搜索 "axil_2d_shift"
  双击 "axil_2d_shift_v1_0" 添加

连接:
  AXI Interconnect M00_AXI → axil_2d_shift_0/s_axil
  axi_dma_0/M_AXIS_MM2S → axil_2d_shift_0/s_axis
  axil_2d_shift_0/m_axis → axi_dma_0/S_AXIS_S2MM

时钟 + 复位:
  FCLK_CLK0 → axil_2d_shift_0/clk
  proc_sys_reset/peripheral_aresetn → axil_2d_shift_0/rstn
```

#### 第 10 步：添加 ILA 核（2 个）

```
操作: Add IP → 搜索 "ila"
  双击 "ILA (Integrated Logic Analyzer)" 添加

ILA 0 (ila_capture) 配置:
  Component Name: ila_capture
  Number of Probes: 9
  Probe Widths: 8,1,1,1,1,1,1,12,1
  Sample Data Depth: 1024
  ☐ Enable Trigger In
  ☐ Enable Trigger Out

ILA 1 (ila_shift) 配置:
  Component Name: ila_shift
  Number of Probes: 10
  Probe Widths: 8,1,1,1,1,1,1,1,12,2
  Sample Data Depth: 1024

时钟连接:
  FCLK_CLK0 → ila_capture/clk
  FCLK_CLK0 → ila_shift/clk

ILA 探针连接: 参见 architecture_v2_block_design.md §5.2-5.3
  当前通过 mark_debug 属性在 RTL 中标记，综合后自动连接。
  如需在 BD 中直接连线，需 accelerator 引出调试端口。
```

#### 第 11 步：地址分配

```
操作: 点击画布上方绿色提示栏 "Run Connection Automation" (如有遗留)
  然后: BD 窗口上方 → Address Editor 标签
  点击右上角 "Assign All" 图标 (自动分配地址)
  确认:
    axil_2d_shift_0/s_axil → 0x43C0_0000 范围
    axi_dma_0/S_AXI_LITE   → 0x43C1_0000 范围
```

#### 第 12 步：验证 BD + 生成 Wrapper

```
操作: 在 BD 画布中右键 → Validate Design (或按 F6)
  确认弹出对话框显示 "Validation Successful" (0 errors)

操作: 在 Sources 面板中右键 hw_base.bd → Create HDL Wrapper
  选择 "Let Vivado manage wrapper and auto-update"
  OK
```

**⚠️ 关键点**：如果 `Create HDL Wrapper` 报错（Vivado 2022.2 已知问题），尝试：
1. 先点 `File → Save Project`
2. 关闭 Vivado 再重新打开
3. 打开 BD 后重试

若仍然失败，记录错误信息，这属于平台基座创建中需要人工排查的问题。

#### 第 13 步：添加约束文件

```
操作: Flow Navigator → Add Sources → Add or Create Constraints
  添加文件: constraints/base_timing.xdc
  添加文件: constraints/base_physical.xdc
  添加文件: constraints/debug.xdc

在 Sources 面板 Constrains 中确认文件顺序:
  base_timing.xdc 在最前
```

#### 第 14 步：运行综合

```
操作: Flow Navigator → Run Synthesis
  或通过 Tcl Console: launch_runs synth_1 -jobs 4

验收:
  - 0 Errors
  - 0 Critical Warnings
  - 资源利用率合理（LUT < 10%, BRAM < 10%）
```

#### 第 15 步：运行实现

```
操作: Flow Navigator → Run Implementation
  或通过 Tcl Console: launch_runs impl_1 -jobs 4

验收:
  - 0 Errors
  - WNS >= 0 ns, WHS >= 0 ns
  - 无 route conflict
```

#### 第 16 步：导出 + 冻结

```
操作:
  Tcl Console 中执行:
    write_bd_tcl vivado/hw_base/bd_export/hw_base_bd.tcl
    write_bd_layout -format pdf vivado/hw_base/bd_export/hw_base_bd.pdf

保存工程:
  File → Save Project
  File → Close Project
```

工程目录 `vivado/hw_base/` 现在是 HW_BASE_v1.0。

---

## 7. 基座验证清单

创建完成后，按以下清单验证基座完整性：

| # | 检查项 | 方法 | 预期结果 |
|---|--------|------|---------|
| 1 | BD Validate | F6 在 BD 窗口中 | 0 errors |
| 2 | HDL Wrapper 生成 | Sources 面板 | wrapper.v 存在 |
| 3 | 综合 | Run Synthesis | 0 errors, 0 critical warnings |
| 4 | 实现 | Run Implementation | WNS >= 0, WHS >= 0 |
| 5 | 地址分配无冲突 | Address Editor | 无红色警告标记 |
| 6 | IP Catalog 可找到 accelerator | 在 BD 中 Add IP 搜索 | axil_2d_shift_v1_0 出现 |
| 7 | ILA 核已正确配置 | 打开各 ILA 的 Re-customize | probe 数量和宽度正确 |
| 8 | 时钟全部连接 | BD 画布 | 无未连接的 ACLK 端口 |
| 9 | 复位全部连接 | BD 画布 | 无未连接的 aresetn 端口 |
| 10 | BD Tcl 导出可读 | 文本编辑器打开 .tcl | 无乱码，结构完整 |

---

## 8. 基座版本管理

### 8.1 版本号规则

```
HW_BASE_v<major>.<minor>

major: BD 拓扑变更、IP 版本升级、接口契约变更
minor: 约束更新、非破坏性参数调整、ILA 配置变更
```

### 8.2 升版触发条件

| 变更 | 升版 |
|------|:--:|
| PS7 配置变更（新增/禁用外设） | major |
| AXI Interconnect 主端口数变化 | major |
| DMA 数据位宽变更 | major |
| 时钟方案变更（频率、PLL 引入） | major |
| 标准插槽端口变更 | major |
| base_timing.xdc 约束调整 | minor |
| ILA 探针数量/宽度调整 | minor |
| 调试约束修改 | minor |
| accelerator RTL 迭代（重新打包 IP） | 不改基座版本 |
| 新增/替换 accelerator | 不改基座版本 |

### 8.3 Changelog

在 `vivado/hw_base/CHANGELOG.md` 中记录每次基座变更：

```markdown
# HW_BASE Changelog

## v1.0 (2026-06-07)
- 初始版本
- PS7 + AXI Interconnect (1:2) + AXI DMA (8-bit) + SmartConnect (2:1) + ILA x2
- 目标器件: xc7z020clg400-1
- 综合 PASS: 0 errors, 0 critical warnings
- 实现 PASS: WNS >= 0 ns
```

---

## 9. 冻结协议

基座一旦标记为冻结版本（如 `HW_BASE_v1.0`）：

1. **BD 不可在 GUI 中修改**——任何改动需在 Changelog 中记录并升版
2. **约束文件 (base_*.xdc) 通过 PR review 修改**——不在 Vivado GUI 中直接编辑
3. **新 accelerator 接入不触发基座变更**——只添加 IP/连接接口，不动已有配置
4. **基座工程目录纳入版本控制**——`.xpr` + `.srcs/` 通过 Git 追踪（大文件用 Git LFS）
5. **BD Tcl 导出随基座版本更新**——每次冻结时重新导出

---

## 10. 灾难恢复

若 `vivado/hw_base/` 工程损坏：

1. 从 Git 恢复工程目录
2. 在 Vivado 中 `Open Project` 直接打开
3. 若工程无法打开：新建空工程 → 使用 `source hw_base_bd.tcl`（最后手段，已知在 PS7 场景可能失败）
4. 若 Tcl 重建失败：按本 §6 流程在 GUI 中重建（使用相同的 IP 版本和参数）

**这解释了为什么基座是工程目录而非 Tcl 脚本**——Tcl 重建不可靠，工程目录是唯一可靠的恢复手段。

---

## 附录 A：BD Tcl 导出参考

创建完成后，在 Vivado Tcl Console 中执行以下命令导出：

```tcl
# 导出 BD 为 Tcl 脚本（供 diff review + 灾难恢复参考）
write_bd_tcl -force vivado/hw_base/bd_export/hw_base_bd.tcl

# 导出 BD 框图为 PDF
write_bd_layout -format pdf vivado/hw_base/bd_export/hw_base_bd.pdf
```

导出的 `.tcl` 文件可纳入 Git 版本控制，用于：
- 基座版本间 diff 对比（确认"此次基座变更改了什么"）
- 灾难恢复的最后手段（已知局限性：PS7 BD Tcl 重建在 Vivado 2022.2 中可能失败）

**不可**将此 Tcl 作为 CI 自动化脚本来"每次从头生成 BD"。
