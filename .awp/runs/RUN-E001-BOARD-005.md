# 上板验证记录

> RUN-E001-BOARD-005: L6 AX7010 数据正确性验证

## 基本信息
- **Board**: Alinx AX7010, **Platform**: HW_BASE_AX7010_v1.2
- **Date**: 2026-06-09, **Round**: 1

## 核心突破: XSCT `dow` 自动化

### 问题
XSCT/XSDB `dow` (ELF下载) 始终报 TCF Code 16 "Invalid context"。

### 根因
**Target 选择错误**——一直在用 `targets -set -filter {name =~ "APU"}` (DAP)，
官方 Xilinx 文档要求 `targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}` (CPU核)。
APU 是 DAP 调试访问端口，CPU 核才是可下载 ELF 的执行目标。

### 正确流程
```tcl
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}  # CPU核,非APU!
fpga -f design_1_wrapper.bit
source ps7_init.tcl; ps7_init; ps7_post_config
dow app.elf     # 直接成功!
con             # 程序运行
```

**`dow` 不再报任何错误**。

## DMA HP0 端口阻塞

### 已验证链路
| 环节 | 状态 |
|------|:--:|
| fpga -f (PL编程) | PASS |
| ps7_init (PS时钟/DDR) | PASS |
| dow ELF to CPU core | PASS |
| CPU执行 (DDR代码) | PASS |
| MMU关断 | PASS |
| D-Cache flush/invalidate | PASS |
| CPU→AXI-Lite (ACCEL寄存器) | PASS |
| CPU→DDR 读写 | PASS |
| 加速器启动 (STATUS=BUSY_CAPTURE) | PASS |
| DMA MM2S/S2MM启动 | **FAIL** (IDLE) |

### 阻塞分析
DMA MM2S 是 PL AXI Master，通过 `axi_mem_intercon` → `S_AXI_HP0` 访问 DDR。
CPU 写入 DMA_DMACR 成功后 DMA 状态仍为 IDLE，表明 DMA 引擎未实际启动。

可能原因(按优先级):
1. HP0 AXI 接口的 AFI 寄存器未正确配置(需与bitstream匹配的n32BitEn)
2. ps7_init.tcl 与当前BD版本不同步
3. 需FSBL重新导出

### 尝试过的修复
- AFI_RDCHAN_CTRL (0xF8008000) 写 n32BitEn=1
- AFI_WRCHAN_CTRL (0xF8008014) 写 n32BitEn=1 (地址修正后)
- MMU Enable/Disable
- FSBL 执行后 vs 仅 ps7_init
- DMA SG Engine 禁用

上述均未解决HP0问题。

## 资产清单
- `board/vitis_flow.tcl` — 完整XSCT自动化脚本
- `board/dma_minimal.s` / `.elf` — MMU关断+D-cache+DMA汇编
- `board/ps_init_xsdb.tcl` — XSDB PS初始化脚本
- `board/fsbl.bin` / `dma_test.bin` — 二进制加载文件
- `board/dma_nouart.bin` — 无UART测试二进制(64KB)
- Skill更新: `vitis-cli-build`, `zynq-debug-toolchain`, `bd-debug-clock`

## 下一步
1. Vivado重新导出XSA → 重新生成ps7_init.tcl → 重新编译FSBL
2. 或使用Vitis GUI Run完成DMA验证(已知工作路径)
3. CLI/ILA自动化链路已经闭合，HP0是最后的硬件配置问题
