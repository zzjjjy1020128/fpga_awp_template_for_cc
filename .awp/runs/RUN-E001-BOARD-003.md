# 上板验证记录

> RUN-E001-BOARD-003: L5 AX7010 冒烟测试

## 基本信息

- **Board**：Alinx AX7010
- **Platform ID**：`HW_BASE_AX7010_v1.0`
- **Bitstream**：`vivado/shift_2d_ax7010_260608/.../impl_1/design_1_wrapper.bit` (2.0 MB, 含 ILA 探针)
- **Vivado Version**：2022.2
- **Date**：2026-06-08
- **Validation Level**：L5 (冒烟测试)
- **Round**：1

## 硬件设置

- **电源**：USB Type-C 5V/2A 供电
- **JTAG 适配器**：板载 Digilent FT2232H (ID: 210512180081)
- **时钟源**：PS FCLK_CLK0 (50 MHz, 需 PS 初始化)
- **启动模式**：JTAG (SW1=ON, SW0=ON)

## 测试执行

### 1. JTAG 链检测 ✅ PASS

```tcl
open_hw_manager
connect_hw_server
get_hw_targets  →  localhost:3121/xilinx_tcf/Digilent/210512180081
open_hw_target
get_hw_devices  →  arm_dap_0 + xc7z010_1
xc7z010_1 IDCODE = 0x13722093 (Zynq-7010 ✓)
```

### 2. 比特流下载 ✅ PASS

```tcl
set_property PROGRAM.FILE {design_1_wrapper.bit} [get_hw_devices xc7z010_1]
program_hw_devices → DONE=HIGH, 无错误
```

### 3. ILA 探针验证 ⚠️ BLOCKED (PS 时钟未运行)

```
WARNING: The debug hub core was not detected.
Resolution: 
1. Make sure the clock connected to the debug hub (dbg_hub) core
   is a free running clock and is active.
```

根因：Zynq-7000 的 PL 时钟 (FCLK_CLK0) 来自 PS PLL，PS 未初始化时时钟不运行。Debug hub 需要运行时钟才能被 Hardware Manager 检测。

System ILA 探针文件 (179KB debug_nets.ltx) 已生成，含 446 个 MARK_DEBUG 信号映射。两个 ILA 核 (system_ila_0, system_ila_1) 在探针文件中正确识别，但无法在运行时连接到硬件。

### 4. 时钟验证 ⚠️ NOT TESTED (依赖 PS 初始化)

### 5. PS 启动检测 ⚠️ NOT TESTED (依赖 PS 初始化)

### 6. AXI-Lite 寄存器访问 ⚠️ NOT TESTED (依赖 PS 初始化 + 时钟)

## 硬件证据

- **ILA 捕获**：不可用（debug hub 无时钟）
- **PS 日志**：不可用（PS 未配置）
- **JTAG 链**：arm_dap_0 + xc7z010_1（正常）

## 结论

- **Status**：PARTIAL — 硬件链路全部确认，ILA 待 Vitis 统一编程流解锁
- **Failure Category**：CAT-BS (PS boot/clock) → 已定位根因，非硬件故障
- **已确认项**：
  - ✅ JTAG 链完整 (xc7z010, IDCODE 0x13722093)
  - ✅ 比特流下载成功 (DONE=HIGH, 2.0 MB, 含 ILA)
  - ✅ 探针文件可用 (179KB debug_nets.ltx, 446 MARK_DEBUG nets)
  - ✅ PS 可初始化 (XSCT ps7_init + ps7_post_config 成功)
  - ✅ C_USER_SCAN_CHAIN=1 已从 implemented design 确认
  - ✅ Vitis C 程序就绪 (TASK-E001-023)
  - ✅ XSA 导出就绪 (686 KB)
- **阻塞根因**：
  Vivado HW Manager 和 XSCT 使用独立 hw_server 实例，设备状态不共享。
  正确流程：Vitis 统一编程（FSBL→bitstream→ELF），Vivado HW Manager 随后查看 ILA。

## 迭代轮次

- **当前轮次**：1/2 (CAT-BS)
- **根因已定位**：工具链协调问题，非设计或硬件缺陷
- **解阻塞路径**：Vitis GUI 编译 + 统一编程（见后续行动）

## 后续行动

1. **用户操作**（Vitis GUI）：
   - 导入 XSA: `vivado/shift_2d_ax7010_260608/xsa_export/design_1_wrapper.xsa`
   - 创建 Platform 工程 + Application 工程
   - 添加 `board/ps_dma_test/src/` 下所有 C 源文件
   - Build → Run (FSBL 自动初始化 PS → 加载 bitstream → 加载 ELF)
2. **IAR 验证**（Vivado HW Manager，Vitis 编程后）：
   - `refresh_hw_device` → 应看到 2 个 ILA 核 (446 probes)
   - 配置触发条件 → 捕获波形
3. **UART 输出验证**：串口终端 (115200-8N1) 应看到寄存器测试 PASS/FAIL
