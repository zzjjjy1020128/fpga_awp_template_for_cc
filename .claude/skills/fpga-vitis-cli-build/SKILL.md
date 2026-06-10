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

**核心发现**：`dow` 必须 target CPU 核心（`ARM Cortex-A9 MPCore #0`），而非 APU。
APU 是 DAP 调试访问端口——这是之前所有 "Invalid context" 错误的根因。

```tcl
# 正确流程
connect
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}  # CPU核!
fpga -f design_1_wrapper.bit
source ps7_init.tcl; ps7_init; ps7_post_config
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

## 语言策略

- C 代码注释：zh 或 en
- 变量/函数名：en
- API 宏名：en
