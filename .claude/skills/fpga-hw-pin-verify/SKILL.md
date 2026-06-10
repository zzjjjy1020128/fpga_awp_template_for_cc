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

## Language policy

- 验证记录：zh
- 引脚名/信号名：en
