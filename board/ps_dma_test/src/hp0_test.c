// hp0_test.c — minimal HP0 DMA test, zero BSP dependencies
// Tests: 1) AFI register writes from CPU  2) DMA loopback through HP0
//
// MMU off, cache off, pure physical addressing
// Result buffer at 0x300000 (known location for XSCT readback)

#define SLCR_UNLOCK  0xF8000008
#define SLCR_LOCK    0xF8000004
#define DMA_BASE     0x40400000
#define ACCEL_BASE   0x60000000
#define RESULT_BASE  0x00300000

// DMA register offsets
#define MM2S_DMACR   0x00
#define MM2S_DMASR   0x04
#define MM2S_SA      0x18
#define MM2S_LENGTH  0x28
#define S2MM_DMACR   0x30
#define S2MM_DMASR   0x34
#define S2MM_DA      0x48
#define S2MM_LENGTH  0x58

#define FRAME_SIZE   1024

// Result buffer
volatile unsigned *R = (volatile unsigned*)RESULT_BASE;

// Test buffers (in .bss, physically addressed)
static unsigned char ping_buf[FRAME_SIZE] __attribute__((aligned(32)));
static unsigned char pong_buf[FRAME_SIZE] __attribute__((aligned(32)));

void _start(void) {
    int ri = 0;
    R[ri++] = 0xBEEF0001;  // entry

    // === STEP 1: Test AFI register writes from CPU ===
    // Unlock SLCR, write AFI, readback, lock
    *(volatile unsigned*)SLCR_UNLOCK = 0xDF0D;

    *(volatile unsigned*)0xF8000860 = 0x10000000;  // AFI0 64-bit
    *(volatile unsigned*)0xF8000864 = 0x10000000;  // AFI1 64-bit

    R[ri++] = *(volatile unsigned*)0xF8000860;  // R[1] = AFI0 readback
    R[ri++] = *(volatile unsigned*)0xF8000864;  // R[2] = AFI1 readback

    // Enable HP0 clock
    *(volatile unsigned*)0xF800012C |= 0x0800;
    R[ri++] = *(volatile unsigned*)0xF800012C;  // R[3] = CLK reg

    *(volatile unsigned*)SLCR_LOCK = 0x767B;
    R[ri++] = 0xBEEF0002;  // AFI done

    // === STEP 2: Fill ping with known data ===
    for (int i = 0; i < FRAME_SIZE; i++) ping_buf[i] = (unsigned char)(i & 0xFF);
    // D-cache is off (MMU off by default), no flush needed
    R[ri++] = 0xBEEF0003;

    // === STEP 3: Config accelerator (RIGHT, step=0 = pass-through) ===
    *(volatile unsigned*)(ACCEL_BASE + 0x08) = 4;   // CFG_DIR=RIGHT
    *(volatile unsigned*)(ACCEL_BASE + 0x10) = 32;  // IMG_COLS
    *(volatile unsigned*)(ACCEL_BASE + 0x0C) = 32;  // IMG_ROWS
    R[ri++] = 0xBEEF0004;

    // === STEP 4: Config DMA (PG021: RESET bit cleared by hardware) ===
    // Assert reset (bit2=1)
    *(volatile unsigned*)(DMA_BASE + MM2S_DMACR) = 4;
    *(volatile unsigned*)(DMA_BASE + S2MM_DMACR) = 4;
    // Wait for hardware to clear reset (DMASR.Halted=1)
    for (volatile int d = 0; d < 100000; d++);

    // Set addresses & length
    *(volatile unsigned*)(DMA_BASE + MM2S_SA)     = (unsigned)ping_buf;
    *(volatile unsigned*)(DMA_BASE + S2MM_DA)     = (unsigned)pong_buf;
    *(volatile unsigned*)(DMA_BASE + MM2S_LENGTH) = FRAME_SIZE;
    *(volatile unsigned*)(DMA_BASE + S2MM_LENGTH) = FRAME_SIZE;
    R[ri++] = 0xBEEF0005;

    // === STEP 5: Verify DMA is halted after reset (PG021: DMASR.Halted=1) ===
    R[ri++] = *(volatile unsigned*)(DMA_BASE + MM2S_DMASR);  // should be 0x0001 (Halted)
    R[ri++] = *(volatile unsigned*)(DMA_BASE + S2MM_DMASR);

    // === STEP 6: Start transfer ===
    // Accelerator first (enters CAPTURE)
    *(volatile unsigned*)(ACCEL_BASE) = 1;  // CTRL.start
    for (volatile int d = 0; d < 50000; d++);  // wait for FSM to enter CAPTURE

    // S2MM before MM2S (PG021: RS=1 starts DMA)
    *(volatile unsigned*)(DMA_BASE + S2MM_DMACR) = 1;  // RS=1
    *(volatile unsigned*)(DMA_BASE + MM2S_DMACR) = 1;  // RS=1
    R[ri++] = 0xBEEF0006;  // DMA started

    // === STEP 7: Wait ===
    for (volatile int d = 0; d < 0x800000; d++);
    R[ri++] = 0xBEEF0007;

    // === STEP 8: Read results ===
    R[ri++] = *(volatile unsigned*)(DMA_BASE + MM2S_DMASR);
    R[ri++] = *(volatile unsigned*)(DMA_BASE + S2MM_DMASR);
    R[ri++] = *(volatile unsigned*)(ACCEL_BASE + 4);  // STATUS

    // === STEP 8: Verify data ===
    int mismatch = -1;
    for (int i = 0; i < FRAME_SIZE; i++) {
        if (ping_buf[i] != pong_buf[i]) { mismatch = i; break; }
    }
    R[ri++] = mismatch;

    // First 4 bytes of each buffer
    R[ri++] = ping_buf[0] | (ping_buf[1]<<8) | (ping_buf[2]<<16) | (ping_buf[3]<<24);
    R[ri++] = pong_buf[0] | (pong_buf[1]<<8) | (pong_buf[2]<<16) | (pong_buf[3]<<24);

    R[ri++] = 0xBEEF9999;  // end marker
    while(1);
}
