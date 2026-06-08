// axil_utils.c — AXI4-Lite 寄存器读写实现
//
// 使用 Xil_In32 / Xil_Out32 通过 M_AXI_GP0 地址空间访问加速器寄存器。
// 地址偏移见 axil_utils.h 和 regs_top.sv 寄存器定义。

#include "axil_utils.h"
#include "xil_io.h"
#include "xil_printf.h"

// ============================================================================
// 基本 32-bit 寄存器访问 (AXI4-Lite, 无 burst)
// ============================================================================

u32 axil_read_reg(u32 base_addr, u32 offset)
{
    return Xil_In32(base_addr + offset);
}

void axil_write_reg(u32 base_addr, u32 offset, u32 value)
{
    Xil_Out32(base_addr + offset, value);
}

// ============================================================================
// 读 STATUS 寄存器
// ============================================================================

u32 axil_read_status(u32 base_addr)
{
    return axil_read_reg(base_addr, ACCEL_OFFSET_STATUS);
}

// ============================================================================
// 配置移位参数
//  dir:    0=none, 1=UP, 2=DOWN, 3=LEFT, 4=RIGHT
//  step:   步长 (0-31)
//  wrap_en: 0=补零模式, 1=缠绕模式
// ============================================================================

void axil_set_cfg(u32 base_addr, u32 dir, u32 step, u32 wrap_en)
{
    u32 cfg = (dir & ACCEL_CFG_DIR_MASK)
            | ((step << ACCEL_CFG_STEP_SHIFT) & ACCEL_CFG_STEP_MASK);
    if (wrap_en) {
        cfg |= ACCEL_CFG_WRAP_EN;
    }
    axil_write_reg(base_addr, ACCEL_OFFSET_CFG, cfg);
}

// ============================================================================
// 设置图像尺寸 (行列数)
//   rows: 行数 (1-1024, 受 MAX_ROWS 限制)
//   cols: 列数 (1-1024, 受 MAX_COLS 限制)
// ============================================================================

void axil_set_img_size(u32 base_addr, u32 rows, u32 cols)
{
    axil_write_reg(base_addr, ACCEL_OFFSET_IMG_ROWS, rows);
    axil_write_reg(base_addr, ACCEL_OFFSET_IMG_COLS, cols);
}

// ============================================================================
// 启动加速器: 写 CTRL.start = 1 (self-clearing)
//   加速器从 IDLE -> CAPTURE 状态, 开始接收 s_axis 数据
// ============================================================================

void axil_start(u32 base_addr)
{
    axil_write_reg(base_addr, ACCEL_OFFSET_CTRL, ACCEL_CTRL_START);
}

// ============================================================================
// 软复位: 写 CTRL.sw_reset = 1 (self-clearing)
//   加速器内部所有状态机复位
// ============================================================================

void axil_sw_reset(u32 base_addr)
{
    axil_write_reg(base_addr, ACCEL_OFFSET_CTRL, ACCEL_CTRL_SW_RESET);
}

// ============================================================================
// 轮询 STATUS.done 位, 直到置位或超时
//   返回: 0 = done, -1 = timeout
//   在 50 MHz 下, 每次轮询约 1 us
// ============================================================================

int axil_wait_for_done(u32 base_addr, u32 timeout_ms)
{
    u32 poll_count = timeout_ms * 1000;  // ~1000 次/ms
    for (u32 i = 0; i < poll_count; i++) {
        if (axil_read_status(base_addr) & ACCEL_STATUS_DONE) {
            return 0;  // done
        }
        for (volatile u32 d = 0; d < 50; d++);  // ~1 us @ 50 MHz
    }
    return -1;  // timeout
}

// ============================================================================
// 打印加速器所有寄存器到 UART
// ============================================================================

void axil_dump_regs(u32 base_addr)
{
    u32 ctrl   = axil_read_reg(base_addr, ACCEL_OFFSET_CTRL);
    u32 status = axil_read_reg(base_addr, ACCEL_OFFSET_STATUS);
    u32 cfg    = axil_read_reg(base_addr, ACCEL_OFFSET_CFG);
    u32 rows   = axil_read_reg(base_addr, ACCEL_OFFSET_IMG_ROWS);
    u32 cols   = axil_read_reg(base_addr, ACCEL_OFFSET_IMG_COLS);

    xil_printf("--- Accelerator Registers (base=0x%08x) ---\r\n", base_addr);
    xil_printf("  CTRL  +0x00: 0x%08x [start=%d, sw_rst=%d]\r\n",
               ctrl, (ctrl >> 0) & 1U, (ctrl >> 1) & 1U);
    xil_printf("  STATUS+0x04: 0x%08x", status);
    if (status & ACCEL_STATUS_IDLE)         xil_printf(" IDLE");
    if (status & ACCEL_STATUS_BUSY_CAPTURE) xil_printf(" CAPTURE");
    if (status & ACCEL_STATUS_BUSY_SHIFT)   xil_printf(" SHIFT");
    if (status & ACCEL_STATUS_DONE)         xil_printf(" DONE");
    xil_printf("\r\n");

    u32 dir   = cfg & ACCEL_CFG_DIR_MASK;
    u32 step  = (cfg & ACCEL_CFG_STEP_MASK) >> ACCEL_CFG_STEP_SHIFT;
    u32 wrap  = (cfg >> 8) & 1U;
    xil_printf("  CFG   +0x08: 0x%08x [dir=%d, step=%d, wrap=%d]\r\n",
               cfg, dir, step, wrap);
    xil_printf("  ROWS  +0x0C: 0x%08x (%d)\r\n", rows, rows);
    xil_printf("  COLS  +0x10: 0x%08x (%d)\r\n", cols, cols);
    xil_printf("------------------------------------------\r\n");
}

// ============================================================================
// AXI-Lite 寄存器自测试
//   1. 写 CFG → 回读验证
//   2. 写 IMG_ROWS → 回读验证
//   3. 写 IMG_COLS → 回读验证
//   4. 读 STATUS (RO, 仅检查可读性)
//   5. 读 CTRL (WO, 预期返回 0)
//   返回: 0 = PASS, -1 = FAIL
// ============================================================================

int axil_reg_test(u32 base_addr)
{
    int pass = 1;
    u32 test_val, read_val;

    xil_printf("=== AXI-Lite Register Test ===\r\n");
    xil_printf("  Accelerator base: 0x%08x\r\n", base_addr);

    // ---- Test 1: CFG write/read ----
    test_val = 0x00000105U;  // dir=5, step=0, wrap=0
    axil_write_reg(base_addr, ACCEL_OFFSET_CFG, test_val);
    read_val = axil_read_reg(base_addr, ACCEL_OFFSET_CFG);
    if (read_val == test_val) {
        xil_printf("  [PASS] CFG: wrote 0x%08x, read 0x%08x\r\n", test_val, read_val);
    } else {
        xil_printf("  [FAIL] CFG: wrote 0x%08x, read 0x%08x\r\n", test_val, read_val);
        pass = 0;
    }

    // ---- Test 2: IMG_ROWS write/read (32) ----
    test_val = 32;
    axil_write_reg(base_addr, ACCEL_OFFSET_IMG_ROWS, test_val);
    read_val = axil_read_reg(base_addr, ACCEL_OFFSET_IMG_ROWS);
    if (read_val == test_val) {
        xil_printf("  [PASS] IMG_ROWS: wrote %d, read %d\r\n", test_val, read_val);
    } else {
        xil_printf("  [FAIL] IMG_ROWS: wrote %d, read %d\r\n", test_val, read_val);
        pass = 0;
    }

    // ---- Test 3: IMG_COLS write/read (32) ----
    test_val = 32;
    axil_write_reg(base_addr, ACCEL_OFFSET_IMG_COLS, test_val);
    read_val = axil_read_reg(base_addr, ACCEL_OFFSET_IMG_COLS);
    if (read_val == test_val) {
        xil_printf("  [PASS] IMG_COLS: wrote %d, read %d\r\n", test_val, read_val);
    } else {
        xil_printf("  [FAIL] IMG_COLS: wrote %d, read %d\r\n", test_val, read_val);
        pass = 0;
    }

    // ---- Test 4: STATUS read (RO, 仅验证可读) ----
    read_val = axil_read_status(base_addr);
    xil_printf("  [INFO] STATUS = 0x%08x (RO register)\r\n", read_val);

    // ---- Test 5: CTRL read (WO, 预期返回 0) ----
    read_val = axil_read_reg(base_addr, ACCEL_OFFSET_CTRL);
    xil_printf("  [INFO] CTRL  = 0x%08x (WO register, expect 0)\r\n", read_val);

    // ---- 恢复 CFG 为默认值 ----
    axil_set_cfg(base_addr, 0, 0, 0);

    xil_printf("------------------------------\r\n");
    if (pass) {
        xil_printf(">>> AXI-Lite Register Test: PASS\r\n");
    } else {
        xil_printf(">>> AXI-Lite Register Test: FAIL\r\n");
    }

    return pass ? 0 : -1;
}
