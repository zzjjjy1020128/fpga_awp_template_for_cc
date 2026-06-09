// Minimal DMA tests - no UART, no GIC, no BSP, polling only
// Stores ALL results at fixed DDR addresses
#define RESULT_BASE 0x00300000
volatile unsigned *R = (volatile unsigned*)RESULT_BASE;

#define ACCEL_BASE 0x60000000
#define DMA_MM2S   0x40400000
#define DMA_S2MM   0x40400030
#define PING_BUF   0x00110760
#define PONG_BUF   0x00110B60

static void dma_reset(void) {
    *(volatile unsigned*)(DMA_MM2S + 0x00) = 4;  // MM2S reset
    *(volatile unsigned*)(DMA_S2MM + 0x00) = 4;  // S2MM reset
    *(volatile unsigned*)(DMA_MM2S + 0x00) = 0;
    *(volatile unsigned*)(DMA_S2MM + 0x00) = 0;
}

void _start(void) {
    int ri = 0;
    R[ri++] = 0xDAAD0000;  // C0: entry marker

    // Fill ping with increment
    unsigned *p = (unsigned*)PING_BUF;
    for (int i = 0; i < 256; i++) {
        p[i] = i * 0x04040404;  // 0, 0x04040404, 0x08080808, ...
    }
    R[ri++] = 0xDAAD0001;  // C1: fill done

    // Flush D-cache for ping
    for (unsigned a = PING_BUF; a < PING_BUF + 1024; a += 64) {
        asm volatile("mcr p15, 0, %0, c7, c10, 1" :: "r"(a));
    }
    asm volatile("dsb" ::: "memory");
    R[ri++] = 0xDAAD0002;  // C2: cache flushed

    // Config accelerator
    *(volatile unsigned*)(ACCEL_BASE + 0x08) = 4;   // CFG = RIGHT
    *(volatile unsigned*)(ACCEL_BASE + 0x0C) = 32;  // ROWS
    *(volatile unsigned*)(ACCEL_BASE + 0x10) = 32;  // COLS
    R[ri++] = 0xDAAD0003;  // C3: accel configured

    // Reset and config DMA
    dma_reset();
    *(volatile unsigned*)(DMA_MM2S + 0x18) = PING_BUF;
    *(volatile unsigned*)(DMA_S2MM + 0x18) = PONG_BUF;
    *(volatile unsigned*)(DMA_MM2S + 0x28) = 1024;
    *(volatile unsigned*)(DMA_S2MM + 0x28) = 1024;
    *(volatile unsigned*)(DMA_MM2S + 0x2C) = 0;  // SG disable
    *(volatile unsigned*)(DMA_S2MM + 0x2C) = 0;
    R[ri++] = 0xDAAD0004;  // C4: DMA configured

    // Start accelerator
    *(volatile unsigned*)(ACCEL_BASE + 0x00) = 1; // CTRL.start
    for (volatile int d = 0; d < 10000; d++);
    R[ri++] = 0xDAAD0005;  // C5: accel started

    // Start DMA
    *(volatile unsigned*)(DMA_S2MM + 0x00) = 1;  // S2MM start
    *(volatile unsigned*)(DMA_MM2S + 0x00) = 1;  // MM2S start
    R[ri++] = 0xDAAD0006;  // C6: DMA started

    // Wait
    for (volatile int d = 0; d < 0x400000; d++);
    R[ri++] = 0xDAAD0007;  // C7: wait done

    // Invalidate D-cache for pong
    for (unsigned a = PONG_BUF; a < PONG_BUF + 1024; a += 64) {
        asm volatile("mcr p15, 0, %0, c7, c6, 1" :: "r"(a));
    }
    asm volatile("dsb" ::: "memory");

    // Store results
    R[ri++] = *(volatile unsigned*)PONG_BUF;        // R8: pong[0]
    R[ri++] = *(volatile unsigned*)(PONG_BUF + 4);   // R9: pong[1]
    R[ri++] = *(volatile unsigned*)(ACCEL_BASE + 4); // R10: STATUS
    R[ri++] = *(volatile unsigned*)(DMA_MM2S + 4);   // R11: MM2S_DMASR
    R[ri++] = *(volatile unsigned*)(DMA_S2MM + 4);   // R12: S2MM_DMASR
    R[ri++] = *(volatile unsigned*)PING_BUF;        // R13: ping[0]
    R[ri++] = 0xDAAD9999;  // FINAL

    while(1);
}
