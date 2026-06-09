// step7: software-gated DMA start for ILA trigger sync
// CPU waits at checkpoint, arm ILA, write flag via mwr, DMA starts immediately
#include "platform.h"
#include "xil_cache.h"

volatile unsigned *R = (volatile unsigned*)0x00300000;
volatile unsigned *GATE = (volatile unsigned*)0x00300100; // gate flag address
u8 ping_buf[1024] __attribute__((aligned(32)));
u8 pong_buf[1024] __attribute__((aligned(32)));

void _start(void) {
    int ri=0;
    R[ri++] = 0xDAAD0001;
    init_platform(); Xil_DCacheEnable();
    R[ri++] = 0xDAAD0002;

    // Fill ping
    for (int i=0; i<1024; i++) ping_buf[i] = (u8)i;
    Xil_DCacheFlushRange((UINTPTR)ping_buf, 1024);
    R[ri++] = 0xDAAD0003;

    // Config accelerator
    *(volatile unsigned*)0x60000008 = 4;   // CFG=RIGHT
    *(volatile unsigned*)0x6000000C = 32;  // ROWS
    *(volatile unsigned*)0x60000010 = 32;  // COLS
    R[ri++] = 0xDAAD0004;

    // Config DMA (reset, set addr, len, disable SG)
    *(volatile unsigned*)0x40400000 = 4;   // MM2S reset
    *(volatile unsigned*)0x40400030 = 4;   // S2MM reset
    *(volatile unsigned*)0x40400000 = 0;
    *(volatile unsigned*)0x40400030 = 0;
    *(volatile unsigned*)0x4040002C = 0;   // SG disable
    *(volatile unsigned*)0x4040005C = 0;
    *(volatile unsigned*)0x40400018 = (u32)ping_buf;
    *(volatile unsigned*)0x40400048 = (u32)pong_buf;
    *(volatile unsigned*)0x40400028 = 1024;
    *(volatile unsigned*)0x40400058 = 1024;
    R[ri++] = 0xDAAD0005;

    // ===== WAIT GATE: write 1 to 0x300100 via mwr to proceed =====
    R[ri++] = 0xDAAD0006;  // waiting at gate
    *GATE = 0;              // init gate to 0
    Xil_DCacheFlushRange((UINTPTR)GATE, 4);  // flush so mrd can see it
    while (*GATE == 0) {
        Xil_DCacheInvalidateRange((UINTPTR)GATE, 4);  // re-read from DDR
    }
    R[ri++] = 0xDAAD0007;  // gate passed!

    // Start accelerator
    *(volatile unsigned*)0x60000000 = 1;  // CTRL.start
    for (volatile int d=0; d<1000; d++);

    // Start DMA — this is what ILA should capture
    *(volatile unsigned*)0x40400030 = 1;  // S2MM start
    *(volatile unsigned*)0x40400000 = 1;  // MM2S start
    R[ri++] = 0xDAAD0008;  // DMA started

    // Wait
    for (volatile int d=0; d<0x400000; d++);
    R[ri++] = 0xDAAD0009;

    // Invalidate + verify
    Xil_DCacheInvalidateRange((UINTPTR)pong_buf, 1024);
    int mismatch = -1;
    for (int i=0; i<1024; i++) {
        if (ping_buf[i] != pong_buf[i]) { mismatch = i; break; }
    }
    R[ri++] = mismatch;
    R[ri++] = *(volatile unsigned*)0x60000004; // STATUS
    R[ri++] = *(volatile unsigned*)0x40400004; // MM2S_DMASR
    R[ri++] = ping_buf[0]|(ping_buf[1]<<8)|(ping_buf[2]<<16)|(ping_buf[3]<<24);
    R[ri++] = pong_buf[0]|(pong_buf[1]<<8)|(pong_buf[2]<<16)|(pong_buf[3]<<24);
    R[ri++] = 0xDAAD9999;
    while(1);
}
