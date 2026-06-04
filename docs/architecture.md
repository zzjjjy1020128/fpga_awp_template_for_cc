# 架构文档：AXI-Lite 2D Shift 模块

## 1. 设计目标

实现一个 AXI-Lite 控制的 2D shift 模块，采用**帧缓冲架构**（先存后读），支持对矩形数据阵列进行 UP / DOWN / LEFT / RIGHT 四方向移位，可选择补零或缠绕模式。单时钟域、同步复位设计。

## 2. 顶层框图

```text
                        +-------------------------------------+
                        |          axil_2d_shift              |
                        |                                     |
  s_axil_* -----------> |  +---------------+   +-----------+  |
                        |  | axil_slave_if |-->|  regs_top |  |
                        |  +---------------+   +-----------+  |
                        |                         |           |
                        |                         v           |
  s_axis_* -----------> |  +-----------+   +-----------+      |
                        |  |axis_input |-->| ctrl_fsm  |      |
                        |  +-----------+   +-----------+      |
                        |       |              |              |
                        |       v              v              |
                        |  +-------------------------------+  |
                        |  |       frame_buf_mgr           |  |
                        |  |  (Dual-port BRAM controller)  |  |
                        |  +-------------------------------+  |
                        |       |              ^              |
                        |       v              |              |
                        |  +-----------+   +----------+       |
                        |  | shift_   |-->|axis_     |------->|----> m_axis_*
                        |  | addr_gen |   |output    |       |
                        |  +-----------+   +----------+       |
                        |                                     |
                        |  clk ----> (all modules)           |
                        |  rstn ---> (all modules, sync)     |
                        +-------------------------------------+
```

### 工作流程

1. **配置阶段**：Host 通过 AXI-Lite 写入 CTRL、CFG、IMG_ROWS、IMG_COLS 等寄存器
2. **采集阶段**：Host 向 CTRL 写入 start=1，模块进入采集状态；输入 AXI-Stream 上的数据按光栅顺序写入帧缓冲 BRAM
3. **移位阶段**：采集完成后自动进入移位阶段；模块从 BRAM 按偏移地址读出数据，经 AXI-Stream 输出
4. **完成**：输出结束后 STATUS.done 置 1，模块返回空闲状态

## 3. 模块划分

| 模块名 | 功能 | 接口 | 状态 |
|--------|------|------|------|
| `axil_slave_if` | AXI4-Lite 从属总线接口：地址译码、握手、响应生成 | s_axil_* 顶层端口；内部写/读 strobe 信号 | planned |
| `regs_top` | 寄存器文件：所有可配置寄存器和状态寄存器 | axil_slave_if 的 strobe 信号；ctrl_fsm 的状态信号 | planned |
| `axis_input` | AXI4-Stream 从属输入处理：VALID/READY 握手、TLAST/TUSER 检测 | s_axis_* 顶层端口；frame_buf_mgr 的写数据和写地址 | planned |
| `axis_output` | AXI4-Stream 主控输出处理：VALID/READY 握手、TLAST/TUSER 生成 | m_axis_* 顶层端口；frame_buf_mgr 的读数据和读地址 | planned |
| `frame_buf_mgr` | 帧缓冲控制器：双端口 BRAM 读写控制、地址管理 | axis_input/axis_output 的读写请求；BRAM 端口 A/B | planned |
| `shift_addr_gen` | 移位地址生成器：根据 SHIFT_DIR、SHIFT_STEP、WRAP_EN 计算输出读地址 | regs_top 的配置参数；ctrl_fsm 的状态 | planned |
| `ctrl_fsm` | 主控制器状态机：管理 IDLE / CAPTURE / SHIFT / DONE 状态转换 | regs_top 的 start/status；其他模块的使能/忙信号 | planned |

### 模块功能详述

#### 3.1 axil_slave_if

- 实现 AXI4-Lite 从属接口的全部 5 个通道（AW、W、B、AR、R）
- 地址译码：根据 `s_axil_awaddr[7:2]`（6-bit 偏移，覆盖 0x00–0x3C 共 16 个寄存器）译码写目标寄存器
- 对外输出 `wr_strobe[15:0]`（each 对应一个 4-byte 对齐的寄存器槽）和 `rd_strobe[15:0]`
- 处理未映射地址：返回 SLVERR（bresp=2'b10, rresp=2'b10）

#### 3.2 regs_top

包含以下寄存器：

| 实例 ID | 说明 |
|---------|------|
| reg_ctrl | CTRL 寄存器（地址 0x00） |
| reg_status | STATUS 寄存器（地址 0x04） |
| reg_cfg | CFG 寄存器（地址 0x08） |
| reg_img_rows | IMG_ROWS 寄存器（地址 0x0C） |
| reg_img_cols | IMG_COLS 寄存器（地址 0x10） |
| reg_reserved[10:0] | 保留寄存器 0x14–0x3C（读返回 0） |

#### 3.3 axis_input

- 实现 AXI-Stream Slave 握手
- 内部维护 `row_cnt` 和 `col_cnt` 计数器，用于生成 BRAM 写地址
- 检测 `s_axis_tuser` 判定帧起始；检测 `s_axis_tlast` 判定行结束
- 当一帧数据收满 `IMG_ROWS * IMG_COLS` 个元素后，通知 ctrl_fsm 采集完成
- 在采集阶段将 s_axis_tdata 和写地址同步送给 frame_buf_mgr

#### 3.4 axis_output

- 实现 AXI-Stream Master 握手
- 从 frame_buf_mgr 获取读数据，通过 m_axis_tdata 输出
- 生成 m_axis_tuser（首个输出元素）和 m_axis_tlast（每行最后一个输出元素）
- 内部维护输出 `row_cnt` 和 `col_cnt`，用于地址生成校验

#### 3.5 frame_buf_mgr

- 实例化一个双端口 BRAM（端口 A 写，端口 B 读）
- BRAM 深度：`MAX_ROWS * MAX_COLS`；宽度：`DATA_WIDTH`
- 端口 A：axis_input 驱动的写地址和数据
- 端口 B：shift_addr_gen 驱动的读地址；读出数据送给 axis_output
- 支持同时读写（双端口独立操作）
- 若 BRAM 深度超过单块 BRAM36K 容量，自动拆分多块（RTL 实现时通过 generate 展开）

#### 3.6 shift_addr_gen

- 根据 CFG.dir 和 CFG.step 生成输出读地址
- 计算公式（像素位于 `(row, col)`，`base_addr = row * IMG_COLS + col`）：

| 模式 | 读地址 |
|------|--------|
| NONE | `row * IMG_COLS + col` |
| UP | `((row + step) % IMG_ROWS) * IMG_COLS + col` |
| DOWN | `((row - step + IMG_ROWS) % IMG_ROWS) * IMG_COLS + col` |
| LEFT | `row * IMG_COLS + ((col + step) % IMG_COLS)` |
| RIGHT | `row * IMG_COLS + ((col - step + IMG_COLS) % IMG_COLS)` |

- 当 WRAP_EN=0 时，超出边界的行/列输出 0（补零模式），非缠绕模式的地址计算如下：

| 模式 | 读条件 | 超出范围输出 |
|------|--------|-------------|
| UP | `row + step < IMG_ROWS` 时读 `(row+step, col)` | 0 |
| DOWN | `row >= step` 时读 `(row-step, col)` | 0 |
| LEFT | `col + step < IMG_COLS` 时读 `(row, col+step)` | 0 |
| RIGHT | `col >= step` 时读 `(row, col-step)` | 0 |

#### 3.7 ctrl_fsm

主状态机状态转换：

```text
         +-------+
         | IDLE  | <----------+
         +---+---+            |
             | start=1        |
             v                |
         +-------+            |
         | CAPTURE|-----------+
         +---+---+ 采集完成
             | 帧数据收满
             v
         +-------+
         | SHIFT |
         +---+---+
             | 输出完成
             v
         +-------+
         | DONE  |
         +---+---+
             | (自动返回 IDLE，等待清除 done)
             v
         +-------+
         | IDLE  |
         +-------+
```

## 4. 接口规范

### 4.1 AXI4-Lite 寄存器映射表

地址偏移 = `s_axil_awaddr[7:2] * 4`（6 位偏移量，4 字节对齐）。

| 偏移 | 名称 | 类型 | 位域 | 默认值 | 说明 |
|------|------|------|------|--------|------|
| 0x00 | CTRL | R/W | [0]=start, [1]=sw_reset | 0x0 | 写 1 启动；sw_reset 自清零 |
| 0x04 | STATUS | R | [0]=idle, [1]=busy_capture, [2]=busy_shift, [3]=done, [4]=error | 0x1 (idle) | 只读 |
| 0x08 | CFG | R/W | [2:0]=dir, [7:3]=step, [8]=wrap_en | 0x0 | dir: 0=none,1=up,2=down,3=left,4=right |
| 0x0C | IMG_ROWS | R/W | [9:0]=rows | 0x1 | 行数 (1..MAX_ROWS) |
| 0x10 | IMG_COLS | R/W | [9:0]=cols | 0x1 | 列数 (1..MAX_COLS) |
| 0x14 | SW_RESET | W | [0]=sw_reset | 0x0 | 写 1 触发软复位（自清零） |
| 0x18–0x3C | Reserved | R | - | 0x0 | 读返回 0，写忽略 |

**CFG 寄存器位域详解**：

```
Bit:  8     7    6    5    4    3    2    1    0
     +-----+-------------------------------------+
     |wrap |          step          |    dir      |
     | en  |                        |             |
     +-----+-------------------------------------+
```

- `dir[2:0]`：000=NONE, 001=UP, 010=DOWN, 011=LEFT, 100=RIGHT, 101–111=保留
- `step[7:3]`：移位步长（0–31）。step=0 等效于 NONE
- `wrap_en[8]`：0=补零, 1=缠绕

**寄存器访问规约**：

| 规则 | 描述 |
|------|------|
| R/W 寄存器 | 支持回读（read-back） |
| 只读寄存器写忽略 | 对 STATUS 的写操作被静默忽略 |
| 保留地址 | 对 0x18–0x3C 的读返回 0，写被静默忽略 |
| 配置必须在 start=0 时 | CTRL.start 为 1 期间，CFG/IMG_ROWS/IMG_COLS 的写入行为未定义 |
| start 自清零 | CTRL.start 写 1 后，模块内部立即清零该位 |

### 4.2 AXI4-Stream 数据接口时序

**基本握手**（VALID/READY 握手机制，符合 AXI4-Stream 标准）：

- 发送方置 VALID 表示数据有效
- 接收方置 READY 表示可以接收
- 数据在 VALID 和 READY 同时为高的时钟沿被传输

**TUSER 规约**：
- TUSER 在帧的第一个元素时拉高，其余时间保持低
- 用于指示帧起始

**TLAST 规约**：
- 每行的最后一个元素时 TLAST 拉高（宽度 1 周期）
- 每帧有 IMG_ROWS 次 TLAST 脉冲

**输入数据顺序**（光栅扫描顺序）：

```
元素顺序: (0,0), (0,1), ..., (0, COLS-1), (1,0), ..., (ROWS-1, COLS-1)
TUSER:    1      0            0         0             0
TLAST:    0      0            1         0             1 (最后一元素)
```

**采集阶段时序约束**：
- 输入流必须连续（无间隙）或允许间隙（通过 READY 背压）
- 采集阶段模块 READY 一直为高（除非 BRAM 写端口忙，设计保证不会发生——写地址每个周期递增一次）

**输出阶段时序约束**：
- 输出流在模块 READY 被拉高时连续输出
- 若对端 m_axis_tready 拉低，模块暂停输出并保持当前读地址不变

## 5. 时钟域

| 时钟域 | 频率 | 来源 | 用途 |
|--------|------|------|------|
| clk | 100 MHz（典型） | 外部时钟源 | 所有逻辑共用同一个时钟域 |

## 6. 复位策略

- **复位类型**：同步复位，低有效（rstn）
- **复位作用域**：所有时序逻辑（寄存器、状态机、计数器）
- **复位后的默认状态**：
  - 所有寄存器恢复默认值（CTRL=0, STATUS=idle, CFG=0, IMG_ROWS=1, IMG_COLS=1）
  - 状态机进入 IDLE 状态
  - AXI-Stream 输出：m_axis_tvalid=0, m_axis_tready=0（slave 端）
  - AXI4-Lite 输出：所有 READY/VALID 信号初始为 0
- **软复位**：SW_RESET 寄存器（地址 0x14）写 1 触发与硬件复位相同的逻辑

## 7. CDC 处理

本项目为**单时钟域设计**，所有逻辑在 `clk` 域内运行，不存在跨时钟域信号。若将来集成到多时钟域系统中，AXI-Lite 接口和 AXI-Stream 接口均需在边界处插入 CDC 同步器（不在本模块范围内，由集成者负责）。

## 8. 关键参数计算

### BRAM 用量

- 帧缓冲大小：`MAX_ROWS * MAX_COLS * DATA_WIDTH` bits
- 默认参数（64x64x8）：32,768 bits = 4 KB
- Xilinx 7-series BRAM36K：36,000 bits（实际可用 32,768 bits 作为 1024x32）
- 实现方式：1 个 BRAM36K 配置为 4096x8（4096 = 64*64），满足默认需求
- 参数放大至 512x512x8 时需 57 个 BRAM36K（需确认目标 FPGA 容量）

### 地址计算延时

- 输出读地址计算包含一次乘法和一次取模运算
- `row * IMG_COLS` 使用乘法器（1 cycle）
- 取模运算简化为比较 + 条件加减（1–2 cycles）
- 读地址到数据输出的 BRAM 读延时：1 cycle
- 总输出流水线深度：~5 cycles

## 9. 综合指导

- 帧缓冲 BRAM 应 inferred 为 block RAM，不实例化原语
- 地址计算中的乘法器可选用 LUT-Mult 或 DSP48（取决于工具自动推断）
- AXI-Lite 接口时序宽松（100 MHz），无需寄存器切片
- 若时钟频率超过 150 MHz，建议在 BRAM 读端口插入输出寄存器
