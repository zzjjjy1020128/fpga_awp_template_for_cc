@ Full DMA loopback test — MMU off before accessing PL AXI
.section .text
.global _start
_start:
    @ Disable MMU
    mrc p15, 0, r0, c1, c0, 0
    bic r0, r0, #1
    mcr p15, 0, r0, c1, c0, 0
    dsb; isb
    mov r0, #0
    mcr p15, 0, r0, c7, c5, 0
    mcr p15, 0, r0, c7, c5, 6
    dsb; isb

    @ Enable AFI0 HP0 with correct 32-bit width
    @ RDCHAN @ 0xF8008000, WRCHAN @ 0xF8008014 (NOT 0x8004!)
    ldr r0, =0xF8008000
    mov r2, #1
    str r2, [r0]            @ RDCHAN_CTRL n32BitEn=1
    str r2, [r0, #0x14]     @ WRCHAN_CTRL n32BitEn=1

    @ Load base addresses
    ldr r3, =0x60000000
    ldr r4, =0x40400000
    ldr r5, =0x40400030
    ldr r8, =0x00200200

    @ Fill ping_buf with increment
    ldr r6, =0x00110760
    mov r0, #0
    mov r9, #0x40       @ 64 words = 256 bytes for quick test
    ldr r10, =0x04040404
1:
    str r0, [r6], #4
    add r0, r0, r10
    subs r9, r9, #1
    bne 1b

    @ Checkpoint 1
    ldr r1, =0xDAAD0001
    str r1, [r8]

    @ Config accelerator: pass-through, 8x8 frame
    mov r0, #4
    mov r1, #8
    str r0, [r3, #8]
    str r1, [r3, #12]
    str r1, [r3, #16]

    @ Reset DMA fully + disable SG mode
    mov r0, #4
    str r0, [r4]            @ MM2S reset
    str r0, [r5]            @ S2MM reset
    mov r0, #0
    str r0, [r4, #44]       @ MM2S_SGCTL = 0 (disable SG)
    str r0, [r5, #44]       @ S2MM_SGCTL = 0 (disable SG)
    str r0, [r4]            @ Clear MM2S reset
    str r0, [r5]            @ Clear S2MM reset
    str r0, [r4, #0x2C]     @ MM2S_SGCTL again (offset 0x2C)

    @ Set DMA addresses and length (64 words = 256 bytes)
    ldr r6, =0x00110760
    ldr r7, =0x00110B60
    ldr r9, =64
    str r6, [r4, #24]
    str r7, [r5, #24]
    str r9, [r4, #40]
    str r9, [r5, #40]

    @ Checkpoint 2
    ldr r1, =0xDAAD0002
    str r1, [r8, #4]

    @ Flush D-cache for ping (16 lines for 1024 bytes)
    ldr r0, =0x00110760
    add r9, r0, #1024
1:
    mcr p15, 0, r0, c7, c10, 1
    add r0, r0, #64
    cmp r0, r9
    blt 1b
    dsb

    @ Start accelerator → S2MM → MM2S
    mov r0, #1
    str r0, [r3]
    ldr r9, =50000
1:  subs r9, r9, #1
    bne 1b
    str r0, [r5]
    str r0, [r4]

    @ Wait
    ldr r9, =0x200000
1:  subs r9, r9, #1
    bne 1b

    @ Checkpoint 3
    ldr r1, =0xDAAD0003
    str r1, [r8, #8]

    @ Invalidate D-cache for pong
    ldr r0, =0x00110B60
    add r9, r0, #1024
1:
    mcr p15, 0, r0, c7, c6, 1
    add r0, r0, #64
    cmp r0, r9
    blt 1b
    dsb

    @ Read results
    ldr r7, =0x00110B60
    ldr r2, [r7]
    str r2, [r8, #12]       @ pong[0]
    ldr r2, [r7, #4]
    str r2, [r8, #16]       @ pong[1]

    ldr r2, [r3, #4]
    str r2, [r8, #20]       @ STATUS

    ldr r2, [r4, #4]
    str r2, [r8, #24]       @ MM2S_DMASR
    ldr r2, [r5, #4]
    str r2, [r8, #28]       @ S2MM_DMASR

    ldr r6, =0x00110760
    ldr r2, [r6]
    str r2, [r8, #32]       @ ping[0]

    ldr r1, =0xDAAD9999
    str r1, [r8, #36]       @ FINAL marker

1:  b 1b
