# AX7010 硬件操作手册

> Alinx AX7010 开发板 (xc7z010clg400-1) 上板验证操作指南
> 最后更新: 2026-06-08

## 1. 板卡识别

- 型号：Alinx AX7010
- 主芯片：Xilinx Zynq-7000 xc7z010clg400-1
- PS：Dual ARM Cortex-A9 @ 667MHz
- PL：Artix-7 架构，28K LUT, 240 DSP48E1, 17 BRAM (36Kb)
- DDR3：512MB (2片 MT41J256M16)
- 参考文档：Alinx AX7010 User Manual v1.1

## 2. 电源

- 输入：DC 5V / 2A (USB Type-C 或 DC 圆口 3.5mm)
- 上电后 POWER LED (D1) 亮红色
- 测量点：TP1 (5V), TP2 (3.3V), TP3 (1.8V), TP4 (1.0V)
- 注意：仅 USB 供电不足 5V/2A 时将导致 PL 部分异常，请使用配套电源适配器

## 3. JTAG 连接

- 接口：板载 USB-JTAG (FT2232H, 双通道)
- 连接：USB Type-C 线连接 PC（与 UART 共用）
- 驱动：Vivado 安装时自动安装 FTDI D2XX 驱动
- Windows 设备管理器检查：Ports (COM & LPT) → FTDI FT2232H 双端口

### JTAG 链检测流程

```tcl
# Vivado Tcl 检测脚本 (Hardware Manager)
## Step 1: 启动 Hardware Manager
open_hw_manager
connect_hw_server

## Step 2: 列出可用目标
get_hw_targets
## 预期输出: localhost:3121/xilinx_tcf/Digilent/xxxxxxxxxxxx

## Step 3: 打开目标
open_hw_target [lindex [get_hw_targets] 0]

## Step 4: 列出器件
current_hw_device [lindex [get_hw_devices] 0]
## 预期输出: xc7z010_0

## Step 5: 读取 IDCODE (验证 JTAG 连接)
get_property IDCODE [get_hw_devices xc7z010_0]
## 预期: 0x23727093 (Zynq-7010)

## Step 6: 下载比特流
set_property PROGRAM.FILE {path/to/top.bit} [get_hw_devices xc7z010_0]
program_hw_devices [get_hw_devices xc7z010_0]
```

### JTAG 连接故障排查

| 现象 | 可能原因 | 解决 |
|------|---------|------|
| `get_hw_targets` 返回空 | USB 线未插或驱动问题 | 检查设备管理器中 FTDI 设备 |
| `open_hw_target` 超时 | JTAG 时钟频率过高 | `set_property PARAM.FREQUENCY 6000000 [get_hw_targets]` |
| 检测到器件但 ID 不匹配 | 板卡上电异常 | 测量 TP1-TP4 电压 |
| Hardware Manager 报 "No JTAG chain" | 启动模式不在 JTAG | 检查 SW1/SW0 (应均为 0) |
| "connect_hw_server" 失败 | Vivado hw_server 未启动 | 从 Vivado 内重试，或手动启动 `hw_server` |

## 4. UART 串口

- 接口：板载 USB-UART (CP2102, Silicon Labs)
- 连接：与 JTAG 共用同一 USB Type-C 口（复合设备）
- 串口参数：115200 baud, 8 data bits, 1 stop bit, no parity
- Windows 识别：设备管理器 → 端口 → Silicon Labs CP210x USB to UART Bridge (COMx)
- 推荐终端：Tera Term / PuTTY / VS Code Serial Monitor

### UART 验证方法

连接串口终端后，PS 启动会输出 BootROM 信息。如无输出：
1. 确认 COM 端口号正确
2. 确认波特率为 115200
3. 按一下 PS_RST 按键 (KEY_RST, 靠近电源口)
4. 如果仍无输出，检查 SW1/SW0 是否在 JTAG 模式

## 5. 启动模式

启动模式由 2 位拨码开关设置（SW1 和 SW0，靠近 JTAG 口，上方标记 ON=0, OFF=1）：

| 模式 | SW1 | SW0 | 说明 |
|------|:--:|:--:|------|
| JTAG | 0 (ON) | 0 (ON) | 上板验证使用此模式 |
| QSPI | 0 (ON) | 1 (OFF) | 从板载 QSPI Flash 启动 |
| SD Card | 1 (OFF) | 0 (ON) | 从 SD 卡启动 |

上板验证时使用 JTAG 模式（两个开关均拨到 ON/LOW 位置，靠近 PCB 标记 ON 侧）。

## 6. 时钟

- PS 系统时钟：33.333333 MHz (板载晶振, Y1)
- PL 时钟：50 MHz (PS FCLK_CLK0，来自 IO_PLL)
  - PS7 配置：PCW_FPGA0_PERIPHERAL_FREQMHZ = 50
  - 源：1000MHz / 5 / 4 = 50MHz
  - CLK_DOMAIN: design_1_processing_system7_0_0_FCLK_CLK0
- PL 备用时钟：板载 50 MHz 有源晶振 (Y2, 连至 PL K17 引脚, 未使用)

上板验证使用 PS FCLK_CLK0 50MHz，已在 BD 中配置，无需额外设置。

## 7. LED 和按键

| 元件 | 功能 | 连接 | 电平 |
|------|------|------|:----:|
| D1 | 电源指示 (红) | 3.3V | 常亮 |
| D2 | PL LED (绿) | PL N1 (IO_L23P_T3) | 高亮 |
| D3 | PL LED (绿) | PL M14 (IO_L23N_T3) | 高亮 |
| D4 | PS LED (绿) | PS MIO0 | GPIO 控制 |
| KEY1 | PL 按键 | PL G15 (IO_L4P_T0) | 按下=低 |
| KEY2 | PL 按键 | PL H16 (IO_L4N_T0) | 按下=低 |
| PS_RST | PS 复位按键 | PS_SRST_B | 按下复位 |

D2/D3/KEY1/KEY2 可用于上板冒烟测试的基本 I/O 验证。

## 8. Vivado 调试配置

### 8.1 System ILA 探针连接 (MARK_DEBUG)

本设计使用两个 System ILA 核，预配置在 BD 中但探针浮空。
通过 `constraints/debug.xdc` 中的 MARK_DEBUG 属性连接信号。

**探针分配方案:**

| System ILA | 监控对象 | 信号列表 |
|:----------:|----------|----------|
| system_ila_0 | AXI 控制面 | wr_strobe[15:0], rd_strobe[15:0], wdata[31:0], rdata[31:0], ctrl_start, ctrl_sw_reset, cfg_dir[2:0], cfg_step[4:0], cfg_wrap_en, img_rows[9:0], img_cols[9:0], status_idle, status_busy_capture, status_busy_shift, status_done |
| system_ila_1 | 数据通路 | s_axis_tdata[7:0], s_axis_tvalid, s_axis_tready, s_axis_tlast, s_axis_tuser, m_axis_tdata[7:0], m_axis_tvalid, m_axis_tready, m_axis_tlast, m_axis_tuser, capture_en, shift_en, shift_en_ao, capture_done, shift_done, write_addr[11:0], write_data[7:0], write_en, read_addr[11:0], read_data[7:0], zero_fill, zero_fill_d1 |

### 8.2 debug.xdc 使用方法

```tcl
# 在 Vivado Tcl Console 中添加调试约束文件
add_files -fileset constrs_1 -norecurse {D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/constraints/debug.xdc}
set_property PROCESSING_ORDER LATE [get_files constraints/debug.xdc]
set_property used_in_synthesis true [get_files constraints/debug.xdc]
set_property used_in_implementation true [get_files constraints/debug.xdc]

# 或通过 GUI: Add Sources → Add or Create Constraints → 选择 debug.xdc
```

### 8.3 综合后验证探针连接

MARK_DEBUG 信号在综合链接阶段被解析。综合后在 Vivado 中验证:

```tcl
open_run synth_1

# 检查 MARK_DEBUG 信号列表
get_nets -hierarchical -filter {MARK_DEBUG == 1}

# 检查特定路径
get_nets -hierarchical -filter {NAME =~ *axil_2d_shift_0*ctrl_start*}

# 打开综合网表查看 Debug 窗口
# GUI: Window → Debug → 应看到所有 MARK_DEBUG 信号
```

### 8.4 调试比特流生成流程

```tcl
# 完整流程 (从项目打开开始)
## Step 1: 添加 debug.xdc
add_files -fileset constrs_1 constraints/debug.xdc
set_property PROCESSING_ORDER LATE [get_files constraints/debug.xdc]

## Step 2: 重综合
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1

## Step 3: 重实现 + 生成比特流
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

## Step 4: 验证比特流
file stat <project>/design_1_wrapper.bit
```

### 8.5 MARK_DEBUG 路径未解析的应对

如果综合后 MARK_DEBUG 信号未出现 (因 OOC IP 内部层次路径差异):

```tcl
# 方法 1: 查找 OOC IP 的实际层次
open_run synth_1
# 显示所有例化单元
report_cell -hierarchical -cells [get_cells -hierarchical -filter {NAME =~ *axil_2d_shift*}]

# 方法 2: 使用扁平名搜索
get_nets -hierarchical -filter {NAME =~ *wr_strobe*}

# 方法 3: 更新 debug.xdc 后重新打开 synth_1
# 修改 debug.xdc 中的层次前缀后重新打开 synth_1:
open_run synth_1
reset_run synth_1
launch_runs synth_1
```

## 9. XSCT (Xilinx Software Command-line Tool) 快速参考

```tcl
# 连接 PS
connect
# 预期: tcfchan:0

# 目标列表
targets
# 预期: 1 ARM Cortex-A9 MP (APU)

# 停止 CPU
stop

# 读写地址 (DDR)
mrd {address} {word_count}
mwr {address} {value}

# 复位 PS
rst -processor

# 下载 FSBL 或裸机程序
dow program.elf
con
```

## 10. 验证检查清单

**上板前：**
- [ ] 电源适配器 5V/2A 已连接
- [ ] USB Type-C 线连接 PC
- [ ] 启动模式开关：JTAG (SW1=ON, SW0=ON)
- [ ] UART 终端已打开 (115200-8N1)
- [ ] POWER LED (D1) 亮起

**上板后：**
- [ ] Vivado Hardware Manager 检测到 xc7z010
- [ ] JTAG IDCODE 读取正确 (0x23727093)
- [ ] 比特流下载成功 (program_hw_devices 无报错)
- [ ] ILA 波形可触发和捕获
- [ ] PS 可通过 XSCT 连接 (connect 命令)
- [ ] UART 终端有 BootROM 输出

**调试比特流生成：**
- [ ] debug.xdc 已加入项目约束集
- [ ] PROCESSING_ORDER 设为 LATE
- [ ] 重综合完成 (synth_1 成功)
- [ ] MARK_DEBUG 信号列表确认 (get_nets -filter MARK_DEBUG)
- [ ] 重实现完成 (impl_1 成功)
- [ ] 比特流生成完成 (write_bitstream 成功)
- [ ] 无时序违规 (WNS >= 0)

## 11. 板卡原理图参考

如需调试板载外设连接，可查阅 Alinx AX7010 原理图 (文件名: AX7010_Sheets.pdf)：
- Sheet 1: 系统框图
- Sheet 2: 电源树
- Sheet 3: Zynq-7000 核心
- Sheet 4: DDR3 存储器
- Sheet 5: QSPI Flash + SD 卡
- Sheet 6: 板载外设 (USB/UART/LED/按键)
- Sheet 7: FMC 连接器 (未使用)
- Sheet 8: HDMI 接口 (未使用)
