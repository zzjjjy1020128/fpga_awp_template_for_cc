# Board Validation Plan — E001: AXI-Lite 2D Shift

> 上板验证计划，覆盖 L5（冒烟测试）和 L6（数据正确性）。
> B-G4 迭代模型和失败分诊规则见 CLAUDE.md §B-G4。

## 1. Validation Scope

| Level | 验证内容 | 平台 | 预计耗时 |
|-------|---------|------|:--:|
| L5 冒烟 | JTAG/时钟/PS启动/AXI-Lite读写/ILA触发 | AX7010 → ZCU102 | 30 min/平台 |
| L6 数据 | DMA传输/移位结果比对/ILA pipeline验证 | AX7010 → ZCU102 | 1-2 hr/平台 |
| L7 复盘 | 资源/吞吐/时序/调试效率评估 | 共享 | 30 min |

## 2. Platform Summary

| 参数 | AX7010 (主力) | ZCU102 (备选) |
|------|:--:|:--:|
| 器件 | xc7z010clg400-1 | xczu9eg-ffvb1156-2-e |
| PS | PS7 (Cortex-A9) | PS8 (Cortex-A53 + R5) |
| 时钟 | 50 MHz (FCLK_CLK0) | 100 MHz |
| BD ILA | system_ila_0, system_ila_1 | ila_capture, ila_shift |
| 比特流 | `vivado/shift_2d_ax7010_260608/.../design_1_wrapper.bit` | `vivado/shift_2d_zcu102_260606/.../design_1_wrapper.bit` |
| 基座状态 | frozen v1.0 | frozen v1.0 |

## 3. Hardware Setup

详见各平台硬件操作手册：
- AX7010: `board/hw_arch_ax7010.md`
- ZCU102: `board/hw_arch_zcu102.md`

### 通用检查清单

- [ ] 电源适配器电压/电流符合板卡要求
- [ ] JTAG 下载器连接（Platform Cable USB II 或兼容）
- [ ] UART USB 转串口连接（115200-8N1）
- [ ] 启动模式开关：JTAG 模式
- [ ] 板卡上电后电源 LED 亮起

## 4. L5 Smoke Test Plan

### 4.1 JTAG Chain Detection

```tcl
open_hw_manager
connect_hw_server
get_hw_targets
open_hw_target
```

预期：`get_hw_targets` 返回目标器件名。

### 4.2 Bitstream Download

```tcl
set_property PROBES.FILE {} [get_hw_devices]
set_property PROGRAM.FILE {<bitstream_path>} [get_hw_devices]
program_hw_devices
```

预期：下载成功，DONE LED 亮起。

### 4.3 Clock Verification

通过 ILA 捕获时钟信号，测量周期：AX7010 20ns (50 MHz) / ZCU102 10ns (100 MHz)。

### 4.4 PS Boot Check

通过 UART 终端观察 PS 启动信息。XSCT 方式：确认 CPU 可 halt/run。

### 4.5 AXI-Lite Register Access

通过 XSCT `mwr`/`mrd` 读写寄存器：
```tcl
mrd <axil_base_addr>           # 读 ID 寄存器
mwr <axil_base_addr+0x04> 0x01 # 写 CTRL 寄存器
mrd <axil_base_addr+0x04>      # 读回验证
```

### 4.6 ILA Trigger Test

配置触发条件（如 `s_axil_awvalid == 1`），执行一次 AXI-Lite 写操作，确认 ILA 捕获到波形。

## 5. L6 Data Correctness Test Plan

### 5.1 Test Data Patterns

| 模式 | 描述 | 用途 |
|------|------|------|
| INCR | 0,1,2,...,N-1 | 检测数据顺序错误 |
| CHECKER | 0x00, 0xFF, 0x00, 0xFF,... | 检测位翻转 |
| ZERO | 全 0x00 | 检测 stuck-at-1 |
| ONES | 全 0xFF | 检测 stuck-at-0 |

### 5.2 Shift Configurations

| 方向 | 步长 | 帧尺寸 | 边界 |
|------|------|--------|------|
| 左 | 1, 2 | 8x8, 64x64 | wrapping, zero-fill |
| 右 | 1, 2 | 8x8, 64x64 | wrapping, zero-fill |
| 上 | 1, 2 | 8x8, 64x64 | wrapping, zero-fill |
| 下 | 1, 2 | 8x8, 64x64 | wrapping, zero-fill |
| 左 | 1 | 15x31 (odd) | wrapping |

### 5.3 DMA Test Flow

```
1. PS CPU: 在 DDR 中生成测试图案 (src_buf)
2. PS CPU: 清零 DDR 中的接收缓冲区 (dst_buf)
3. PS CPU: 配置 DMA MM2S 描述符 (src_buf → accelerator s_axis)
4. PS CPU: 配置 DMA S2MM 描述符 (accelerator m_axis → dst_buf)
5. PS CPU: 配置 axil_2d_shift 寄存器（帧尺寸、移位参数、启动）
6. PS CPU: 启动 DMA MM2S + S2MM
7. 等待 DMA 中断（s2mm_introut）
8. PS CPU: 读取 dst_buf，与软件 golden 参考比对
9. PS CPU: UART 输出 PASS/FAIL
```

### 5.4 ILA Capture Plan

关键捕获信号：`s_axis_tdata/tvalid/tready/tlast`, `m_axis_tdata/tvalid/tready/tlast`, `ctrl_fsm.state`, `capture_en/shift_en`, `shift_addr_gen counters`, `read_addr/data`, `zero_fill`。触发条件：`s_axis_tvalid && s_axis_tready`。

## 6. Golden Data Reference

L6 数据正确性比对的 golden 数据来自 L1c 全系统仿真 (`sim/sim_axil_2d_shift.log`)。若仿真未保存 golden 文件，需先运行 `sim/run_axil_2d_shift_sim.py --save-golden`。

## 7. Failure Handling (B-G4)

上板验证失败遵循 B-G4 分诊模型（CLAUDE.md §B-G4）。每次上板 session 失败必须记录：
- `failure_category` (CAT-HW/BS/AX/IL/SW/DT/RT)
- `platform_id`
- `hardware_evidence` (ILA 波形、PS 日志)
- `bitstream_version` (SHA256 或生成日期)

## 8. Run Records Index

| Run ID | Task | Platform | Level | 状态 |
|--------|------|----------|:--:|:--:|
| RUN-E001-BOARD-001 | TASK-019 | AX7010 | B0 infra | pending |
| RUN-E001-BOARD-002 | TASK-020 | ZCU102 | B0 infra | pending |
| RUN-E001-BOARD-003 | TASK-021 | AX7010 | L5 | pending |
| RUN-E001-BOARD-004 | TASK-022 | ZCU102 | L5 | pending |
| RUN-E001-BOARD-005 | TASK-024 | AX7010 | L6 | pending |
| RUN-E001-BOARD-006 | TASK-025 | ZCU102 | L6 | pending |
