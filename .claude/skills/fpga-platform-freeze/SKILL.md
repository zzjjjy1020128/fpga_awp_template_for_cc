# 平台基座冻结

> 将已通过综合+实现+比特流的 Vivado BD 工程冻结为 AWP 硬件基座。
> 生成平台清单、注册到 workspace manifest、导出归档。

## 触发条件

自动触发：
- Task 的 `target_validation_level >= L4` 且 `validation_status.L4 == "pass"`
- 用户显式说"冻结基座"

手动触发：
- 用户说 "冻结" / "freeze" / "锁定基座"

## 前提条件

执行前必须确认以下全部满足：

- [ ] BD `validate_bd_design` 通过（0 Critical Warnings）
- [ ] HDL Wrapper 已生成
- [ ] 综合通过（0 errors）
- [ ] 实现通过（WNS >= 0, WHS >= 0）
- [ ] 比特流已生成（.bit 文件存在）
- [ ] 约束文件已添加到工程
- [ ] 平台 ID 已确定（格式: `HW_BASE_{BOARD}_v{major}.{minor}`）

## 执行流程

### Step 1: 收集元数据

从 Vivado 工程和 session 上下文收集中提取以下信息：

```yaml
platform.id:        # 从 task 或用户确认
platform.target:    # get_property PART [current_project]
vivado_project:     # 工程路径
frozen_ip:          # get_bd_cells + get_property VLNV
slots:              # 从 architecture 文档或 BD interface nets 提取
clock_reset:        # 从 PS IP 配置提取
validation:         # 从 synth/impl run 提取
```

### Step 2: 写平台清单

生成 `.awp/platform/{platform.id}.yaml`，模板结构参照 `.awp/platform/hw_base_ax7010_v1.0.yaml`。

必需字段：
- `platform.id`, `platform.status` (= "frozen"), `platform.frozen_date`
- `platform.target` (part, board, family)
- `platform.vivado_project` (path, bd_name, wrapper)
- `platform.frozen_ip[]` (每个 IP 的 name, vlnv, role)
- `platform.slots` (SLOT_AXIL / SLOT_AXIS_I / SLOT_AXIS_O / SLOT_IRQ)
- `platform.constraints.frozen[]`
- `platform.validation` (synthesis, implementation, bitstream — 含数值)
- `platform.changelog[0]`

### Step 3: 注册到 workspace manifest

编辑 `.awp/workspace_manifest.json`，在 `platforms[]` 数组中新增条目：

```json
{
  "id": "{platform.id}",
  "manifest": ".awp/platform/{platform.id}.yaml",
  "status": "frozen",
  "frozen_date": "{date}",
  "description": "{board} — {chip_family} ({part}). {freq}, {role}."
}
```

### Step 4: 导出 BD 归档

```tcl
open_bd_design [get_files {bd_name}.bd]
write_bd_tcl -force vivado/{proj}/bd_export/{bd_name}_bd.tcl
```

### Step 5: 写 CHANGELOG

创建/更新 `vivado/{proj}/CHANGELOG.md`，记录初始版本和验证指标。

### Step 6: 写决策记录

在 `.awp/decisions.md` 中新增 ADR 条目（若为新平台首次冻结）。

### Step 7: 自洽验证

```bash
python scripts/validate_awp.py --sync
python scripts/validate_awp.py
```

确认 `workspace_manifest.json` 的 `platforms[]` 引用指向实际存在的 `.awp/platform/*.yaml` 文件。

## 平台命名规范

```
HW_BASE_{BOARD}_v{major}.{minor}

BOARD:    ZCU102 / AX7010 / KC705 / ... (板卡型号，大写)
major:    BD 拓扑变更、IP 版本升级、接口契约变更
minor:    约束更新、非破坏性参数调整
```

## 冻结后规则

| 操作 | 允许？ | 条件 |
|------|:--:|------|
| 修改 BD IP 配置 | 否 | 需平台级理由 + major 升版 |
| 修改 base_*.xdc | 否 | 需平台级理由 + minor 升版 |
| 替换 accelerator IP | 是 | 保持相同 SLOT_* 接口 |
| 升级 accelerator IP 版本 | 是 | BD 中 Upgrade IP → 重综合 |
| 新增 ILA 探针 | 是 | 修改 debug.xdc（不属 base） |
| 重新综合/实现 | 是 | 不修改 BD 即可重跑 |

## 与 AWP 资产的引用关系

```
platform-freeze 产出:
  .awp/platform/{id}.yaml        ← validate_awp.py --check-platform 校验 (待实现)
  workspace_manifest.json         ← SessionStart hook 读取 (待实现)
  vivado/{proj}/CHANGELOG.md      ← human-readable
  vivado/{proj}/bd_export/*.tcl   ← 灾难恢复

被引用:
  docs/project_contract.md        ← 合同索引
  CLAUDE.md G9                    ← 平台合同管理规则
  TASK-*.yaml#target_platform     ← task 绑定
```
