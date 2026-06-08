// platform.c — BSP 平台初始化
// 独立实现，不依赖 Vitis 模板

#include "xil_cache.h"
#include "xil_printf.h"

void init_platform(void)
{
    Xil_DCacheEnable();
    Xil_ICacheEnable();
}

void cleanup_platform(void)
{
    Xil_DCacheDisable();
    Xil_ICacheDisable();
}
