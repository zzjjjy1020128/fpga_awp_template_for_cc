---
skill_id: SKILL-FPGA-HOST-ENV-DETECT
name: fpga-host-env-detect
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-011
validated_in_projects: ["E001"]
last_reviewed: "2026-06-15"
owner: human_owner
---

# 主机环境检测与描述符管理

> ⚠️ **触发（强制）**：
> 1. **Session 启动时** — orchestrator 恢复上下文后第一件事
> 2. **首次 Vivado/Vitis 操作前** — `fpga-vivado-preflight` 读取 host_env 做静态检查
> 3. **用户报告环境变更时** — "我升级了 Vivado" / "换了台机器" / "装了新工具"
> 4. **工具未找到时** — 任何 "command not found" / "xsct not found" 类错误后

## 目的

FPGA 开发依赖特定版本的工具链。`host_env.yaml` 是本机工具链的**权威描述符**——
它是"主机端的平台清单"，与 `hw_base_*.yaml`（硬件端）对称。

没有 host_env → 模型会猜测工具路径 → 错了就浪费数小时 debug（TASK-E001-030 实战教训）。

## host_env.yaml 结构

```yaml
host:
  id: "HOST-{user}-{os}"       # 主机唯一标识
  os: "Windows 11 Home China"
  hostname: "laptop_zjy"

toolchain:
  vivado:
    path: "G:/vivado2022.2/Vivado/2022.2"
    version: "2022.2"
    hw_server: "G:/vivado2022.2/Vivado/2022.2/bin/hw_server.bat"

  vitis:
    path: "G:/vivado2022.2/Vitis/2022.2"
    xsct: "G:/vivado2022.2/Vitis/2022.2/bin/xsct.bat"   # ⚠️ 在 Vitis 目录，非 Vivado bin

  simulation:
    iverilog:
      path: "/g/iverilog/iverilog/bin/iverilog"
      version: "11.0"

  python:
    version: "3.11.9"

board:
  jtag_id: "Digilent/210512180081"
  hw_server_url: "TCP:localhost:3121"
  target_device: "xc7z010"

project:
  vivado_project: "vivado/shift_2d_ax7010_260608/..."

status: "active"  # active | stale | invalid
generated_date: "2026-06-15"
last_verified: "2026-06-15"
```

## 检测流程

### 自动扫描

```bash
# Vivado
ls <vivado_base>/Vivado/<version>/bin/vivado.bat

# Vitis / XSCT
ls <vivado_base>/Vitis/<version>/bin/xsct.bat   # ⚠️ 不在 Vivado/bin！

# iverilog
which iverilog && iverilog -V 2>&1 | head -1

# Python
python --version

# Board (from hw_server)
# 检查 hw_server 是否可达：netstat -ano | grep 3121
# JTAG ID 从上一次连接记录中提取
```

### 验证规则

| 检查项 | 条件 | 失败动作 |
|--------|------|---------|
| Vivado 可执行文件存在 | `vivado.bat` 存在 | BLOCK — 无法综合 |
| XSCT 可执行文件存在 | `xsct.bat` 存在（Zynq 平台） | BLOCK — 无法上板 |
| iverilog 可用 | `iverilog -V` exit 0 | WARN — 无快速语法检查 |
| Python + PyYAML | `python -c "import yaml"` exit 0 | BLOCK — validate_awp 无法运行 |
| host_env.yaml status | `active` | 过期 → 重新扫描 |

### 何时更新

| 事件 | 动作 |
|------|------|
| 首次设置 | 运行完整扫描，生成 `host_env.yaml` |
| 工具链升级 | 更新对应 toolchain 节，修改 `last_verified` |
| 切换板卡 | 更新 board 节（JTAG ID 可能变化） |
| 每次 session 启动 | 验证 `last_verified` 在 7 天内，否则提示重新扫描 |
| 工具未找到 | 立即标记 `status: stale`，重新扫描 |

## 与其他资产的关系

```
host_env.yaml 被读取:
  ├── fpga-vivado-preflight → Phase 1 静态检查
  ├── fpga-zynq-debug-toolchain → XSCT 路径引用
  ├── fpga-vitis-cli-build → XSCT 路径引用
  ├── fpga-board-validation → hw_server URL, JTAG ID
  ├── fpga-iteration-economics → 工具可用性影响决策成本
  └── CLAUDE.md Session Protocol → 启动时自动验证

host_env.yaml 被写入:
  └── fpga-host-env-detect（本 skill）→ 扫描 + 生成 + 更新
```

## 反模式

### ❌ "我大概知道 Vivado 在哪"（不查 host_env）
```
模型凭经验猜测 Vivado 路径 → 猜错 → "command not found"
→ 用户说"不是装了吗" → 浪费时间排查
```

### ❌ "XSCT 应该在 Vivado/bin 下"（凭推理猜测路径）
```
TASK-E001-030 实战：在 Vivado/bin 找了半天找不到 XSCT。
实际位置：Vitis/<version>/bin/xsct.bat。
host_env.yaml 直接记录正确路径，消除猜测。
```

### ❌ "上次能用，这次肯定也能用"（不验证最后检查时间）
```
工具链可能已被卸载/升级/移动。host_env.yaml 的 last_verified
字段确保环境描述不会悄悄过期。
```

## 语言策略

- YAML key：en
- 路径：en（OS 原生格式）
- 说明：zh
