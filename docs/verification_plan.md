# 验证计划：AXI-Lite 2D Shift 模块

## 1. 验证范围

### 1.1 验证覆盖的模块

| 模块 | 验证方法 | 说明 |
|------|---------|------|
| axil_slave_if | 定向测试 + 随机序列 | AXI-Lite 总线协议完整验证 |
| regs_top | 定向测试 | 每个寄存器读写、默认值、位域 |
| axis_input | 定向测试 | 流输入握手、TUSER/TLAST 检测 |
| axis_output | 定向测试 | 流输出握手、TUSER/TLAST 生成 |
| frame_buf_mgr | 定向测试 | BRAM 写/读正确性、地址映射 |
| shift_addr_gen | 定向测试 + 穷举计算对比 | 所有方向/步长/缠绕组合 |
| ctrl_fsm | 定向测试 | 状态转换、使能信号、done/error 生成 |
| **顶层集成** | 完整的端到端测试 | 所有子模块联动 |
| **AXI-Lite 隔离** | 错误注入 | 未映射地址、写只读寄存器 |

### 1.2 不覆盖的范围

- 多时钟域验证（本设计为单时钟域）
- 布局布线后时序仿真（由后续 L2/L3 阶段覆盖）
- BRAM 的物理行为（由工艺库保证）

## 2. 验证环境

### 2.1 仿真环境

- **仿真器**：Questa / Vivado xsim / Verilator（任选）
- **语言**：SystemVerilog（推荐 UVM 风格，或 SV 简单 testbench）
- **结构**：分层验证环境
  - **Driver**：驱动 AXI4-Lite 和 AXI4-Stream 接口
  - **Monitor**：监视 AXI4-Stream 输出
  - **Scoreboard**：软件参考模型比对
  - **Checker**：断言检查

### 2.2 参考模型

在 testbench 中用纯软件实现 2D shift 参考函数（SystemVerilog function 或 DPI-C）：

```
function automatic void ref_2d_shift(
    ref bit [DATA_WIDTH-1:0] img_in [][],
    ref bit [DATA_WIDTH-1:0] img_out [][],
    int rows, int cols,
    int dir, int step, bit wrap_en
);
```

### 2.3 断言检查

| 断言 | 描述 |
|------|------|
| `axil_protocol_assert` | AXI-Lite 协议符合性（VALID 不可依赖 READY 等） |
| `axis_protocol_assert` | AXI-Stream 协议符合性（TVALID/TREADY 互不依赖） |
| `data_integrity_assert` | 输出数据与参考模型一致 |
| `ctrl_fsm_state_assert` | 状态机不进入非法状态 |
| `reg_access_assert` | 只读寄存器不可写，只写寄存器不可读 |
| `frame_count_assert` | 采集和输出阶段元素计数一致 |

## 3. 测试用例

### 3.1 功能测试用例

| 用例 ID | 目标模块 | 描述 | 输入 | 预期输出 | 类型 | 状态 |
|---------|---------|------|------|---------|------|------|
| TC-001 | 顶层集成 | NONE 模式透传，4x4 图像 | 4x4 全元素递增 0..15 | 与输入完全一致 | directed | planned |
| TC-002 | 顶层集成 | UP shift 2，4x4 图像，零填充 | 4x4 递增，方向=UP，step=2 | 第2行对齐输出第0行，前2行补0 | directed | planned |
| TC-003 | 顶层集成 | DOWN shift 2，4x4 图像，零填充 | 4x4 递增，方向=DOWN，step=2 | 前2行补0，后2行对齐输出前2行 | directed | planned |
| TC-004 | 顶层集成 | LEFT shift 2，4x4 图像，零填充 | 4x4 递增，方向=LEFT，step=2 | 每行前2列丢弃，后2列补0 | directed | planned |
| TC-005 | 顶层集成 | RIGHT shift 2，4x4 图像，零填充 | 4x4 递增，方向=RIGHT，step=2 | 每行前2列补0，后2列丢弃 | directed | planned |
| TC-006 | 顶层集成 | UP shift 2，4x4 图像，缠绕模式 | 4x4 递增，方向=UP，step=2，wrap=1 | 第0-1行缠绕到底部 | directed | planned |
| TC-007 | 顶层集成 | DOWN shift 1，4x4 图像，缠绕模式 | 4x4 递增，方向=DOWN，step=1，wrap=1 | 最后一行缠绕到顶部 | directed | planned |
| TC-008 | 顶层集成 | LEFT shift 1，4x4 图像，缠绕模式 | 4x4 递增，方向=LEFT，step=1，wrap=1 | 每行第0列缠绕到行末 | directed | planned |
| TC-009 | 顶层集成 | RIGHT shift 1，4x4 图像，缠绕模式 | 4x4 递增，方向=RIGHT，step=1，wrap=1 | 每行第3列缠绕到行首 | directed | planned |
| TC-010 | 顶层集成 | 大图像多方向组合，8x8 | 8x8 数据，逐个测试 4 个方向各 3 个步长 | 与参考模型一致 | directed | planned |
| TC-011 | 全部 | 1xN 单行图像 LEFT/RIGHT shift | 1x8 数据，LEFT step=2 | 每行（只有一行）左移2 | directed | planned |
| TC-012 | 全部 | Nx1 单列图像 UP/DOWN shift | 8x1 数据，UP step=2 | 每列（只有一列）上移2 | directed | planned |
| TC-013 | 全部 | step=0 等效 NONE | 4x4 递增，方向=UP，step=0 | 与输入一致 | directed | planned |
| TC-014 | 全部 | step 等于图像维度（full wrap） | 4x4，UP step=4，wrap=1 | 与输入一致（完整一周） | directed | planned |
| TC-015 | 全部 | step 大于图像维度 | 4x4，UP step=6，wrap=1 | 等效 step=2（6%4） | directed | planned |

### 3.2 AXI-Lite 接口测试用例

| 用例 ID | 目标模块 | 描述 | 输入 | 预期输出 | 类型 | 状态 |
|---------|---------|------|------|---------|------|------|
| TC-020 | axil_slave_if / regs_top | 遍历所有寄存器写后读回 | 每个 R/W 寄存器写入特定值后回读 | 读回值与写入一致 | directed | **done** |
| TC-021 | axil_slave_if | 写 STATUS（只读寄存器） | 向 0x04 写任意值 | 值被忽略，回读保持默认 | directed | planned |
| TC-022 | axil_slave_if | 读保留地址（0x18–0x3C） | 读 0x18 和 0x3C | 返回 0 | directed | **done** |
| TC-023 | axil_slave_if | 写保留地址（0x18–0x3C） | 写任意值到 0x18 | 写被忽略，读返回 0 | directed | **done** |
| TC-024 | axil_slave_if | 未映射地址读/写 | 读/写 0x100 | BRESP/RRESP = SLVERR | directed | **done** |
| TC-025 | axil_slave_if | AXI-Lite 随机序列 | 随机写/读地址和数据 | 协议无违规，数据一致性 | random | planned |
| TC-026 | regs_top | CTRL.start 写 1 后自清零 | 读 CTRL 确认 start 位 | start 位为 0 | directed | **done** |
| TC-027 | regs_top | SW_RESET 写 1 后寄存器恢复默认 | 修改配置后触发 SW_RESET | 所有寄存器回到默认值 | directed | **done** |

### 3.3 控制 / 状态测试用例

| 用例 ID | 目标模块 | 描述 | 输入 | 预期输出 | 类型 | 状态 |
|---------|---------|------|------|---------|------|------|
| TC-030 | ctrl_fsm | 标准 START→CAPTURE→SHIFT→DONE 流程 | 配置 → start=1 → 送数据 | STATUS 状态位依次变化，done 置 1 | directed | planned |
| TC-031 | ctrl_fsm | START 后未送数据即读状态 | start=1 但不送数据 | STATUS.busy_capture=1 | directed | planned |
| TC-032 | ctrl_fsm | 一帧完成后连续第二帧（无需复位） | 完成第一帧后重新 start | 第二帧正确输出 | directed | planned |
| TC-033 | ctrl_fsm | 移位过程中 TREADY 背压 | 移位阶段 m_axis_tready 随机拉低 | 模块暂停输出，恢复后数据正确 | directed | planned |
| TC-034 | ctrl_fsm | 采集过程中 TREADY 背压（输入背压） | 采集阶段 s_axis_tready 被拉低 | 模块暂停接收，恢复后数据正确 | directed | planned |
| TC-035 | ctrl_fsm | 采集过程中复位 | 采集中断言 rstn=0 | 模块复位，状态回到 IDLE | directed | planned |
| TC-036 | axis_input / axis_output | TUSER 和 TLAST 生成正确性 | 标准 4x4 数据 | 输出 TUSER 仅在第一个元素为高，TLAST 每行最后一个为高 | directed | planned |

### 3.4 边界 / 压力测试用例

| 用例 ID | 目标模块 | 描述 | 输入 | 预期输出 | 类型 | 状态 |
|---------|---------|------|------|---------|------|------|
| TC-040 | 顶层集成 | 最大尺寸图像（64x64） | 64x64 随机数据，所有方向/步长 | 与参考模型一致 | random | planned |
| TC-041 | 顶层集成 | 最小图像（1x1） | 1x1 数据，所有方向 step=0 | 输出与输入一致 | directed | planned |
| TC-042 | 顶层集成 | AXI-Stream 零间隙全速传输 | 4x4，连续时钟传输 | 无 stall 完成 | directed | planned |
| TC-043 | 顶层集成 | AXI-Stream 随机间隙传输 | 4x4，随机插入 wait states | 输出数据正确，无关插入模式 | random | planned |
| TC-044 | 顶层集成 | 连续多帧无间隔 | 连续 10 帧 4x4 数据 | 每帧都正确移位 | directed | planned |
| TC-045 | frame_buf_mgr | BRAM 地址边界 | 配置最大维度后写最大地址 | 数据正确写入和读出 | directed | done |
| TC-046 | 顶层集成 | 移位后全帧验证（累加和校验） | 各种配置 | 输出元素的累加和与参考模型一致 | directed | planned |
| TC-047 | 顶层集成 | 配置在 start 后变更 | start=1 后写 CFG | 行为未定义（仅记录，不视为错误） | directed | planned |

## 4. 覆盖率目标

### 4.1 代码覆盖率

| 类型 | 目标 | 说明 |
|------|------|------|
| Line coverage | >= 90% | 每行代码至少执行一次 |
| Branch coverage | >= 85% | 条件分支双向覆盖 |
| FSM state coverage | 100% | 所有状态至少进入一次 |
| FSM transition coverage | >= 90% | 所有合法状态转换至少发生一次 |
| Toggle coverage | >= 70% | 顶层端口信号翻转 |

### 4.2 功能覆盖率

| 功能点 | 覆盖组 | 目标 |
|--------|--------|------|
| 移位方向 | covergroup: shift_dir | 每个方向至少 5 次（含 NONE） |
| 移位步长 | covergroup: shift_step | step=0, 1, 2, max-1, max 至少各 1 次 |
| 缠绕模式 | covergroup: wrap_en | wrap=0 和 wrap=1 各至少 10 次 |
| 图像尺寸 | covergroup: img_size | 1x1, 1xN, Nx1, NxN, 最大尺寸各至少 1 次 |
| 图像尺寸组合 | covergroup: cross_dir_wrap | 方向 x 缠绕模式的交叉覆盖 >= 90% |
| 状态机 | covergroup: fsm_state | 每个状态至少 5 次 |
| AXI-Lite 地址 | covergroup: axil_addr | 每个映射寄存器至少读写各 1 次 |
| 流背压 | covergroup: backpressure | 输入背压和输出背压至少各 3 次 |
| 多帧 | covergroup: multi_frame | 连续 2 帧和 3 帧操作至少各 1 次 |

### 4.3 断言覆盖率

- 所有定义的断言（见 2.3 节）必须在仿真中至少触发一次
- 断言违反次数 = 0

## 5. 测试通过标准

同时满足以下条件时验证通过：
1. 所有 TC-001 至 TC-047 用例通过
2. 代码覆盖率满足 4.1 节目标
3. 功能覆盖率满足 4.2 节目标
4. 所有断言在仿真过程中未触发违反
5. 至少完成一次随机序列测试（TC-025 和 TC-043），种子至少 3 个

## 6. 回归策略

- **每次 RTL 修改后**：运行 TC-001 至 TC-015（快速冒烟测试）
- **提交 PR 前**：完整回归所有 TC-001 至 TC-047
- **覆盖率检查**：每次完整回归后生成覆盖率报告，低于目标值的模块需补充用例
