// Step 2: add init_platform + Xil_DCacheEnable
#include "axil_utils.h"
#include "platform.h"
#include "xil_cache.h"

#define ACCEL_BASE 0x60000000
volatile unsigned *R = (volatile unsigned*)0x00300000;

void _start(void) {
    R[0] = 0xDAAD0001;

    // This is what main() does first
    init_platform();         // UART init (controller regs only, no xil_printf)
    Xil_DCacheEnable();      // enable data cache
    R[1] = 0xDAAD0002;       // survived platform init

    int ret = axil_reg_test(ACCEL_BASE);
    R[2] = ret;

    unsigned cfg = axil_read_reg(ACCEL_BASE, 0x08);
    R[3] = cfg;

    unsigned st = axil_read_reg(ACCEL_BASE, 0x04);
    R[4] = st;

    R[5] = 0xDAAD9999;
    while(1);
}
