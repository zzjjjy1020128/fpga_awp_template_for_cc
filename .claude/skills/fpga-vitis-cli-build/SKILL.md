---
skill_id: SKILL-FPGA-VITIS-CLI-BUILD
name: fpga-vitis-cli-build
layer: FPGA-Method
status: local_adapted
source_basis:
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-15"
owner: human_owner
---

# Skill: vitis-cli-build

## When to use

在 CLI 环境下编译 Zynq baremetal C 代码并下载到目标执行时使用。
覆盖完整流程：编译 → 二进制准备 → XSCT 下载 → 执行。

## 编译

见原有编译流程（arm-none-eabi-gcc + BSP + lscript.ld + libxil.a + libc + libgcc）。

**关键**：CLI 自动化需去除 `xil_printf` 阻塞——用空的 stub 函数替代：
```c
void xil_printf(const char *fmt, ...) { (void)fmt; }
```
同时需要 stub `__libc_init_array`, `__libc_fini_array`, `exit`, `malloc`, `memset` 等。
链接顺序：stub.o 放在 libxil.a 之前以覆盖库函数。

## CLI 下载与执行（替代 Vitis GUI Run）

> ⚠️ **XSCT 路径**：从 `.awp/platform/host_env.yaml#toolchain.vitis.xsct` 读取。

**核心发现**：`dow` 必须 target CPU 核心（`ARM Cortex-A9 MPCore #0`），而非 APU。
APU 是 DAP 调试访问端口——这是之前所有 "Invalid context" 错误的根因。

```tcl
# 正确流程（PS 初始化必须先于 PL 烧录！）
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}  # CPU核!
source ps7_init.tcl; ps7_init; ps7_post_config             # 先 PS
fpga -f design_1_wrapper.bit                                # 再 PL
dow app.elf    # 直接成功! 无需 dow -data 或二进制转换
con            # 执行
```

**`dow` (ELF) 在正确 target 下完全可用**，不需要 `dow -data` 二进制加载。
`dow -data` 仅在需要加载 FSBL 二进制到 OCM 时使用（FSBL 无 ELF 头依赖）。

## 标准调试流 (UG908)

```
hw_server -d (守护进程, 端口 3121)
  ├── XSCT (主导): connect -url tcp:localhost:3121
  │     → fpga -f → ps7_init → dow app.elf → con
  └── Vivado MCP (观察者): connect_hw_server -url TCP:localhost:3121
        → arm ILA → 等待捕获 → upload → write .ila
```

两者通过同一 hw_server 共享 JTAG——不存在冲突。

## C 代码逐步验证方法

调试 BSP 启动问题时使用 `step1→step2→...→stepN` 逐步加回功能：
1. step1: 仅 `_start` + `axil_reg_test` (验证 Xil_In32/Out32)
2. step2: + `init_platform` + `Xil_DCacheEnable`
3. step3: + GIC + DMA init (验证中断连接)
4. step4: + DMA loopback (验证完整数据通路)
5. step7: + 软件 gate 等待 (ILA 同步)

## 反模式（禁止事项）

### ❌ "BSP 链接报错 → 手写汇编替代驱动库"
```
案例：遇到 undefined reference to `Xil_DCacheFlushRange' 等链接错误，
模型尝试用裸机 MMIO poke 替代 XAxiDma 驱动。
事实：DMA 有严格的复位序列（写 RESET→等 Halted→确认）、描述符链表、
中断状态清除。裸机 poke 几乎必然遗漏关键步骤。
结果：浪费数小时写 + 调试手写 DMA 驱动，最终回归 BSP。
```
**正解**：链接错误 → 检查链接顺序、补齐 stub 函数、确认 BSP lib 路径。
参考 `fpga-zynq-debug-toolchain` §"硬规则 4" 的 DMA 复位正确写法。

### ❌ "加几个 xil_printf 看看走到哪了"
```
xil_printf 本身需要 UART 初始化 → 增加了调试依赖。
在 DMA 性能关键路径中插入 printf 会改变时序、破坏 DMA 窗口。
不如 ILA 直接看波形——ILA 已经在 hw_server 上连着。
```
**正解**：ILA 波形 > AXI-Lite 寄存器 dump > DMA 寄存器 dump > UART 输出。

### ❌ "换个编译选项试试能不能绕过"
```
遇到链接错误时随意改 -mcpu/-mfpu 等编译标志，或尝试不同的 link script。
这些改动可能隐藏真正的根因（如 stub 缺失、库版本不匹配），
并且可能产生"编译通过但运行时崩溃"的更难 debug 的问题。
```
**正解**：追查具体错误消息 → 查 BSP include 文件 → 确认 API 签名 → 修正代码。

### ❌ "用 Vivado Hardware Manager 烧录更快"
```
program_hw_devices 只烧 PL，覆盖 PS 状态（DDR 内容、外设初始化）。
Zynq PS-PL 联调必须 XSCT 同时管理 PS 和 PL。
```
**正解**：XSCT `fpga -f` + `dow app.elf` + `con`（见 `fpga-zynq-debug-toolchain`）。

### ❌ "Vitis GUI 比 CLI 更可靠"
```
Vitis GUI 在 CLI/远程环境下不稳定，且隐藏了编译和下载的实际错误。
CLI 流程（arm-none-eabi-gcc + XSCT dow）更透明、可复现、可自动化。
```
**正解**：CLI 编译（本 skill §编译）+ CLI 下载（本 skill §CLI 下载与执行）。

## 相关 Skills

- `fpga-zynq-debug-toolchain` — DMA 复位、ILA 触发、软件 gate、XSCT 流程
- `fpga-official-doc-first` — 调用 BSP API 前查 .h 文件确认签名
- `fpga-iteration-economics` — 理解"改 C 代码 → 编译 → 下载"的成本 vs "先看 ILA"
- `fpga-software-env-profile` — 工具链版本和环境配置

## 语言策略

- C 代码注释：zh 或 en
- 变量/函数名：en
- API 宏名：en
