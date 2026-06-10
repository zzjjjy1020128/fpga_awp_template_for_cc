---
skill_id: SKILL-FPGA-BOARD-VALIDATION
name: fpga-board-validation
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-008
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-10"
owner: human_owner
---

# 上板验证 (L5-L6)

## 适用场景
- hardware_validator 执行 L5（冒烟测试）和 L6（数据正确性）
- 比特流首次上板时的系统性验证
- 上板失败后的归因与证据采集

## 输入文件
- Bitstream 文件（`.bit`）
- `docs/board_validation.md`（上板验证计划）
- 平台硬件操作手册 `board/hw_arch_*.md`
- 平台清单 `.awp/platform/hw_base_*.yaml`

## L5 — Board Smoke Test Checklist

### 硬件连接
- [ ] JTAG 连接正常，FPGA 可检测（`get_hw_targets` 返回目标器件）
- [ ] 电源正常（LED 指示、电压测量点确认）
- [ ] 时钟频率确认（ILA 捕获时钟周期测量，对比平台清单中的期望频率）

### PS 启动（Zynq 平台）
- [ ] PS 启动完成（UART 终端有输出或 XSCT 可连接）
- [ ] 使用 XSCT 初始化 PS（`ps7_init.tcl`），不用 Vivado HW Manager
- [ ] DDR 可读写（XSCT `mrd`/`mwr` 验证）

### Bitstream 下载
- [ ] Bitstream 下载成功（无 DONE 错误）
- [ ] 下载后 PL 时钟工作（ILA 采样有时钟边沿）

### 基本 I/O
- [ ] 基本 I/O 功能正常（LED/按键，如适用）
- [ ] AXI-Lite 寄存器读回（ID 寄存器返回预期值）
- [ ] AXI-Lite 寄存器写+读验证（CTRL 寄存器写入后读回一致）

### ILA 验证
- [ ] ILA 触发条件已配置（非 don't-care 触发值）
- [ ] ILA 测试捕获展示有效波形
- [ ] 对时序敏感的捕获（DMA stream），使用软件 gate 等待机制：
  ```
  CPU 停 gate → arm ILA → 释放 gate → DMA 跑 → ILA 捕获
  ```

## L6 — Board Data Correctness Checklist

### PS 软件准备
- [ ] PS DMA 软件编译通过并部署到目标板
- [ ] DMA 描述符链表正确（地址、长度、wrap 标志）
- [ ] Cache 一致性处理（DDR 区域需 non-cacheable 或 cache flush）

### 数据传输验证
- [ ] DMA MM2S 传输测试图案到加速器输入
- [ ] 加速器处理后 DMA S2MM 读回数据
- [ ] 回读数据与仿真 golden 参考比对一致

### 多场景覆盖
- [ ] 多种移位方向（左/右/上/下）验证通过
- [ ] 多种步长（1, 2, half）验证通过
- [ ] 多种帧尺寸（含 odd 尺寸）验证通过
- [ ] 帧边界处理（wrapping/zero-fill）正确

### 稳定性
- [ ] 持续多帧传输无数据错位或丢失
- [ ] ILA 捕获展示 pipeline 时序与仿真一致

## Hardware Evidence Collection (required for failures)

每次上板 session 发生失败时，必须一次性采集以下证据（标注在 RUN record 中）：

- [ ] **ILA 波形捕获文件路径**（`.ila` 或导出 `.vcd`）
- [ ] **PS 控制台完整日志**（UART 输出 / XSCT 输出）
- [ ] **失败类别标注**（CAT-HW/BS/AX/IL/SW/DT/RT —— 见 B-G4 分诊表）
- [ ] **比特流版本标识**（生成日期或 SHA256）
- [ ] **平台 ID**（HW_BASE_xxx_vX.X）

缺少任意一项 → 不得关闭 session。

## 常用 XSCT 命令速查

```tcl
# 连接目标
connect
targets -set -filter {name =~ "PS"}
source ps7_init.tcl
ps7_init

# DDR 读写测试
mwr 0x00100000 0xDEADBEEF
mrd 0x00100000

# 下载 bitstream
targets -set -filter {name =~ "FPGA"}
fpga -file design_1_wrapper.bit

# 运行 FSBL + 加载 ELF
source fsbl_dma_test.tcl
```

## 输出格式
- `.awp/runs/RUN-{exp}-BOARD-{seq}.md`（格式见板卡验证模板 `TEMPLATE.md`）
- ILA/VIO 截图或波形文件路径
- PS 控制台完整日志
