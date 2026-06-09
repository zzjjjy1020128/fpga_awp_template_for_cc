// afi_patch.h — HP0 AXI interface init for Zynq-7000 bare-metal apps
//
// Workaround for Vivado 2022.2 bug: ps7_init does NOT configure AFI registers
// for HP slave ports, even when USE_S_AXI_HP0=1 in the PS7 IP config.
//
// Usage: call afi_hp0_init() once after ps7_init/init_platform,
//        before any DMA transfer through HP0.
#ifndef AFI_PATCH_H
#define AFI_PATCH_H

#include "xil_types.h"

static inline void afi_hp0_init(void)
{
    // SLCR unlock
    *(volatile u32*)0xF8000008 = 0xDF0D;

    // AFI0: HP0 RDCHAN 64-bit width (bits[31:28]=1)
    // Reset default is 0 (32-bit), BD configures HP0=64-bit
    *(volatile u32*)0xF8000860 = 0x10000000;

    // AFI1: HP0 WRCHAN 64-bit width
    *(volatile u32*)0xF8000864 = 0x10000000;

    // APER_CLK_CTRL: enable AXI_HP0 clock (bit11)
    // ps7_init explicitly clears this bit
    *(volatile u32*)0xF800012C |= 0x0800;

    // SLCR lock
    *(volatile u32*)0xF8000004 = 0x767B;
}

#endif // AFI_PATCH_H
