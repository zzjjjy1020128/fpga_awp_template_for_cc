---
skill_id: SKILL-FPGA-SOFTWARE-ENV-PROFILE
name: fpga-software-env-profile
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-011
validated_in_projects: []
last_reviewed: "2026-06-15"
owner: human_owner
---

# 软件环境配置

使用 `SOFTWARE_ENV_PROFILE_TEMPLATE.md` 模板创建软件环境配置。

记录内容：
- Vivado 版本和安装路径
- 仿真器（iverilog/verilator）版本
- Python 版本和关键依赖
- OS 信息
- 上板工具链（Vitis/XSCT）版本

## 反模式

### ❌ "环境变了但没记录，后来发现跑不通"
```
切换开发机器、升级工具链、重装 OS → 环境变化 → 以前通过的流程现在失败。
环境配置必须在变更时同步更新，不能等到"跑不通"才排查。
```

## 相关 Skills

- `fpga-vitis-cli-build` — CLI 编译（依赖环境配置）
- `fpga-vivado-preflight` — Vivado 环境检查
- `fpga-project-charter` — 项目约束（含工具链约束）
