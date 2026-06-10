---
skill_id: SKILL-FPGA-SIM-VERIFICATION
name: fpga-sim-verification
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-004
  - SRC-FPGA-005
  - SRC-FPGA-006
validated_in_projects: []
last_reviewed: "2026-06-10"
owner: human_owner
---

# 仿真验证方法论（L1a/L1b/L1c）

## 适用场景
- 编写模块级（L1a）、数据通路闭环（L1b）、全系统（L1c）testbench
- 设计 scoreboard、golden model、random stimulus
- 判定仿真是否"真正通过"（非波形看起来正确）

## Testbench 架构模式

### 组件
- [ ] **DUT 实例化**：正确连接所有端口，未连接端口显式接地/上拉
- [ ] **Clock generator**：`always #(CLK_PERIOD/2) clk = ~clk`
- [ ] **Reset sequence**：上电后至少 10 周期复位，复位释放后至少 5 周期等待
- [ ] **BFM (Bus Functional Model)**：AXI-Lite master、AXIS source/sink
- [ ] **Scoreboard**：期望值 vs 实际值比对
- [ ] **Monitor**：被动采样总线事务，不驱动信号

### Golden Model
- [ ] 对数据通路模块（如 2D shift、DMA），创建软件 reference model
- [ ] 同一输入激励同时送入 DUT 和 golden model
- [ ] Scoreboard 逐周期/逐帧比对 DUT 输出与 golden model 输出

### Random Stimulus
- [ ] 对 AXI-Stream source：随机化 `tready` backpressure（概率 20%-80%）
- [ ] 对配置接口：随机化寄存器写入顺序和值
- [ ] 对帧尺寸：随机化在 [1, MAX_SIZE] 范围
- [ ] 对延迟：随机化事务间隔（0-20 周期）

## 仿真通过标准

### L1a（模块级）
- [ ] 所有定向测试 case 通过
- [ ] reset + basic + boundary + backpressure 全部覆盖
- [ ] 0 个 `$error` / `$fatal`
- [ ] 波形关键信号在预期范围内

### L1b（数据通路闭环）
- [ ] ≥3 帧连续传输无错位
- [ ] 跨帧状态无残留（帧 2 输出不含帧 1 数据）
- [ ] backpressure 随机化下数据完整
- [ ] Scoreboard 全部比对通过

### L1c（全系统）
- [ ] 所有接口同时工作无死锁
- [ ] 配置通道和数据通路并发操作正确
- [ ] ≥10 帧随机参数组合通过
- [ ] Golden model 比对 100% 一致

## 运行命令（iverilog）
```bash
iverilog -g2012 -o simv tb/<tb_file>.sv rtl/*.sv
vvp simv
# 检查 exit code 和 stdout 中的 PASS/FAIL
```

## 输出格式
- `.awp/runs/RUN-{exp}-SIM-{seq}.md`
- 包含：测试 case 列表、每个 case 的 PASS/FAIL、波形路径、未覆盖项
