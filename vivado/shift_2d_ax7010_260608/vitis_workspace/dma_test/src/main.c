// main.c — PS DMA Test Program for axil_2d_shift
//
// 目标平台: Alinx AX7010 (xc7z010clg400-1)
// PL 时钟: 50 MHz (PS FCLK_CLK0, IO_PLL: 1000/5/4)
// 工具链: Vitis 2022.2, Standalone BSP
//
// 程序流程:
//   1. init_platform()          — BSP 初始化 (UART, cache 等)
//   2. setup_interrupt_controller() — GIC 初始化
//   3. dma_init()               — AXI DMA 驱动初始化
//   4. setup_dma_interrupt()    — 连接 S2MM 中断
//   5. axil_reg_test()          — 加速器寄存器访问测试
//   6. dma_loopback_test()      — DMA→加速器→DMA 环回验证
//
// 地址映射 (来自 xparameters.h, 预期值):
//   axil_2d_shift_0 S_AXI:   0x43C0_0000  (64 KB)
//   AXI DMA_0:                0x43C1_0000  (64 KB)
//   S2MM IRQ_F2P[0]:         ID 61
//
// Cache 一致性:
//   - MM2S 前: Xil_DCacheFlushRange(ping)
//   - S2MM 后: Xil_DCacheInvalidateRange(pong)

#include <stdio.h>
#include "xil_printf.h"
#include "xil_cache.h"
#include "xil_exception.h"
#include "xscugic.h"
#include "xparameters.h"
#include "xaxidma.h"
#include "platform.h"

#include "axil_utils.h"
#include "dma_utils.h"
#include "test_patterns.h"

// ============================================================================
// 硬件参数
// ============================================================================

// 加速器 AXI-Lite 基地址 (来自 xparameters.h)
// 预期: XPAR_AXIL_2D_SHIFT_0_BASEADDR = 0x43C0_0000
// 如果宏名不匹配, 在 xparameters.h 中搜索 axil_2d_shift 找到正确名称
#define ACCEL_BASEADDR      XPAR_AXIL_2D_SHIFT_0_BASEADDR

// DMA 设备 ID (来自 xparameters.h)
// 预期: XPAR_AXI_DMA_0_DEVICE_ID = 0
#define DMA_DEVICE_ID       XPAR_AXI_DMA_0_DEVICE_ID

// S2MM 中断 ID (来自 xparameters.h)
// 预期: XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR = 61
// IRQ_F2P[0] 在 Zynq-7000 GIC 中对应 ID 61
#define S2MM_INTR_ID        XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR

// ============================================================================
// 测试参数
// ============================================================================

// 图像尺寸 (32x32 = 1024 像素, 帧缓冲最大值)
#define TEST_ROWS           32
#define TEST_COLS           32
#define TEST_FRAME_SIZE     (TEST_ROWS * TEST_COLS)

// DMA 缓冲区对齐 (Cortex-A9 cache line = 32 bytes)
#define BUF_ALIGN           32

// 轮询超时 (毫秒)
#define TIMEOUT_MS          5000

// ============================================================================
// 全局变量
// ============================================================================

XScuGic                gic_inst;       // GIC 中断控制器实例
XAxiDma                dma_inst;       // AXI DMA 驱动实例
volatile int           g_s2mm_done;    // S2MM 中断完成标志

// DMA 双缓冲 (cache line aligned)
u8 ping_buf[TEST_FRAME_SIZE] __attribute__((aligned(BUF_ALIGN)));
u8 pong_buf[TEST_FRAME_SIZE] __attribute__((aligned(BUF_ALIGN)));

// ============================================================================
// GIC 中断控制器初始化
// ============================================================================

static int setup_interrupt_controller(void)
{
    XScuGic_Config *cfg;

    cfg = XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
    if (!cfg) {
        xil_printf("  [ERR] No GIC config found\r\n");
        return -1;
    }

    int status = XScuGic_CfgInitialize(&gic_inst, cfg, cfg->CpuBaseAddress);
    if (status != XST_SUCCESS) {
        xil_printf("  [ERR] GIC init failed: %d\r\n", status);
        return -1;
    }

    // 注册 GIC 中断处理函数到 ARM 处理器
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
        (Xil_ExceptionHandler)XScuGic_InterruptHandler, &gic_inst);
    Xil_ExceptionEnable();

    xil_printf("  [INFO] GIC initialized (base=0x%08x)\r\n", cfg->CpuBaseAddress);
    return 0;
}

// ============================================================================
// DMA 中断设置: 连接 S2MM 中断到 GIC
// ============================================================================

static int setup_dma_interrupt(void)
{
    int status;

    // 确保中断未使能 (避免 spurious interrupt)
    XScuGic_Disable(&gic_inst, S2MM_INTR_ID);

    // 连接 S2MM 中断处理函数
    status = XScuGic_Connect(&gic_inst, S2MM_INTR_ID,
                (Xil_InterruptHandler)dma_s2mm_isr,
                (void *)&dma_inst);
    if (status != XST_SUCCESS) {
        xil_printf("  [ERR] GIC_Connect failed: %d\r\n", status);
        return -1;
    }

    // 使能 GIC 中的 S2MM 中断
    XScuGic_Enable(&gic_inst, S2MM_INTR_ID);

    // 使能 DMA 中的 S2MM IOC + Error 中断
    XAxiDma_IntrEnable(&dma_inst, XAXIDMA_DEVICE_TO_DMA,
                       XAXIDMA_IRQ_IOC_MASK | XAXIDMA_IRQ_ERROR_MASK);

    xil_printf("  [INFO] S2MM interrupt connected (IRQ_ID=%d)\r\n", S2MM_INTR_ID);
    return 0;
}

// ============================================================================
// 格式化输出测试结果
// ============================================================================

static void print_result(const char *test_name, int result)
{
    if (result == 0) {
        xil_printf("[PASS] %s\r\n", test_name);
    } else {
        xil_printf("[FAIL] %s (code=%d)\r\n", test_name, result);
    }
}

// ============================================================================
// DMA 环回测试 (核心测试)
//
// 流程:
//   1. 配置加速器: dir, step, rows, cols
//   2. Flush ping 缓冲区 (cache → DDR, 确保 DMA 读到最新数据)
//   3. 复位 DMA
//   4. 启动加速器 (进入 CAPTURE 状态)
//   5. 启动 S2MM (DMA 准备接收输出)
//   6. 启动 MM2S (DDR → 加速器 → S2MM → DDR)
//   7. 等待 S2MM 完成 (中断或轮询)
//   8. 检查 DMA 错误状态
//   9. Invalidate pong 缓冲区 (DDR → cache, 确保 CPU 读到最新数据)
//   10. 对比 ping 和 pong
//
// 返回: 0 = PASS, >0 = 首个 mismatch 位置, <0 = 硬件错误
// ============================================================================

static int dma_loopback_test(const char *test_name,
                             u32 accel_base,
                             u8 *ping, u8 *pong,
                             u32 rows, u32 cols,
                             u32 dir, u32 step)
{
    u32 len = rows * cols;
    int ret;
    u32 dma_err;

    xil_printf("\r\n--- %s ---\r\n", test_name);
    xil_printf("  size=%dx%d (%d bytes), dir=%d, step=%d\r\n",
               rows, cols, len, dir, step);

    // ---- Step 1: 配置加速器 ----
    axil_set_cfg(accel_base, dir, step, 0);   // wrap=0
    axil_set_img_size(accel_base, rows, cols);

    // ---- Step 2: Flush ping cache ----
    // 使 ping 缓冲区的 dirty cache line 写回 DDR
    Xil_DCacheFlushRange((UINTPTR)ping, len);

    // ---- Step 3: 复位 DMA (确保 clean state) ----
    dma_reset(&dma_inst);

    // ---- Step 4: 清除中断标志 ----
    g_s2mm_done = 0;

    // ---- Step 5: 启动加速器 (进入 CAPTURE 状态) ----
    // 加速器在 CAPTURE 状态下会使能 s_axis_tready
    axil_start(accel_base);
    for (volatile u32 d = 0; d < 200; d++);  // 短延迟, 等 FSM 响应

    // ---- Step 6: 先启动 S2MM (等待接收加速器输出) ----
    // 必须在 MM2S 之前启动 S2MM, 否则加速器输出时 S2MM 未就绪
    xil_printf("  Start S2MM (dst=0x%08x, len=%d)...\r\n",
               (UINTPTR)pong, len);
    ret = dma_s2mm_start(&dma_inst, (u32)(UINTPTR)pong, len);
    if (ret != 0) return -2;

    // ---- Step 7: 启动 MM2S (DDR → 加速器) ----
    xil_printf("  Start MM2S (src=0x%08x, len=%d)...\r\n",
               (UINTPTR)ping, len);
    ret = dma_mm2s_start(&dma_inst, (u32)(UINTPTR)ping, len);
    if (ret != 0) return -3;

    // ---- Step 8: 等待 S2MM 完成 ----
    // 先等中断标志, 若中断未触发则回退到轮询
    u32 wait_ms = TIMEOUT_MS;
    xil_printf("  Waiting for S2MM completion...\r\n");
    while (wait_ms--) {
        if (g_s2mm_done) {
            xil_printf("  S2MM done (interrupt)\r\n");
            break;
        }
        // 轮询 fallback
        if (!dma_s2mm_is_busy(&dma_inst)) {
            xil_printf("  S2MM done (polling)\r\n");
            g_s2mm_done = 1;
            break;
        }
        // ~1 ms delay
        for (volatile u32 d = 0; d < 50000; d++);
    }

    if (!g_s2mm_done) {
        xil_printf("  [FAIL] S2MM timeout (>%d ms)\r\n", TIMEOUT_MS);
        axil_dump_regs(accel_base);
        return -4;
    }

    // ---- Step 9: 等待加速器完成 ----
    ret = axil_wait_for_done(accel_base, TIMEOUT_MS);
    if (ret != 0) {
        xil_printf("  [WARN] Accelerator done timeout\r\n");
    }

    // ---- Step 10: 检查 DMA 错误状态 ----
    dma_err = XAxiDma_IntrGetIrq(&dma_inst, XAXIDMA_DEVICE_TO_DMA);
    if (dma_err & XAXIDMA_IRQ_ERROR_MASK) {
        xil_printf("  [FAIL] S2MM error status: 0x%08x\r\n", dma_err);
        return -5;
    }
    dma_err = XAxiDma_IntrGetIrq(&dma_inst, XAXIDMA_DMA_TO_DEVICE);
    if (dma_err & XAXIDMA_IRQ_ERROR_MASK) {
        xil_printf("  [FAIL] MM2S error status: 0x%08x\r\n", dma_err);
        return -6;
    }

    // ---- Step 11: Invalidate pong cache ----
    // DMA 直接写入 DDR, 但 cached 区域的 stale line 可能未更新
    // Invalidate 确保下次 CPU 读从 DDR 获取最新数据
    Xil_DCacheInvalidateRange((UINTPTR)pong, len);

    // ---- Step 12: 验证数据 ----
    ret = verify_pattern(ping, pong, len);
    if (ret == 0) {
        xil_printf(">>> PASS: all %d bytes match\r\n", len);
    } else {
        u32 mismatch_idx = (u32)(ret - 1);
        xil_printf(">>> FAIL: mismatch at byte %d\r\n", mismatch_idx);
        // 打印附近 8 个 mismatches
        u32 start = (mismatch_idx > 4) ? mismatch_idx - 4 : 0;
        u32 end = (mismatch_idx + 4 < len) ? mismatch_idx + 4 : len;
        for (u32 i = start; i < end; i++) {
            if (ping[i] != pong[i]) {
                xil_printf("  [%4d] exp=0x%02x  act=0x%02x %s\r\n",
                           i, ping[i], pong[i],
                           (i == mismatch_idx) ? "<-- FIRST" : "");
            } else {
                xil_printf("  [%4d] exp=0x%02x  act=0x%02x\r\n",
                           i, ping[i], pong[i]);
            }
        }
    }

    return ret;
}

// ============================================================================
// 主函数
// ============================================================================

int main(void)
{
    int ret;
    int all_pass = 1;

    // ----------------------------------------------------------------
    // Banner
    // ----------------------------------------------------------------
    xil_printf("\r\n");
    xil_printf("========================================\r\n");
    xil_printf("  axil_2d_shift PS DMA Test Program     \r\n");
    xil_printf("  Platform: AX7010 (xc7z010clg400-1)    \r\n");
    xil_printf("  PL Clock: 50 MHz                      \r\n");
    xil_printf("========================================\r\n");
    xil_printf("\r\n");

    // ----------------------------------------------------------------
    // Phase 1: BSP 初始化
    // ----------------------------------------------------------------
    xil_printf("--- Phase 1: Platform Init ---\r\n");
    init_platform();
    Xil_DCacheEnable();
    xil_printf("  [INFO] Data cache enabled\r\n");

    // ----------------------------------------------------------------
    // Phase 2: GIC 中断控制器
    // ----------------------------------------------------------------
    xil_printf("\r\n--- Phase 2: Interrupt Controller ---\r\n");
    ret = setup_interrupt_controller();
    if (ret != 0) {
        xil_printf("[FATAL] GIC init failed, abort\r\n");
        cleanup_platform();
        return -1;
    }

    // ----------------------------------------------------------------
    // Phase 3: AXI DMA 初始化
    // ----------------------------------------------------------------
    xil_printf("\r\n--- Phase 3: AXI DMA Init ---\r\n");
    ret = dma_init(&dma_inst, DMA_DEVICE_ID);
    if (ret != 0) {
        xil_printf("[FATAL] DMA init failed, abort\r\n");
        cleanup_platform();
        return -1;
    }

    // ----------------------------------------------------------------
    // Phase 4: DMA 中断连接
    // ----------------------------------------------------------------
    xil_printf("\r\n--- Phase 4: DMA Interrupt ---\r\n");
    ret = setup_dma_interrupt();
    if (ret != 0) {
        xil_printf("[FATAL] DMA interrupt setup failed, abort\r\n");
        cleanup_platform();
        return -1;
    }

    // ----------------------------------------------------------------
    // Phase 5: AXI-Lite 寄存器测试
    // ----------------------------------------------------------------
    xil_printf("\r\n--- Phase 5: Register Test ---\r\n");
    ret = axil_reg_test(ACCEL_BASEADDR);
    print_result("AXI-Lite Register Test", ret);

    axil_dump_regs(ACCEL_BASEADDR);

    if (ret != 0) {
        xil_printf("[FATAL] Register test failed, cannot continue\r\n");
        all_pass = 0;
        goto done;
    }

    // ----------------------------------------------------------------
    // Phase 6: DMA 环回测试 (多种模式)
    // ----------------------------------------------------------------

    // Test A: 递增模式, pass-through (RIGHT, step=0)
    xil_printf("\r\n--- Phase 6a: Increment Pattern ---\r\n");
    fill_pattern_increment(ping_buf, TEST_FRAME_SIZE);
    ret = dma_loopback_test("Increment (RIGHT step=0)",
                            ACCEL_BASEADDR, ping_buf, pong_buf,
                            TEST_ROWS, TEST_COLS,
                            ACCEL_DIR_RIGHT, 0);
    print_result("DMA Loopback Increment", ret);
    if (ret != 0) all_pass = 0;

    // Test B: 棋盘格, dir=DOWN, step=0
    xil_printf("\r\n--- Phase 6b: Checkerboard Pattern ---\r\n");
    fill_pattern_checkerboard(ping_buf, TEST_ROWS, TEST_COLS);
    ret = dma_loopback_test("Checkerboard (DOWN step=0)",
                            ACCEL_BASEADDR, ping_buf, pong_buf,
                            TEST_ROWS, TEST_COLS,
                            ACCEL_DIR_DOWN, 0);
    print_result("DMA Loopback Checkerboard", ret);
    if (ret != 0) all_pass = 0;

    // Test C: 固定值 0x5A, dir=RIGHT, step=0
    xil_printf("\r\n--- Phase 6c: Uniform Pattern ---\r\n");
    fill_pattern_fixed(ping_buf, TEST_FRAME_SIZE, 0x5A);
    ret = dma_loopback_test("Uniform 0x5A (RIGHT step=0)",
                            ACCEL_BASEADDR, ping_buf, pong_buf,
                            TEST_ROWS, TEST_COLS,
                            ACCEL_DIR_RIGHT, 0);
    print_result("DMA Loopback Uniform", ret);
    if (ret != 0) all_pass = 0;

    // Test D: 行斜坡模式, dir=LEFT, step=0
    xil_printf("\r\n--- Phase 6d: Row Ramp Pattern ---\r\n");
    fill_pattern_ramp_row(ping_buf, TEST_ROWS, TEST_COLS);
    ret = dma_loopback_test("Row Ramp (LEFT step=0)",
                            ACCEL_BASEADDR, ping_buf, pong_buf,
                            TEST_ROWS, TEST_COLS,
                            ACCEL_DIR_LEFT, 0);
    print_result("DMA Loopback Row Ramp", ret);
    if (ret != 0) all_pass = 0;

    // Test E: 更小尺寸 (16x16), 验证非整帧边界
    xil_printf("\r\n--- Phase 6e: Small Frame (16x16) ---\r\n");
    fill_pattern_increment(ping_buf, 16 * 16);
    ret = dma_loopback_test("Small Frame 16x16 (RIGHT step=0)",
                            ACCEL_BASEADDR, ping_buf, pong_buf,
                            16, 16,
                            ACCEL_DIR_RIGHT, 0);
    print_result("DMA Loopback Small Frame", ret);
    if (ret != 0) all_pass = 0;

    // ----------------------------------------------------------------
    // Summary
    // ----------------------------------------------------------------
    xil_printf("\r\n");
    xil_printf("========================================\r\n");
    if (all_pass) {
        xil_printf("  ALL TESTS PASSED\r\n");
        xil_printf("  axil_2d_shift DMA path verified    \r\n");
        xil_printf("  Ready for shift validation (L6)    \r\n");
    } else {
        xil_printf("  SOME TESTS FAILED\r\n");
        xil_printf("  Check above for FAIL entries       \r\n");
    }
    xil_printf("========================================\r\n");

done:
    // ----------------------------------------------------------------
    // Cleanup
    // ----------------------------------------------------------------
    XScuGic_Disconnect(&gic_inst, S2MM_INTR_ID);
    Xil_DCacheDisable();
    cleanup_platform();

    return all_pass ? 0 : -1;
}
