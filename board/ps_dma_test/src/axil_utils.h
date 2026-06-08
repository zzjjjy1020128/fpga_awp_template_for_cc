// axil_utils.h — AXI4-Lite 寄存器读写工具
// 目标平台: AX7010 (xc7z010clg400-1)
// 用于: 通过 PS M_AXI_GP0 访问 axil_2d_shift 的 AXI-Lite 从接口
//
// 地址映射 (来自 BD Address Editor, 预期值):
//   axil_2d_shift_0: 0x43C0_0000 (64 KB 范围)
//   AXI DMA_0:       0x43C1_0000 (64 KB 范围)
//
// 在 xparameters.h 中查找的宏:
//   XPAR_AXIL_2D_SHIFT_0_S_AXI_BASEADDR — 加速器基地址
//   XPAR_AXI_DMA_0_BASEADDR              — DMA 基地址

#ifndef AXIL_UTILS_H
#define AXIL_UTILS_H

#include "xil_types.h"  /* u32, u16, u8 */

// ============================================================================
// 加速器寄存器偏移 (RTL: regs_top.sv 定义)
// 每个 slot 对齐到 4 字节 (AXI4-Lite 固定)
// ============================================================================

// Slot 0 (0x00): CTRL (WO, 读返回 0)
//   [0] = start      — WO, self-clearing: 写 1 启动加速器
//   [1] = sw_reset   — WO, self-clearing: 写 1 软复位
#define ACCEL_OFFSET_CTRL       0x00U

// Slot 1 (0x04): STATUS (RO)
//   [0] = idle           — 1=空闲
//   [1] = busy_capture   — 1=正在采集
//   [2] = busy_shift     — 1=正在移位
//   [3] = done           — 1=完成 (锁存, 写 CTRL.start 清除)
#define ACCEL_OFFSET_STATUS     0x04U

// Slot 2 (0x08): CFG (RW)
//   [2:0] = dir       — 方向: 0=none, 1=UP, 2=DOWN, 3=LEFT, 4=RIGHT
//   [7:3] = step      — 步长 (0-31)
//   [8]   = wrap_en   — 1=缠绕模式, 0=补零
#define ACCEL_OFFSET_CFG        0x08U

// Slot 3 (0x0C): IMG_ROWS (RW, [9:0], 默认=1)
#define ACCEL_OFFSET_IMG_ROWS   0x0CU

// Slot 4 (0x10): IMG_COLS (RW, [9:0], 默认=1)
#define ACCEL_OFFSET_IMG_COLS   0x10U

// 保留区间 0x14-0x3C (slot 5-15): 读返回 0, 写忽略

// ============================================================================
// CTRL 寄存器位定义
// ============================================================================
#define ACCEL_CTRL_START        (1U << 0)
#define ACCEL_CTRL_SW_RESET     (1U << 1)

// ============================================================================
// STATUS 寄存器位定义
// ============================================================================
#define ACCEL_STATUS_IDLE           (1U << 0)
#define ACCEL_STATUS_BUSY_CAPTURE   (1U << 1)
#define ACCEL_STATUS_BUSY_SHIFT     (1U << 2)
#define ACCEL_STATUS_DONE           (1U << 3)

// ============================================================================
// CFG 寄存器位域
// ============================================================================
#define ACCEL_CFG_DIR_MASK      0x07U
#define ACCEL_CFG_STEP_SHIFT    3
#define ACCEL_CFG_STEP_MASK     (0x1FU << ACCEL_CFG_STEP_SHIFT)  // [7:3]
#define ACCEL_CFG_WRAP_EN       (1U << 8)

// ============================================================================
// 移位方向常量
// ============================================================================
#define ACCEL_DIR_NONE      0
#define ACCEL_DIR_UP        1
#define ACCEL_DIR_DOWN      2
#define ACCEL_DIR_LEFT      3
#define ACCEL_DIR_RIGHT     4

// ============================================================================
// 函数原型
// ============================================================================

// 基本寄存器访问 (使用 Xil_In32 / Xil_Out32)
u32     axil_read_reg(u32 base_addr, u32 offset);
void    axil_write_reg(u32 base_addr, u32 offset, u32 value);

// 加速器专用操作
u32     axil_read_status(u32 base_addr);
void    axil_set_cfg(u32 base_addr, u32 dir, u32 step, u32 wrap_en);
void    axil_set_img_size(u32 base_addr, u32 rows, u32 cols);
void    axil_start(u32 base_addr);
void    axil_sw_reset(u32 base_addr);

// 等待 STATUS.done (轮询, 超时返回 -1)
int     axil_wait_for_done(u32 base_addr, u32 timeout_ms);

// 打印所有寄存器
void    axil_dump_regs(u32 base_addr);

// 自测试: CFG/IMG_ROWS/IMG_COLS 写回读
// 返回 0 = PASS, -1 = FAIL
int     axil_reg_test(u32 base_addr);

#endif /* AXIL_UTILS_H */
