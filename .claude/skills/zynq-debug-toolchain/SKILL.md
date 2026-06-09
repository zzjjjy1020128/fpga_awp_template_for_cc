# Skill: zynq-debug-toolchain

## When to use

Zynq-7000 PS-PL 联合调试，涉及 DMA 数据通路、AXI Stream 连通性、加速器行为诊断。

## 整体思维：工具链是一个闭合环路

```
Vivado BD  ──→  XSA  ──→  Vitis/BSP  ──→  C 代码  ──→  XSCT  ──→  硬件
    ↑                                                            │
    └──────────── ILA 观察 / 反馈 ←──────────────────────────────┘
```

**任何一个环节的断裂都会导致下游全部白费**。AWP 当前最大的缺口就是缺乏环节间的检查点。

## 环节 0：进入 Vitis 前的强制前置检查

> **在执行任何 Vitis/BSP/C 代码工作之前，必须逐项确认。跳过即白忙。**

### 检查点 A：BD 完整性

```
[ ] ILA probe 无悬空 — 每个 System ILA SLOT 是否连接到了正确的 AXI 接口？
[ ] Accelerator IP 端口连接完整 — s_axis / m_axis / s_axil 是否都连上？
[ ] DMA 到 Interconnect 到 HP0 的 AXI 通路无断点
[ ] validate_bd_design 通过
```

**为什么**：如果 BD 中 ILA probe 悬空或 stream 连接断开，后面在 Vitis 里写再多 C 代码也是基于错误硬件。

### 检查点 B：XSA ↔ Vivado 工程同步

```
[ ] 用户最近一次 export XSA 的时间戳？是否晚于最后 BD 修改？
[ ] 当前 Vitis 使用的 XSA 和 Vivado 工程生成的是同一个文件吗？
[ ] bitstream 和 XSA 是否配套（同一次 export hardware 产出）？
[ ] ps7_init.tcl 是从同一个 XSA 中提取的吗？
```

**为什么**：XSA 不一致会导致 BSP 的 xparameters.h 地址错误、ps7_init 不匹配、bitstream 和 BSP 不配套。

### 检查点 C：用户声明优先

```
[ ] 用户是否明确说了 "我已经重新 generate BD → bitstream → export XSA"？
      如果是 → 立即丢弃旧 XSA 和工作区，从新 XSA 开始
[ ] 用户是否提到了 BD 中的手动修改？
      如果是 → 先看 BD 确认修改内容
```

**为什么**：用户对 BD 的修改（如手动连接 ILA probe）不会自动同步到我之前的认知中。用户说"已重新导出"意味着旧的 XSA 和平台都是废的，必须从零重建。

## 核心原则：先诊断，后修复

**诊断优先链**：ILA 波形 > AXI-Lite 寄存器 dump > 改 C 代码加 debug 输出

ILA 能直接回答"这根线上有没有数据"——是硬件调试最快的手段。
不要用 C 代码里的 `R[ri++]` 手工寄存器 dump 替代 ILA。ILA 已经在 hw_server 上连着，直接用。

## 架构：hw_server 守护进程 + 双客户端

```
hw_server -d -p3121          ← 单一 JTAG 主控
  ├── XSCT: connect -url tcp:localhost:3121  (PS 控制者)
  │     职责: ps7_init, fpga -f, dow, con, mwr gate
  └── Vivado MCP: connect_hw_server -url TCP:localhost:3121  (PL 观察者)
        职责: 配置 ILA 触发, arm, upload, 导出 CSV
```

两者**同时**连接同一 hw_server，无冲突。

## 标准 XSCT 下载流程

```tcl
# 1. 连接 + PS 初始化
connect -url tcp:localhost:3121
targets -set -filter {name =~ "APU"}
catch {rst -system}
after 1000
source <xsa_extracted>/ps7_init.tcl
ps7_init; ps7_post_config

# 2. 烧录 PL (XSCT 烧录, 不用 Vivado Hardware Manager!)
fpga -f design_1_wrapper.bit

# 3. 下载 + 运行
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
dow app.elf
con
```

## 硬规则

### 1. 永远不用 Vivado Hardware Manager 烧录 FPGA
`program_hw_devices` 只烧 PL，会覆盖 PS 状态（DDR 内容、外设初始化）。Zynq PS-PL 联调必须 XSCT 同时管理 PS 和 PL。

### 2. ILA 触发条件：手握手，不平铺
System ILA 在 BD SLOT 模式下**支持 BASIC_ONLY 触发**，可以在运行时改 compare value：
```tcl
# 设置触发: tvalid==1 AND tready==1 (AXI Stream handshake)
set probes [get_hw_probes -of_objects $ila -filter {IS_TRIGGER == 1}]
# 格式: <operator><width>'<radix><value>
set_property TRIGGER_COMPARE_VALUE {eq1'b1} [lindex $probes <tvalid_idx>]
set_property TRIGGER_COMPARE_VALUE {eq1'b1} [lindex $probes <tready_idx>]
```

**为什么必须 handshake**：如果触发条件设为 don't-care (`eq*'hX`，默认值)，ILA arm 后立即在 IDLE 状态下触发满，抓到全是无效数据。

### 3. 软件 Gate 实现 CPU-ILA 同步
```c
// C 代码: CPU 在 gate 处无限等待
*GATE = 0;
Xil_DCacheFlushRange((UINTPTR)GATE, 4);
while (*GATE == 0) {
    Xil_DCacheInvalidateRange((UINTPTR)GATE, 4);
}
// gate 释放后才启动 DMA
```

```tcl
# Tcl 侧: arm ILA → 释放 gate → DMA 精准捕获
# 1. XSCT: dow gate_test.elf; con → CPU 跑到 gate 停下
# 2. Vivado MCP: run_hw_ila → WAITING FOR TRIGGER
# 3. XSCT: mwr -force 0x300100 1; con → ILA 精准捕获
```

Gate 机制弥补了 ILA 深度不足（1024 @ 50MHz = 20μs）的问题。CPU 可以等任意长时间，ILA 只在 DMA 活跃的瞬间触发。

### 4. DMA 复位：硬件自清除，不能手写 0
```c
// 正确: 只写 RESET=1, 等硬件清除
*(volatile u32*)(DMA_BASE) = 4;  // RESET bit
while (!(*(volatile u32*)(DMA_BASE + 4) & 1));  // 等待 Halted=1

// 错误: 写 4 后立即写 0 — 打断硬件复位时序
```

## Vitis 工程标准流程

### 从 XSA 生成 BSP
```tcl
hsi open_hw_design design_1_wrapper.xsa
hsi generate_bsp -dir bsp_dir -proc ps7_cortexa9_0 -os standalone -compile
```

### 提取 ps7_init + bitstream
```bash
unzip design_1_wrapper.xsa "ps7_init.tcl" "design_1_wrapper.bit"
```

### 编译 DMA 测试
```bash
arm-none-eabi-gcc -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard \
  -I<bsp>/include -c -o test.o test.c
arm-none-eabi-gcc ... -nostartfiles -T lscript.ld \
  -L<bsp>/lib -o test.elf test.o stubs.o \
  -Wl,--start-group,-lxil,-lc,-lgcc,--end-group
```

stubs.c 需要提供 `_init` 和 `_fini` 空函数解决链接依赖。

### 使用 XAxiDma 驱动
标准 XAxiDma API（非裸机 poke）：
```c
XAxiDma_CfgInitialize(&dma, cfg);          // 2 参数, 不是 3
XAxiDma_Reset(&dma);                       // void 返回, 不是 int
while (!XAxiDma_ResetIsDone(&dma));
XAxiDma_SimpleTransfer(&dma, buf, len, XAXIDMA_DEVICE_TO_DMA);
XAxiDma_IntrGetIrq(&dma, XAXIDMA_DEVICE_TO_DMA);  // 不是 IntrGetStatus
XAxiDma_IntrAckIrq(&dma, s, XAXIDMA_DEVICE_TO_DMA); // 不是 IntrClear
```

不同 BSP 版本 API 有差异，**以 `<bsp>/include/xaxidma.h` 声明为准**。

## 常见死胡同（不要重蹈覆辙）

| 死胡同 | 为什么是死胡同 | 正解 |
|--------|--------------|------|
| 追 AFI 寄存器 (0xF8000860) | Zynq-7000 上只读, ps7_init 不配是设计行为 | 不是 DMA 不通的根因 |
| Vivado 烧录 PS | 覆盖 PS 状态, PL 时钟丢失 | XSCT 全程管理 |
| 反复改 C 代码加 dump | 手工 dump 不如 ILA 直接看波形 | 先用 ILA 定位, 再改代码 |
| 假设 Vitis GUI 能通 | 未经验证的前提 | 先在 CLI 跑通, 再对比 |
| 裸机寄存器 poke DMA | 复位时序、状态机容易出错 | 用标准 XAxiDma 驱动 |

## 调试优先级

1. **ILA 看 stream** → 确认数据是否到达 (tvalid/tready/tdata/tlast)
2. **ILA 看两侧** → 输入侧和输出侧分别触发，确认断点在哪
3. **AXI-Lite 读 STATUS** → 确认 FSM 状态
4. **DMA 寄存器 dump** → 确认 DMASR/IOC 状态
5. **改 C 代码** → 最后的诊断手段

## ILA 数据分析要点

- 触发前样本 (pre-trigger): IDLE 状态，验证初始条件
- 触发点 (TRIGGER=1): 握手发生的精确时刻
- 触发后样本: 有效数据流，关注 tdata 值、tlast 位置、tkeep 完整性
- ILA 深度有限 (1024 @ 50MHz = 20μs)，长传输用 gate 截取关键窗口

## 语言策略

- 工具链操作/脚本：en
- 原则说明：zh
