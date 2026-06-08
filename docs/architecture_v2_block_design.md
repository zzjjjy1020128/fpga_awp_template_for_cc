# Block Design 架构：Zynq PS7 + axil_2d_shift

> 设计日期：2026-06-06
> 目标器件：xc7z020clg400-1 (Zynq-7000)
> 前置文档：`docs/architecture.md`（原 PL-only 架构）、`docs/retrospective_iob_decision_failure.md`
> 设计目的：将 axil_2d_shift 从 102 外部 IOB 架构重构为 Zynq Block Design，利用 PS AXI 接口和内部 ILA 调试，消除外部引脚瓶颈
> 相关决策：AWP-0001 平台层冻结策略

---

## 0. 平台分层策略

本 Block Design 采用**稳定平台 BD + 标准插槽 + wrapper/adapter**的分层架构：

```
┌──────────────────────────────────────────┐
│  平台 BD (frozen shell) — v1.0            │  ← 仅平台级需求变化时修改
│  PS7 + AXI Interconnect + DMA + ILA       │
│                                           │
│  标准插槽 (slots):                         │
│   SLOT_AXIL:  S_AXI (AXI-Lite, 32-bit)    │  ← AXI Interconnect M00
│   SLOT_AXIS_I: S_AXIS (8-bit)             │  ← AXI DMA MM2S
│   SLOT_AXIS_O: M_AXIS (8-bit)             │  ← AXI DMA S2MM
│   SLOT_IRQ:    IRQ_F2P[0]                 │  ← AXI DMA s2mm_intr
├──────────────────────────────────────────┤
│  accelerator_shell (稳定接口)              │  ← wrapper 对外端口 = 标准插槽
│  axil_2d_shift 当前直接适配插槽，          │     不随 custom IP 内部迭代变化
│  无需额外 adapter（接口天然匹配）           │
├──────────────────────────────────────────┤
│  custom IP (快速迭代)                      │  ← 内部实现自由修改
│  axil_2d_shift 内核 (7 个子模块)            │     不影响平台 BD
└──────────────────────────────────────────┘
```

**核心原则**：

| 原则 | 说明 |
|------|------|
| 平台 BD 冻结 | BD 创建后即 baseline，不自 Driver 自动修改。回归风险降至零 |
| 插槽标准化 | 平台提供 SLOT_AXIL / SLOT_AXIS_I / SLOT_AXIS_O 三个标准槽位 |
| adapter 消化差异 | 新 accelerator 接口不匹配时，写 wrapper/adapter 而非修改 BD |
| BD 变更门槛 | 仅平台级需求变化（PS 外设变更、DMA 位宽升级、时钟方案调整）才修改 BD |

**适用场景**：

| 场景 | 做法 |
|------|------|
| 当前：axil_2d_shift 接入 | 直接连接标准插槽（接口天然匹配，无需 adapter） |
| 将来：新 accelerator X 接入 | 写 `accel_x_wrapper.sv` 将 X 的接口适配到标准插槽；BD 不变 |
| 将来：升级 DMA 位宽 8→32 | 平台级变更 → 修改 BD、更新插槽规格 → accelerator wrapper 同步适配 |

**本项目中 axil_2d_shift 的接口与标准插槽的对应**：

| 标准插槽 | 信号 | axil_2d_shift 端口 | 匹配 |
|----------|------|-------------------|:--:|
| SLOT_AXIL | AXI4-Lite (32-bit) | s_axil_* | 天然 |
| SLOT_AXIS_I | AXI-Stream (8-bit) | s_axis_* | 天然 |
| SLOT_AXIS_O | AXI-Stream (8-bit) | m_axis_* | 天然 |

> 当前无需 adapter。若将来某 accelerator 的 data width 为 16-bit 或接口协议为 AXI4-Full，则写一个 `accel_x_adapter.sv` 做宽度转换/协议转换，BD 保持不变。

---

## 1. Block Design 框图

```
+============================================================================+
|                        Zynq Block Design (BD)                              |
|                          Target: xc7z020clg400-1                           |
+============================================================================+
|                                                                             |
|  +-----------------------+        +===============================+        |
|  |   Zynq7 Processing    |        |  PL Logic (100 MHz fabric)    |        |
|  |   System (PS7)        |        |                               |        |
|  |                       |        |  +---------+  +----------+    |        |
|  |   +-----+  +------+  |        |  | AXI     |  | axil_2d  |    |        |
|  |   | CPU |  | DDR  |  |        |  | Interco |  | _shift   |    |        |
|  |   |     |  | Ctrl |  |        |  | nnect   |  | (PL IP)  |    |        |
|  |   +--+--+  +------+  |        |  | (2:2)   |  |          |    |        |
|  |      |               |        |  |         |  | S_AXI ◄--+    |        |
|  |   +--+------------+  |        |  | M0 ─────+-->|          |    |        |
|  |   |  AXI Infra    |  | M_AXI  |  | M1 ─────+-->| S_AXIS   |    |        |
|  |   |  (internal)   |--+-GP0--->|  |         |  |  ◄------ |    |        |
|  |   |               |  |        |  +---------+  |          |    |        |
|  |   |  S_AXI_HP0 ◄-+--+--------|----------------+-- M_AXIS  |    |        |
|  |   |               |  |        |  |         |  |  --------► |    |        |
|  |   +---------------+  |        |  +---------+  +----------+    |        |
|  +-----------------------+        |        ^                      |        |
|                                    |        |                      |        |
|   PS Sideclocks/resets via MIO    |   +------------+  +--------+  |        |
|   (no external PL pins needed)    |   | AXI Smart  |  | ILA    |  |        |
|                                    |   | Connect    |  | (dbg)  |  |        |
|                                    |   | (64-bit,   |  |        |  |        |
|                                    |   |  2:1)      |  | probes +--+        |
|                                    |   |            |  +--------+  |        |
|                                    |   | S0 ◄-------|--------------+        |
|             DDR(PS MIO)            |   |   DMA M_AXI_MM2S          |        |
|             UART(PS MIO)           |   | S1 ◄-------|--------------+        |
|                                    |   |   DMA M_AXI_S2MM          |        |
|                                    |   |            |              |        |
|                                    |   | M0 ─────---+---> PS_HP0  |        |
|                                    |   +------------+              |        |
|                                    +===============================+        |
|                                                                             |
|  +=================================+                                       |
|  |  AXI DMA (Simple Mode)         |                                       |
|  |  +--------+   +--------------+  |                                       |
|  |  | MM2S   |   | S2MM        |  |                                       |
|  |  | M_AXIS ─+──►| s_axis       |  |                                       |
|  |  |        |  |  | S_AXIS ◄---+--+--- m_axis of shift                   |
|  |  |        |  |  | S_AXI_LITE +--+--- AXI Interconnect M1               |
|  |  | S_AXI  +--+  |            |  |                                       |
|  |  | _LITE  |  |  +--------------+  |                                       |
|  |  +--------+  +--------------+  |                                       |
|  +=================================+                                       |
|                                                                             |
|  +=================================+                                       |
|  |  Processor System Reset        |                                       |
|  |  (proc_sys_reset)              |                                       |
|  |  slowest_sync_clk = FCLK_CLK0  |                                       |
|  |  ext_reset_in = FCLK_RESET0_N  |                                       |
|  |  peripheral_aresetn → all PL   |                                       |
|  +=================================+                                       |
+============================================================================+

时钟域:
  FCLK_CLK0 (100 MHz) ──→ 所有 PL 模块、AXI Interconnect、AXI DMA、ILA

复位域:
  FCLK_RESET0_N ──→ proc_sys_reset ──→ peripheral_aresetn ──→ 所有 PL 模块
```

### 数据流路径

```
┌──────────┐    ┌──────────┐    ┌──────────────┐    ┌──────────┐    ┌──────────┐
│  PS CPU  │    │  DDR3   │    │  AXI DMA     │    │ axil_2d  │    │  PS CPU  │
│          │    │ SDRAM   │    │  (Simple)    │    │ _shift   │    │          │
│ 1. Write │───►│ img_in  │───►│ MM2S: DDR →  │───►│ S_AXIS   │    │          │
│    img   │    │         │    │ Stream       │    │ → shift  │    │          │
│          │    │         │    │              │    │ → output │    │          │
│ 5. Read  │◄───│ img_out │◄───│ S2MM: Stream │◄───│ M_AXIS   │    │          │
│    result│    │         │    │ → DDR        │    │          │    │          │
└──────────┘    └──────────┘    └──────────────┘    └──────────┘    └──────────┘

控制路径:
  PS CPU ──→ M_AXI_GP0 ──→ AXI Interconnect ──→ axil_2d_shift S_AXI (寄存器配置)
                                       └──→ AXI DMA S_AXI_LITE (DMA 控制)
```

### 工作流程（软件视角）

```
步骤 1: PS 将输入帧数据写入 DDR（由 PS 软件分配缓冲区）
步骤 2: PS 通过 AXI-Lite 配置 axil_2d_shift 寄存器（方向、步长、模式、尺寸）
步骤 3: PS 配置 AXI DMA：
          - MM2S: src_addr = DDR buffer (input), len = rows * cols
          - S2MM: dst_addr = DDR buffer (output), len = rows * cols
步骤 4: PS 启动 AXI DMA (MM2S + S2MM)
步骤 5: AXI DMA 从 DDR 读取数据 → 通过 AXI-Stream 送入 axil_2d_shift
步骤 6: axil_2d_shift 采集完成 → 自动进入移位阶段 → 输出 AXI-Stream
步骤 7: AXI DMA S2MM 接收输出数据 → 写入 DDR
步骤 8: PS 轮询 DMA 完成状态 / 中断
步骤 9: PS 从 DDR 读取移位结果
```

---

## 2. PS7 配置参数表

| 配置项 | 参数 | 值 | 说明 |
|--------|------|-----|------|
| **PS 核心配置** | | | |
| | Device Part | xc7z020clg400-1 | Zynq-7000 |
| | MIO Configuration | UART1 (MIO 48,49), USB0 (MIO 28-39), Quad SPI (MIO 1-6) | 调试启动接口 |
| | DDR Controller | MT41K256M16RE-15E | DDR3, 512MB, 16-bit, 1066 MT/s |
| | DDR Type | DDR3 | 1.5V |
| **时钟配置** | | | |
| | Input Clock | 33.33333 MHz | PS_CLK (MIO) |
| | CPU Clock | 666.666 MHz | 6x PLL |
| | DDR Clock | 533.333 MHz | 1066 MT/s |
| | FCLK_CLK0 | **100.000 MHz** | PL 织物时钟 (PLL output) |
| | FCLK_CLK1-3 | Disabled | 无需额外时钟域 |
| **AXI 接口** | | | |
| | M_AXI_GP0 | Enabled, 32-bit | AXI 主接口 (控制总线) |
| | M_AXI_GP0 Freq | FCLK_CLK0 / 100 MHz | 与 PL 同步 |
| | S_AXI_HP0 | **Enabled, 64-bit** | AXI 从接口 (高性能数据通道) |
| | S_AXI_HP0 Freq | FCLK_CLK0 / 100 MHz | 与 PL 同步 |
| | S_AXI_ACP | Disabled | 无需一致性访问 |
| | S_AXI_HP1-3 | Disabled | 仅单 HP 接口够用 |
| **中断** | | | |
| | IRQ_F2P[0:0] | Enabled | 来自 PL 的中断 (AXI DMA done) |
| **复位** | | | |
| | FCLK_RESET0_N | Enabled | PL 复位输出 (~3 ms pulse) |
| **外设 (MIO)** | | | |
| | UART1 | Enabled (MIO 48,49) | 调试串口 (115200 baud) |
| | USB0 | Enabled (MIO 28-39) | 启动/编程/外设 |
| | Quad SPI | Enabled (MIO 1-6) | Flash 启动镜像存储 |
| | SD0 | Disabled (用 USB 替代) | |
| | I2C0, I2C1 | Disabled | |
| | SPI0, SPI1 | Disabled | |
| | GPIO MIO | Disabled | |
| | TTC0 | Enabled | Timer for driver timing |
| | SWDT | Enabled | Watchdog |

### PS 内存地址映射 (AXI 地址空间)

| 地址范围 | 大小 | 目标 | 连接 |
|----------|------|------|------|
| 0x0000_0000 - 0x3FFF_FFFF | 1 GB | DDR (512 MB 可用) | PS DDR Controller |
| 0x4000_0000 - 0x7FFF_FFFF | 1 GB | DDR 镜像 (高地址) | PS DDR Controller |
| **0x4xxx_xxxx** | **64 KB** | **axil_2d_shift S_AXI** | **M_AXI_GP0 → Interconnect** |
| **0x4xxx_xxxx + 0x10000** | **64 KB** | **AXI DMA S_AXI_LITE** | **M_AXI_GP0 → Interconnect** |
| 0xE000_0000 - 0xE000_0FFF | 4 KB | PS UART1 | PS Internal |
| 0xE000_D000 - 0xE000_DFFF | 4 KB | PS TTC0 | PS Internal |

> **注**：axil_2d_shift 和 AXI DMA 的具体基地址由 Block Design 自动分配
> (Vivado Address Editor)，典型值在 0x43C0_0000 附近。

---

## 3. AXI Interconnect 连接表

本设计使用 **两个** AXI 互联模块，分别处理控制通路和数据通路。

### 3.1 AXI Interconnect (GP - 控制通路)

| 属性 | 值 |
|------|-----|
| IP 核 | AXI Interconnect (Vivado IP) |
| 从接口数 | 1 |
| 主接口数 | 2 |
| 数据宽度 | 32-bit |
| 时钟 | FCLK_CLK0 (100 MHz) |
| 协议 | AXI3 (PS side) → AXI4-Lite (slave side) |

**Slave 端口映射**:

| 从端口 | 主端口 | 地址范围 | 备注 |
|--------|--------|----------|------|
| PS M_AXI_GP0 | — | — | 唯一 AXI Master (PS) |

**Master 端口映射**:

| 主端口 | 从设备 | 从接口 | 协议 | 地址偏移 | 地址范围 |
|--------|--------|--------|------|---------|---------|
| Master[0] | axil_2d_shift | S_AXI | AXI4-Lite | 0x43C0_0000 | 64 KB |
| Master[1] | AXI DMA | S_AXI_LITE | AXI4-Lite | 0x43C1_0000 | 64 KB |

**信号连接表**:

| PS 信号 | Interconnect 信号 | 方向 |
|---------|-------------------|------|
| M_AXI_GP0_AWADDR | S00_AXI_AWADDR | PS → Interconnect |
| M_AXI_GP0_AWVALID | S00_AXI_AWVALID | PS → Interconnect |
| M_AXI_GP0_AWREADY | S00_AXI_AWREADY | Interconnect → PS |
| M_AXI_GP0_WDATA | S00_AXI_WDATA | PS → Interconnect |
| M_AXI_GP0_WVALID | S00_AXI_WVALID | PS → Interconnect |
| M_AXI_GP0_WREADY | S00_AXI_WREADY | Interconnect → PS |
| M_AXI_GP0_BRESP | S00_AXI_BRESP | Interconnect → PS |
| M_AXI_GP0_BVALID | S00_AXI_BVALID | Interconnect → PS |
| M_AXI_GP0_BREADY | S00_AXI_BREADY | PS → Interconnect |
| M_AXI_GP0_ARADDR | S00_AXI_ARADDR | PS → Interconnect |
| M_AXI_GP0_ARVALID | S00_AXI_ARVALID | PS → Interconnect |
| M_AXI_GP0_ARREADY | S00_AXI_ARREADY | Interconnect → PS |
| M_AXI_GP0_RDATA | S00_AXI_RDATA | Interconnect → PS |
| M_AXI_GP0_RRESP | S00_AXI_RRESP | Interconnect → PS |
| M_AXI_GP0_RVALID | S00_AXI_RVALID | Interconnect → PS |
| M_AXI_GP0_RREADY | S00_AXI_RREADY | PS → Interconnect |

**Master[0] → axil_2d_shift S_AXI 连接**:

| Interconnect M00_AXI | axil_2d_shift S_AXI | 方向 |
|----------------------|---------------------|------|
| AWADDR | s_axil_awaddr | Interconnect → axil_2d_shift |
| AWVALID | s_axil_awvalid | Interconnect → axil_2d_shift |
| AWREADY | s_axil_awready | axil_2d_shift → Interconnect |
| WDATA | s_axil_wdata | Interconnect → axil_2d_shift |
| WSTRB | s_axil_wstrb | Interconnect → axil_2d_shift |
| WVALID | s_axil_wvalid | Interconnect → axil_2d_shift |
| WREADY | s_axil_wready | axil_2d_shift → Interconnect |
| BRESP | s_axil_bresp | axil_2d_shift → Interconnect |
| BVALID | s_axil_bvalid | axil_2d_shift → Interconnect |
| BREADY | s_axil_bready | Interconnect → axil_2d_shift |
| ARADDR | s_axil_araddr | Interconnect → axil_2d_shift |
| ARVALID | s_axil_arvalid | Interconnect → axil_2d_shift |
| ARREADY | s_axil_arready | axil_2d_shift → Interconnect |
| RDATA | s_axil_rdata | axil_2d_shift → Interconnect |
| RRESP | s_axil_rresp | axil_2d_shift → Interconnect |
| RVALID | s_axil_rvalid | axil_2d_shift → Interconnect |
| RREADY | s_axil_rready | Interconnect → axil_2d_shift |

**Master[1] → AXI DMA S_AXI_LITE 连接**:

| Interconnect M01_AXI | AXI DMA S_AXI_LITE | 方向 |
|----------------------|--------------------|------|
| AWADDR | s_axi_lite_awaddr | Interconnect → DMA |
| AWVALID | s_axi_lite_awvalid | Interconnect → DMA |
| AWREADY | s_axi_lite_awready | DMA → Interconnect |
| WDATA | s_axi_lite_wdata | Interconnect → DMA |
| WVALID | s_axi_lite_wvalid | Interconnect → DMA |
| WREADY | s_axi_lite_wready | DMA → Interconnect |
| BRESP | s_axi_lite_bresp | DMA → Interconnect |
| BVALID | s_axi_lite_bvalid | DMA → Interconnect |
| BREADY | s_axi_lite_bready | Interconnect → DMA |
| ARADDR | s_axi_lite_araddr | Interconnect → DMA |
| ARVALID | s_axi_lite_arvalid | Interconnect → DMA |
| ARREADY | s_axi_lite_arready | DMA → Interconnect |
| RDATA | s_axi_lite_rdata | DMA → Interconnect |
| RRESP | s_axi_lite_rresp | DMA → Interconnect |
| RVALID | s_axi_lite_rvalid | DMA → Interconnect |
| RREADY | s_axi_lite_rready | Interconnect → DMA |

### 3.2 AXI SmartConnect (HP - 数据通路)

| 属性 | 值 |
|------|-----|
| IP 核 | AXI SmartConnect (Vivado IP, 64-bit) |
| 从接口数 | 2 (AXI DMA MM2S + S2MM) |
| 主接口数 | 1 (PS S_AXI_HP0) |
| 数据宽度 | 64-bit (HP0 原生宽度) |
| 时钟 | FCLK_CLK0 (100 MHz) |
| 协议 | AXI4 Full |

**从端口映射**:

| 从端口 | 主设备 | 主端口 | 带宽需求 | 数据宽度 |
|--------|--------|--------|---------|---------|
| Slave[0] | AXI DMA | M_AXI_MM2S | 100 MB/s (8-bit @ 100 MHz) | 32-bit |
| Slave[1] | AXI DMA | M_AXI_S2MM | 100 MB/s (8-bit @ 100 MHz) | 32-bit |

**主端口映射**:

| 主端口 | 目标设备 | 目标端口 | 说明 |
|--------|---------|---------|------|
| Master[0] | PS7 | S_AXI_HP0 | DDR 访问 (64-bit HP 接口) |

**连接表 (SmartConnect → PS7 HP0)**:

| SmartConnect M00_AXI | PS7 S_AXI_HP0 | 方向 |
|----------------------|---------------|------|
| AWADDR | SAXI_HP0_AWADDR | SmartConnect → PS7 |
| AWVALID | SAXI_HP0_AWVALID | SmartConnect → PS7 |
| AWREADY | SAXI_HP0_AWREADY | PS7 → SmartConnect |
| WDATA | SAXI_HP0_WDATA | SmartConnect → PS7 |
| WSTRB | SAXI_HP0_WSTRB | SmartConnect → PS7 |
| WVALID | SAXI_HP0_WVALID | SmartConnect → PS7 |
| WREADY | SAXI_HP0_WREADY | PS7 → SmartConnect |
| BRESP | SAXI_HP0_BRESP | PS7 → SmartConnect |
| BVALID | SAXI_HP0_BVALID | PS7 → SmartConnect |
| BREADY | SAXI_HP0_BREADY | SmartConnect → PS7 |
| ARADDR | SAXI_HP0_ARADDR | SmartConnect → PS7 |
| ARVALID | SAXI_HP0_ARVALID | SmartConnect → PS7 |
| ARREADY | SAXI_HP0_ARREADY | PS7 → SmartConnect |
| RDATA | SAXI_HP0_RDATA | PS7 → SmartConnect |
| RRESP | SAXI_HP0_RRESP | PS7 → SmartConnect |
| RVALID | SAXI_HP0_RVALID | PS7 → SmartConnect |
| RREADY | SAXI_HP0_RREADY | SmartConnect → PS7 |

---

## 4. AXI DMA 配置

### 4.1 IP 核选择

- **IP 核**：AXI Direct Memory Access (AXI DMA) v7.1
- **Vivado 版本兼容性**：Vivado 2022.2 (v7.1)
- **工作模式**：Simple DMA (无 Scatter Gather，简化驱动)

### 4.2 参数配置表

| 参数 | 值 | 说明 |
|------|-----|------|
| **DMA Mode** | Simple DMA | 单事务模式，无需描述符链表 |
| **Enable Scatter Gather** | Unchecked | 保持驱动简单 |
| **Width of Buffer Length Register** | 23 bits | 最大传输长度 = 8 MB |
| **Enable Read Channel (MM2S)** | Enabled | DDR → AXI-Stream (输入数据) |
| **Enable Write Channel (S2MM)** | Enabled | AXI-Stream → DDR (输出数据) |
| **Channel Type** | Full Duplex | MM2S 和 S2MM 同时运行 |
| **Enable Micro DMA** | Unchecked | 标准 DMA，不限制 burst |
| **Data Width for MM2S** | 8 bits | 与 axil_2d_shift DATA_WIDTH 匹配 |
| **Data Width for S2MM** | 8 bits | 与 axil_2d_shift DATA_WIDTH 匹配 |
| **Max Burst Length (MM2S/S2MM)** | 16 | 中等 burst 长度，平衡 DDR 效率 |
| **Enable Control/Status Stream** | Unchecked | 不使用 control/status stream |
| **Allow Unaligned Transfers** | Unchecked | 地址需字节对齐 |
| **Enable Interrupt (MM2S)** | Unchecked | PS 通过轮询检查 DMA 状态 |
| **Enable Interrupt (S2MM)** | Checked | S2MM 完成中断 → IRQ_F2P[0] |
| **Number of Clocks for AXI** | 1 | 单时钟域 (FCLK_CLK0) |

### 4.3 端口连接表

| AXI DMA 端口 | 方向 | 连接目标 | 协议 |
|-------------|------|---------|------|
| M_AXI_MM2S | Master | AXI SmartConnect Slave[0] | AXI4 Full (32-bit) |
| M_AXI_S2MM | Master | AXI SmartConnect Slave[1] | AXI4 Full (32-bit) |
| M_AXIS_MM2S | Master | axil_2d_shift s_axis | AXI4-Stream (8-bit) |
| S_AXIS_S2MM | Slave | axil_2d_shift m_axis | AXI4-Stream (8-bit) |
| S_AXI_LITE | Slave | AXI Interconnect Master[1] | AXI4-Lite (32-bit) |
| mm2s_introut | Master | (NC, 可连 PS IRQ_F2P) | Interrupt |
| s2mm_introut | Master | PS IRQ_F2P[0] (推荐) | Interrupt |
| axi_rstn | Input | proc_sys_reset peripheral_aresetn | Reset |

### 4.4 AXI-Stream 数据宽度匹配

axil_2d_shift 的 DATA_WIDTH 默认 = 8。AXI DMA 的 MM2S/S2MM 数据宽度也配置为 8。

若将来需要增大 DATA_WIDTH（如 16 或 32 位），需同步修改：
- axil_2d_shift DATA_WIDTH 参数
- AXI DMA Data Width for MM2S/S2MM
- 帧缓冲 BRAM 宽度

### 4.5 中断连接

| 信号 | 来源 | 目标 | 用途 |
|------|------|------|------|
| s2mm_introut | AXI DMA | PS IRQ_F2P[0] | S2MM 传输完成 (输出数据就绪) |
| mm2s_introut | AXI DMA | (NC) 或 PS IRQ_F2P[1] | MM2S 传输完成 (可选) |

建议 S2MM 中断用于通知 PS 输出数据已写入 DDR，PS 即可读取结果。MM2S 通过轮询检测完成状态。

---

## 5. ILA 核配置

### 5.1 总体配置

| 参数 | 值 | 说明 |
|------|-----|------|
| IP 核 | Integrated Logic Analyzer (ILA) v1.8 | Vivado 2022.2 |
| 组件数 | 2 个 ILA 核 | 分别监控采集路径和移位路径 |
| 采样深度 | 1024 | 足够捕获 32x32 完整帧的多数内部信号 |
| 触发位置 | 512 (居中) | 触发前后各 512 样本 |
| 时钟 | FCLK_CLK0 (100 MHz) | 与 PL 逻辑同步 |

### 5.2 ILA 核 0：采集监控 (Capture Monitor)

| 探针 | 宽度 | 用途 | 信号来源 |
|------|------|------|---------|
| PROBE[0] | 8 | s_axis_tdata (输入数据) | axis_input 内部寄存器 |
| PROBE[1] | 1 | s_axis_tvalid | axis_input |
| PROBE[2] | 1 | s_axis_tready | axis_input |
| PROBE[3] | 1 | s_axis_tlast (行结束) | axis_input |
| PROBE[4] | 1 | s_axis_tuser (帧起始) | axis_input |
| PROBE[5] | 1 | capture_en (采集使能) | ctrl_fsm → axis_input |
| PROBE[6] | 1 | capture_done (采集完成) | axis_input → ctrl_fsm |
| PROBE[7] | 12 | write_addr (BRAM 写地址) | axis_input → frame_buf_mgr |
| PROBE[8] | 1 | write_en (BRAM 写使能) | axis_input → frame_buf_mgr |
| **小计** | **27** | | |

### 5.3 ILA 核 1：移位监控 (Shift Monitor)

| 探针 | 宽度 | 用途 | 信号来源 |
|------|------|------|---------|
| PROBE[0] | 8 | m_axis_tdata (输出数据) | axis_output 输出寄存器 |
| PROBE[1] | 1 | m_axis_tvalid | axis_output |
| PROBE[2] | 1 | m_axis_tready | axis_output |
| PROBE[3] | 1 | m_axis_tlast (行结束) | axis_output |
| PROBE[4] | 1 | m_axis_tuser (帧起始) | axis_output |
| PROBE[5] | 1 | shift_en (移位使能) | ctrl_fsm |
| PROBE[6] | 1 | shift_done (移位完成) | axis_output → ctrl_fsm |
| PROBE[7] | 1 | zero_fill (补零标志) | shift_addr_gen → axis_output |
| PROBE[8] | 12 | read_addr (BRAM 读地址) | shift_addr_gen → frame_buf_mgr |
| PROBE[9] | 2 | fsm_state (ctrl_fsm 状态) | ctrl_fsm 状态编码 |
| **小计** | **29** | | |

### 5.4 触发条件

| ILA 核 | 触发条件 | 用途 |
|--------|---------|------|
| ILA 0 | RISE s_axis_tuser | 帧开始时触发，捕获整帧采集过程 |
| ILA 0 (alt) | RISE capture_en | 采集使能上升沿触发 |
| ILA 1 | RISE m_axis_tuser | 输出帧开始时触发，捕获整帧输出过程 |
| ILA 1 (alt) | RISE shift_en | 移位使能上升沿触发 |
| ILA 1 (alt) | RISE zero_fill | 补零事件触发（验证零填充正确性） |

### 5.5 Debug 连接方式

有两种实现方案：

**方案 A：mark_debug 属性（推荐）**

在 RTL 中为目标信号添加 Synth 属性，由 Vivado 综合后自动连接到 ILA：

```systemverilog
// 在 ctrl_fsm.sv 中
(* mark_debug = "true" *) logic [1:0] state_q;

// 在 axis_output.sv 中
(* mark_debug = "true" *) logic [DATA_WIDTH-1:0] m_axis_tdata_reg;
```

Pros：不修改模块接口；Cons：需要在 RTL 中添加 debug 属性。

**方案 B：调试端口 wrapper（BD 友好）**

创建一个 BD wrapper 模块，将 axil_2d_shift 的内部信号引出为调试端口：

```systemverilog
module axil_2d_shift_wrapper #(
    parameter DATA_WIDTH = 8,
    ...
) (
    // 原始接口：所有 axil_2d_shift 的端口
    ...
    // 调试端口输出（仅仿真/调试用，可综合为空）
    output [DATA_WIDTH-1:0] dbg_s_axis_tdata,
    output                  dbg_capture_en,
    output                  dbg_shift_en,
    output [1:0]            dbg_fsm_state,
    ...
);
```

Pros：BD 中直接连接 ILA；Cons：增加了顶层端口（但标记为 debug-only，IOB 不会分配）。

**推荐方案 A** 用于快速调试（直接 mark_debug），**方案 B** 用于正式的 BD 集成（端口整洁）。本架构文档推荐**方案 A**。

---

## 6. 外部引脚表

### 6.1 必需的 PL 外部引脚

| 信号名 | 方向 | 位宽 | 电平标准 | 说明 |
|--------|------|------|---------|------|
| (无) | — | — | — | Zynq BD 方案不需要任何 PL 外部引脚 |

### 6.2 PS 外部引脚 (MIO, 非 PL IOB)

以下信号通过 PS 的 MIO 引脚连接板级外设，**不计入 PL IOB 利用率**：

| 功能 | 引脚数 | MIO 分配 | 说明 |
|------|--------|---------|------|
| PS_CLK | 1 | MIO 专用 | 33.333 MHz 板级晶振 |
| PS_POR_B | 1 | MIO 专用 | 上电复位 |
| DDR3 (地址/命令/数据) | ~60 | MIO 预分配 | 16-bit DDR3 + 地址/控制 |
| UART1 (TXD/RXD) | 2 | MIO 48,49 | 调试串口 |
| USB0 (D+/D- + 控制) | ~12 | MIO 28-39 | USB 启动/外设 |
| Quad SPI (CLK/CS/IO0-3) | ~6 | MIO 1-6 | SPI Flash 启动 |
| **PS MIO 小计** | **~82** | | **非 PL IOB** |

### 6.3 可选的 PL 外部引脚 (非必需)

以下信号可引出但非必须——PS BD 方案完全通过内部接口工作：

| 信号名 | 方向 | 位宽 | 说明 | 建议 |
|--------|------|------|------|------|
| pl_clk_in | Input | 1 | 备用 PL 时钟输入 | **NC** (使用 PS FCLK_CLK0) |
| pl_rstn_in | Input | 1 | 备用 PL 复位输入 | **NC** (使用 PS FCLK_RESET0_N) |
| debug_led[3:0] | Output | 4 | 状态指示 LED | 可选 (若硬件有 LED) |
| btn[1:0] | Input | 2 | 用户按钮 | 可选 (若硬件有按钮) |

### 6.4 外部引脚总表 (PL IOB 视角)

| 信号类别 | 引脚数 | 用途 |
|----------|--------|------|
| 时钟 (clk) | 0 | 使用 PS FCLK_CLK0 (内部生成) |
| 复位 (rstn) | 0 | 使用 PS FCLK_RESET0_N + proc_sys_reset |
| AXI-Lite (原 68 引脚) | 0 | 通过 PS M_AXI_GP0 内部连接 |
| AXI-Stream (原 12+12 = 24 引脚) | 0 | 通过 AXI DMA 内部连接 |
| **PL IOB 总数** | **0** | **不需要外部 PL 引脚** |

---

## 7. IOB 预估计算

### 7.1 xc7z020 IOB 资源

| 资源 | 总量 |
|------|------|
| xc7z020clg400 I/O Pins (PL IOB) | 125 |
| 其中可用 IOB (扣除专用时钟/配置引脚) | ~100+ |

### 7.2 Block Design IOB 占用

| 方案 | PL IOB | 利用率 | 说明 |
|------|--------|--------|------|
| **BD 方案** (无外部引脚) | **0** | **0%** | 全部通过 PS MIO + 内部 AXI 连接 |
| **BD 方案** (带 2 调试 LED) | **4** | **3.2%** | 仅 LED/按钮 (可选) |
| BD 方案 (带 EMIO UART 备份) | 2 | 1.6% | 可选 UART 调试备份 |

**与原始方案对比**:

| 方案对比 | 外部 IOB | 利用率 | IOB 减少 |
|----------|----------|--------|---------|
| 原始 PL-only 方案 | 102 | 81.6% | — |
| BD 方案 (最小) | 0 | **0%** | 100% |
| BD 方案 (带可选调试) | 4 | **3.2%** | 96% |

### 7.3 根因分析：为什么 IOB 从 102 -> 0

原始 PL-only 架构需要 102 个外部引脚的原因：

| 接口 | 原始引脚数 | BD 替代方案 | 节省引脚 |
|------|-----------|-------------|---------|
| AXI-Lite (32-bit addr/data + control) | 68 | PS M_AXI_GP0 (内部 AXI 总线) | 68 |
| AXI-Stream Input (data+control) | 12 | AXI DMA MM2S (内部 Stream 总线) | 12 |
| AXI-Stream Output (data+control) | 12 | AXI DMA S2MM (内部 Stream 总线) | 12 |
| Clock | 2 (clk, rstn) | PS FCLK (内部时钟生成) | 2 |
| Misc | ~8 | N/A (PS 内部状态检查) | ~8 |
| **总计** | **102** | **0** | **102** |

BD 方案利用 Zynq-7000 的 PS 内部 AXI 基础设施，将原本需要外部连接的信号全部在芯片内部完成，仅消耗 MIO 引脚 (不占用 PL IOB) 用于 DDR、UART、USB 等系统接口。

---

## 8. Vivado Tcl 自动化脚本骨架

### 8.1 完整 BD 创建脚本

```tcl
#==============================================================================
# create_bd_axil_2d_shift.tcl
# Vivado 2022.2 Block Design 自动化创建脚本
# 用途：创建包含 PS7 + axil_2d_shift + AXI DMA + ILA 的 Block Design
#
# 使用方法：
#   Vivado 2022.2 Tcl Console:
#     source {path/to/create_bd_axil_2d_shift.tcl}
#   或命令行:
#     vivado -mode batch -source create_bd_axil_2d_shift.tcl
#==============================================================================

# --- 1. 创建工程 (如已有工程则跳过) ---
if {[info exists ::argv] && [llength $::argv] > 0} {
    set proj_dir [lindex $::argv 0]
} else {
    set proj_dir "./vivado/axil_2d_shift_bd"
}

if {![file exists "$proj_dir/$proj_dir.xpr"]} {
    create_project -force bd_project $proj_dir -part xc7z020clg400-1
    
    # 添加 axil_2d_shift 的 RTL 文件 (顶层 + 7 个子模块)
    set rtl_files [glob -dir ./rtl *.sv]
    foreach f $rtl_files {
        add_files -norecurse $f
    }
} else {
    open_project "$proj_dir/$proj_dir.xpr"
}

# --- 2. 创建 Block Design ---
create_bd_design "axil_2d_shift_bd"

# --- 3. PS7 配置 ---
# 使用 Tcl 方式创建并配置 PS7
set ps7_cell [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0]

# 在 Vivado 2022.2 中，PS7 配置通过 CONFIG 参数进行
# 完整配置通过 apply_bd_automation 或 preset 文件
set_property -dict [list \
    CONFIG.PCW_PRESET_BANK0_VOLTAGE {LVCMOS 3.3V} \
    CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 1.8V} \
    CONFIG.PCW_UART1_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_UART1_UART_IO {MIO 48 .. 49} \
    CONFIG.PCW_USB0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_USB0_USB0_IO {MIO 28 .. 39} \
    CONFIG.PCW_QSPI_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_QSPI_QSPI_IO {MIO 1 .. 6} \
    CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_EN_CLK0_PORT {1} \
    CONFIG.PCW_FCLK0_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_FCLK_CLK0_FREQ {100000000} \
    CONFIG.PCW_EN_RST0_PORT {1} \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_M_AXI_GP0_FREQUENCY {100000000} \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
    CONFIG.PCW_IRQ_F2P_INTR {1} \
    CONFIG.PCW_PACKAGE_NAME {clg400} \
] $ps7_cell

# --- 4. AXI Interconnect (GP 控制通路) ---
set axi_intercon_gp [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_intercon_gp]
set_property -dict [list \
    CONFIG.NUM_SI {1} \
    CONFIG.NUM_MI {2} \
    CONFIG.INTERFACE_CLK_RT {100} \
    CONFIG.SYNCHRONIZATION_STAGES {2} \
] $axi_intercon_gp

# --- 5. Processor System Reset ---
set proc_sys_reset [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0]

# --- 6. AXI DMA ---
set axi_dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0]
set_property -dict [list \
    CONFIG.c_include_mm2s {1} \
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_m_axi_mm2s_data_width {32} \
    CONFIG.c_m_axis_mm2s_tdata_width {8} \
    CONFIG.c_m_axis_mm2s_tuser_width {1} \
    CONFIG.c_s_axis_s2mm_tdata_width {8} \
    CONFIG.c_s_axis_s2mm_tuser_width {1} \
    CONFIG.c_sg_include_desc {0} \
    CONFIG.c_sg_length_width {23} \
] $axi_dma

# --- 7. AXI SmartConnect (HP 数据通路) ---
set axi_smc [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_smc:1.0 axi_smc]
set_property -dict [list \
    CONFIG.NUM_SI {2} \
    CONFIG.NUM_MI {1} \
] $axi_smc

# --- 8. ILA 核 ---
# ILA 0: 采集监控 (27-bit probe)
set ila_capture [create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_capture]
set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES {9} \
    CONFIG.C_PROBE0_WIDTH {8} \
    CONFIG.C_PROBE1_WIDTH {1} \
    CONFIG.C_PROBE2_WIDTH {1} \
    CONFIG.C_PROBE3_WIDTH {1} \
    CONFIG.C_PROBE4_WIDTH {1} \
    CONFIG.C_PROBE5_WIDTH {1} \
    CONFIG.C_PROBE6_WIDTH {1} \
    CONFIG.C_PROBE7_WIDTH {12} \
    CONFIG.C_PROBE8_WIDTH {1} \
    CONFIG.C_SAMPLE_DEPTH {1024} \
    CONFIG.C_TRIGIN_EN {false} \
    CONFIG.C_TRIGOUT_EN {false} \
] $ila_capture

# ILA 1: 移位监控 (29-bit probe)
set ila_shift [create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_shift]
set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES {10} \
    CONFIG.C_PROBE0_WIDTH {8} \
    CONFIG.C_PROBE1_WIDTH {1} \
    CONFIG.C_PROBE2_WIDTH {1} \
    CONFIG.C_PROBE3_WIDTH {1} \
    CONFIG.C_PROBE4_WIDTH {1} \
    CONFIG.C_PROBE5_WIDTH {1} \
    CONFIG.C_PROBE6_WIDTH {1} \
    CONFIG.C_PROBE7_WIDTH {1} \
    CONFIG.C_PROBE8_WIDTH {12} \
    CONFIG.C_PROBE9_WIDTH {2} \
    CONFIG.C_SAMPLE_DEPTH {1024} \
] $ila_shift

# --- 9. 连接时钟和复位 ---
# FCLK_CLK0 → 所有模块的时钟输入
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
              [get_bd_pins axi_intercon_gp/ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
              [get_bd_pins axi_intercon_gp/S00_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
              [get_bd_pins axi_intercon_gp/M00_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
              [get_bd_pins axi_intercon_gp/M01_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
              [get_bd_pins axi_dma_0/s_axi_lite_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
              [get_bd_pins axi_dma_0/m_axi_mm2s_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
              [get_bd_pins axi_dma_0/m_axi_s2mm_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
              [get_bd_pins axi_smc/aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
              [get_bd_pins axi_smc/S00_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
              [get_bd_pins axi_smc/S01_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
              [get_bd_pins axi_smc/M00_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
              [get_bd_pins ila_capture/clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
              [get_bd_pins ila_shift/clk]

# proc_sys_reset 配置
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] \
              [get_bd_pins proc_sys_reset_0/ext_reset_in]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
              [get_bd_pins proc_sys_reset_0/slowest_sync_clk]

# peripheral_aresetn → 所有模块 (除 PS7 外)
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
              [get_bd_pins axi_dma_0/axi_resetn]
# 其他模块的复位将在连接 interface 时自动处理

# --- 10. 连接 PS M_AXI_GP0 → AXI Interconnect ---
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] \
                    [get_bd_intf_pins axi_intercon_gp/S00_AXI]

# --- 11. 连接 Interconnect Master[0] → axil_2d_shift S_AXI ---
# (假设 axil_2d_shift 已经在工程中作为 IP 或 RTL 模块存在)
# 创建 axil_2d_shift IP 或使用 RTL 模块
# 此处使用 create_bd_cell -type module 方式导入 RTL
# (RTL 文件需已在工程中)
set axil_2d_shift_cell [create_bd_cell -type module -reference axil_2d_shift axil_2d_shift_0]
connect_bd_intf_net [get_bd_intf_pins axi_intercon_gp/M00_AXI] \
                    [get_bd_intf_pins axil_2d_shift_0/s_axil]

# --- 12. 连接 Interconnect Master[1] → AXI DMA S_AXI_LITE ---
connect_bd_intf_net [get_bd_intf_pins axi_intercon_gp/M01_AXI] \
                    [get_bd_intf_pins axi_dma_0/S_AXI_LITE]

# --- 13. 连接 AXI DMA MM2S → axil_2d_shift s_axis ---
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] \
                    [get_bd_intf_pins axil_2d_shift_0/s_axis]

# --- 14. 连接 axil_2d_shift m_axis → AXI DMA S2MM ---
connect_bd_intf_net [get_bd_intf_pins axil_2d_shift_0/m_axis] \
                    [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

# --- 15. 连接 AXI DMA MM2S/S2MM → SmartConnect → PS HP0 ---
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] \
                    [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] \
                    [get_bd_intf_pins axi_smc/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
                    [get_bd_intf_pins processing_system7_0/S_AXI_HP0]

# --- 16. 连接 ILA 探针 (mark_debug 方式, BD 中不直接连接) ---
# ILA 探针通过 mark_debug 属性在 RTL 中定义，综合后自动连接。
# 或在 BD 中通过 create_bd_cell -type debug_hub 自动探测。
#
# 如果需要 BD 中直接连接 (方案 B wrapper 方式)，则添加以下连接:
# connect_bd_net [get_bd_pins axil_2d_shift_0/dbg_capture_en] \
#               [get_bd_pins ila_capture/probe5]

# --- 17. 连接中断 ---
connect_bd_net [get_bd_pins axi_dma_0/s2mm_introut] \
              [get_bd_pins processing_system7_0/IRQ_F2P]
# 注意: IRQ_F2P 是 1-bit 向量 [0:0]

# --- 18. 分配地址 ---
# 自动分配地址 (Vivado Address Editor)
assign_bd_address

# --- 19. 验证 BD ---
validate_bd_design

# --- 20. 生成顶层 HDL Wrapper ---
make_wrapper -files [get_files axil_2d_shift_bd.bd] -top
add_files -norecurse [glob -dir ./vivado *.sv]

# --- 21. 生成 IP 核输出产物 ---
generate_target all [get_files axil_2d_shift_bd.bd]

puts "Block Design 创建完成!"
puts "轴地址映射:"
puts [report_bd_address_map -no_bd_bus_info]

puts "运行综合: launch_runs synth_1 -jobs 4"
```

### 8.2 XDC 约束 (最小)

```tcl
#==============================================================================
# axil_2d_shift_bd.xdc — 最小约束文件
# Block Design 方案不需要外部 I/O 约束
#==============================================================================

# 创建时钟 (由 PS FCLK_CLK0 自动生成，XDC 中仅做约束声明)
create_clock -period 10.000 -name pl_clk0 [get_pins processing_system7_0/FCLK_CLK0]

# 时序例外（无外部 I/O，无需 input/output delay）
# 所有时序路径在 PS 和 PL 之间由 AXI Interconnect/SmartConnect 管理

# 仅需要的约束：ILA 调试的时钟域定义
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {processing_system7_0/FCLK_CLK0}]
```

### 8.3 PS 软件驱动骨架 (C 参考, 用于完整度)

```c
// axil_2d_shift_driver.h — 参考驱动接口
// 1. AXI-Lite 寄存器访问 (通过 M_AXI_GP0 映射的内存地址)
void axil_2d_shift_write_reg(uint32_t base_addr, uint32_t offset, uint32_t value);
uint32_t axil_2d_shift_read_reg(uint32_t base_addr, uint32_t offset);

// 2. AXI DMA 控制
void axi_dma_mm2s_start(uint32_t dma_base_addr, uint32_t src_addr, uint32_t length);
void axi_dma_s2mm_start(uint32_t dma_base_addr, uint32_t dst_addr, uint32_t length);
int  axi_dma_s2mm_is_done(uint32_t dma_base_addr);

// 3. 2D 移位操作 (主 API)
void shift_2d_frame(uint32_t shift_base, uint32_t dma_base,
                    uint8_t *input_frame, uint8_t *output_frame,
                    uint32_t rows, uint32_t cols,
                    uint32_t direction, uint32_t step, int wrap_en);
```

---

## 9. 与原始架构的差异总结

| 维度 | 原始 PL-only 方案 | BD 方案 |
|------|------------------|---------|
| **外部 IOB** | 102 (81.6%) | 0 (0%) 或 2-4 (3.2%) |
| **调试手段** | 需外部逻辑分析仪 | 内部 ILA (Vivado HW Manager) |
| **数据源** | 外部 AXI-Stream 源 | DDR → AXI DMA → AXI-Stream |
| **数据汇** | 外部 AXI-Stream 汇 | AXI-Stream → AXI DMA → DDR |
| **配置接口** | 外部 IOB 的 AXI-Lite | PS M_AXI_GP0 内部 AXI 总线 |
| **系统时钟** | 外部晶振 (clk 引脚) | PS PLL → FCLK_CLK0 |
| **系统复位** | 外部 rstn 引脚 | PS FCLK_RESET0_N + proc_sys_reset |
| **RTL 修改** | — | **不需要修改** (原模块端口不变) |
| **BRAM 用量** | 1-2 BRAM36K | 不变 (帧缓冲仍在 PL 中) |
| **LUT/FF 用量** | ~500 LUT / ~300 FF | 不变 (逻辑不变) |
| **附加 IP 开销** | 无 | AXI Interconnect + DMA + SmartConnect + ILA |

### 9.1 资源消耗预估 (额外)

| IP 核 | LUT | FF | BRAM | 说明 |
|-------|-----|----|------|------|
| AXI Interconnect (GP, 1:2) | ~300 | ~400 | 0 | 32-bit 控制总线桥接 |
| AXI DMA (Simple, MM2S+S2MM) | ~1500 | ~1800 | 0-1 | DMA 引擎 (含 FIFO) |
| AXI SmartConnect (HP, 2:1) | ~500 | ~600 | 0 | 64-bit 数据互联 |
| Processor System Reset | ~50 | ~100 | 0 | 复位同步器 |
| ILA x2 (1024 depth) | ~600 | ~800 | 2 | 调试核 |
| **附加总计** | **~2950** | **~3700** | **2-3** | |
| xc7z020 总量 | 53200 | 106400 | 140 | 可用资源 |
| 附加占比 | 5.5% | 3.5% | 1.4-2.1% | 所有额外 IP 总和 < 6% |

> **注**：axil_2d_shift 原有逻辑的 LUT/FF/BRAM 消耗不变。附加 IP 的开销微小且仅用于控制通路和数据通路桥接。ILA 在比特流交付产品前可以移除（从 BD 中删除 ILA 核即可回收资源）。

---

## 10. 设计约束与风险

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| AXI DMA 与 AXI-Stream 之间的同步 | 数据丢失或错位 | AXI DMA 内置 FIFO；可在 DMA 和 shift 之间添加 axis_data_fifo (depth=16) 做弹性缓冲 |
| PS 时钟与 PL 时钟的相位一致性 | 通常不影响（同一 PLL 输出） | 使用 FCLK_CLK0 (不跨 PLL) |
| AXI Interconnect 桥上延时 | 寄存器写延迟增加数周期 | 控制路径为粗粒度操作 (< 100 MHz)，额外延迟无影响 |
| S_AXI_HP0 背压 | DMA 传输暂停 | HP0 内置 256 深度的写入 FIFO；默认 64-bit 宽度足够缓存 |
| IRQ_F2P 单线中断 | 仅 1 个中断线可用 | S2MM 完成中断已够用；MM2S 采用轮询 |
| ILA 深度 1024 无法捕获大帧 | 大帧 (64x64 = 4096 元素) 需分段触发 | 调整 ILA depth 为 16384 (可配置) 或分段捕获 |

---

## 11. 验证策略建议 (BD 层级)

| 验证级别 | 方法 | 工具 |
|---------|------|------|
| L1c (系统级仿真) | BD 导出 HDL 后进行全系统仿真，含 PS AXI 总线功能模型 | Vivado xsim / Questa |
| L2 (综合) | 在 Vivado 中运行 synth_1 | Vivado 2022.2 |
| L3 (实现) | 运行 impl_1，检查时序 | Vivado 2022.2 |
| L5-L6 (上板) | 加载比特流，通过 PS 软件驱动进行 DMA 传输验证 | Vivado HW Manager + Xilinx SDK |
