---
skill_id: SKILL-FPGA-AXIL-REVIEW
name: fpga-axi-lite-review
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-005
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-10"
owner: human_owner
---

# AXI-Lite 接口审查

## 适用场景
- RTL review：审查 AXI-Lite 从机/主机接口
- L1a：验证寄存器读写正确性
- L1b/L1c：集成验证时的 AXI-Lite 地址映射检查
- Board debug：AXI-Lite 寄存器读写异常归因（CAT-AX）

## 输入文件
- AXI-Lite 相关 RTL 文件
- 寄存器映射文档（地址、位域定义、读写权限、side effect）

## 检查清单

### 写通道（AW/W/B）
- [ ] AWVALID/AWREADY 握手完成 → AWADDR 被锁存
- [ ] WVALID/WREADY 握手完成 → WDATA/WSTRB 被锁存
- [ ] AW 和 W 可独立到达（无顺序依赖）—— 从机需处理乱序
- [ ] BVALID/BREADY 握手 → 写响应返回（BRESP = OKAY/SLVERR/DECERR）
- [ ] WSTRB 支持窄位宽写入（任意字节组合）
- [ ] 对只读寄存器写入：BRESP = SLVERR 且数据不改变

### 读通道（AR/R）
- [ ] ARVALID/ARREADY 握手完成 → ARADDR 被锁存
- [ ] RVALID/RREADY 握手完成 → RDATA 返回
- [ ] RRESP 正确：OKAY（正常）/ SLVERR（非法地址/只写寄存器读）
- [ ] 读 side-effect 寄存器：读操作本身可能改变状态（如 clear-on-read）
- [ ] 对只写寄存器读取：RRESP = SLVERR，RDATA 可为 0

### 地址与寄存器
- [ ] 寄存器地址空间与文档一致（验证基址 + offset）
- [ ] 未实现地址返回 DECERR
- [ ] 地址对齐检查（32-bit 对齐，AWADDR[1:0] = 0）
- [ ] 读写冲突：同一周期对同一地址同时读写 → 行为有定义

### 时序与性能
- [ ] 读写通道独立，可并发操作（全双工）
- [ ] 从机支持连续事务（burst-like back-to-back）
- [ ] 无意外阻塞（BVALID/RVALID 不被无限延迟）

### 常见错误模式
- [ ] 无从机在 AW 到达前就等待 W（忽略乱序）
- [ ] 无 BVALID 忘记发出（master 永远等待写响应）
- [ ] 无 RVALID 忘记发出（master 永远等待读数据）
- [ ] 无寄存器 side-effect 在仿真中未被发现（读即触发动作）

## 反模式（禁止事项）

### ❌ "BVALID 等几拍也没关系"
```
AXI-Lite 从机无限延迟 BVALID/RVALID → master 永远等待 → 系统死锁。
每个读写事务必须有最坏情况响应延迟上限。
```

### ❌ "WSTRB 全 1 就行，不需要验证窄位宽"
```
WSTRB 支持任意字节组合。假设 WSTRB 永远全 1 → 窄位宽写入时写入错误的字节。
必须测试 WSTRB 非全 1 场景。
```

## 相关 Skills

- `fpga-axis-review` — AXI-Stream 协议审查（数据通路侧）
- `fpga-rtl-review` — L0 审查中的 AXI-Lite 初步检查
- `fpga-integration-failure-debug` — 寄存器读写异常时（CAT-AX）的调试

## 审查输出
- `.awp/reviews/REV-{exp}-{task_seq}-AXIL-{seq}.md`
- 含：寄存器地址空间校验表、协议违规项数、修复建议

## 语言规范
- 审查报告：zh
- 信号名/寄存器名：en
