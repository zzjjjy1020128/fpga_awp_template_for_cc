---
skill_id: SKILL-FPGA-VIVADO-PREFLIGHT
name: fpga-vivado-preflight
layer: FPGA-Method
status: candidate
source_basis:
  - SRC-FPGA-011
validated_in_projects: []
last_reviewed: "2026-06-15"
owner: human_owner
---

# Vivado 环境预检

> 对标 `docs/project_contract.md` 的软件环境合同，在 Vivado 工作前做环境完整性检查。
> 防止出现"跑了一半发现 license 过期 / IP repo 缺失 / 器件不支持"的情况。

## 触发条件

自动触发：
- Session 恢复后首次需要执行 Vivado 操作时
- Task 的 `agent == "vivado_integrator"` 且 `status` 变为 `in_progress` 时
- 切换目标平台时（`target_platform` 变更）

手动触发：
- 用户说 "preflight" / "环境检查" / "检查 Vivado"

## 检查清单

### Phase 1: Static（不启动 Vivado，< 5 秒）

| # | 检查项 | 方法 | 预期 |
|---|--------|------|------|
| 1 | Vivado 可执行文件存在 | 从 `host_env.yaml#toolchain.vivado.executable` 读取路径 | 存在 |
| 2 | 目标器件是否在支持列表 | 查 `project_contract.md#2.1` | 已确认 |
| 3 | 平台清单存在 | `ls .awp/platform/{id}.yaml` | 存在且 YAML 语法有效 |
| 4 | IP repo 目录存在 | `ls vivado/ip/` | 存在 component.xml |
| 5 | **RTL 源一致性** ⚠️ | `diff rtl/*.sv vivado/ip/.../src/*.sv` | 全部 identical |
| 6 | 约束文件存在 | `ls constraints/{base_timing, base_physical}.xdc` | 存在 |
| 7 | Vivado 工程存在 | `ls {vivado_project_path}.xpr` | 存在 |
| 8 | Python + PyYAML 就绪 | `python -c "import yaml"` | exit 0 |
| 9 | Pre-commit hook 已安装 | `ls .git/hooks/pre-commit` | 存在 |
| 10 | **XSCT 可用（Zynq 平台）** ⚠️ | 读取 `host_env.yaml#toolchain.vitis.xsct` 并验证文件存在 | 存在且可执行 |
| 11 | **ILA probes 文件存在** | `ls {impl_dir}/debug_nets.ltx` | 存在且与 bitstream 同目录 |
| 12 | **host_env.yaml 有效** | 读取 `.awp/platform/host_env.yaml` | `status: active` 且 `last_verified` 在 7 天内 |

> **⚠️ #5, #10, #11, #12** 是 TASK-E001-030 实战新增的检查项。
> - #10：XSCT 路径从 host_env.yaml 读取，不猜测
> - #11：`debug_nets.ltx` 烧录后须关联到 hw_device
> - #12：host_env.yaml 是 #1-#10 的基础——没有它，所有路径检查都是猜测

### host_env.yaml 读取方式

所有 Phase 1 的路径检查（#1 Vivado, #4 IP repo, #6 约束, #7 工程, #10 XSCT）
优先从 `.awp/platform/host_env.yaml` 读取。若 host_env 不存在或 stale → **BLOCK**，
先触发 `fpga-host-env-detect`。
> Vivado 工程可能直接引用 `rtl/` 目录下的 RTL 文件进行综合（而非 `vivado/ip/.../src/`）。
> 如果 rtl/ 和 vivado/ip/.../src/ 中的文件不一致，Vivado 综合使用的是 rtl/ 的版本，
> 但 IP 重新打包时会使用 vivado/ip/.../src/ 的旧版本。必须保持两者同步。

### Phase 2: Vivado Live（需启动 MCP session，~30 秒）

| # | 检查项 | 方法 | 预期 |
|---|--------|------|------|
| 9 | MCP Vivado 连通 | `start_session mode=tcl` | VMCP_READY |
| 10 | 工程可打开 | `open_project {xpr_path}` | 成功，无 fatal error |
| 11 | License 状态 | `get_license Synthesis` 或检查 MCP 连接日志 | 可获取 synthesis license |
| 12 | IP catalog 可刷新 | `get_ipdefs -all` 非空 | IP 列表不为空 |
| 13 | 目标器件匹配 | `get_property PART [current_project]` | 与平台清单一致 |
| 14 | BD 可打开且验证通过 | `open_bd_design` + `validate_bd_design` | 0 Critical Warnings |
| 15 | 约束文件在工程中 | `get_files -of [current_fileset -constr]` | 非空 |

### Phase 3: 合同对标（读文件，< 2 秒）

| # | 检查项 | 方法 | 预期 |
|---|--------|------|------|
| 16 | 软件环境合同已冻结 | 读 `project_contract.md#合同状态追踪` | 软件环境 = frozen |
| 17 | 硬件基座合同已冻结 | 读 `workspace_manifest.json#platforms[]` → manifest | 目标平台 status = frozen |
| 18 | 验收合同阶段匹配 | 读 `project_contract.md#3` | 当前 target level 的验收标准已定义 |

## 输出格式

```text
=== Vivado Preflight: {platform_id} ===

Phase 1 (Static):
  [PASS] Vivado executable: G:/vivado2022.2/Vivado/2022.2/bin/vivado.bat
  [PASS] Target part: xc7z010clg400-1 (confirmed in contract)
  [PASS] Platform manifest: .awp/platform/hw_base_ax7010_v1.0.yaml
  [PASS] IP repo: vivado/ip/axil_2d_shift_v1_0/component.xml
  [PASS] Constraint files: 2 found
  [PASS] Vivado project: vivado/shift_2d_ax7010_260608/shift_2d_ax7010_260608.xpr
  [WARN] Pre-commit hook: not installed

Phase 2 (Live):
  [PASS] MCP connectivity
  [PASS] Project opens
  [PASS] License: OK
  [PASS] IP catalog: {N} IPs loaded
  [PASS] Device matches: xc7z010clg400-1
  [PASS] BD validates: 0 Critical Warnings
  [PASS] Constraints in project: 2 files

Phase 3 (Contract):
  [PASS] Software Env: frozen (2026-06-08)
  [PASS] Hardware Base: frozen (2026-06-08)
  [PASS] Acceptance: L4 criteria defined

Result: READY — 18/18 checks passed
```

## 失败处理

| 失败阶段 | 动作 |
|---------|------|
| Phase 1 #5 FAIL | **阻断**。`rtl/` 与 `vivado/ip/.../src/` 不同步。立即同步两个副本，记录同步时间。 |
| Phase 1 其他任意项 FAIL | **阻断**。修复环境后再试。输出具体修复命令。 |
| Phase 2 #9 FAIL | MCP 服务未启动。检查 vivado-mcp 安装。 |
| Phase 2 #11 FAIL | License 问题。检查 license 文件或切换器件。 |
| Phase 2 #13 FAIL | 器件不匹配。确认正确的 xpr 文件。停止，不继续。 |
| Phase 3 任意项 FAIL | **阻断**（若状态为 candidate 且有 unknown 项）。提示用户确认后冻结合同。 |

## 反模式（禁止事项）

### ❌ "跳过 preflight，直接开 Vivado"
```
preflight 6 秒检查 vs 跑一半发现 license 过期/IP 缺失/器件不匹配
→ 白费 30 分钟。每次 Vivado 操作前必须跑 preflight。
```

### ❌ "昨天跑过了，今天不用跑"
```
环境可能已变化（license 过期、工程被他人修改、XSA 被覆盖）。
preflight 是易失检查——每次 session 恢复后首次 Vivado 操作前必须重跑。
```

## 相关 Skills

- `fpga-vivado-methodology` — 综合/实现流程（preflight 的前置条件）
- `fpga-iteration-economics` — 理解跳过 preflight 的成本
- `fpga-platform-freeze` — 平台冻结时的 contract 检查

## 与 AWP 资产的引用关系

```
vivado-preflight 读取:
  docs/project_contract.md         ← 合同状态 + 工具链版本
  workspace_manifest.json          ← 平台注册 + manifest 路径
  .awp/platform/{id}.yaml          ← 平台详细信息（器件、工程路径）
  constraints/                     ← 约束文件存在性

vivado-preflight 不修改任何文件（只读）。
```
