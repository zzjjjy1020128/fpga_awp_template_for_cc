# 项目宪章：AXI-Lite 2D Shift 模块

## 1. 项目概述

### 1.1 目的

设计一个 AXI-Lite 控制的 2D shift 模块，用于对 2D 数据阵列（如灰度图像像素、矩阵元素）进行行列方向的数据移位。模块通过 AXI4-Lite 从属接口接收配置参数，通过 AXI4-Stream 接口输入原始数据、输出移位结果。

### 1.2 应用场景

- **图像处理预处理**：像素重排、图像卷移（cyclic shift），用于卷积神经网络前处理或形态学滤波
- **数据对齐**：矩阵运算前的行/列对齐操作
- **显示驱动**：屏幕画面的上下左右平移

### 1.3 功能定义

模块将输入的 2D 数据阵列视为一个矩阵，按照配置的**方向**和**步长**进行整体平移：

| 方向 | 含义 | 空位处理 |
|------|------|---------|
| NONE（000） | 透传 | - |
| UP（001） | 每列元素向上平移 N 行 | 底部补零或缠绕 |
| DOWN（010） | 每列元素向下平移 N 行 | 顶部补零或缠绕 |
| LEFT（011） | 每行元素向左平移 N 列 | 右侧补零或缠绕 |
| RIGHT（100） | 每行元素向右平移 N 列 | 左侧补零或缠绕 |

**缠绕模式（wrap）**：移出边界的元素从对侧边界重新进入；**补零模式（zero-fill）**：移出边界的元素丢弃，空位填 0。

### 1.4 输入 / 输出规约

| 接口 | 方向 | 协议 | 数据宽度 | 说明 |
|------|------|------|---------|------|
| s_axil | 输入 | AXI4-Lite Slave | 32-bit 地址/数据 | 寄存器配置 |
| s_axis | 输入 | AXI4-Stream Slave | DATA_WIDTH bit | 原始像素/数据输入 |
| m_axis | 输出 | AXI4-Stream Master | DATA_WIDTH bit | 移位后数据输出 |
| clk | 输入 | - | - | 单一时钟 |
| rstn | 输入 | 同步复位 | - | 低有效 |

### 1.5 可配置参数

| 参数名 | 默认值 | 范围 | 说明 |
|--------|--------|------|------|
| DATA_WIDTH | 8 | 1..32 | 每个数据元素的位宽 |
| MAX_ROWS | 64 | 1..1024 | 最大图像行数 |
| MAX_COLS | 64 | 1..1024 | 最大图像列数 |
| AXIL_ADDR_WIDTH | 32 | 32 | AXI-Lite 地址位宽 |
| AXIL_DATA_WIDTH | 32 | 32 | AXI-Lite 数据位宽 |

### 1.6 性能目标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 时钟频率 | 100 MHz（典型值） | 可综合至 Artix-7 / Cyclone V 级别 |
| 数据吞吐率 | 1 element / cycle | 采集阶段和输出阶段各自达到 1 拍 1 元素 |
| 全帧延迟 | IMG_ROWS x IMG_COLS + 10 周期 | 先收完整帧再输出 |
| 资源预算 | < 2 个 BRAM36K（64x64 默认配置） | 帧缓冲使用单口/双口 BRAM |
| 资源预算 | < 500 LUT + < 300 FF | 控制逻辑和 AXI-Lite 接口 |

### 1.7 验证目标

| 级别 | 目标 |
|------|------|
| L0 | 静态审查通过 |
| L1 | 仿真验证：所有测试用例通过 |
| L2–L7 | 后续阶段（本 task 仅到 L0） |

## 2. 范围边界

### 2.1 范围内

- 2D 数据阵列的 UP / DOWN / LEFT / RIGHT 移位
- 补零模式与缠绕模式
- AXI4-Lite 寄存器接口（配置 / 控制 / 状态）
- AXI4-Stream 数据输入输出
- 帧缓冲模式（先存后读）
- 同步复位，单时钟域

### 2.2 范围外（后续版本可扩展）

- 非矩形图像（如任意形状 ROI）
- 多通道数据（RGB / 多波段）
- AXI4 full 接口（直接内存读写）
- 流水线直通模式（无帧缓冲，仅限部分方向）
- 多个 2D shift 模块级联
- 异步时钟域、多时钟域

## 3. 接口列表

### 3.1 时钟与复位

| 信号 | 位宽 | 方向 | 说明 |
|------|------|------|------|
| clk | 1 | input | 主时钟，所有逻辑的同步时钟 |
| rstn | 1 | input | 同步复位，低有效 |


### 3.2 AXI4-Lite Slave 接口

| 信号 | 位宽 | 方向 | 说明 |
|------|------|------|------|
| s_axil_awaddr | AXIL_ADDR_WIDTH | input | 写地址 |
| s_axil_awvalid | 1 | input | 写地址有效 |
| s_axil_awready | 1 | output | 写地址就绪 |
| s_axil_wdata | AXIL_DATA_WIDTH | input | 写数据 |
| s_axil_wstrb | AXIL_DATA_WIDTH/8 | input | 写选通 |
| s_axil_wvalid | 1 | input | 写数据有效 |
| s_axil_wready | 1 | output | 写数据就绪 |
| s_axil_bresp | 2 | output | 写响应 |
| s_axil_bvalid | 1 | output | 写响应有效 |
| s_axil_bready | 1 | input | 写响应就绪 |
| s_axil_araddr | AXIL_ADDR_WIDTH | input | 读地址 |
| s_axil_arvalid | 1 | input | 读地址有效 |
| s_axil_arready | 1 | output | 读地址就绪 |
| s_axil_rdata | AXIL_DATA_WIDTH | output | 读数据 |
| s_axil_rresp | 2 | output | 读响应 |
| s_axil_rvalid | 1 | output | 读数据有效 |
| s_axil_rready | 1 | input | 读数据就绪 |

### 3.3 AXI4-Stream Slave 接口（数据输入）

| 信号 | 位宽 | 方向 | 说明 |
|------|------|------|------|
| s_axis_tdata | DATA_WIDTH | input | 输入数据 |
| s_axis_tvalid | 1 | input | 输入数据有效 |
| s_axis_tready | 1 | output | 输入数据就绪 |
| s_axis_tlast | 1 | input | 行结束标志（每行最后一个元素） |
| s_axis_tuser | 1 | input | 帧开始标志（每帧第一个元素） |

### 3.4 AXI4-Stream Master 接口（数据输出）

| 信号 | 位宽 | 方向 | 说明 |
|------|------|------|------|
| m_axis_tdata | DATA_WIDTH | output | 输出数据 |
| m_axis_tvalid | 1 | output | 输出数据有效 |
| m_axis_tready | 1 | input | 输出数据就绪 |
| m_axis_tlast | 1 | output | 行结束标志 |
| m_axis_tuser | 1 | output | 帧开始标志 |

## 4. 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| BRAM 资源超限 | 大尺寸图像无法容纳 | 默认 MAX_ROWS/COLS=64 控制 BRAM 用量；参数化设计 |
| 吞吐率不匹配 | 输入/输出速率受对端影响 | AXI-Stream 握手机制天然支持背压 |
| 移位溢出 | 步长大于图像维度 | 寄存器配置时软件保证或硬件截断 |
