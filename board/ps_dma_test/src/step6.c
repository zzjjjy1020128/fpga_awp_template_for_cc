// Step 6: DMA DMACR drill-down — clear reset, check bit1
#include "platform.h"
#include "xil_cache.h"

volatile unsigned *R = (volatile unsigned*)0x00300000;
#define MM2S_BASE 0x40400000

void _start(void) {
    int ri=0;
    R[ri++] = 0xDAAD0001;
    init_platform();
    R[ri++] = 0xDAAD0002;

    // Read initial DMACR
    unsigned cr0 = *(volatile unsigned*)(MM2S_BASE + 0x00);
    R[ri++] = cr0;

    // Try: write 0 to all bits, wait, read
    *(volatile unsigned*)(MM2S_BASE + 0x00) = 0;
    for (volatile int d=0; d<10000; d++);
    unsigned cr1 = *(volatile unsigned*)(MM2S_BASE + 0x00);
    R[ri++] = cr1;

    // Try: write 4 (soft reset bit 2), wait, write 0, wait, read
    *(volatile unsigned*)(MM2S_BASE + 0x00) = 4;
    for (volatile int d=0; d<10000; d++);
    *(volatile unsigned*)(MM2S_BASE + 0x00) = 0;
    for (volatile int d=0; d<10000; d++);
    unsigned cr2 = *(volatile unsigned*)(MM2S_BASE + 0x00);
    R[ri++] = cr2;

    // Read DMASR
    unsigned sr = *(volatile unsigned*)(MM2S_BASE + 0x04);
    R[ri++] = sr;

    // Try: write RS=1 only (bit 0), read back
    *(volatile unsigned*)(MM2S_BASE + 0x00) = 1;
    for (volatile int d=0; d<100; d++);
    unsigned cr3 = *(volatile unsigned*)(MM2S_BASE + 0x00);
    R[ri++] = cr3;

    // Read DMASR again
    unsigned sr2 = *(volatile unsigned*)(MM2S_BASE + 0x04);
    R[ri++] = sr2;

    // Try: write 0x10001 (RS=1 + IRQThreshold bit for polling mode)
    *(volatile unsigned*)(MM2S_BASE + 0x00) = 0;
    for (volatile int d=0; d<1000; d++);
    // Now try different values
    unsigned vals_to_test[] = {1, 0x10001, 0x10000, 3, 0x10003};
    for (int vi=0; vi<5; vi++) {
        *(volatile unsigned*)(MM2S_BASE + 0x00) = 0;
        for (volatile int d=0; d<1000; d++);
        *(volatile unsigned*)(MM2S_BASE + 0x00) = vals_to_test[vi];
        for (volatile int d=0; d<100; d++);
        R[ri++] = *(volatile unsigned*)(MM2S_BASE + 0x00);
        R[ri++] = *(volatile unsigned*)(MM2S_BASE + 0x04);
    }

    // Also check PS-side: read FPGA_RST_CTRL and other SLCR registers
    // that control PL peripheral resets
    R[ri++] = *(volatile unsigned*)0xF8000240; // FPGA_RST_CTRL
    R[ri++] = *(volatile unsigned*)0xF800012C; // APER_CLK_CTRL
    R[ri++] = *(volatile unsigned*)0xF8000900; // LVL_SHFTR_EN

    R[ri++] = 0xDAAD9999;
    while(1);
}
