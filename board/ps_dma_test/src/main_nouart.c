// main_nouart.c — L6 DMA test without UART dependency
// Stores all results in DDR at known locations for CLI readback
// Based on main.c but replaces xil_printf with memory logging

#define NOUART 1

#include "xil_cache.h"
#include "xil_exception.h"
#include "xscugic.h"
#include "xparameters.h"
#include "xaxidma.h"
#include "platform.h"
#include "axil_utils.h"
#include "dma_utils.h"
#include "test_patterns.h"

// Results stored at fixed DDR address
#define RESULT_BASE     0x00200000
#define RESULT_MAGIC    0x4C365230  // "L6R0"
#define RESULT_COUNT    64

static volatile u32 *result = (volatile u32 *)RESULT_BASE;

static int result_idx = 0;
static void log_result(u32 val) {
    if (result_idx < RESULT_COUNT)
        result[result_idx++] = val;
}

#define ACCEL_BASEADDR      XPAR_AXIL_2D_SHIFT_0_BASEADDR
#define DMA_DEVICE_ID       XPAR_AXI_DMA_0_DEVICE_ID
#define S2MM_INTR_ID        XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR

#define TEST_ROWS           32
#define TEST_COLS           32
#define TEST_FRAME_SIZE     (TEST_ROWS * TEST_COLS)
#define BUF_ALIGN           32
#define TIMEOUT_MS          5000

XScuGic                gic_inst;
XAxiDma                dma_inst;
volatile int           g_s2mm_done;

u8 ping_buf[TEST_FRAME_SIZE] __attribute__((aligned(BUF_ALIGN)));
u8 pong_buf[TEST_FRAME_SIZE] __attribute__((aligned(BUF_ALIGN)));

static int setup_interrupt_controller(void) {
    XScuGic_Config *cfg = XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
    if (!cfg) return -1;
    int status = XScuGic_CfgInitialize(&gic_inst, cfg, cfg->CpuBaseAddress);
    if (status != XST_SUCCESS) return -1;
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
        (Xil_ExceptionHandler)XScuGic_InterruptHandler, &gic_inst);
    Xil_ExceptionEnable();
    return 0;
}

static int setup_dma_interrupt(void) {
    XScuGic_Disable(&gic_inst, S2MM_INTR_ID);
    int status = XScuGic_Connect(&gic_inst, S2MM_INTR_ID,
        (Xil_InterruptHandler)dma_s2mm_isr, (void *)&dma_inst);
    if (status != XST_SUCCESS) return -1;
    XScuGic_Enable(&gic_inst, S2MM_INTR_ID);
    XAxiDma_IntrEnable(&dma_inst, XAXIDMA_DEVICE_TO_DMA,
                       XAXIDMA_IRQ_IOC_MASK | XAXIDMA_IRQ_ERROR_MASK);
    return 0;
}

static int dma_loopback_test(u8 *ping, u8 *pong,
                             u32 rows, u32 cols,
                             u32 dir, u32 step)
{
    u32 len = rows * cols;

    axil_set_cfg(ACCEL_BASEADDR, dir, step, 0);
    axil_set_img_size(ACCEL_BASEADDR, rows, cols);
    Xil_DCacheFlushRange((UINTPTR)ping, len);
    dma_reset(&dma_inst);
    g_s2mm_done = 0;

    axil_start(ACCEL_BASEADDR);
    for (volatile u32 d = 0; d < 200; d++);

    int ret = dma_s2mm_start(&dma_inst, (u32)(UINTPTR)pong, len);
    if (ret != 0) return -2;
    ret = dma_mm2s_start(&dma_inst, (u32)(UINTPTR)ping, len);
    if (ret != 0) return -3;

    u32 wait_ms = TIMEOUT_MS;
    while (wait_ms--) {
        if (g_s2mm_done) break;
        if (!dma_s2mm_is_busy(&dma_inst)) { g_s2mm_done = 1; break; }
        for (volatile u32 d = 0; d < 50000; d++);
    }
    if (!g_s2mm_done) return -4;

    axil_wait_for_done(ACCEL_BASEADDR, TIMEOUT_MS);
    u32 dma_err = XAxiDma_IntrGetIrq(&dma_inst, XAXIDMA_DEVICE_TO_DMA);
    if (dma_err & XAXIDMA_IRQ_ERROR_MASK) return -5;

    Xil_DCacheInvalidateRange((UINTPTR)pong, len);
    return verify_pattern(ping, pong, len);
}

int main(void) {
    result_idx = 0;
    result[0] = RESULT_MAGIC;  // Magic marker
    result_idx = 1;

    // Phase 1: Platform init
    init_platform();
    Xil_DCacheEnable();

    // Phase 2: GIC
    int ret = setup_interrupt_controller();
    log_result(ret);  // result[1]

    // Phase 3: DMA init
    ret = dma_init(&dma_inst, DMA_DEVICE_ID);
    log_result(ret);  // result[2]

    // Phase 4: DMA interrupt
    ret = setup_dma_interrupt();
    log_result(ret);  // result[3]

    // Phase 5: Register test
    ret = axil_reg_test(ACCEL_BASEADDR);
    log_result(ret);  // result[4]

    // Read back status
    u32 status = axil_read_status(ACCEL_BASEADDR);
    log_result(status);  // result[5]

    // Phase 6: DMA loopback - Increment pattern, RIGHT step=0 (pass-through)
    fill_pattern_increment(ping_buf, TEST_FRAME_SIZE);
    ret = dma_loopback_test(ping_buf, pong_buf, TEST_ROWS, TEST_COLS, ACCEL_DIR_RIGHT, 0);
    log_result(ret);  // result[6] — 0 = PASS

    // Store first 4 bytes of ping and pong for quick verification
    log_result(*(u32*)ping_buf);  // result[7] — ping[0:3]
    log_result(*(u32*)pong_buf);  // result[8] — pong[0:3]

    // Store DMA status
    u32 mm2s_status = *(volatile u32*)0x40400004;
    u32 s2mm_status = *(volatile u32*)0x40400034;
    log_result(mm2s_status);  // result[9]
    log_result(s2mm_status);  // result[10]

    // Store accelerator status
    status = axil_read_status(ACCEL_BASEADDR);
    log_result(status);  // result[11]

    // Cleanup
    XScuGic_Disconnect(&gic_inst, S2MM_INTR_ID);
    Xil_DCacheDisable();
    cleanup_platform();

    // Final marker
    result[63] = 0x4C36454E;  // "L6EN"

    // Infinite loop — CPU stays here for XSDB to read results
    while(1);
    return 0;
}
