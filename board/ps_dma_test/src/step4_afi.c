// step4_afi.c — DMA loopback with AFI patch embedded in C
// Key: ARM core writes AFI registers directly (not through JTAG)
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

static void afi_hp0_init(void)
{
    // SLCR unlock
    *(volatile unsigned*)0xF8000008 = 0xDF0D;

    // AFI0: HP0 RD 64-bit
    *(volatile unsigned*)0xF8000860 = 0x10000000;

    // AFI1: HP0 WR 64-bit
    *(volatile unsigned*)0xF8000864 = 0x10000000;

    // APER_CLK_CTRL: enable HP0 clock (bit11)
    *(volatile unsigned*)0xF800012C |= 0x0800;

    // Readback for debug
    R[100] = *(volatile unsigned*)0xF8000860;
    R[101] = *(volatile unsigned*)0xF8000864;
    R[102] = *(volatile unsigned*)0xF800012C;

    // SLCR lock
    *(volatile unsigned*)0xF8000004 = 0x767B;
}

void _start(void) {
    int ri=0;
    R[ri++] = 0xDAAD0001;

    init_platform(); Xil_DCacheEnable();
    R[ri++] = 0xDAAD0002;

    // ---- AFI PATCH: configure HP0 BEFORE using DMA ----
    afi_hp0_init();
    R[ri++] = 0xDAAD00AF;  // AFI patch applied

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

    // Wait for DMA
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
    R[ri++] = mismatch;

    // Store debug
    R[ri++] = *(volatile unsigned*)(ACCEL_BASE + 0x04); // STATUS
    R[ri++] = *(volatile unsigned*)0x40400004; // MM2S_DMASR
    R[ri++] = *(volatile unsigned*)0x40400034; // S2MM_DMASR
    R[ri++] = ping_buf[0] | (ping_buf[1]<<8) | (ping_buf[2]<<16) | (ping_buf[3]<<24);
    R[ri++] = pong_buf[0] | (pong_buf[1]<<8) | (pong_buf[2]<<16) | (pong_buf[3]<<24);
    R[ri++] = 0xDAAD9999;
    while(1);
}
