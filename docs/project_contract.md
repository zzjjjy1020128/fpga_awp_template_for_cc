# 项目合同 —— E001: AXI-Lite 2D Shift

> 合同状态: **candidate**（首次汇编，待跑通一次完整流程后升级为 frozen）
> 汇编日期: 2026-06-07
> 
> 本项目合同由三部分组成，共同定义"在什么平台上、用什么工具、以什么标准验收"。
> 三份合同有统一的状态生命周期: unknown → draft → candidate → frozen → revised。

---

## 合同索引

| # | 合同 | 文件 | 状态 | 冻结日期 |
|---|------|------|:--:|------|
| 1 | 硬件基座合同 (ZCU102) | `.awp/platform/hw_base_zcu102_v1.0.yaml` | **frozen** | 2026-06-07 |
| 1b | 硬件基座合同 (AX7010) | `.awp/platform/hw_base_ax7010_v1.0.yaml` | **待创建** (TASK-E001-018) | — |
| 2 | 软件环境合同 | `docs/project_contract.md#2-软件环境合同` (本文 §2) | **frozen** | 2026-06-08 |
| 3 | 验收与约束合同 | `docs/project_contract.md#3-验收与约束合同` (本文 §3) | candidate | — |

---

## 1. 硬件基座合同

> 权威来源: `.awp/platform/hw_base_v1.0.yaml`
> 状态: **frozen**

### 摘要

| 项目 | 值 |
|------|-----|
| 基座版本 | HW_BASE_v1.0 |
| 器件 | xczu9eg-ffvb1156-2-e (Zynq UltraScale+ MPSoC) |
| 板卡 | ZCU102 |
| Vivado 工程 | `vivado/shift_2d_zcu102_260606/shift_2d_zcu102_260606.xpr` |
| BD 名称 | design_1 (wrapper: design_1_wrapper) |

### BD 内 IP（全部冻结）

| IP | VLNV | 数 |
|----|------|:--:|
| Zynq UltraScale+ PS | zynq_ultra_ps_e:3.4 | 1 |
| AXI Interconnect | axi_interconnect:2.1 | 1 |
| AXI SmartConnect | smartconnect:1.0 | 1 |
| AXI DMA (8-bit, Simple) | axi_dma:7.1 | 1 |
| Processor System Reset | proc_sys_reset:5.0 | 1 |
| ILA (1024 depth) | ila:6.2 | 2 |
| xlconcat | xlconcat:2.1 | 1 |

### Accelerator 插槽

| 插槽 | 协议 | 位宽 |
|------|------|------|
| SLOT_AXIL | AXI4-Lite | 32-bit addr / 32-bit data |
| SLOT_AXIS_I | AXI4-Stream | 8-bit data |
| SLOT_AXIS_O | AXI4-Stream | 8-bit data |
| SLOT_IRQ | Single wire | 1-bit |

### 约束文件

| 文件 | 层级 | 状态 |
|------|------|:--:|
| `constraints/base_timing.xdc` | 基座 | frozen |
| `constraints/base_physical.xdc` | 基座 | frozen (空) |

### 验证状态

| 级别 | 状态 | 指标 |
|------|:--:|------|
| L2 综合 | pass | 0 errors |
| L3 实现 | pass | WNS +5.636 ns, WHS +0.010 ns |
| L4 比特流 | pass | 26.5 MB, design_1_wrapper.bit |

---

## 2. 软件环境合同

> 状态: **frozen** (冻结日期: 2026-06-08)
> 
> 以下信息从 MCP session 日志、Makefile、requirements.txt 及当前会话环境中提取并已由用户确认。

### 2.1 综合/实现工具链

| 项目 | 值 | 状态 |
|------|-----|:--:|
| Vivado 版本 | **2022.2** | confirmed |
| Vivado 安装路径 | `G:/vivado2022.2/Vivado/2022.2/` | confirmed |
| Vivado 可执行文件 | `G:/vivado2022.2/Vivado/2022.2/bin/vivado.bat` | confirmed |
| License 状态 | OK（综合/实现均成功获取 license） | confirmed |
| 支持的器件系列 | zynquplus (xczu9eg) | confirmed |
| Board files | 未使用独立 board files（PS IP 内置） | N/A |
| MCP Vivado 端口 | 9999 (tcl mode) | confirmed |

### 2.2 仿真工具链

| 项目 | 值 | 状态 |
|------|-----|:--:|
| 主要仿真器 | Icarus Verilog (iverilog + vvp) | confirmed |
| Icarus 版本 | 11.0 (devel) | confirmed |
| Icarus 路径 | `/g/iverilog/iverilog/bin/iverilog` | confirmed |
| XSim (Vivado 内置) | 可用但不稳定（Win 11 NoDefaultCurrentDirectoryInExePath 策略影响） | confirmed |
| 备用仿真器 | 无 | N/A |
| 波形查看器 | GTKWave（随 Icarus 安装，也可用 Vivado 内置） | confirmed |

### 2.3 脚本与自动化

| 项目 | 值 | 状态 |
|------|-----|:--:|
| Python 版本 | 3.11.9 | confirmed |
| Python 路径 | 系统默认 | confirmed |
| PyYAML | 6.0.3 | confirmed |
| 其他依赖 | 无（仅需 PyYAML） | confirmed |
| make | 可用（路径: MSYS2/Cygwin） | confirmed |
| Vivado Tcl (MCP) | 可用 | confirmed |
| iverilog (via MCP) | 已安装，已在系统 PATH (`/g/iverilog/iverilog/bin/`) | confirmed |

### 2.4 操作系统与环境

| 项目 | 值 | 状态 |
|------|-----|:--:|
| OS | Windows 11 Home China (build 26200) | confirmed |
| Shell | bash (MSYS2/Cygwin via Claude Code) | confirmed |
| 路径编码 | **GBK** (Windows 默认) — 已知风险，见 ISS-E001-001 | confirmed |
| 换行符 | CRLF (Windows) / LF (Git managed) | confirmed |
| Git 版本 | Git for Windows | confirmed |
| Pre-commit hook | 已安装（`python scripts/install_pre_commit.py`），兼容 AWP v0.2 | confirmed |
| Win 11 策略风险 | `NoDefaultCurrentDirectoryInExePath` 已开启，影响 Vivado sim 子进程 | confirmed |

### 2.5 IP 与外部依赖

| 项目 | 值 | 状态 |
|------|-----|:--:|
| 本地 IP repo | `vivado/ip/` (axil_2d_shift_v1_0) | confirmed |
| Vivado IP catalog | Vivado 2022.2 内置 + 本地 repo | confirmed |
| Vendor IP 许可证 | OK | confirmed |

### 2.6 上板工具链

| 项目 | 值 | 状态 |
|------|-----|:--:|
| Vitis / XSDK | Vitis 2022.2（与 Vivado 同版本） | confirmed |
| HW Manager | Vivado 2022.2 内置 | confirmed |
| JTAG 连接 | ZCU102 板载 USB-JTAG | confirmed |
| 串口终端 | PuTTY（连接 PS UART1 MIO 48,49 @115200） | confirmed |

### 2.7 已知环境问题

1. **路径编码 GBK**：Windows 默认 GBK 编码曾导致 10 个 RUN 文件无法以 UTF-8 读取（ISS-E001-001），已在 `validate_awp.py` 中添加 GBK fallback
2. **XSim 子进程**：Win 11 24H2+ `NoDefaultCurrentDirectoryInExePath` 策略导致 Vivado sim 子进程启动失败，需手动设置注册表绕过
3. **GUI vs Tcl 冲突**：Vivado 不支持同一工程同时被 GUI 和 Tcl 打开（会话实测），协作时需互斥

---

## 3. 验收与约束合同

> 状态: **candidate**
> 
> 标准从各 task YAML 的 acceptance 字段与 session 实测数据中提取。

### 3.1 全局验收标准

| 级别 | 通过标准 | 当前状态 | 证据 |
|------|---------|:--:|------|
| L0 | RTL review + lint 通过 | pass | 各模块 review report |
| L1a | 单模块 iverilog 仿真，≥1 测试用例通过 | pass | 各模块 RUN 记录 |
| L1b | ≥2 模块串联，跨帧测试通过 | pass | RUN-E001-L1B-WRITE/READ/CONTROL |
| L1c | 全系统 iverilog 仿真，多帧测试通过 | pass | RUN-E001-SIM-007 (247/247 assertions) |
| L2 | Vivado synth_design: 0 errors, 0 CW | pass | synth_1 Complete |
| L3 | Vivado impl: WNS ≥ 0, WHS ≥ 0 | pass | WNS +5.636 ns, WHS +0.010 ns |
| L4 | write_bitstream 成功，.bit 文件存在 | pass | 26.5 MB |
| L5 | 上板冒烟：JTAG 检测、时钟确认、PS 启动、AXI-Lite 寄存器读写、ILA 触发捕获 | pending | — |
| L6 | 上板数据：DMA 传输 (MM2S→加速器→S2MM)、移位结果与仿真 golden 比对 (多方向/步长/帧尺寸)、ILA pipeline 验证 | pending | — |
| L7 | 资源/性能复盘 | pending | — |

### 3.2 时序目标

| 指标 | 目标 | 实测 |
|------|------|------|
| 主时钟频率 | 100 MHz (周期 10.000 ns) | clk_pl_0 @ 100 MHz |
| Setup WNS | ≥ 0 ns | +5.636 ns |
| Hold WHS | ≥ 0 ns | +0.010 ns |
| 时序模型 | post-route final | ✓ |

### 3.3 资源预算

| 资源 | accelerator 消耗 | BD IP 附加 | 总计估算 | xczu9eg 总量 | 占比 |
|------|:--:|:--:|:--:|------|:--:|
| LUT | ~811 | ~2,950 | ~3,761 | 274,080 | 1.4% |
| FF | ~313 | ~3,700 | ~4,013 | 548,160 | 0.7% |
| BRAM | 1 | 2-3 (ILA + DMA FIFO) | 3-4 | 912 | 0.4% |
| DSP | 2 | 0 | 2 | 2,520 | 0.1% |
| IOB | 0 | 0 | 0 | 328 | 0% |

### 3.4 接口契约

与硬件基座合同 §Accelerator 插槽一致：
- **SLOT_AXIL**: AXI4-Lite slave, 32-bit addr/data, 100 MHz
- **SLOT_AXIS_I**: AXI4-Stream slave, 8-bit data, TLAST=行结束, TUSER=帧起始
- **SLOT_AXIS_O**: AXI4-Stream master, 8-bit data, TLAST=行结束, TUSER=帧起始
- **SLOT_IRQ**: DMA S2MM 完成中断 → PS IRQ_F2P[0]

### 3.5 失败处理规则

#### RTL/验证阶段（L1a-L4）：G4 标准迭代

| 失败阶段 | 回退路径 | 最大往返轮次 |
|---------|---------|:--:|
| L1a fail | RTL 修复 → 重跑 L1a | 3 |
| L1b/L1c fail | 创建 ISS issue → module_owner 修复 → L1a 回验 → 重跑 L1b/L1c | 3 |
| L2 fail | RTL 修复 or 综合策略调整 | 2 |
| L3 fail | RTL 修复 or 约束调整 or 策略调整 | 3 |
| 3 轮迭代无改善 | 停止，转 human_owner | — |

#### 上板验证阶段（L5/L6）：B-G4 分诊迭代

上板失败按类别分诊，不同类别有独立轮次上限和升级路径：

| 类别 | 含义 | 上限 | 超限动作 |
|------|------|:--:|---------|
| CAT-HW | JTAG 链/电源/线缆/适配器物理问题 | 2 | → human_owner |
| CAT-BS | PS 启动失败/时钟异常/比特流加载失败 | 2 | → human_owner |
| CAT-AX | AXI-Lite 寄存器读写异常（地址映射/互联问题） | 2 | → vivado_integrator |
| CAT-IL | ILA 触发不工作/探针无信号/捕获深度不足 | 2 | → vivado_integrator |
| CAT-SW | PS 软件 bug（DMA 描述符/buffer 对齐等） | 3 | → human_owner |
| CAT-DT | DMA 传输完成但数据异常（不匹配 golden） | 3 | → vivado_integrator 或 rtl_implementer |
| CAT-RT | ILA 证据确认的 RTL 逻辑 bug | 3 | → rtl_implementer（需重新走 L1a→IP→bitstream） |

**B-G4 关键规则**：
- 每次上板 session 失败必须一次性采集：ILA 波形 + PS 日志 + 比特流版本
- CAT-RT 是最昂贵路径（触发完整 RTL 回修链），必须经 ILA 证据确认后才能发起
- CAT-RT 未经 ILA 证据确认 → 硬阻断，需 human_owner 介入
- 同一 issue 的 CAT-DT/CAT-RT 连续 3 轮无改善 → 阻断，human_owner 确认方向

### 3.6 明确的 Out-of-Scope

- PS 端完整 Linux 驱动（当前仅需 Standalone BSP 裸机 DMA 测试程序）
- Vitis/XRT/PetaLinux 嵌入式 Linux 构建
- 多 accelerator 并发调度
- DDR 带宽优化
- 功耗分析

---

## 合同状态追踪

| 合同 | 状态 | 冻结条件 | 下一步 |
|------|:--:|------|------|
| 硬件基座 | frozen | BD + 约束 + 验证已完成 | 见基座修改规则 |
| 软件环境 | **frozen** | 全部项已确认 | — |
| 验收标准 | candidate | L5/L6/L7 跑通 → frozen | 上板验证 |

---

> **合同修改规则**：
> - Contract 状态为 `frozen` 时，修改需更新状态为 `revised` + ADR 记录 + 日期
> - `candidate` 状态可自由更新，争取在一个完整流程后冻结
> - 修改合同时需同步更新 task YAML 中相关字段（如资源预算、时序目标）
