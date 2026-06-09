// Step 1: minimal C + BSP — just axil_reg_test, no UART/GIC/DMA/cache
#include "axil_utils.h"

#define ACCEL_BASE 0x60000000
volatile unsigned *R = (volatile unsigned*)0x00300000;

void _start(void) {
    R[0] = 0xDAAD0001;  // entry marker

    // Call the EXISTING BSP axil_reg_test — same code Vitis GUI uses
    int ret = axil_reg_test(ACCEL_BASE);
    R[1] = ret;  // 0 = PASS

    // Write CFG=0x105, read back
    axil_write_reg(ACCEL_BASE, 0x08, 0x105);
    unsigned cfg = axil_read_reg(ACCEL_BASE, 0x08);
    R[2] = cfg;  // should be 0x105

    // Read STATUS
    unsigned st = axil_read_reg(ACCEL_BASE, 0x04);
    R[3] = st;   // should be 0x1 (IDLE)

    // Read CTRL (WO — returns 0)
    unsigned ctrl = axil_read_reg(ACCEL_BASE, 0x00);
    R[4] = ctrl;

    R[5] = 0xDAAD9999;  // final marker
    while(1);
}
