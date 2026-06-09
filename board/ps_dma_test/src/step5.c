// Step 5: DMA register write/read test — does CPU→DMA register path work?
#include "platform.h"
#include "xil_cache.h"

volatile unsigned *R = (volatile unsigned*)0x00300000;
#define MM2S_BASE 0x40400000
#define S2MM_BASE 0x40400030
#define ACCEL_BASE 0x60000000

void _start(void) {
    int ri=0;
    R[ri++] = 0xDAAD0001;

    init_platform();
    Xil_DCacheEnable();
    R[ri++] = 0xDAAD0002;

    // Test 1: Write then read MM2S source address register
    *(volatile unsigned*)(MM2S_BASE + 0x18) = 0xDEADBEEF;
    unsigned sa = *(volatile unsigned*)(MM2S_BASE + 0x18);
    R[ri++] = sa;  // R[2]: should be 0xDEADBEEF
    R[ri++] = 0xDAAD0003;

    // Test 2: Write then read S2MM destination address register
    *(volatile unsigned*)(S2MM_BASE + 0x18) = 0xCAFEBABE;
    unsigned da = *(volatile unsigned*)(S2MM_BASE + 0x18);
    R[ri++] = da;  // R[4]: should be 0xCAFEBABE
    R[ri++] = 0xDAAD0004;

    // Test 3: Read DMA status before any start
    unsigned mm2s_sr0 = *(volatile unsigned*)(MM2S_BASE + 0x04);
    unsigned s2mm_sr0 = *(volatile unsigned*)(S2MM_BASE + 0x04);
    R[ri++] = mm2s_sr0;  // R[6]: initial MM2S status
    R[ri++] = s2mm_sr0;  // R[7]: initial S2MM status

    // Test 4: Write DMACR=1 (start), immediately read back
    *(volatile unsigned*)(MM2S_BASE + 0x00) = 1;
    unsigned mm2s_cr = *(volatile unsigned*)(MM2S_BASE + 0x00);
    R[ri++] = mm2s_cr;  // R[8]: DMACR after write

    *(volatile unsigned*)(S2MM_BASE + 0x00) = 1;
    unsigned s2mm_cr = *(volatile unsigned*)(S2MM_BASE + 0x00);
    R[ri++] = s2mm_cr;  // R[9]: S2MM DMACR after write

    // Test 5: Read DMA status after start attempt
    volatile int d;
    for (d=0; d<1000; d++);
    unsigned mm2s_sr1 = *(volatile unsigned*)(MM2S_BASE + 0x04);
    unsigned s2mm_sr1 = *(volatile unsigned*)(S2MM_BASE + 0x04);
    R[ri++] = mm2s_sr1;  // R[10]: MM2S status after start
    R[ri++] = s2mm_sr1;  // R[11]: S2MM status after start

    // Test 6: Write then read ACCEL CFG register (known working path)
    *(volatile unsigned*)(ACCEL_BASE + 0x08) = 0x105;
    unsigned cfg = *(volatile unsigned*)(ACCEL_BASE + 0x08);
    R[ri++] = cfg;  // R[12]: should be 0x105 — positive control

    // Test 7: Reset DMA, write DMACR=1 again, read back with more delay
    *(volatile unsigned*)(MM2S_BASE + 0x00) = 4;  // reset
    for (d=0; d<1000; d++);
    *(volatile unsigned*)(MM2S_BASE + 0x00) = 0;  // clear reset
    for (d=0; d<1000; d++);
    // Write start
    *(volatile unsigned*)(MM2S_BASE + 0x00) = 1;
    for (d=0; d<1000; d++);
    unsigned mm2s_cr2 = *(volatile unsigned*)(MM2S_BASE + 0x00);
    unsigned mm2s_sr2 = *(volatile unsigned*)(MM2S_BASE + 0x04);
    R[ri++] = mm2s_cr2;  // R[13]
    R[ri++] = mm2s_sr2;  // R[14]

    R[ri++] = 0xDAAD9999;
    while(1);
}
