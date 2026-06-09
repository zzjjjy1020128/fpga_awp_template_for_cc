// Step 3: add GIC + DMA init
#include "axil_utils.h"
#include "dma_utils.h"
#include "platform.h"
#include "xil_cache.h"
#include "xil_exception.h"
#include "xscugic.h"
#include "xparameters.h"
#include "xaxidma.h"

#define ACCEL_BASE XPAR_AXIL_2D_SHIFT_0_BASEADDR
#define DMA_DEV_ID XPAR_AXI_DMA_0_DEVICE_ID
#define S2MM_INTR  XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR

volatile unsigned *R = (volatile unsigned*)0x00300000;
XScuGic gic_inst;
XAxiDma dma_inst;
volatile int g_s2mm_done;
void _start(void) {
    int ri=0, ret;
    R[ri++] = 0xDAAD0001;

    // Phase 1: Platform + Cache
    init_platform(); Xil_DCacheEnable();
    R[ri++] = 0xDAAD0002;

    // Phase 2: GIC
    XScuGic_Config *gcfg = XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
    ret = XScuGic_CfgInitialize(&gic_inst, gcfg, gcfg->CpuBaseAddress);
    R[ri++] = ret;  // should be 0 (XST_SUCCESS)
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler)XScuGic_InterruptHandler, &gic_inst);
    Xil_ExceptionEnable();
    R[ri++] = 0xDAAD0003;

    // Phase 3: DMA init
    ret = dma_init(&dma_inst, DMA_DEV_ID);
    R[ri++] = ret;  // 0 = success

    // Phase 4: DMA interrupt
    XScuGic_Disable(&gic_inst, S2MM_INTR);
    ret = XScuGic_Connect(&gic_inst, S2MM_INTR, (Xil_InterruptHandler)dma_s2mm_isr, &dma_inst);
    R[ri++] = ret;
    XScuGic_Enable(&gic_inst, S2MM_INTR);
    XAxiDma_IntrEnable(&dma_inst, XAXIDMA_DEVICE_TO_DMA, XAXIDMA_IRQ_IOC_MASK|XAXIDMA_IRQ_ERROR_MASK);
    R[ri++] = 0xDAAD0004;

    // Phase 5: register test
    ret = axil_reg_test(ACCEL_BASE);
    R[ri++] = ret;
    R[ri++] = axil_read_reg(ACCEL_BASE, 0x04); // STATUS

    R[ri++] = 0xDAAD9999;
    while(1);
}
