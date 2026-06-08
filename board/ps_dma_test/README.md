# axil_2d_shift PS DMA 测试程序

## 概述

本程序是 axil_2d_shift 加速器的 PS (ARM Cortex-A9) 端测试程序，用于验证：

1. **AXI-Lite 寄存器访问**：通过 PS M_AXI_GP0 读写加速器寄存器
2. **AXI DMA 数据传输**：MM2S (DDR→Stream) + S2MM (Stream→DDR) 全双工传输
3. **加速器数据通路**：DMA→加速器→DMA 的数据环回正确性

### 硬件平台

- 开发板：Alinx AX7010 (xc7z010clg400-1)
- 比特流：`vivado/shift_2d_ax7010_260608/xsa_export/design_1_wrapper.bit`
- XSA 硬件定义：`vivado/shift_2d_ax7010_260608/xsa_export/design_1_wrapper.xsa`
- PL 时钟：50 MHz (PS FCLK_CLK0)

### 软件工具

- Vitis 2022.2
- Xilinx Standalone BSP (无 Linux)
- 串口终端：115200-8N1

---

## 目录结构

```
board/ps_dma_test/
  README.md               -- 本文件
  src/
    main.c                -- 主程序入口 + 测试流程编排
    axil_utils.h          -- AXI-Lite 寄存器读写 API
    axil_utils.c          -- AXI-Lite 寄存器读写实现
    dma_utils.h           -- AXI DMA 驱动 API
    dma_utils.c           -- AXI DMA 驱动实现 (含 ISR)
    test_patterns.h       -- 测试数据生成 API
    test_patterns.c       -- 测试数据生成与验证实现
```

---

## Vitis 工程创建步骤

### 1. 创建 Platform 工程

1. 启动 Vitis 2022.2
2. File → New → Platform Project
3. Project name: `ax7010_ps_dma_platform`
4. Create from hardware specification (XSA): 选择 `design_1_wrapper.xsa`
5. Operating System: `standalone`
6. Processor: `ps7_cortexa9_0`
7. Finish

Vitis 将自动生成 BSP 和 `xparameters.h`。

**检查 xparameters.h 中的宏名称**：
编译前必须确认以下宏在 BSP 的 xparameters.h 中存在：

```
XPAR_AXIL_2D_SHIFT_0_S_AXI_BASEADDR      -- 加速器基地址 (预期 0x43C0_0000)
XPAR_AXI_DMA_0_DEVICE_ID                  -- DMA 设备 ID (预期 0)
XPAR_AXI_DMA_0_BASEADDR                   -- DMA 基地址 (预期 0x43C1_0000)
XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR   -- S2MM 中断 ID (预期 61)
XPAR_SCUGIC_SINGLE_DEVICE_ID              -- GIC 设备 ID
```

如果宏名不匹配（例如因为 IP 接口名导致宏名不同），需更新 `main.c` 中的 `#define`。

### 2. 创建 Application 工程

1. 在 Vitis 中：File → New → Application Project
2. Platform: 选择刚才创建的 `ax7010_ps_dma_platform`
3. Project name: `ps_dma_test`
4. Domain: `standalone_on_ps7_cortexa9_0`
5. Template: **Empty Application (C)**
6. Finish

### 3. 添加源码文件

将 `board/ps_dma_test/src/` 下的所有 `.c` 和 `.h` 文件复制到 Application 工程的 `src/` 目录：

```
ps_dma_test/
  src/
    main.c
    axil_utils.c
    axil_utils.h
    dma_utils.c
    dma_utils.h
    test_patterns.c
    test_patterns.h
```

在 Vitis 中，右键 `src/` → Refresh，文件自动加入工程。

### 4. 编译

1. 确保 BSP 已配置正确（右键 platform → Build Project）
2. 右键 `ps_dma_test` → Build Project
3. 预期编译无错误，生成可执行文件 `ps_dma_test.elf`

**常见编译错误**：

| 错误 | 原因 | 解决 |
|------|------|------|
| `XPAR_AXIL_2D_SHIFT_0_S_AXI_BASEADDR` 未定义 | xparameters.h 中宏名不同 | 搜索 `axil_2d_shift` 找到正确的宏名, 更新 main.c |
| `XAxiDma_CfgInitialize` 参数不匹配 | 驱动版本差异 | 检查 xaxidma.h 中函数原型, 调整参数 |
| `Xil_DCacheFlushRange` 未定义 | 缺少 xil_cache.h | 确认 BSP 包含 xilcache 库 |

---

## 烧写与运行

### 方法一：通过 Vitis （推荐）

1. 连接 AX7010：USB Type-C 连接 PC（JTAG + UART 共用）
2. 设置启动模式：JTAG (SW1=ON, SW0=ON)
3. 打开 UART 终端：115200-8N1
4. 在 Vitis 中：右键 `ps_dma_test` → Run As → Launch on Hardware (Single Application Debug)
5. Vitis 自动下载比特流并运行程序

### 方法二：通过 XSCT 命令行

```tcl
# 连接目标
connect

# 目标列表 (确认 ARM Cortex-A9)
targets

# 选择 APU
targets 2

# 复位 PS
rst -processor

# 下载比特流
fpga {path/to/design_1_wrapper.bit}

# 下载 ELF
dow {path/to/ps_dma_test.elf}

# 运行
con
```

### 方法三：通过 Vivado Hardware Manager + XSCT

1. Vivado: Open Hardware Manager → Program device (选择比特流)
2. XSCT: `connect` → `targets` → `dow ps_dma_test.elf` → `con`

---

## 预期输出

正确运行后, UART 终端应输出如下内容 (伪代码格式):

```
========================================
  axil_2d_shift PS DMA Test Program
  Platform: AX7010 (xc7z010clg400-1)
  PL Clock: 50 MHz
========================================

--- Phase 1: Platform Init ---
  [INFO] Data cache enabled

--- Phase 2: Interrupt Controller ---
  [INFO] GIC initialized (base=0xF8F01000)

--- Phase 3: AXI DMA Init ---
  [INFO] DMA initialized: dev_id=0, base=0x43C10000

--- Phase 4: DMA Interrupt ---
  [INFO] S2MM interrupt connected (IRQ_ID=61)

--- Phase 5: Register Test ---
=== AXI-Lite Register Test ===
  Accelerator base: 0x43C00000
  [PASS] CFG: wrote 0x00000105, read 0x00000105
  [PASS] IMG_ROWS: wrote 32, read 32
  [PASS] IMG_COLS: wrote 32, read 32
  [INFO] STATUS = 0x00000001 (RO register)
  [INFO] CTRL  = 0x00000000 (WO register, expect 0)
>>> AXI-Lite Register Test: PASS
  ... register dump ...

--- Phase 6a: Increment Pattern ---
  ... DMA transfer ...
>>> PASS: all 1024 bytes match

--- Phase 6b: Checkerboard Pattern ---
  ... DMA transfer ...
>>> PASS: all 1024 bytes match

...

========================================
  ALL TESTS PASSED
  axil_2d_shift DMA path verified
  Ready for shift validation (L6)
========================================
```

### 失败情况

如果 DMA 环回测试失败 (mismatch):

```
>>> FAIL: mismatch at byte 33
  [   33] exp=0x21  act=0x00 <-- FIRST
```

可能原因：

| 现象 | 可能原因 | 排查方向 |
|------|---------|---------|
| 前 32 字节匹配，之后全 0 | accelerator 只处理了一行 | 检查 IMG_COLS 配置是否正确 |
| 所有数据偏移 N 字节 | stream 数据对齐问题 | 检查 DMA/accelerator 数据宽度 |
| 随机 mismatch | cache 一致性未正确处理 | 检查 Xil_DCacheFlushRange/InvalidateRange |
| DMA 超时 | HP0 路径不通或 DMA 配置错误 | 检查 XSA 中 DMA 和 HP0 连接 |
| STATUS 始终 IDLE | AXI-Lite 地址错误 | 验证 ACCEL_BASEADDR 宏值 |

---

## 串口终端设置

| 参数 | 值 |
|------|-----|
| 波特率 | 115200 |
| 数据位 | 8 |
| 停止位 | 1 |
| 校验位 | None |
| 流控 | None |

推荐终端软件：Tera Term, PuTTY, VS Code Serial Monitor。

---

## 扩展与调试

### 修改测试参数

在 `main.c` 中修改以下宏：

```c
#define TEST_ROWS   32   // 测试图像行数
#define TEST_COLS   32   // 测试图像列数
#define TIMEOUT_MS  5000 // DMA 超时 (ms)
```

### 添加新的移位方向测试

在 `main.c` 的 Phase 6 中添加：

```c
// 例: LEFT 方向, step=1
fill_pattern_increment(ping_buf, TEST_FRAME_SIZE);
dma_loopback_test("LEFT step=1", ACCEL_BASEADDR,
                  ping_buf, pong_buf,
                  TEST_ROWS, TEST_COLS,
                  ACCEL_DIR_LEFT, 1);
```

### ILA 调试配合

在程序执行到 `axil_start()` 后，ILA 应在加速器内部捕获到：

| 信号 | 预期行为 |
|------|---------|
| `capture_en` | 置 1 (采集使能) |
| `s_axis_tvalid` | MM2S 数据到达时置 1 |
| `s_axis_tdata` | 与 ping_buf 内容一致 |
| `shift_en` | capture_done 后置 1 |
| `m_axis_tdata` | 移位后输出 (pass-through 模式应与输入一致) |
| `shift_done` | 输出完成后置 1 |
| `status_done` | 加速器完成置 1 |
