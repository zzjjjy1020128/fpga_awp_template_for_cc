# RUN-E001-SYNTH-030: Vivado 综合 — axis_output tlast 修复

## Metadata

- **Task**: TASK-E001-030
- **Verification Level**: L2 (Synthesis)
- **Date**: 2026-06-15
- **RTL Change**: axis_output.sv tlast 从帧末改为每行末（ISS-E001-011 修复）

## Result

| Item | Value |
|------|-------|
| Status | **PASS** |
| Errors | 0 |
| Critical Warnings | 0 |
| Warnings | 173 |
| Duration | 51s |

## Consistency Checks

| Check | Status |
|-------|:--:|
| IP RTL (`vivado/ip/...`) vs Project RTL (`rtl/`) | IDENTICAL |
| Vivado synthesis source | `rtl/axis_output.sv` (not IP repo copy) |
| BD validation | Pre-validated |
| XDC lint | PASS (3 files) |
| IP status | All up to date (50 IPs) |

## Notes

- Vivado 项目直接使用 `rtl/` 下的 RTL 源文件进行综合，而非 `vivado/ip/` 下的 IP 仓库副本
- 这意味着：修改 rtl/axis_output.sv 后，Vivado 综合会自动使用最新版本
- 但 IP repo 副本 (`vivado/ip/...`) 不会自动同步 → 如果后续需要重新打包 IP，会使用旧版本
- 建议：建立 `rtl/` → `vivado/ip/.../src/` 的单向同步机制（或删除 IP repo 副本，统一使用 rtl/）
