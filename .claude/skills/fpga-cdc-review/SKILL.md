---
skill_id: SKILL-FPGA-CDC-REVIEW
name: fpga-cdc-review
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-10"
owner: human_owner
---

# CDC + 复位跨域审查

## 适用场景
- RTL review：含多时钟域模块的代码审查
- L0 静态审查：综合前检查 CDC 合规性
- 时序不收敛时排查跨域约束缺失

## 输入文件
- 含 CDC 逻辑的 RTL 文件
- 约束文件（`constraints/*.xdc`）
- 架构文档中的时钟域图（如 `docs/architecture.md`）

## CDC 检查清单

### 时钟域识别
- [ ] 所有时钟域已识别并记录（列出每个时钟及其频率）
- [ ] 每个信号标注其所属时钟域（在代码注释或文档中）
- [ ] 时钟域边界清晰（哪些信号跨域，方向如何）

### 单 bit 同步
- [ ] 单 bit 控制信号使用 2+ 级同步器（`xpm_cdc_single` 或显式 FF 链）
- [ ] 同步器第一级 FF 后无组合逻辑（保证 MTBF）
- [ ] 同步器输出在同一目的时钟域使用
- [ ] 电平信号（非脉冲）才可双 FF 同步（脉冲需握手或展宽）

### 多 bit 总线
- [ ] 多 bit 数据使用异步 FIFO（`xpm_cdc_async_fifo` 或 Gray-code FIFO）
- [ ] 多 bit 控制使用握手协议（`xpm_cdc_handshake`）
- [ ] 无直接跨域组合逻辑（不同域信号不应在同一 always_comb 中）
- [ ] 无多 bit 总线不经同步直连（data bus crossing）

### 约束
- [ ] `set_clock_groups -asynchronous` 声明所有异步时钟组
- [ ] 同步跨域路径有 `set_max_delay -datapath_only` 约束
- [ ] 无 `set_false_path` 掩盖真实 CDC 问题（确认路径确实无需时序分析）
- [ ] 约束覆盖所有跨域边界

## 复位检查清单

### 复位策略
- [ ] 每个时钟域有独立复位同步器（`xpm_cdc_async_rst` 或显式复位桥）
- [ ] 异步复位输入经同步释放（避免恢复/移除违例）
- [ ] 复位释放顺序：先释放源时钟域复位，再释放目的域复位
- [ ] 复位信号跨域不使用简单双 FF（需 `xpm_cdc_async_rst`）

### 复位行为
- [ ] 复位期间所有输出为已知安全值（非 X）
- [ ] 复位释放后状态机从 IDLE 开始（非随机状态）
- [ ] 复位释放后至少 5 周期再开始正常操作
- [ ] 部分复位的模块（如仅复位数据路径不复位配置寄存器）已明确标注

## 异步 FIFO 专项
- [ ] 读写指针为 Gray 编码（相邻地址仅 1 bit 变化）
- [ ] 满/空标志经同步后生成（非直接比较读写指针）
- [ ] FIFO 深度 ≥ 2×（写速率/读速率）上取整（避免溢出）
- [ ] 写使能在写时钟域，读使能在读时钟域（各自域控制）

## 审查输出
- `.awp/reviews/REV-{exp}-{task_seq}-CDC-{seq}.md`
- 含：跨域路径清单（每条路径的源/目的/同步方式）、违规项、修复建议

## 语言规范
- 审查报告：zh
- 信号名：en
