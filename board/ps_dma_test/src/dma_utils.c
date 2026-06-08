// dma_utils.c — AXI DMA 驱动实现
//
// 基于 XAxiDma 驱动库, Simple DMA 模式。
// 使用 Xil_DCacheFlushRange / Xil_DCacheInvalidateRange 处理 cache 一致性。
//
// 注意:
//   - MM2S 传输前必须 Xil_DCacheFlushRange 源缓冲区
//   - S2MM 传输后必须 Xil_DCacheInvalidateRange 目的缓冲区
//   - DMA 缓冲区需 32 字节对齐 (Cortex-A9 cache line)

#include "dma_utils.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "xparameters.h"

/* DMA 基地址 (来自 xparameters.h, 预期 0x43C1_0000) */
#ifndef XPAR_AXI_DMA_0_BASEADDR
#warning "XPAR_AXI_DMA_0_BASEADDR not defined, check xparameters.h"
#define XPAR_AXI_DMA_0_BASEADDR 0x43C10000U
#endif

// ============================================================================
// 初始化 AXI DMA 驱动
//   1. 查找 DMA 配置 (xparameters.h)
//   2. 初始化驱动实例
//   3. 验证为 Simple DMA 模式 (非 Scatter Gather)
// ============================================================================

int dma_init(XAxiDma *dma_inst, u16 device_id)
{
    XAxiDma_Config *cfg;

    cfg = XAxiDma_LookupConfig(device_id);
    if (!cfg) {
        xil_printf("  [ERR] DMA_LookupConfig failed (dev_id=%d)\r\n", device_id);
        return -1;
    }

    int status = XAxiDma_CfgInitialize(dma_inst, cfg);
    if (status != XST_SUCCESS) {
        xil_printf("  [ERR] DMA_CfgInitialize failed: %d\r\n", status);
        return -1;
    }

    // 检查是否为 Simple DMA 模式 (非 Scatter Gather)
    if (XAxiDma_HasSg(dma_inst)) {
        xil_printf("  [ERR] DMA is in Scatter Gather mode, expected Simple DMA\r\n");
        return -1;
    }

    xil_printf("  [INFO] DMA initialized: dev_id=%d, base=0x%08x\r\n",
               device_id, XPAR_AXI_DMA_0_BASEADDR);
    return 0;
}

// ============================================================================
// 启动 MM2S 传输
//   src_addr: DDR 中的源数据缓冲区物理地址
//   len: 传输字节数 (与图像尺寸 rows*cols 一致)
//   注意: 调用前需已执行 Xil_DCacheFlushRange(src_addr, len)
// ============================================================================

int dma_mm2s_start(XAxiDma *dma_inst, u32 src_addr, u32 len)
{
    int status = XAxiDma_SimpleTransfer(dma_inst, (UINTPTR)src_addr, len,
                                        XAXIDMA_DMA_TO_DEVICE);
    if (status != XST_SUCCESS) {
        xil_printf("  [ERR] MM2S_SimpleTransfer failed: %d\r\n", status);
        return -1;
    }
    return 0;
}

// ============================================================================
// 启动 S2MM 传输
//   dst_addr: DDR 中的目的缓冲区物理地址
//   len: 传输字节数 (与图像尺寸 rows*cols 一致)
//   注意: 传输完成后需执行 Xil_DCacheInvalidateRange(dst_addr, len)
//         否则 CPU 可能读到 stale cache 数据
// ============================================================================

int dma_s2mm_start(XAxiDma *dma_inst, u32 dst_addr, u32 len)
{
    int status = XAxiDma_SimpleTransfer(dma_inst, (UINTPTR)dst_addr, len,
                                        XAXIDMA_DEVICE_TO_DMA);
    if (status != XST_SUCCESS) {
        xil_printf("  [ERR] S2MM_SimpleTransfer failed: %d\r\n", status);
        return -1;
    }
    return 0;
}

// ============================================================================
// 查询 DMA 通道忙闲状态
//   返回: 1 = 传输进行中 (忙), 0 = 空闲
// ============================================================================

int dma_mm2s_is_busy(XAxiDma *dma_inst)
{
    return XAxiDma_Busy(dma_inst, XAXIDMA_DMA_TO_DEVICE);
}

int dma_s2mm_is_busy(XAxiDma *dma_inst)
{
    return XAxiDma_Busy(dma_inst, XAXIDMA_DEVICE_TO_DMA);
}

// ============================================================================
// 轮询等待传输完成
//   返回: 0 = 完成, -1 = 超时
//   在 50 MHz 下每次轮询约 1 us
// ============================================================================

int dma_wait_for_s2mm_done(XAxiDma *dma_inst, u32 timeout_ms)
{
    u32 polls = timeout_ms * 1000;
    while (polls--) {
        if (!XAxiDma_Busy(dma_inst, XAXIDMA_DEVICE_TO_DMA)) {
            return 0;
        }
        for (volatile u32 d = 0; d < 50; d++);  // ~1 us
    }
    return -1;
}

int dma_wait_for_mm2s_done(XAxiDma *dma_inst, u32 timeout_ms)
{
    u32 polls = timeout_ms * 1000;
    while (polls--) {
        if (!XAxiDma_Busy(dma_inst, XAXIDMA_DMA_TO_DEVICE)) {
            return 0;
        }
        for (volatile u32 d = 0; d < 50; d++);  // ~1 us
    }
    return -1;
}

// ============================================================================
// DMA 复位
//   1. 触发复位
//   2. 等待复位完成 (超时 1s)
//   返回: 0 = 成功, -1 = 失败
// ============================================================================

int dma_reset(XAxiDma *dma_inst)
{
    XAxiDma_Reset(dma_inst);

    // 等待复位完成
    u32 timeout = 1000000;  // ~1s
    while (timeout--) {
        if (XAxiDma_ResetIsDone(dma_inst)) {
            xil_printf("  [INFO] DMA reset done\r\n");
            return 0;
        }
    }
    xil_printf("  [ERR] DMA reset timeout\r\n");
    return -1;
}

// ============================================================================
// S2MM 中断服务例程
//   当 S2MM 传输完成或发生错误时由 GIC 调用。
//   设置 g_s2mm_done 标志, 主循环轮询此标志。
//
//   callback_ref: 指向 XAxiDma 实例的指针
// ============================================================================

void dma_s2mm_isr(void *callback_ref)
{
    XAxiDma *dma_inst = (XAxiDma *)callback_ref;
    u32 irq_status;

    // 获取并应答 S2MM 中断
    irq_status = XAxiDma_IntrGetIrq(dma_inst, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrAckIrq(dma_inst, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

    // 错误报告
    if (irq_status & XAXIDMA_IRQ_ERROR_MASK) {
        xil_printf("  [ISR] S2MM error: 0x%08x\r\n", irq_status);
    }

    // 传输完成 (IOC = Interrupt On Completion)
    if (irq_status & XAXIDMA_IRQ_IOC_MASK) {
        g_s2mm_done = 1;
    }
}
