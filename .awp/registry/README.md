# AWP ID Registry

FPGA-AWP 的 ID 注册和命名空间管理。

## 文件说明

| 文件 | 用途 |
|------|------|
| `namespaces.yaml` | 定义所有 ID 类型的前缀、格式、生命周期 |
| `id_registry.yaml` | 记录已分配的所有 ID 实例 |
| `relations.yaml` | 记录对象之间的引用关系 |

## 使用规则

1. **创建 ID 前**：查阅 `namespaces.yaml` 确认格式，检查 `id_registry.yaml` 避免冲突
2. **创建 ID 后**：在 `id_registry.yaml` 中注册，在 `relations.yaml` 中记录引用关系
3. **校验**：运行 `make validate-awp` 自动检查 ID 格式和引用完整性

## ID 格式速查

| 类型 | 示例 |
|------|------|
| EXP | `EXP001` |
| TASK | `TASK-E001-001` |
| SESSION | `SESS-E001-OR-001` |
| HANDOFF | `HO-E001-001-001` |
| REVIEW | `REV-E001-001-RTL-001` |
| RUN | `RUN-E001-SIM-001` |
| DECISION | `DEC-AWP-0001` |
| ISSUE | `ISS-E001-001` |
| ARTIFACT | `ART-E001-BIT-001` |
