# ZCU102 硬件操作手册

> Xilinx ZCU102 评估套件 (xczu9eg-ffvb1156-2-e) 上板验证操作指南

## 1. 板卡识别

- 型号：Xilinx ZCU102 Evaluation Kit
- 主芯片：Zynq UltraScale+ MPSoC xczu9eg-ffvb1156-2-e
- PS：Quad ARM Cortex-A53 + Dual ARM Cortex-R5
- DDR4：4GB (PS), 512MB (PL)
- 参考文档：UG1182 ZCU102 Evaluation Board User Guide

## 2. 电源

- 输入：DC 12V / 5A (随板附赠适配器)
- 上电后供电指示灯亮
- 板载 PMBus 电源管理

## 3. JTAG 连接

- 接口：板载 USB-JTAG (FT4232H)
- 连接：USB Micro-AB 线连接 PC 的 JTAG 口 (J2)
- 驱动：需安装 FTDI 驱动（Vivado 自带）

```tcl
# Vivado Tcl 检测脚本
open_hw_manager
connect_hw_server
get_hw_targets
# 预期输出包含 xczu9eg
```

## 4. UART 串口

- 接口：板载 USB-UART (CP2108)
- 连接：USB Micro-AB 线连接 PC 的 UART 口 (J83)
- 串口参数：115200 baud, 8 data bits, 1 stop bit, no parity

## 5. 启动模式

ZCU102 启动模式由 4 位 DIP 开关 (SW6) 设置：

| 模式 | SW6[4:1] | 说明 |
|------|:--:|------|
| JTAG | 0000 | 上板验证使用此模式 |
| QSPI32 | 0100 | 从 QSPI Flash 启动 |
| SD1 | 1001 | 从 SD 卡启动 |

上板验证时 SW6 全部置 OFF (0000 = JTAG mode)。

## 6. 时钟

- PS 参考时钟：33.333333 MHz
- PL 时钟：100 MHz (PS PL_CLK0)
- 板载可编程时钟：SI570 (默认 300 MHz，可编程)

上板验证使用 PS PL_CLK0 100MHz，已在 BD 中配置。

## 7. 与 AX7010 的关键差异

| 特性 | AX7010 | ZCU102 |
|------|--------|--------|
| 器件 | xc7z010-1 | xczu9eg-2-e |
| PS | Cortex-A9 ×2 | Cortex-A53 ×4 + R5 ×2 |
| DDR | DDR3 512MB | DDR4 4GB (PS) |
| 时钟 | 50 MHz | 100 MHz |
| JTAG | 板载 FT2232 | 板载 FT4232 |
| 比特流大小 | ~2 MB | ~26.5 MB |
| ILA 类型 | System ILA 1.1 | ILA 6.2 |

## 8. ZCU102 特定 ILA 配置

ZCU102 BD 使用 ILA 6.2（非 System ILA），探针浮空。
需通过 `constraints/debug_zcu102.xdc` 中的 MARK_DEBUG 属性连接探针。

| ILA 核 | 探针数 | 位宽 | 深度 | 用途 |
|--------|:--:|:--:|:--:|------|
| ila_capture | 9 | 27 | 1024 | 数据捕获路径 |
| ila_shift | 10 | 29 | 1024 | 移位处理路径 |

## 9. 验证检查清单

**上板前**：
- [ ] 12V 电源适配器已连接
- [ ] USB Micro-AB 线连接 JTAG 口 (J2)
- [ ] USB Micro-AB 线连接 UART 口 (J83)
- [ ] SW6 全部 OFF (JTAG 模式)
- [ ] UART 终端已打开 (115200-8N1)

**上板后**：
- [ ] Vivado Hardware Manager 检测到 xczu9eg
- [ ] 比特流下载成功（~26.5 MB，下载约 30 秒）
- [ ] PS 可通过 XSCT 连接
