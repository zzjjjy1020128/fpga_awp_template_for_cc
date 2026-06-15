---
skill_id: SKILL-FPGA-HW-PIN-VERIFY
name: fpga-hw-pin-verify
layer: FPGA-Method
status: local_adapted
source_basis:
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-15"
owner: human_owner
---

# Skill: hw-pin-verify

## When to use

在 Vivado 工程中为 PL I/O 添加 `PACKAGE_PIN` 约束时使用。**必须在写入 XDC 之前执行。**
也适用于审查 sub-agent（如 hardware_validator）产出的 `board/hw_arch_*.md` 中的引脚描述。

## 问题背景

Sub-agent（hardware_validator）在生成 `board/hw_arch_ax7010.md` 时，将 AX7010 板载 50MHz 外部晶振的引脚写为 **K17**。
但 AX7010 官方手册（`AX7010UserManual.html`）明确标注 PL 外部时钟引脚为 **U18**。
K17 是错误的，导致 ILA 时钟域实际无信号，整个调试基础设施失效。

**Sub-agent 会产生幻觉引脚号。必须交叉验证。**

## Checklist

- [ ] 找到目标板卡的**官方文档/手册**（优先官方 PDF 或 readthedocs）
- [ ] 对每个 PL I/O 约束（PACKAGE_PIN），在官方手册中**逐条确认引脚号**
- [ ] 特别注意：时钟引脚（MRCC/SRCC）、差分对引脚、Bank 电压
- [ ] 交叉验证：手册中的引脚表 vs XDC 中的 `set_property PACKAGE_PIN`
- [ ] 对 sub-agent 产出的 `board/hw_arch_*.md` 做同样的引脚交叉验证
- [ ] 确认 IOSTANDARD 与 Bank 电压一致（如 LVCMOS33 for 3.3V Bank）

## 常见板卡参考

| 板卡 | 官方文档 |
|------|---------|
| Alinx AX7010 | `https://ax7010-20231-v101.readthedocs.io/` |
| Alinx AX7020 | Alinx 官网 |
| Xilinx ZCU102 | UG1182 |
| Digilent Arty Z7 | Digilent Reference Manual |

## 反模式

### ❌ "K17 看起来像标准的 PL 时钟输入"（Sub-agent 幻觉）
```
Sub-agent 会凭空产生引脚号。必须交叉验证官方手册。
案例：AX7010 外部晶振 —— Sub-agent 写 K17，官方手册标注 U18。
```

### ❌ "这个板卡和那个板卡差不多，引脚应该一样"
```
不同板卡即使使用同一 FPGA 器件，引脚分配也完全不同。
必须在目标板卡的官方手册中逐脚确认。
```

## 相关 Skills

- `fpga-official-doc-first` — 文档优先原则
- `fpga-board-validation` — L5 冒烟测试（包含 JTAG/时钟验证）
- `fpga-bd-debug-clock` — ILA 时钟域（引脚错误直接影响 debug infra）

## Language policy

- 验证记录：zh
- 引脚名/信号名：en
