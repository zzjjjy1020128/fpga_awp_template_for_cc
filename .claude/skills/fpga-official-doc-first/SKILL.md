---
skill_id: SKILL-FPGA-OFFICIAL-DOC-FIRST
name: fpga-official-doc-first
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-15"
owner: human_owner
---

# 官方文档优先

> **触发（强制）**：模型遇到以下任何情况时，必须在采取行动前查阅官方文档，禁止猜测：
> - 需要知道某个引脚的物理位置（PACKAGE_PIN）
> - 需要调用 BSP/驱动 API（如 XAxiDma_*）
> - 需要配置 IP 参数（如 DMA 宽度/burst length）
> - 需要理解器件硬件特性（如寄存器只读/可写、时钟架构）
> - 遇到不熟悉的工具链错误消息
> - 需要写约束（IOSTANDARD、时钟周期、false path）

## 核心原则

**FPGA 开发中，"猜一下试试"的成本极高。**

猜错一个 API 参数 → 编译失败（5min 浪费）。
猜错一个引脚号 → 综合+实现+上板失败（45min 浪费）。
猜错一个 IP 配置 → 整个数据通路不符合预期（数小时 debug）。

与其猜测，不如花 2-5 分钟查官方文档。正确率从 ~50% 提升到 ~100%。

## 什么时候必须查文档

### 1. 引脚号 / IOSTANDARD

```
触发条件：写 set_property PACKAGE_PIN 或 set_property IOSTANDARD 时
强制动作：打开板卡官方手册/原理图，逐引脚确认
禁止：凭记忆、凭推理、凭"类似的板卡"
```

**官方文档位置**：
| 板卡 | 文档 | 查找方式 |
|------|------|---------|
| Alinx AX7010 | https://ax7010-20231-v101.readthedocs.io/ | 引脚表章节 |
| Alinx AX7020 | Alinx 官网 → 产品页 → 用户手册 | 引脚表章节 |
| Xilinx ZCU102 | UG1182 | Zynq UltraScale+ MPSoC Base TRD |
| Digilent Arty Z7 | Digilent Reference Manual | FPGA I/O 章节 |

### 2. BSP / 驱动 API

```
触发条件：调用 XAxiDma_* / XScuGic_* / XSpi_* / 任何 BSP 函数时
强制动作：打开 <bsp>/include/ 下的对应 .h 文件，确认函数签名
禁止：凭其他项目经验、凭网络搜索到的旧版本文档
```

**API 验证方法**：
```bash
# 确认函数签名
grep -A5 "XAxiDma_CfgInitialize" bsp/ps7_cortexa9_0/include/xaxidma.h
# 确认返回值类型
grep "return" bsp/ps7_cortexa9_0/include/xaxidma.h
# 确认参数个数
grep -c "," bsp/ps7_cortexa9_0/include/xaxidma.h  # 辅助确认
```

**常见 API 版本差异**（同一个函数在不同 BSP 版本参数不同）：
- `XAxiDma_CfgInitialize`：某些版本 2 参数，某些 3 参数
- `XAxiDma_Reset`：某些版本返回 void，某些返回 int
- **以你的 BSP include 文件为准，不以网络搜索为准**

### 3. IP 配置参数

```
触发条件：使用 set_property CONFIG.* 或 BD 中配置 IP 时
强制动作：查阅 IP product guide (PGxxx)，确认参数含义和有效范围
禁止：凭参数名字猜测含义
```

**常用 IP 文档**（Xilinx）：
| IP | 文档编号 | 内容 |
|----|---------|------|
| AXI DMA | PG021 | 寄存器定义、Simple vs SG 模式、复位序列 |
| AXI Interconnect | PG059 | 连接模式、时钟域交叉选项 |
| AXI GPIO | PG144 | 通道配置、中断使能 |
| AXI UART Lite | PG142 | 波特率、FIFO 配置 |
| Processing System 7 | UG585 (TRM) | PS-PL 接口、MIO/EMIO、时钟架构 |

### 4. 器件硬件特性

```
触发条件：对器件行为做假设时（"这个寄存器应该可写"、"这个外设应该默认开启"）
强制动作：查阅 TRM（Technical Reference Manual）或 Datasheet
禁止：凭通用嵌入式经验推断
```

**示例 — Zynq-7000 AFI 寄存器 (0xF8000860)**：
- **事实**（DS190/UG585）：AFI 寄存器在 Zynq-7000 上是**只读**的
- **模型错误假设**：应该可以写，ps7_init 应该配它
- **正确做法**：查 DS190 确认 → 理解是设计行为 → 不再追踪此路径

### 5. 工具链错误

```
触发条件：Vivado/Vitis/XSCT 报错或 CRITICAL WARNING 时
强制动作：先查 Vivado MCP 文档 / UGxxx，再解读；不懂的 CW 分类到 fpga-vivado-log-analysis
禁止：忽略 CW 继续下一步
```

## 反模式（禁止事项）

### ❌ "我见过类似的，应该是一样的"
```
案例：模型将 AX7010 的时钟引脚写为 K17（"看起来像标准的 PL 时钟输入"）
事实：AX7010 官方手册标注为 U18
结果：整个 ILA 调试基础设施失效，数小时 debug 归因于一个引脚错误
```
**正解**：`fpga-hw-pin-verify` — 逐引脚交叉验证。

### ❌ "标准 API，我知道怎么调"
```
案例：模型调用 XAxiDma_CfgInitialize(&dma, cfg, 0)（3 参数版本）
事实：当前 BSP 版本的 xaxidma.h 只接受 2 参数
结果：编译失败 → 花时间 debug 编译错误 → 最终查 .h 才发现
```
**正解**：每次调 BSP API 前 `grep` 对应 .h 文件确认函数签名。

### ❌ "手写汇编/原始寄存器操作比用驱动库更可控"
```
案例：模型在 Vitis 裸机遇到 BSP 链接问题时，选择手写 MMIO 替代 XAxiDma
事实：DMA 有复杂的复位序列、状态机、描述符链表——裸机 poke 几乎必然出错
结果：浪费数小时写汇编代码，最后回归 BSP 驱动库
```
**正解**：编译/link 问题去解决编译/link 问题，不要绕路。参考 `fpga-vitis-cli-build` 和 `fpga-zynq-debug-toolchain`。

### ❌ "这个参数名字听起来就是我要改的"
```
案例：模型看到 IP 配置中有个参数名字含"width"，直接改了
事实：可能有多个 width 参数（data width / address width / interface width），改了错误的
结果：IP 生成失败或行为异常
```
**正解**：查 PGxxx 确认每个 CONFIG.* 参数的精确含义。

### ❌ "先用默认值试试，不行再查文档"
```
默认值的代价：
- 错误的 IOSTANDARD → 位流生成无报错 → 上板可能损坏 I/O Bank
- 错误的时钟周期 → 时序分析基于错误约束 → 全部路径分析无效
- 错误的 DMA burst length → 性能严重退化 → 以为是设计瓶颈
```
**正解**：先查文档确定正确值，不要以后来修。

## 文档查找快速指南

### Xilinx 文档命名规则

| 前缀 | 含义 | 用途 |
|------|------|------|
| UG | User Guide | 操作方法、工具使用 |
| PG | Product Guide | IP 核详细规格 |
| DS | Data Sheet | 器件电气特性、引脚定义 |
| TRM | Technical Reference Manual | 器件架构、寄存器定义 |
| AR | Answer Record | 已知问题与解决方案 |

### 本地文档（BSP）

```
<vitis_workspace>/<platform>/ps7_cortexa9_0/include/
├── xaxidma.h        # DMA 驱动 API
├── xparameters.h    # 外设地址映射（自动生成，不要手改）
├── xscugic.h        # 中断控制器 API
├── xil_cache.h      # Cache 操作 API
├── xil_printf.h     # 轻量 printf API
└── ...
```

### 本地文档（Vivado IP）

```
<vivado_install>/data/ip/xilinx/
├── axi_dma_v7_1/doc/       # AXI DMA PG021
├── axi_interconnect_v2_1/  # AXI Interconnect PG059
└── ...
```

## 遇到"查不到"时

1. 确认文档编号正确（UG/PG/DS 号是否匹配你的 IP/器件版本）
2. 确认搜索关键词（用 IP 全名搜索，非缩写）
3. 确认版本匹配（Vivado 2022.2 的 IP 文档与 2022.1 可能不同）
4. 最后手段：在 BSP include 文件或 IP component.xml 中找线索
5. **仍然查不到 → 标记为 unknown，不要猜测，请求 human_owner 确认**

## 与相关 Skill 的关系

- `fpga-hw-pin-verify` — 本 skill 的强制执行者（引脚验证）
- `fpga-vitis-cli-build` — BSP API 验证的具体操作
- `fpga-zynq-debug-toolchain` — 官方调试工具链（替代裸机 poke）
- `fpga-iteration-economics` — 为什么"猜一下"的成本这么高
- `fpga-vivado-log-analysis` — CW/ERROR 的官方分类和解读

## 语言策略

- 文档引用：en（文档标题、编号）
- 原则说明：zh
