---
skill_id: SKILL-FPGA-PROJECT-ACCEPTANCE
name: fpga-project-acceptance
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-011
validated_in_projects: []
last_reviewed: "2026-06-15"
owner: human_owner
---

# 项目验收合同

使用 `ACCEPTANCE_CONTRACT_TEMPLATE.md` 模板创建项目验收合同。

验收合同定义：
- 每级验证的 pass/fail 标准
- 时序收敛目标（WNS/WHS）
- 资源占用上限（LUT/FF/BRAM/DSP/IOB 百分比）
- out-of-scope 范围

合同状态生命周期: unknown → draft → candidate → frozen → revised

## 反模式

### ❌ "先开发，验收标准以后再说"
```
没有验收标准的项目 = 不知道什么时候算"做完"。
即使在早期阶段，至少 L0-L1a 的 pass/fail 标准必须先行定义。
否则开发团队和审查团队对"通过"没有共识。
```

## 相关 Skills

- `fpga-project-charter` — 项目范围与目标定义
- `fpga-validation-levels` — L0-L7 门禁规则
- `fpga-vivado-methodology` — 资源/时序目标参考
