// dma_utils.h — AXI DMA 驱动工具 (Simple DMA 模式)
//
// 使用 XAxiDma 驱动库驱动 AXI DMA (xilinx.com:ip:axi_dma:7.1)。
// 配置: Simple DMA, MM2S+S2MM, 8-bit stream, s2mm_introut → PS IRQ_F2P[0]
//
// 数据流:
//   DDR ←HP0→ [AXI SmartConnect] ←MM2S/S2MM→ [AXI DMA] ←stream→ [accelerator]
//
// 在 xparameters.h 中查找的宏:
//   XPAR_AXI_DMA_0_DEVICE_ID             — DMA 设备 ID (通常为 0)
//   XPAR_AXI_DMA_0_BASEADDR              — DMA 控制寄存器基地址 (预期 0x43C1_0000)
//   XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR — S2MM 中断 ID (预期 61)

#ifndef DMA_UTILS_H
#define DMA_UTILS_H

#include "xil_types.h"
#include "xaxidma.h"

// ============================================================================
// DMA 传输方向常量 (封装 XAXIDMA 常量)
// ============================================================================
#define DMA_MM2S  XAXIDMA_DMA_TO_DEVICE   // DDR → AXI-Stream (加速器输入)
#define DMA_S2MM  XAXIDMA_DEVICE_TO_DMA   // AXI-Stream → DDR (加速器输出)

// ============================================================================
// S2MM 中断完成标志 (定义在 main.c, 由 dma_s2mm_isr 设置)
// ============================================================================
extern volatile int g_s2mm_done;

// ============================================================================
// 函数原型
// ============================================================================

// 初始化 AXI DMA 驱动
//   device_id: XPAR_AXI_DMA_0_DEVICE_ID
//   返回 0 = 成功, -1 = 失败
int dma_init(XAxiDma *dma_inst, u16 device_id);

// 启动 MM2S: DDR → AXI-Stream
//   src_addr: DDR 源地址 (需 cache flush 后)
//   len: 传输字节数
int dma_mm2s_start(XAxiDma *dma_inst, u32 src_addr, u32 len);

// 启动 S2MM: AXI-Stream → DDR
//   dst_addr: DDR 目的地址 (需 cache invalidate 后)
//   len: 传输字节数
int dma_s2mm_start(XAxiDma *dma_inst, u32 dst_addr, u32 len);

// 查询传输状态 (返回 1=忙, 0=空闲)
int dma_mm2s_is_busy(XAxiDma *dma_inst);
int dma_s2mm_is_busy(XAxiDma *dma_inst);

// 轮询等待传输完成 (返回 0=完成, -1=超时)
int dma_wait_for_s2mm_done(XAxiDma *dma_inst, u32 timeout_ms);
int dma_wait_for_mm2s_done(XAxiDma *dma_inst, u32 timeout_ms);

// 复位 DMA 引擎 (返回 0=成功, -1=失败)
int dma_reset(XAxiDma *dma_inst);

// S2MM 中断服务例程 (由 XScuGic 调用)
void dma_s2mm_isr(void *callback_ref);

#endif /* DMA_UTILS_H */
