// Step 4: DMA loopback with polling (no interrupt needed)
#include "axil_utils.h"
#include "platform.h"
#include "xil_cache.h"

#define ACCEL_BASE 0x60000000
#define TEST_ROWS 32
#define TEST_COLS 32
#define FRAME_SIZE (TEST_ROWS * TEST_COLS)
volatile unsigned *R = (volatile unsigned*)0x00300000;
u8 ping_buf[FRAME_SIZE] __attribute__((aligned(32)));
u8 pong_buf[FRAME_SIZE] __attribute__((aligned(32)));

volatile int g_s2mm_done;
void _start(void) {
    int ri=0;
    R[ri++] = 0xDAAD0001;

    init_platform(); Xil_DCacheEnable();
    R[ri++] = 0xDAAD0002;

    // Fill ping with increment
    for (int i=0; i<FRAME_SIZE; i++) ping_buf[i] = (u8)i;
    R[ri++] = 0xDAAD0003;

    // Flush D-cache for ping
    Xil_DCacheFlushRange((UINTPTR)ping_buf, FRAME_SIZE);
    R[ri++] = 0xDAAD0004;

    // Config accelerator: RIGHT step=0 (pass-through), 32x32
    axil_set_cfg(ACCEL_BASE, 4, 0, 0);
    axil_set_img_size(ACCEL_BASE, TEST_ROWS, TEST_COLS);
    R[ri++] = 0xDAAD0005;

    // DMA reset
    *(volatile unsigned*)0x40400000 = 4; *(volatile unsigned*)0x40400030 = 4;
    *(volatile unsigned*)0x40400000 = 0; *(volatile unsigned*)0x40400030 = 0;
    // Disable SG
    *(volatile unsigned*)0x4040002C = 0; *(volatile unsigned*)0x4040005C = 0;
    // Set DMA addresses + length
    *(volatile unsigned*)0x40400018 = (u32)ping_buf;
    *(volatile unsigned*)0x40400048 = (u32)pong_buf;
    *(volatile unsigned*)0x40400028 = FRAME_SIZE;
    *(volatile unsigned*)0x40400058 = FRAME_SIZE;
    R[ri++] = 0xDAAD0006;

    // Start ACCEL → delay → S2MM → MM2S
    *(volatile unsigned*)(ACCEL_BASE + 0x00) = 1;
    for (volatile int d=0; d<10000; d++);
    *(volatile unsigned*)0x40400030 = 1;  // S2MM start
    *(volatile unsigned*)0x40400000 = 1;  // MM2S start
    R[ri++] = 0xDAAD0007;

    // Wait for DMA (polling or timeout)
    for (volatile int d=0; d<0x400000; d++);
    R[ri++] = 0xDAAD0008;

    // Invalidate pong D-cache
    Xil_DCacheInvalidateRange((UINTPTR)pong_buf, FRAME_SIZE);
    R[ri++] = 0xDAAD0009;

    // Verify
    int mismatch = -1;
    for (int i=0; i<FRAME_SIZE; i++) {
        if (ping_buf[i] != pong_buf[i]) { mismatch = i; break; }
    }
    R[ri++] = mismatch;  // -1 = ALL MATCH (PASS)

    // Store more debug
    R[ri++] = *(volatile unsigned*)(ACCEL_BASE + 0x04); // STATUS
    R[ri++] = *(volatile unsigned*)0x40400004; // MM2S_DMASR
    R[ri++] = *(volatile unsigned*)0x40400034; // S2MM_DMASR
    R[ri++] = ping_buf[0] | (ping_buf[1]<<8) | (ping_buf[2]<<16) | (ping_buf[3]<<24);
    R[ri++] = pong_buf[0] | (pong_buf[1]<<8) | (pong_buf[2]<<16) | (pong_buf[3]<<24);
    R[ri++] = 0xDAAD9999;
    while(1);
}
