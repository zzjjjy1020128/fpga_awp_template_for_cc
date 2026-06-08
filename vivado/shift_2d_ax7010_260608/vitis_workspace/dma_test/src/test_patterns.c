// test_patterns.c — 测试数据生成与验证实现

#include "test_patterns.h"
#include "xil_printf.h"

// ============================================================================
// 递增模式: 0, 1, 2, ..., 255, 0, 1, ...
// 每 256 字节循环一次, 适合检测 bit 错位
// ============================================================================

void fill_pattern_increment(u8 *buf, u32 len)
{
    for (u32 i = 0; i < len; i++) {
        buf[i] = (u8)(i & 0xFF);
    }
}

// ============================================================================
// 棋盘格: (r+c) % 2 == 0 -> 0xAA, else -> 0x55
// 相邻像素必然不同, 适合检测 stream 错位或数据混淆
// ============================================================================

void fill_pattern_checkerboard(u8 *buf, u32 rows, u32 cols)
{
    for (u32 r = 0; r < rows; r++) {
        for (u32 c = 0; c < cols; c++) {
            buf[r * cols + c] = ((r + c) & 1U) ? 0x55 : 0xAA;
        }
    }
}

// ============================================================================
// 固定值填充
// ============================================================================

void fill_pattern_fixed(u8 *buf, u32 len, u8 value)
{
    for (u32 i = 0; i < len; i++) {
        buf[i] = value;
    }
}

// ============================================================================
// 行斜坡: 每行值 = 列号 % 256
//   同一行相邻像素递增, 行与行之间相同
//   适合检测行错位 (每行重复)
// ============================================================================

void fill_pattern_ramp_row(u8 *buf, u32 rows, u32 cols)
{
    for (u32 r = 0; r < rows; r++) {
        for (u32 c = 0; c < cols; c++) {
            buf[r * cols + c] = (u8)(c & 0xFF);
        }
    }
}

// ============================================================================
// 列斜坡: 每列值 = 行号 % 256
//   同一列相邻像素递增, 列与列之间相同
//   适合检测列错位 (每列重复)
// ============================================================================

void fill_pattern_ramp_col(u8 *buf, u32 rows, u32 cols)
{
    for (u32 r = 0; r < rows; r++) {
        for (u32 c = 0; c < cols; c++) {
            buf[r * cols + c] = (u8)(r & 0xFF);
        }
    }
}

// ============================================================================
// 验证: 逐字节比较两个缓冲区
//   返回: 0 = 完全匹配
//         N = 首个不匹配的索引 + 1 (即 mismatch at index N-1)
// ============================================================================

int verify_pattern(const u8 *expected, const u8 *actual, u32 len)
{
    for (u32 i = 0; i < len; i++) {
        if (expected[i] != actual[i]) {
            return (int)(i + 1);  // mismatch at index i
        }
    }
    return 0;  // all match
}

// ============================================================================
// Hex dump 到 UART
//   每行 items_per_line 个字节 (建议 16)
// ============================================================================

void dump_buf(const u8 *buf, u32 len, u32 items_per_line)
{
    for (u32 i = 0; i < len; i++) {
        if (i % items_per_line == 0) {
            if (i != 0) xil_printf("\r\n");
            xil_printf("  %04x: ", i);
        }
        xil_printf("%02x ", buf[i]);
    }
    xil_printf("\r\n");
}

// ============================================================================
// 只打印 mismatch 的位置和期望/实际值
//   max_display: 最大显示条数 (防止刷屏)
// ============================================================================

void dump_mismatch(const u8 *expected, const u8 *actual, u32 len, u32 max_display)
{
    u32 display_count = 0;
    u32 total_mismatch = 0;

    // 先统计总数
    for (u32 i = 0; i < len; i++) {
        if (expected[i] != actual[i]) {
            total_mismatch++;
        }
    }

    // 打印前 max_display 条
    for (u32 i = 0; i < len && display_count < max_display; i++) {
        if (expected[i] != actual[i]) {
            xil_printf("  [%4d] exp=0x%02x act=0x%02x\r\n",
                       i, expected[i], actual[i]);
            display_count++;
        }
    }

    if (total_mismatch > max_display) {
        xil_printf("  ... (%d total mismatches, showing first %d)\r\n",
                   total_mismatch, max_display);
    } else {
        xil_printf("  Total mismatches: %d\r\n", total_mismatch);
    }
}
