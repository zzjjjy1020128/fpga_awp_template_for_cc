---
skill_id: SKILL-FPGA-BOARD-VALIDATION
name: fpga-board-validation
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-008
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-15"
owner: human_owner
mcp_tools_gated:
  - mcp__vivado__program_device
  - mcp__vivado__get_io_report
  - mcp__vivado__verify_io_placement_tool
---

# 上板验证 (L5-L6)

> ⚠️ **MCP Gate**：本 skill 是以下 MCP 操作的唯一入口。
> 模型不得直接调用 `program_device` / `get_io_report` / `verify_io_placement_tool`，
> 必须先经过本 skill 的前置检查和平台判断。

## 适用场景
- hardware_validator 执行 L5（冒烟测试）和 L6（数据正确性）
- 比特流首次上板时的系统性验证
- 上板失败后的归因与证据采集

## 输入文件
- Bitstream 文件（`.bit`）
- `docs/board_validation.md`（上板验证计划）
- 平台硬件操作手册 `board/hw_arch_*.md`
- 平台清单 `.awp/platform/hw_base_*.yaml`

## L5 — Board Smoke Test Checklist

### 硬件连接
- [ ] JTAG 连接正常，FPGA 可检测（`get_hw_targets` 返回目标器件）
- [ ] 电源正常（LED 指示、电压测量点确认）
- [ ] 时钟频率确认（ILA 捕获时钟周期测量，对比平台清单中的期望频率）

### PS 启动（Zynq 平台）

> ⚠️ **先 PS 后 PL**：Zynq 必须先通过 XSCT 初始化 PS（`ps7_init`）再烧录 PL。
> 用 Vivado HW Manager 直接烧 PL → PS 未初始化 → FCLK 不运行 → ILA 不可见。

- [ ] PS 启动完成（UART 终端有输出或 XSCT 可连接）
- [ ] 使用 XSCT 初始化 PS（`source ps7_init.tcl; ps7_init; ps7_post_config`），不用 Vivado HW Manager
- [ ] DDR 可读写（XSCT `mrd`/`mwr` 验证）

### Bitstream 下载
- [ ] Bitstream 下载成功（无 DONE 错误）：Zynq 必须通过 XSCT `fpga -f`，纯 PL 可用 Vivado
- [ ] 下载后 PL 时钟工作（ILA 采样有时钟边沿）
- [ ] Zynq 检查：PS 初始化后 Vivado 端 `refresh_hw_device`，确认 ILA 可见

### 基本 I/O
- [ ] 基本 I/O 功能正常（LED/按键，如适用）
- [ ] AXI-Lite 寄存器读回（ID 寄存器返回预期值）
- [ ] AXI-Lite 寄存器写+读验证（CTRL 寄存器写入后读回一致）

### ILA 验证
- [ ] ILA 触发条件已配置（非 don't-care 触发值）
- [ ] **Probes 文件已关联**：每次 `refresh_hw_device` 后执行 `set_property PROBES.FILE {path/to/debug_nets.ltx} [get_hw_devices]`，否则 ILA 不可见
- [ ] ILA 测试捕获展示有效波形
- [ ] 对时序敏感的捕获（DMA stream），使用软件 gate 等待机制：
  ```
  CPU 停 gate → arm ILA → 释放 gate → DMA 跑 → ILA 捕获
  ```
- [ ] **ILA arm 时机**：Zynq 平台 CAPTURE 阶段长达 51k+ cycle。ILA 环形缓冲只有 1024 sample。**必须在 gate 释放后、SHIFT 开始前 arm ILA**，否则捕获窗口被 CAPTURE 空闲填满

## L6 — Board Data Correctness Checklist

### PS 软件准备
- [ ] PS DMA 软件编译通过并部署到目标板
- [ ] DMA 描述符链表正确（地址、长度、wrap 标志）
- [ ] Cache 一致性处理（DDR 区域需 non-cacheable 或 cache flush）
- [ ] **测试数据禁止 `(u8)i` 截断**：`u8` 类型在 i≥256 时绕回 0，导致 1024 字节帧中每 256 字节数据重复。使用 `(u8)(i & 0xFF)` 或 16-bit 数据区分全帧

### 数据传输验证
- [ ] DMA MM2S 传输测试图案到加速器输入
- [ ] 加速器处理后 DMA S2MM 读回数据
- [ ] 回读数据与仿真 golden 参考比对一致

### 多场景覆盖
- [ ] 多种移位方向（左/右/上/下）验证通过
- [ ] 多种步长（1, 2, half）验证通过
- [ ] 多种帧尺寸（含 odd 尺寸）验证通过
- [ ] 帧边界处理（wrapping/zero-fill）正确

### 稳定性
- [ ] 持续多帧传输无数据错位或丢失
- [ ] ILA 捕获展示 pipeline 时序与仿真一致

## Hardware Evidence Collection (required for failures)

每次上板 session 发生失败时，必须一次性采集以下证据（标注在 RUN record 中）：

- [ ] **ILA 波形捕获文件路径**（`.ila` 或导出 `.vcd`）
- [ ] **PS 控制台完整日志**（UART 输出 / XSCT 输出）
- [ ] **失败类别标注**（CAT-HW/BS/AX/IL/SW/DT/RT —— 见 B-G4 分诊表）
- [ ] **比特流版本标识**（生成日期或 SHA256）
- [ ] **平台 ID**（HW_BASE_xxx_vX.X）

缺少任意一项 → 不得关闭 session。

### ❌ "直接在 Bash 跑 xsct.bat 烧板"（最常犯）
```
Bash 裸调 xsct.bat → 绕过本 skill 的 Zynq PS/PL 检查
→ probes 文件未关联 → ILA 不可见 → 调试失败
→ 或者 PS 未初始化就烧 PL → FCLK 不跑 → ILA 时钟没有
```
**正解**：烧录/验证操作必须先调本 skill，skill 内部确认平台类型后再执行 XSCT 命令。

## 反模式（禁止事项）

### ❌ "上板失败了，加几个 printf 看看"
```
printf 调试需要：改 C 代码 → 重新编译 → 下载 ELF → 运行 → 看 UART。
这个过程 3-5 分钟每次迭代。而 ILA 已经在硬件上连着，
直接配置触发条件看波形只需 30 秒。
更糟的是：在 DMA 关键路径上加 printf 会改变时序、破坏 DMA 窗口。
```
**正解**：ILA 波形 > AXI-Lite 寄存器 dump > DMA DMASR 寄存器 > C 代码改。

### ❌ "换个 bitstream 试试"（不记录版本）
```
不记录 bitstream 版本的情况下反复重烧 → 不知道哪个版本对应什么行为。
出现"刚才还好好的现在不行了"时无法追溯到具体变更。
```
**正解**：每次上板记录 bitstream 生成日期/commit SHA。失败时采集完整证据包。

### ❌ "这个 ILA 触发条件看起来差不多"
```
ILA 触发条件配置不精确（如将所有 probe 设 don't-care）→ ILA 被噪声触发
→ 捕获窗口不在目标事件上 → 误判为"硬件没数据"。
```
**正解**：精确配置触发条件（如 tvalid==1 && tready==1 && tlast==1）。参考 `fpga-zynq-debug-toolchain` §"硬规则 2"。

### ❌ "仿真过了，上板肯定没问题"
```
仿真无法覆盖：实际时钟抖动、信号完整性、DDR 时序、PS-PL 接口延迟。
L1c 全 PASS 只是上板的必要条件，不是充分条件。
```
**正解**：L5 冒烟测试 → L6 数据正确性 → 逐级递进，不可跳过。

### ❌ "板卡 JTAG 检测不到？重启 Vivado 试试"
```
反复重启 Vivado 是无效的试错。JTAG 检测不到的原因通常是：
1) 板卡没上电 2) 下载器驱动未装 3) hw_server 端口被占用。
重启 Vivado 不解决任何上述问题。
```
**正解**：按 CAT-HW 分诊：电源 → 线缆 → 驱动 → hw_server 端口。参考 `fpga-validation-levels` §"上板失败分诊表"。

## 常用 XSCT 命令速查

```tcl
# 连接目标
connect
targets -set -filter {name =~ "PS"}
source ps7_init.tcl
ps7_init

# DDR 读写测试
mwr 0x00100000 0xDEADBEEF
mrd 0x00100000

# 下载 bitstream
targets -set -filter {name =~ "FPGA"}
fpga -file design_1_wrapper.bit

# 运行 FSBL + 加载 ELF
source fsbl_dma_test.tcl
```

## 相关 Skills

- `fpga-zynq-debug-toolchain` — ILA 触发配置、软件 gate、XSCT 下载流程
- `fpga-bd-debug-clock` — ILA 时钟域、debug hub 诊断
- `fpga-hw-pin-verify` — 上板前引脚交叉验证
- `fpga-vitis-cli-build` — PS 软件编译和 CLI 下载
- `fpga-iteration-economics` — 理解每次上板迭代的真实时间成本
- `fpga-validation-levels` — L5/L6 门禁规则和 CAT-* 分诊表

## 输出格式
- `.awp/runs/RUN-{exp}-BOARD-{seq}.md`（格式见板卡验证模板 `TEMPLATE.md`）
- ILA/VIO 截图或波形文件路径
- PS 控制台完整日志

## XSCT 脚本模板 (Zynq 平台)

每次上板使用以下标准脚本（避免每次手写重连逻辑）：

```tcl
# xsct_full_flow.tcl — 标准 Zynq 上板流程
connect
target 1
rst -system
after 1000
target 2
source ../ps7_init.tcl
ps7_init
ps7_post_config

# DDR 测试
mwr 0x00100000 0xDEADBEEF
mrd 0x00100000

# 烧录 PL
target 4
fpga -f <bitstream_path>.bit

# 下载 ELF
target 2
dow <elf_path>.elf
con
```

**关键注意事项**：
- 每次 XSCT 调用是独立会话，必须 `connect`
- Zynq 先 `ps7_init` 再 `fpga -f`
- DDR 测试验证 PS 初始化正确
- `con` 后 CPU 运行，内存写入（`mwr`）直接生效无需 `stop`
