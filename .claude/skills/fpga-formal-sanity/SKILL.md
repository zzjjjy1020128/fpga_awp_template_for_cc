---
skill_id: SKILL-FPGA-FORMAL-SANITY
name: fpga-formal-sanity
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-007
validated_in_projects: []
last_reviewed: "2026-06-10"
owner: human_owner
---

# 轻量形式验证

## 适用场景
- 控制 FSM 正确性验证（无死锁、cover 所有状态）
- AXI 握手协议稳定性验证（valid/ready 不卡死）
- FIFO 满空标志正确性验证
- 小规模 (< 500 行) 模块的形式安全检查
- **注意**：skill 当前为 candidate 状态，工具链（SymbiYosys）尚未集成到标准流程

## 前置条件
- SymbiYosys 已安装（`sby --version`）
- 目标模块为纯可综合 Verilog/SystemVerilog
- 无 vendor primitive（`BUFG`/`MMCM` 等不可形式化）

## 形式检查清单

### 控制 FSM
- [ ] assert 无死锁状态（每个状态有有效次态）
- [ ] cover 所有状态在 N 个周期内可达
- [ ] assert reset 后进入已知状态
- [ ] assert 无单向状态（进入后无法退出）

### 握手协议
- [ ] assert `tvalid && !tready` → 下一拍 `tvalid` 保持（数据不丢失）
- [ ] assert `!tvalid` → 最终 `tvalid` 会置位（不死锁在 idle）
- [ ] assert `tready` 不会无限低（sink 不永久阻塞）

### FIFO 检查
- [ ] assert `empty` → `rdata` 无效（不读垃圾）
- [ ] assert `full` → 写操作被忽略（不覆盖有效数据）
- [ ] assert FIFO 深度计数器与实际占用一致

## 运行命令
```bash
# 创建 .sby 配置文件
cat > check.sby << 'EOF'
[options]
mode bmc
depth 20

[engines]
smtbmc boolector

[script]
read -formal rtl/<module>.sv
prep -top <module>

[files]
rtl/<module>.sv
EOF

sby -f check.sby
```

## 输出格式
- `.awp/runs/RUN-{exp}-FORMAL-{seq}.md`
- 包含：pass/fail 状态、cover trace、bound depth、已知限制

## 当前限制
- 仅适合小规模控制逻辑和简单协议检查
- 不替代仿真（L1a），是仿真之前的前置质量闸
- 不覆盖多时钟域、vendor IP、模拟电路

## 反模式

### ❌ "仿真过了就不需要形式验证"
```
仿真覆盖有限输入组合。形式验证穷举所有可能状态空间——
对控制 FSM 和握手协议，形式验证可以发现仿真遗漏的 corner case。
```

### ❌ "模块超过 500 行，形式验证不适用"
```
形式验证对数据通路（宽算术）不适用，但即使大模块的控制部分
（FSM、使能链、握手机制）仍可隔离后单独形式化。
```

## 相关 Skills

- `fpga-sim-verification` — 仿真验证（与形式验证互补）
- `fpga-rtl-style` — FSM 编码规范（枚举状态、无隐式 latch）
- `fpga-cdc-review` — 多时钟域设计（形式验证不覆盖）
