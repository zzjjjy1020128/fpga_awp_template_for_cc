# 上板验证记录

> RUN-E001-BOARD-003: L5 AX7010 冒烟测试 (第二轮)

## 基本信息

- **Board**：Alinx AX7010
- **Platform ID**：`HW_BASE_AX7010_v1.2`（ILA 时钟改回 FCLK_CLK0）
- **Bitstream**：`vivado/shift_2d_ax7010_260608/.../impl_1/design_1_wrapper.bit` (2.0 MB)
- **Vivado Version**：2022.2
- **Date**：2026-06-09
- **Validation Level**：L5 (冒烟测试)
- **Round**：2/2

## 本轮关键变更

上一轮 (Round 1) ILA 时钟源为板载 U18 晶振 (BD v1.1)，调试发现 debug hub 不可检测。
根因诊断：U18 (Y2) 50MHz 晶振在 AX7010 板卡标注"未使用"，极可能未启振。

本轮修复：
1. BD v1.1 → v1.2：ILA 时钟改回 FCLK_CLK0 (PS7 IP)
2. 移除 `constraints/debug.xdc` 中无效的 `create_generated_clock`（dbg_hub 在 XDC 解析时不存在）
3. 重新综合 (0 CW) → 实现 (0 CW) → 比特流 (2.0 MB)

## 测试执行

### 1. JTAG 链检测 ✅ PASS

```tcl
open_hw_manager → connect_hw_server → get_hw_targets
→ localhost:3121/xilinx_tcf/Digilent/210512180081
→ arm_dap_0 + xc7z010_1
→ IDCODE = 0x13722093 (Zynq-7010 ✓)
```

### 2. 比特流下载 ✅ PASS

```tcl
program_hw_devices → DONE=HIGH, 0 errors
```

### 3. PS 初始化 ✅ PASS

通过 XSDB 脚本执行 `ps7_init` + `ps7_post_config`，FCLK_CLK0 = 50MHz 启动。

关键发现：XSDB 与 Vivado MCP 可共存——Vivado 管 hw_server/PL，XSDB 直连 DAP/PS，不冲突。

### 4. ILA 探针检测 ✅ PASS

```tcl
refresh_hw_device → 2 ILA core(s)
hw_ila_1: 32 probes (system_ila_0, AXI control plane)
hw_ila_2: 32 probes (system_ila_1, AXI data path)
```

### 5. ILA 波形捕获 ✅ PASS

```tcl
run_hw_ila [get_hw_ilas]
→ ILA1: CORE_STATUS=FULL, SAMPLE_COUNT=1024
→ ILA2: CORE_STATUS=FULL, SAMPLE_COUNT=1024
```

ILA 在 ALWAYS 捕获模式下连续采集 1024 个样本，缓冲满后停止。波形数据存在 `hw_ila_data_1` / `hw_ila_data_2` 对象中。

### 6. AXI-Lite 寄存器访问 ✅ PASS (mwr CPU 执行方案)

XSDB `dow` (ELF 下载) 因 DAP TCF Download 服务上下文失效（Code 16）阻塞——
但 **DAP Memory 服务 (`mwr`/`mrd`) 正常工作**。

通过实验发现：`mwr` 可将 ARM 机器码直接写入 OCM，`rwr pc 0` + `con` 即可
让 CPU 执行。用 14 条 ARM 指令实现最小化 AXI-Lite 寄存器测试，完全无需 ELF：

```
Vivado MCP → program bitstream
XSDB       → ps7_init → ps7_post_config
XSDB       → mwr 14条指令到 OCM 0x0
XSDB       → rwr pc 0 → con → stop
XSDB       → mrd 0x10000 读取结果
```

实测结果：
| 寄存器 | 地址 | 操作 | 结果 |
|--------|------|------|:--:|
| STATUS | 0x60000004 | 读 | 0x00000001 (IDLE) ✅ |
| CFG | 0x60000008 | 写 0x105 再读 | 0x00000105 ✅ |
| CTRL | 0x60000000 | 读 (WO寄存) | 0x00000000 ✅ |

关键发现：`dow` 失败 ≠ 不能加载代码。DAP 的 Download 服务和 Memory 服务
是独立的 TCF 协议层——Download 需要 CPU 上下文，Memory 直接走 DAP 的 AHB-AP。

### 7. 完整的 CLI 自动化链路

```
┌─ Vivado MCP ──────────────────────────────────────┐
│  open_hw_manager → program_hw_devices              │
│  → refresh_hw_device → get_hw_ilas (2 cores)       │
│  → run_hw_ila → wait → upload_hw_ila_data          │
└────────────────────────────────────────────────────┘
         ↓ (FPGA configured, ILA armed)
┌─ XSDB ─────────────────────────────────────────────┐
│  connect → targets APU → ps7_init → ps7_post_config│
│  → mwr <program> to OCM → rwr pc 0 → con → stop   │
│  → mrd <result> from OCM                           │
└────────────────────────────────────────────────────┘
         ↓ (AXI-Lite test completes)
┌─ Vivado MCP ──────────────────────────────────────┐
│  get_hw_ila_datas → 1024 samples captured          │
└────────────────────────────────────────────────────┘
```

全 CLI、无 GUI、无 SD 卡、无手动插拔。

## 硬件证据

- **ILA 波形**：hw_ila_data_1 (1024 samples), hw_ila_data_2 (1024 samples)
- **PS 日志**：ps7_init + ps7_post_config 均成功执行
- **比特流版本**：v1.2 (ILA clock = FCLK_CLK0, 0 CW)

## 工具链分工发现

| 工具 | 职责 | 连接方式 |
|------|------|---------|
| Vivado MCP | PL 编程 + ILA 操作 | hw_server → PL TAP |
| XSDB | PS 初始化 + CPU 控制 | TCF → ARM DAP |

两者可同时工作，不冲突。**禁止 XSCT `rst` 命令**（会清除 PL 配置，DONE→0）。

## 结论

- **Status**：PASS — L5 冒烟核心指标全部通过
- **ILA 调试基础设施**：完全可用，CLI 自动化链路打通
- **已知限制**：XSDB CLI ELF 下载待解决（Vitis GUI 路径可用作 fallback）
- **Failure Category**：本轮无失败

## 迭代轮次

- Round 1 (2026-06-08)：CAT-IL — ILA 时钟源 U18 未启振 → 根因定位
- Round 2 (2026-06-09)：BD v1.2 修复 → 全部核心指标 PASS
- L5 冒烟验证完成，可进入 L6 数据正确性验证

## 后续行动

1. 用户验证 UART 输出（Vitis GUI Run 或解决 XSDB ELF 下载问题）
2. L6 数据正确性测试（TASK-E001-024）：DMA 传输 + 移位结果比对
3. 方法收敛为 skills：`bd-debug-clock`（诊断链）、`zynq-debug-toolchain`（工具链分工 + CLI ILA 配方）
