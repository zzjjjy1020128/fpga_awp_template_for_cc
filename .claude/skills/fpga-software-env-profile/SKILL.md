---
description: 软件环境配置模板——记录工具链版本、依赖、环境变量
when_to_use: 项目启动时记录软件环境；切换开发机器时复现环境；平台合同冻结前确认工具链
allowed-tools: Read, Write, Edit
---

# 软件环境配置

使用 `SOFTWARE_ENV_PROFILE_TEMPLATE.md` 模板创建软件环境配置。

记录内容：
- Vivado 版本和安装路径
- 仿真器（iverilog/verilator）版本
- Python 版本和关键依赖
- OS 信息
- 上板工具链（Vitis/XSCT）版本
