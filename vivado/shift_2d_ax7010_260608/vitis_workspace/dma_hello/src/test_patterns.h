// test_patterns.h — 测试数据生成与验证工具
//
// 提供递增、棋盘格、固定值等模式用于 DMA 传输验证。
// 所有函数在 PS DDR 中操作, 配合 Xil_DCacheFlushRange 使用。

#ifndef TEST_PATTERNS_H
#define TEST_PATTERNS_H

#include "xil_types.h"  /* u8, u32 */

// ============================================================================
// 模式生成
// ============================================================================

// 递增模式: 0, 1, 2, ..., 255, 0, 1, ...
void fill_pattern_increment(u8 *buf, u32 len);

// 棋盘格: (r+c)偶=0xAA, (r+c)奇=0x55
void fill_pattern_checkerboard(u8 *buf, u32 rows, u32 cols);

// 固定值: buf 全部设为 value
void fill_pattern_fixed(u8 *buf, u32 len, u8 value);

// 行斜坡: 每行值 = 列号 % 256
void fill_pattern_ramp_row(u8 *buf, u32 rows, u32 cols);

// 列斜坡: 每列值 = 行号 % 256
void fill_pattern_ramp_col(u8 *buf, u32 rows, u32 cols);

// ============================================================================
// 验证
// ============================================================================

// 比较两个缓冲区, 返回 0 = 完全匹配, >0 = 首个不匹配的索引+1
int verify_pattern(const u8 *expected, const u8 *actual, u32 len);

// ============================================================================
// 调试输出
// ============================================================================

// Hex dump: 每行 items_per_line 个字节
void dump_buf(const u8 *buf, u32 len, u32 items_per_line);

// 打印 mismatches: 最多显示 max_display 条
void dump_mismatch(const u8 *expected, const u8 *actual, u32 len, u32 max_display);

#endif /* TEST_PATTERNS_H */
