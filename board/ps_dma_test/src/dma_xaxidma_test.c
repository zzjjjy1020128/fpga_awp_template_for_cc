// Standard DMA test using XAxiDma driver (v9.15) + Vitis BSP
#include <stdio.h>
#include "xil_cache.h"
#include "xil_exception.h"
#include "xscugic.h"
#include "xparameters.h"
#include "xaxidma.h"
#include "xil_mmu.h"

// Hardware addresses from xparameters.h
#define DMA_DEV_ID      XPAR_AXI_DMA_0_DEVICE_ID
#define ACCEL_BASE      XPAR_AXIL_2D_SHIFT_0_BASEADDR
#define S2MM_INTR_ID    XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR

#define TEST_ROWS       32
#define TEST_COLS       32
#define FRAME_SIZE      (TEST_ROWS * TEST_COLS)
#define BUF_ALIGN       32

// Result buffer at known DDR location
volatile unsigned *R = (volatile unsigned*)0x00300000;

XAxiDma     dma_inst;
XScuGic     gic_inst;
volatile int s2mm_done;

u8 ping_buf[FRAME_SIZE] __attribute__((aligned(BUF_ALIGN)));
u8 pong_buf[FRAME_SIZE] __attribute__((aligned(BUF_ALIGN)));

static void s2mm_isr(void *cb) {
    u32 s = XAxiDma_IntrGetIrq((XAxiDma*)cb, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrAckIrq((XAxiDma*)cb, s, XAXIDMA_DEVICE_TO_DMA);
    if (s & XAXIDMA_IRQ_IOC_MASK) s2mm_done = 1;
}

int main(void) {
    int ri = 0, ret;
    R[ri++] = 0xDAAA0001;

    // Phase 1: Platform init
    Xil_DCacheEnable();
    Xil_ICacheEnable();
    Xil_ExceptionEnable();
    R[ri++] = 0xDAAA0002;

    // Phase 2: GIC init
    XScuGic_Config *gcfg = XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
    XScuGic_CfgInitialize(&gic_inst, gcfg, gcfg->CpuBaseAddress);
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
        (Xil_ExceptionHandler)XScuGic_InterruptHandler, &gic_inst);
    R[ri++] = 0xDAAA0003;

    // Phase 3: DMA init
    XAxiDma_Config *dcfg = XAxiDma_LookupConfig(DMA_DEV_ID);
    XAxiDma_CfgInitialize(&dma_inst, dcfg);
    R[ri++] = 0xDAAA0004;

    // Phase 4: DMA interrupt setup
    XScuGic_Disconnect(&gic_inst, S2MM_INTR_ID);
    XScuGic_Connect(&gic_inst, S2MM_INTR_ID,
        (Xil_InterruptHandler)s2mm_isr, &dma_inst);
    XScuGic_Enable(&gic_inst, S2MM_INTR_ID);
    XAxiDma_IntrEnable(&dma_inst, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
    R[ri++] = 0xDAAA0005;

    // Phase 5: Fill ping
    for (int i = 0; i < FRAME_SIZE; i++) ping_buf[i] = (u8)i;
    Xil_DCacheFlushRange((UINTPTR)ping_buf, FRAME_SIZE);
    R[ri++] = 0xDAAA0006;

    // Phase 6: Accelerator SW reset + config (RIGHT step=0 = pass-through)
    *(volatile u32*)(ACCEL_BASE + 0x00) = 2;   // CTRL.sw_reset
    for (volatile int d = 0; d < 1000; d++);
    *(volatile u32*)(ACCEL_BASE + 0x00) = 0;   // Clear reset
    *(volatile u32*)(ACCEL_BASE + 0x08) = 4;   // CFG_DIR=RIGHT
    *(volatile u32*)(ACCEL_BASE + 0x10) = TEST_COLS;
    *(volatile u32*)(ACCEL_BASE + 0x0C) = TEST_ROWS;
    R[ri++] = 0xDAAA0007;
    R[ri++] = *(volatile u32*)(ACCEL_BASE + 4);  // STATUS after reset

    // Phase 7: DMA reset (standard driver flow)
    XAxiDma_Reset(&dma_inst);
    while (!XAxiDma_ResetIsDone(&dma_inst));
    s2mm_done = 0;
    R[ri++] = 0xDAAA0008;

    // Phase 8: Start accelerator → S2MM → MM2S
    *(volatile u32*)(ACCEL_BASE) = 1;  // CTRL.start
    for (volatile int d = 0; d < 100000; d++);

    ret = XAxiDma_SimpleTransfer(&dma_inst, (UINTPTR)pong_buf, FRAME_SIZE, XAXIDMA_DEVICE_TO_DMA);
    R[ri++] = ret;
    ret = XAxiDma_SimpleTransfer(&dma_inst, (UINTPTR)ping_buf, FRAME_SIZE, XAXIDMA_DMA_TO_DEVICE);
    R[ri++] = ret;
    R[ri++] = 0xDAAA0009;  // DMA started

    // Phase 9: Wait
    for (volatile int d = 0; d < 0x800000; d++);
    R[ri++] = 0xDAAA000A;

    // Phase 10: Check results
    R[ri++] = XAxiDma_IntrGetIrq(&dma_inst, XAXIDMA_DEVICE_TO_DMA);
    R[ri++] = XAxiDma_IntrGetIrq(&dma_inst, XAXIDMA_DMA_TO_DEVICE);
    R[ri++] = *(volatile u32*)(ACCEL_BASE + 4);
    // DMA register dump for debug
    R[ri++] = *(volatile u32*)0x40400004;  // MM2S_DMASR
    R[ri++] = *(volatile u32*)0x40400034;  // S2MM_DMASR
    R[ri++] = *(volatile u32*)0x40400018;  // MM2S_SA
    R[ri++] = (u32)ping_buf;                // ping address
    R[ri++] = (u32)pong_buf;                // pong address

    Xil_DCacheInvalidateRange((UINTPTR)pong_buf, FRAME_SIZE);
    int mismatch = -1;
    for (int i = 0; i < FRAME_SIZE; i++) {
        if (ping_buf[i] != pong_buf[i]) { mismatch = i; break; }
    }
    R[ri++] = mismatch;
    R[ri++] = ping_buf[0] | (ping_buf[1]<<8) | (ping_buf[2]<<16) | (ping_buf[3]<<24);
    R[ri++] = pong_buf[0] | (pong_buf[1]<<8) | (pong_buf[2]<<16) | (pong_buf[3]<<24);
    R[ri++] = 0xDAAA9999;
    while(1);
    return 0;
}
