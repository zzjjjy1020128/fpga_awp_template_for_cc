// Gated DMA test: CPU waits at gate until mwr releases it
// Timing: arm ILA → mwr gate=1 → DMA fires → ILA captures
#include <stdio.h>
#include "xil_cache.h"
#include "xil_exception.h"
#include "xscugic.h"
#include "xparameters.h"
#include "xaxidma.h"

#define DMA_DEV_ID      XPAR_AXI_DMA_0_DEVICE_ID
#define ACCEL_BASE      XPAR_AXIL_2D_SHIFT_0_BASEADDR
#define S2MM_INTR_ID    XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR
#define FRAME_SIZE      1024
#define BUF_ALIGN       32

volatile unsigned *R = (volatile unsigned*)0x00300000;
volatile unsigned *GATE = (volatile unsigned*)0x00300100;

XAxiDma     dma_inst;
XScuGic     gic_inst;

u8 ping_buf[FRAME_SIZE] __attribute__((aligned(BUF_ALIGN)));
u8 pong_buf[FRAME_SIZE] __attribute__((aligned(BUF_ALIGN)));

static void s2mm_isr(void *cb) {
    u32 s = XAxiDma_IntrGetIrq((XAxiDma*)cb, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrAckIrq((XAxiDma*)cb, s, XAXIDMA_DEVICE_TO_DMA);
}

int main(void) {
    int ri = 0;
    R[ri++] = 0xDAAD0001;

    Xil_DCacheEnable(); Xil_ICacheEnable();
    Xil_ExceptionEnable();
    R[ri++] = 0xDAAD0002;

    XScuGic_Config *gcfg = XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
    XScuGic_CfgInitialize(&gic_inst, gcfg, gcfg->CpuBaseAddress);
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
        (Xil_ExceptionHandler)XScuGic_InterruptHandler, &gic_inst);
    R[ri++] = 0xDAAD0003;

    XAxiDma_Config *dcfg = XAxiDma_LookupConfig(DMA_DEV_ID);
    XAxiDma_CfgInitialize(&dma_inst, dcfg);
    R[ri++] = 0xDAAD0004;

    // Interrupt
    XScuGic_Connect(&gic_inst, S2MM_INTR_ID,
        (Xil_InterruptHandler)s2mm_isr, &dma_inst);
    XScuGic_Enable(&gic_inst, S2MM_INTR_ID);
    XAxiDma_IntrEnable(&dma_inst, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
    R[ri++] = 0xDAAD0005;

    // Fill ping
    for (int i = 0; i < FRAME_SIZE; i++) ping_buf[i] = (u8)i;
    Xil_DCacheFlushRange((UINTPTR)ping_buf, FRAME_SIZE);
    R[ri++] = 0xDAAD0006;

    // Accel reset + config
    *(volatile u32*)(ACCEL_BASE) = 2; for (volatile int d=0; d<1000; d++);
    *(volatile u32*)(ACCEL_BASE) = 0;
    *(volatile u32*)(ACCEL_BASE + 0x08) = 4;  // RIGHT
    *(volatile u32*)(ACCEL_BASE + 0x10) = 32;
    *(volatile u32*)(ACCEL_BASE + 0x0C) = 32;
    R[ri++] = 0xDAAD0007;

    // DMA reset
    XAxiDma_Reset(&dma_inst); while (!XAxiDma_ResetIsDone(&dma_inst));
    R[ri++] = 0xDAAD0008;

    // Config DMA
    XAxiDma_SimpleTransfer(&dma_inst, (UINTPTR)pong_buf, FRAME_SIZE, XAXIDMA_DEVICE_TO_DMA);
    // MM2S NOT started yet! CPU waits at gate.
    R[ri++] = 0xDAAD0009;  // READY at gate

    // === GATE: wait for mwr 0x300100 = 1 ===
    *GATE = 0;
    Xil_DCacheFlushRange((UINTPTR)GATE, 4);
    R[ri++] = 0xDAAD000A;  // waiting
    while (*GATE == 0) {
        Xil_DCacheInvalidateRange((UINTPTR)GATE, 4);
    }
    R[ri++] = 0xDAAD000B;  // gate passed!

    // Now fire: accelerator + MM2S simultaneously
    *(volatile u32*)(ACCEL_BASE) = 1;  // Start accel
    for (volatile int d=0; d<50000; d++);
    XAxiDma_SimpleTransfer(&dma_inst, (UINTPTR)ping_buf, FRAME_SIZE, XAXIDMA_DMA_TO_DEVICE);
    R[ri++] = 0xDAAD000C;  // DMA fired

    // Wait
    for (volatile int d=0; d<0x800000; d++);
    R[ri++] = 0xDAAD000D;

    // Results
    R[ri++] = XAxiDma_IntrGetIrq(&dma_inst, XAXIDMA_DEVICE_TO_DMA);
    R[ri++] = XAxiDma_IntrGetIrq(&dma_inst, XAXIDMA_DMA_TO_DEVICE);
    R[ri++] = *(volatile u32*)(ACCEL_BASE + 4);
    R[ri++] = *(volatile u32*)0x40400004;
    R[ri++] = *(volatile u32*)0x40400034;

    Xil_DCacheInvalidateRange((UINTPTR)pong_buf, FRAME_SIZE);
    int mismatch = -1;
    // AO output register adds 1-cycle delay: pong[0] is register init value,
    // real pixel data starts at pong[1]. Compare pong[1..1023] vs ping[0..1022].
    for (int i=1; i<FRAME_SIZE; i++) {
        if (ping_buf[i-1] != pong_buf[i]) { mismatch = i; break; }
    }
    R[ri++] = mismatch;
    R[ri++] = ping_buf[0] | (ping_buf[1]<<8) | (ping_buf[2]<<16) | (ping_buf[3]<<24);
    R[ri++] = pong_buf[0] | (pong_buf[1]<<8) | (pong_buf[2]<<16) | (pong_buf[3]<<24);
    R[ri++] = 0xDAAD9999;
    while(1);
    return 0;
}
