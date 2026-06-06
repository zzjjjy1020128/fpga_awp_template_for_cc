#!/usr/bin/env python3
"""
FPGA-AWP Workspace Validator

校验 FPGA-AWP 工作空间的完整性：
  - Task YAML 格式校验（对照 task.schema.json）
  - ID 命名规范校验（对照 .awp/registry/namespaces.yaml）
  - 跨文件引用完整性检查（对照 .awp/registry/relations.yaml）
  - 验证门禁检查（L0→L7 递进）
  - Task board 自动生成

用法：
  python scripts/validate_awp.py                  # 完整校验
  python scripts/validate_awp.py --summary        # 任务状态汇总
  python scripts/validate_awp.py --gate-check     # 门禁检查
  python scripts/validate_awp.py --gen-task-board # 生成 task_board.md
  python scripts/validate_awp.py --sync           # 自动修复可检测的不一致
  python scripts/validate_awp.py --guard <mode>   # AWP guard (hooks 用)
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required. Install with: pip install pyyaml")
    sys.exit(1)

# 项目根目录（脚本在 scripts/ 下）
ROOT = Path(__file__).resolve().parent.parent

# 命名空间格式正则（从 namespaces.yaml 提取）
NAMESPACE_PATTERNS = {
    "EXP": re.compile(r"^EXP\d{3}$"),
    "TASK": re.compile(r"^TASK-[A-Z]\d{3}-\d{3}$"),
    "SESSION": re.compile(r"^SESS-[A-Z]\d{3}-OR-\d{3}$"),
    "HANDOFF": re.compile(r"^HO-[A-Z]\d{3}-\d{3}-\d{3}$"),
    "REVIEW": re.compile(r"^REV-[A-Z]\d{3}-\d{3}-[A-Z]+-\d{3}$"),
    "RUN": re.compile(r"^RUN-[A-Z]\d{3}-(?:[A-Z0-9]+-)?[A-Z0-9]+-\d{3}$"),
    "DECISION": re.compile(r"^DEC-[A-Z]+-\d{4}$"),
    "ISSUE": re.compile(r"^ISS-[A-Z]\d{3}-\d{3}$"),
    "ARTIFACT": re.compile(r"^ART-[A-Z]\d{3}-[A-Z]+-\d{3}$"),
}

VALID_TASK_STATUSES = {"ready", "in_progress", "blocked", "review", "done"}

# v0.2: 即使有 L1b GAP 也允许 spawn 的 agent（修复、建 task、审查、流程修补）
GAP_SAFE_AGENTS = {"planner", "rtl_implementer", "rtl_reviewer", "process_owner"}
VALID_VAL_STATUSES = {"pending", "pass", "fail", "skip"}
VALID_L_LEVELS = ["L0", "L1a", "L1b", "L1c", "L2", "L3", "L4", "L5", "L6", "L7"]


def load_json_schema(path):
    """加载 JSON Schema 文件"""
    try:
        with open(ROOT / path, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return None
    except json.JSONDecodeError as e:
        print(f"  ERROR: Invalid JSON in {path}: {e}")
        return None


def load_yaml_file(path):
    """加载 YAML 文件"""
    full = ROOT / path
    if not full.exists():
        return None, f"File not found: {path}"
    try:
        with open(full, "r", encoding="utf-8") as f:
            return yaml.safe_load(f), None
    except yaml.YAMLError as e:
        return None, f"YAML parse error in {path}: {e}"


def validate_schema_required(data, schema, path=""):
    """验证 data 是否符合 schema 的 required 字段和类型约束"""
    errors = []
    if not isinstance(data, dict):
        return [f"{path}: expected object, got {type(data).__name__}"]

    for key in schema.get("required", []):
        if key not in data or data[key] is None:
            errors.append(f"{path}: missing required field '{key}'")

    for key, prop in schema.get("properties", {}).items():
        if key not in data or data.get(key) is None:
            continue
        value = data[key]
        prop_type = prop.get("type")

        if prop_type == "string":
            if not isinstance(value, str):
                errors.append(f"{path}.{key}: expected string, got {type(value).__name__}")
                continue
            if "enum" in prop and value not in prop["enum"]:
                errors.append(f"{path}.{key}: '{value}' not in enum {prop['enum']}")
            if "pattern" in prop and not re.match(prop["pattern"], value):
                errors.append(f"{path}.{key}: '{value}' does not match pattern '{prop['pattern']}'")

        elif prop_type == "object" and isinstance(value, dict):
            errors.extend(validate_schema_required(value, prop, f"{path}.{key}"))

        elif prop_type == "array" and isinstance(value, list):
            item_type = prop.get("items", {}).get("type")
            if item_type == "string":
                for i, item in enumerate(value):
                    if not isinstance(item, str):
                        errors.append(f"{path}.{key}[{i}]: expected string")

    return errors


def load_namespace_patterns():
    """从 namespaces.yaml 动态加载 pattern 字段，fallback 到硬编码 NAMESPACE_PATTERNS"""
    ns_data, err = load_yaml_file(".awp/registry/namespaces.yaml")
    if err or not ns_data:
        return NAMESPACE_PATTERNS.copy()

    patterns = {}
    for ns_name, ns_info in ns_data.get("namespaces", {}).items():
        pattern_str = ns_info.get("pattern")
        if pattern_str:
            try:
                patterns[ns_name] = re.compile(pattern_str)
            except re.error:
                pass  # 无效正则，跳过

    # fallback：硬编码中定义但 namespaces.yaml 没有 pattern 的
    for ns_name, pattern in NAMESPACE_PATTERNS.items():
        if ns_name not in patterns:
            patterns[ns_name] = pattern

    return patterns


def check_id_format(id_str):
    """检查 ID 字符串是否符合任一已知 namespace 格式（动态加载 patterns）"""
    patterns = load_namespace_patterns()
    for ns, pattern in patterns.items():
        if pattern.match(id_str):
            return ns
    return None


def validate_task_files():
    """校验 .awp/tasks/*.yaml 文件"""
    errors = []
    tasks_dir = ROOT / ".awp" / "tasks"
    if not tasks_dir.exists():
        return errors

    schema = load_json_schema(".awp/schemas/task.schema.json")
    if schema is None:
        errors.append("Cannot load task.schema.json")
        return errors

    for yaml_file in sorted(tasks_dir.glob("*.yaml")):
        if yaml_file.name == ".gitkeep":
            continue
        rel = str(yaml_file.relative_to(ROOT))
        data, err = load_yaml_file(rel)
        if err:
            errors.append(err)
            continue
        if data is None:
            continue

        # Schema 校验
        errors.extend(validate_schema_required(data, schema, rel))

        # ID 格式校验
        task_id = data.get("task_id", "")
        if task_id and not check_id_format(str(task_id)):
            errors.append(f"{rel}: task_id '{task_id}' has invalid format")

        # validation_status 递进检查
        vs = data.get("validation_status", {})
        prev_pass = True
        for level in VALID_L_LEVELS:
            status = vs.get(level, "pending")
            if status not in VALID_VAL_STATUSES:
                errors.append(f"{rel}: validation_status.{level} invalid value '{status}'")
            if status == "pass" and not prev_pass:
                errors.append(
                    f"{rel}: validation_status {level}=pass but previous level is not pass (gate violation)"
                )
            if status != "pass" and status != "skip":
                prev_pass = False

    return errors


def validate_review_files():
    """校验 .awp/reviews/*.md 的 YAML frontmatter"""
    errors = []
    reviews_dir = ROOT / ".awp" / "reviews"
    if not reviews_dir.exists():
        return errors

    VALID_RESULTS = {"pass", "pass_with_notes", "fail"}
    for md_file in sorted(reviews_dir.glob("*.md")):
        if md_file.name == ".gitkeep":
            continue
        rel = str(md_file.relative_to(ROOT))
        try:
            with open(md_file, "r", encoding="utf-8") as f:
                content = f.read()
        except Exception as e:
            errors.append(f"{rel}: read error: {e}")
            continue

        # 提取 YAML frontmatter
        fm = extract_frontmatter(content)
        if fm is None:
            errors.append(f"{rel}: missing or malformed YAML frontmatter")
            continue

        if "task_id" not in fm:
            errors.append(f"{rel}: frontmatter missing 'task_id'")
        elif not check_id_format(str(fm["task_id"])):
            errors.append(f"{rel}: frontmatter task_id '{fm['task_id']}' has invalid format")

        if "reviewer" not in fm:
            errors.append(f"{rel}: frontmatter missing 'reviewer'")

        if "result" not in fm:
            errors.append(f"{rel}: frontmatter missing 'result'")
        elif fm["result"] not in VALID_RESULTS:
            errors.append(f"{rel}: frontmatter result '{fm['result']}' not in {VALID_RESULTS}")

        if "date" not in fm:
            errors.append(f"{rel}: frontmatter missing 'date'")

    return errors


def extract_frontmatter(content):
    """提取 Markdown 文件的 YAML frontmatter（--- 包围）"""
    if not content.startswith("---"):
        return None
    # 找第二个 ---
    end = content.find("---", 3)
    if end == -1:
        return None
    try:
        return yaml.safe_load(content[3:end])
    except yaml.YAMLError:
        return None


def validate_cross_references():
    """检查跨文件引用完整性"""
    errors = []
    tasks_dir = ROOT / ".awp" / "tasks"
    reviews_dir = ROOT / ".awp" / "reviews"

    # 收集已注册的 task_id
    known_task_ids = set()
    if tasks_dir.exists():
        for yaml_file in tasks_dir.glob("*.yaml"):
            if yaml_file.name == ".gitkeep":
                continue
            data, _ = load_yaml_file(str(yaml_file.relative_to(ROOT)))
            if data and data.get("task_id"):
                known_task_ids.add(data["task_id"])

    # 检查 review 引用的 task_id
    if reviews_dir.exists():
        for md_file in reviews_dir.glob("*.md"):
            if md_file.name == ".gitkeep":
                continue
            rel = str(md_file.relative_to(ROOT))
            try:
                with open(md_file, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception:
                continue
            fm = extract_frontmatter(content)
            if fm and fm.get("task_id") and fm["task_id"] not in known_task_ids:
                errors.append(f"{rel}: references unknown task_id '{fm['task_id']}'")

    # 检查依赖链和 handoff.next_task
    if tasks_dir.exists():
        for yaml_file in tasks_dir.glob("*.yaml"):
            if yaml_file.name == ".gitkeep":
                continue
            rel = str(yaml_file.relative_to(ROOT))
            data, _ = load_yaml_file(rel)
            if not data:
                continue
            for dep_id in data.get("depends_on", []) or []:
                if dep_id not in known_task_ids:
                    errors.append(f"{rel}: depends on unknown task_id '{dep_id}'")
            # 检查 handoff.next_task 引用
            handoff = data.get("handoff", {}) or {}
            next_task = handoff.get("next_task", "")
            if next_task and next_task not in known_task_ids:
                errors.append(f"{rel}: handoff.next_task references unknown task_id '{next_task}'")

    return errors


def validate_review_coverage():
    """检查每个 RTL task 是否有对应的通过 review（按 G3 规则）"""
    errors = []
    tasks_dir = ROOT / ".awp" / "tasks"
    reviews_dir = ROOT / ".awp" / "reviews"

    if not tasks_dir.exists():
        return errors

    # 收集 task_id → review results
    task_reviews = defaultdict(list)
    if reviews_dir.exists():
        for md_file in reviews_dir.glob("*.md"):
            if md_file.name == ".gitkeep":
                continue
            try:
                with open(md_file, "r", encoding="utf-8") as f:
                    content = f.read()
            except Exception:
                continue
            fm = extract_frontmatter(content)
            if fm and fm.get("task_id") and fm.get("result"):
                task_reviews[fm["task_id"]].append(fm["result"])

    # G3 规则：所有 RTL 文件必须 review
    for yaml_file in sorted(tasks_dir.glob("*.yaml")):
        if yaml_file.name == ".gitkeep":
            continue
        rel = str(yaml_file.relative_to(ROOT))
        data, _ = load_yaml_file(rel)
        if not data:
            continue
        tid = data.get("task_id", "")
        status = data.get("status", "")
        agent = data.get("agent", "")

        # 只检查 active/done 的 rtl_implementer task
        if status not in ("in_progress", "review", "done"):
            continue
        if agent not in ("rtl_implementer",):
            continue

        results = task_reviews.get(tid, [])
        has_pass = any(r in ("pass", "pass_with_notes") for r in results)
        if not has_pass:
            if not results:
                errors.append(f"{rel}: task '{tid}' ({status}) has NO review (G3: all RTL must be reviewed)")
            else:
                errors.append(f"{rel}: task '{tid}' ({status}) has no PASSING review (results: {results})")

    return errors


def validate_skip_usage():
    """检查 skip 语义是否被滥用。
    - skip = 该验证级别对此 task 类型/scope 确实不适用（如 planner 不需要仿真）
    - rtl_implementer + integration_scope=module 的 task，L1b/L1c 不得为 skip
      （模块的正确性需要在数据通路闭环 L1b 和全系统 L1c 中确认，不能声称"跳过"）
    - tb_verifier + integration_scope=module 同理，L1b/L1c 不得为 skip
    """
    errors = []
    tasks_dir = ROOT / ".awp" / "tasks"
    if not tasks_dir.exists():
        return errors

    # Agent 类型与 must-not-skip 的 level 映射
    # 规则：对模块级 RTL/验证 task，L1b(数据通路闭环) 和 L1c(全系统集成) 必须 pending
    AGENT_MUST_NOT_SKIP = {
        "rtl_implementer": ["L1b", "L1c"],
    }

    for yaml_file in sorted(tasks_dir.glob("*.yaml")):
        if yaml_file.name == ".gitkeep":
            continue
        rel = str(yaml_file.relative_to(ROOT))
        data, _ = load_yaml_file(rel)
        if not data:
            continue
        tid = data.get("task_id", "")
        agent = data.get("agent", "")
        scope = data.get("integration_scope", "module")
        vs = data.get("validation_status", {})

        if agent not in AGENT_MUST_NOT_SKIP:
            continue
        if scope not in ("module",):
            # datapath/system scope tasks may legitimately skip lower levels
            continue

        for level in AGENT_MUST_NOT_SKIP[agent]:
            if vs.get(level) == "skip":
                errors.append(
                    f"{rel}: {level}=skip is invalid for agent={agent} scope={scope}. "
                    f"Module-level tasks must have {level}=pending (verified in integration tasks, not skipped)"
                )

    return errors


def validate_fail_status():
    """检查 validation_status 中的 fail 与 task status 的一致性。
    - 如果某 level=fail 且 task status=done，该 task 不应是 done（有未解决的验证失败）
    - 如果 task status=in_progress/review 且有 level=fail，提醒需要修复
    """
    errors = []
    tasks_dir = ROOT / ".awp" / "tasks"
    if not tasks_dir.exists():
        return errors

    for yaml_file in sorted(tasks_dir.glob("*.yaml")):
        if yaml_file.name == ".gitkeep":
            continue
        rel = str(yaml_file.relative_to(ROOT))
        data, _ = load_yaml_file(rel)
        if not data:
            continue
        tid = data.get("task_id", "")
        status = data.get("status", "")
        vs = data.get("validation_status", {})

        failed_levels = [lv for lv in VALID_L_LEVELS if vs.get(lv) == "fail"]
        if not failed_levels:
            continue

        if status == "done":
            errors.append(
                f"{rel}: task '{tid}' is done but has fail in {failed_levels}. "
                f"Done tasks must have no failing validation levels."
            )
        elif status not in ("in_progress", "blocked"):
            errors.append(
                f"{rel}: task '{tid}' has fail in {failed_levels} but status={status}. "
                f"Should be in_progress or blocked."
            )

    return errors


def validate_output_files():
    """检查 required_outputs 和 must_read 中列出的文件是否存在"""
    errors = []
    tasks_dir = ROOT / ".awp" / "tasks"
    if not tasks_dir.exists():
        return errors

    for yaml_file in sorted(tasks_dir.glob("*.yaml")):
        if yaml_file.name == ".gitkeep":
            continue
        rel = str(yaml_file.relative_to(ROOT))
        data, _ = load_yaml_file(rel)
        if not data:
            continue

        status = data.get("status", "")
        if status not in ("in_progress", "review", "done"):
            continue

        # 检查 required_outputs
        for fpath in data.get("required_outputs", []) or []:
            if not (ROOT / fpath).exists():
                errors.append(f"{rel}: required_output '{fpath}' does not exist (task status={status})")

        # 检查 must_read
        for fpath in data.get("context", {}).get("must_read", []) or []:
            if not (ROOT / fpath).exists():
                errors.append(f"{rel}: must_read '{fpath}' does not exist")

    return errors


def validate_issue_files():
    """校验 .awp/issues/*.yaml 文件"""
    errors = []
    issues_dir = ROOT / ".awp" / "issues"
    if not issues_dir.exists():
        return errors

    schema = load_json_schema(".awp/schemas/issue.schema.json")
    if schema is None:
        return errors  # schema 不存在时不报错（可能是首次初始化）

    for yaml_file in sorted(issues_dir.glob("*.yaml")):
        if yaml_file.name == ".gitkeep":
            continue
        rel = str(yaml_file.relative_to(ROOT))
        data, err = load_yaml_file(rel)
        if err:
            errors.append(err)
            continue
        if data is None:
            continue
        errors.extend(validate_schema_required(data, schema, rel))

        # 检查 round_count 超限
        rc = data.get("round_count", 0)
        mr = data.get("max_rounds", 3)
        status = data.get("status", "")
        if rc > mr and status not in ("blocked", "resolved", "closed"):
            errors.append(
                f"{rel}: round_count={rc} exceeds max_rounds={mr}, "
                f"status should be blocked (current: {status})"
            )

    return errors


def validate_integration_scope():
    """v0.2: 检查 integration_verifier task 的 scope 是否违规修改子模块 RTL"""
    errors = []
    tasks_dir = ROOT / ".awp" / "tasks"
    if not tasks_dir.exists():
        return errors

    for yaml_file in sorted(tasks_dir.glob("*.yaml")):
        if yaml_file.name == ".gitkeep":
            continue
        rel = str(yaml_file.relative_to(ROOT))
        data, _ = load_yaml_file(rel)
        if not data:
            continue

        agent = data.get("agent", "")
        if agent != "integration_verifier":
            continue

        # integration_verifier 的 allowed_edit_paths 不应包含子模块 RTL
        # 例外：顶层集成模块本身（如 axil_2d_shift.sv）是合法的
        allowed = data.get("scope", {}).get("allowed_edit_paths", []) or []
        forbidden = data.get("scope", {}).get("forbidden_edit_paths", []) or []
        for path in allowed:
            if path.startswith("rtl/") and path != "rtl/":
                # 如果路径也在 forbidden 中（矛盾），跳过
                if path in forbidden:
                    continue
                # 检查是否为已知子模块 RTL（非顶层集成模块）
                fname = path.replace("rtl/", "")
                if fname in ("axil_slave_if.sv", "regs_top.sv", "ctrl_fsm.sv",
                             "axis_input.sv", "shift_addr_gen.sv", "axis_output.sv",
                             "frame_buf_mgr.sv"):
                    errors.append(
                        f"{rel}: integration_verifier allows edit of '{path}'. "
                        f"Per G6, integration_verifier must not modify sub-module RTL."
                    )

    return errors


def validate_dependency_ripple():
    """检测依赖链上的验证状态不一致。
    当上游 task 的验证 level 回退（如 L1a pass→pending），下游 task 的对应 level
    应同步回退。例如 TASK-E001-004 L1a 回退 → TASK-E001-009 的 L1b 也应 pending。
    """
    errors = []
    tasks_dir = ROOT / ".awp" / "tasks"
    if not tasks_dir.exists():
        return errors

    # 收集所有 task
    all_tasks = {}
    for yaml_file in sorted(tasks_dir.glob("*.yaml")):
        if yaml_file.name == ".gitkeep":
            continue
        rel = str(yaml_file.relative_to(ROOT))
        data, _ = load_yaml_file(rel)
        if data:
            all_tasks[data.get("task_id", "")] = data

    # Level 映射：上游 task 的 target level → 下游 task 应关注的 level
    # rtl_implementer (target=L1a) → 下游 integration task 应关注 L1b
    UPSTREAM_TARGET_TO_DOWNSTREAM_LEVEL = {
        "L1a": "L1b",
        "L1b": "L1c",
    }

    for tid, t in all_tasks.items():
        deps = t.get("depends_on", []) or []
        upstream_target = t.get("target_validation_level", "")
        downstream_level = UPSTREAM_TARGET_TO_DOWNSTREAM_LEVEL.get(upstream_target, "")

        if not downstream_level:
            continue

        for dep_id in deps:
            if dep_id not in all_tasks:
                continue
            dep_task = all_tasks[dep_id]
            dep_vs = dep_task.get("validation_status", {})
            # 如果下游 task 的该 level 是 pass，但上游 task 的 target 不是 pass → 涟漪未传播
            downstream_status = dep_vs.get(downstream_level, "pending")
            upstream_vs = t.get("validation_status", {})
            upstream_status = upstream_vs.get(upstream_target, "pending")

            if downstream_status == "pass" and upstream_status not in ("pass", "skip"):
                errors.append(
                    f".awp/tasks/{tid}.yaml: depends on {dep_id} but "
                    f"{dep_id}.{upstream_target}={upstream_status} while "
                    f"{tid}.{downstream_level}=pass. "
                    f"Upstream regression should propagate — set {downstream_level}=pending."
                )

    return errors


def validate_issue_coverage():
    """检查每个 FAIL 的 RUN 是否有对应的 ISS issue，以及 issue 的完整性。
    这是 G4 规则"每个 L1b/L1c fail 必须创建 ISS issue"的程序化执行。
    """
    errors = []
    runs_dir = ROOT / ".awp" / "runs"
    issues_dir = ROOT / ".awp" / "issues"

    if not runs_dir.exists():
        return errors

    # 收集所有 RUN 的状态
    failed_runs = []
    for f in sorted(runs_dir.glob("RUN-*.md")):
        try:
            content = _read_file_robust(f)
        except Exception:
            continue
        for line in content.split("\n")[:30]:
            if "Status" in line and ("FAIL" in line or "fail" in line):
                failed_runs.append(f.stem)
                break

    if not failed_runs:
        return errors

    # 收集已存在的 issue 指向的 run（支持逗号分隔的多引用）
    issue_run_map = {}
    if issues_dir.exists():
        for f in sorted(issues_dir.glob("ISS-*.yaml")):
            data, _ = load_yaml_file(str(f.relative_to(ROOT)))
            if data:
                run_ref = data.get("detected_in_run", "")
                if run_ref:
                    for rid in run_ref.split(","):
                        rid = rid.strip()
                        if rid:
                            issue_run_map[rid] = f.stem

    # 检查每个 FAIL run 是否有 issue
    for run_id in failed_runs:
        if run_id not in issue_run_map:
            errors.append(
                f"RUN {run_id} has FAIL status but no corresponding ISS issue. "
                f"Create issue at .awp/issues/ with detected_in_run: {run_id}"
            )

    # 检查每个 open issue 是否有 suspected_owner_task
    if issues_dir.exists():
        for f in sorted(issues_dir.glob("ISS-*.yaml")):
            data, _ = load_yaml_file(str(f.relative_to(ROOT)))
            if not data:
                continue
            if data.get("status") in ("open", "in_progress"):
                if not data.get("suspected_owner_task"):
                    errors.append(f"{f.stem}: open but no suspected_owner_task assigned")
                if data.get("round_count", 0) > data.get("max_rounds", 3):
                    errors.append(f"{f.stem}: round_count exceeds max_rounds, should be blocked")

    return errors


def validate_port_connectivity():
    """检查 SystemVerilog 模块端口在所有实例化点是否完整连接。
    防止 sub-agent 添加端口后遗漏某些实例化点的连接。
    """
    errors = []
    rtl_dir = ROOT / "rtl"
    tb_dir = ROOT / "tb"
    if not rtl_dir.exists():
        return errors

    # 1. 收集所有模块的端口定义: module_name -> {input_ports, output_ports}
    module_inputs = {}
    for sv_file in sorted(rtl_dir.glob("*.sv")):
        try:
            content = sv_file.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            try:
                content = sv_file.read_text(encoding="gbk", errors="replace")
            except Exception:
                continue
        # 提取 module 声明和端口列表
        m = re.search(r'module\s+(\w+)\s*#?\s*\(.*?\)\s*\(\s*(.*?)\s*\)\s*;', content, re.DOTALL)
        if not m:
            continue
        mod_name = m.group(1)
        port_block = m.group(2)
        # 只收集 input 端口（output 可以不连）
        input_ports = set()
        for line in port_block.split(","):
            line = re.sub(r'//.*$', '', line).strip()
            pm = re.search(r'(\w+)\s*$', line)
            if pm and re.search(r'\binput\b', line):
                input_ports.add(pm.group(1))
        if input_ports:
            module_inputs[mod_name] = input_ports

    if not module_inputs:
        return errors

    # 2. 收集所有文件中的模块实例化，检查 input 端口连接
    all_files = list(rtl_dir.glob("*.sv")) + list(tb_dir.glob("*.sv"))
    for sv_file in sorted(all_files):
        try:
            content = sv_file.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            try:
                content = sv_file.read_text(encoding="gbk", errors="replace")
            except Exception:
                continue

        for mod_name, defined_inputs in module_inputs.items():
            # 跳过模块自身的定义文件
            if sv_file.stem == mod_name:
                continue
            # 找所有该模块的实例化
            inst_pattern = re.compile(
                r'\b' + re.escape(mod_name) + r'\s*(?:#\s*\(.*?\))?\s*(\w+)\s*\(\s*(.*?)\s*\)\s*;',
                re.DOTALL
            )
            for inst_m in inst_pattern.finditer(content):
                inst_name = inst_m.group(1)
                conn_block = inst_m.group(2)
                # 提取连接的端口名: .portname(...) 或 .portname(signal)
                connected = set(re.findall(r'\.(\w+)\s*\(', conn_block))
                # 隐式连接: .portname  (无括号)
                connected.update(re.findall(r'\.(\w+)\s*,', conn_block))
                # 检查缺失
                missing = defined_inputs - connected
                # 排除常见不需要显式连接的端口（如 outputs 未驱动、L1b TB 部分连接等）
                # regex 解析可能有假阳性（如 .port 出现在字符串或注释中）
                if missing:
                    rel = str(sv_file.relative_to(ROOT))
                    errors.append(
                        f"{rel}: port-check: {mod_name} instance '{inst_name}' "
                        f"may be missing connection(s): {', '.join(sorted(missing))}. "
                        f"Verify manually — regex may have false positives."
                    )

    return errors


def validate_resource_thresholds():
    """检查 L2/L3 run 报告中的资源利用率是否超过器件阈值。
    IOB > 70%、BRAM > 90%、DSP > 80% 触发 WARN——可能说明架构方向错误。
    """
    warnings = []
    runs_dir = ROOT / ".awp" / "runs"
    if not runs_dir.exists():
        return warnings

    thresholds = {
        "IOB": 0.70,
        "Block RAM": 0.90,
        "DSP": 0.80,
    }

    for f in sorted(runs_dir.glob("RUN-E001-SYNTH-*.md"), reverse=True)[:1]:
        try:
            content = _read_file_robust(f)
        except Exception:
            continue

        for line in content.split("\n"):
            for resource, threshold in thresholds.items():
                if resource in line and "%" in line:
                    # 提取百分比数值
                    import re
                    m = re.search(r'(\d+\.?\d*)\s*%', line)
                    if m:
                        pct = float(m.group(1)) / 100.0
                        if pct > threshold:
                            warnings.append(
                                f"{f.stem}: {resource} = {pct*100:.1f}% exceeds "
                                f"{threshold*100:.0f}% threshold. "
                                f"Consider architectural review — may need Block Design, "
                                f"ILA, or device port reduction instead of external IOB."
                            )
    return warnings


def validate_manifest():
    """校验 workspace_manifest.json"""
    errors = []
    schema = load_json_schema(".awp/schemas/workspace_manifest.schema.json")
    if schema is None:
        errors.append("Cannot load workspace_manifest.schema.json")
        return errors

    data_path = ROOT / ".awp" / "workspace_manifest.json"
    if not data_path.exists():
        errors.append(".awp/workspace_manifest.json not found")
        return errors

    try:
        with open(data_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        errors.append(f".awp/workspace_manifest.json: invalid JSON: {e}")
        return errors

    errors.extend(validate_schema_required(data, schema, ".awp/workspace_manifest.json"))
    return errors


def collect_tasks():
    """收集所有任务的 (task_id, status, agent, title, validation_status, target_level)"""
    tasks = []
    tasks_dir = ROOT / ".awp" / "tasks"
    if not tasks_dir.exists():
        return tasks
    for yaml_file in sorted(tasks_dir.glob("*.yaml")):
        if yaml_file.name == ".gitkeep":
            continue
        data, _ = load_yaml_file(str(yaml_file.relative_to(ROOT)))
        if data:
            tasks.append(data)
    return tasks


def cmd_validate():
    """执行完整校验"""
    all_errors = []
    all_errors.extend(validate_manifest())
    all_errors.extend(validate_task_files())
    all_errors.extend(validate_review_files())
    all_errors.extend(validate_cross_references())
    all_errors.extend(validate_review_coverage())
    all_errors.extend(validate_output_files())
    all_errors.extend(validate_skip_usage())
    all_errors.extend(validate_fail_status())
    all_errors.extend(validate_issue_files())
    all_errors.extend(validate_integration_scope())
    # NOTE: validate_dependency_ripple() temporarily disabled — the logic
    # produces false positives when only one module in a dependency chain
    # regresses while other modules remain verified. Needs refinement
    # to only flag regressions along the specific module's verification path.
    # all_errors.extend(validate_dependency_ripple())
    all_errors.extend(validate_registry_consistency())
    all_errors.extend(validate_issue_coverage())
    all_errors.extend(validate_port_connectivity())
    all_errors.extend(validate_resource_thresholds())

    if all_errors:
        print(f"\n[FAIL] {len(all_errors)} validation error(s):\n")
        for e in all_errors:
            print(f"  - {e}")
        print()
        return 1
    else:
        print("[PASS] All validations passed.\n")
        return 0


def sync_registry():
    """从实际文件自动生成 id_registry.yaml 和 relations.yaml"""
    entities = {}   # id -> {id, type, title, status, created}
    rels = []       # [{from, to, type}]

    # --- 1. Tasks ---
    for t in collect_tasks():
        tid = t.get("task_id", "")
        if not tid:
            continue
        entities[tid] = {
            "id": tid, "type": "TASK",
            "title": t.get("title", ""),
            "status": "active" if t.get("status") != "done" else "closed",
            "created": t.get("created_date", ""),
        }
        for dep in t.get("depends_on", []) or []:
            rels.append({"from": tid, "to": dep, "type": "depends_on"})

    # --- 2. Reviews ---
    reviews_dir = ROOT / ".awp" / "reviews"
    if reviews_dir.exists():
        for f in sorted(reviews_dir.glob("REV-*.md")):
            rid = f.stem
            try:
                content = _read_file_robust(f)
            except Exception:
                continue
            fm = extract_frontmatter(content)
            task_ref = fm.get("task_id", "") if fm else ""
            review_type = rid.split("-")[3] if len(rid.split("-")) >= 4 else ""
            entities[rid] = {
                "id": rid, "type": "REVIEW",
                "title": f"Review of {task_ref} ({review_type})" if task_ref else f"Review {rid}",
                "status": "closed" if fm and fm.get("result") in ("pass", "pass_with_notes") else "active",
                "created": fm.get("date", "") if fm else "",
            }
            if task_ref:
                rels.append({"from": rid, "to": task_ref, "type": "reviews"})

    # --- 3. Runs ---
    runs_dir = ROOT / ".awp" / "runs"
    if runs_dir.exists():
        for f in sorted(runs_dir.glob("RUN-*.md")):
            rid = f.stem
            try:
                content = _read_file_robust(f)
            except Exception:
                continue
            task_ref = ""
            date_str = ""
            title_str = ""
            for line in content.split("\n"):
                if line.startswith("- **Task**:"):
                    task_ref = line.split(":")[-1].strip().strip("`")
                elif line.startswith("- **Date**:"):
                    date_str = line.split(":")[-1].strip()
                elif line.startswith("# ") and not title_str:
                    title_str = line[2:].strip()
            entities[rid] = {
                "id": rid, "type": "RUN",
                "title": title_str or rid,
                "status": "active",
                "created": date_str,
            }
            if task_ref:
                rels.append({"from": rid, "to": task_ref, "type": "runs_for"})

    # --- 4. Sessions ---
    sessions_dir = ROOT / ".awp" / "sessions"
    if sessions_dir.exists():
        for f in sorted(sessions_dir.glob("SESS-*.md")):
            sid = f.stem
            try:
                content = _read_file_robust(f)
            except Exception:
                continue
            first_line = ""
            for line in content.split("\n"):
                if line.startswith("# ") and not first_line:
                    first_line = line[2:].strip()
                    break
            entities[sid] = {
                "id": sid, "type": "SESSION",
                "title": first_line or sid,
                "status": "closed",
                "created": _extract_file_date(f),
            }

    # --- 5. Handoffs ---
    handoff_dir = ROOT / ".awp" / "handoffs"
    if handoff_dir.exists():
        for f in sorted(handoff_dir.glob("HO-*.md")):
            hid = f.stem
            try:
                content = _read_file_robust(f)
            except Exception:
                continue
            fm = extract_frontmatter(content)
            h_id = fm.get("handoff_id", hid) if fm else hid
            from_sess = fm.get("from_session", "") if fm else ""
            entities[h_id] = {
                "id": h_id, "type": "HANDOFF",
                "title": f"Handoff {h_id}",
                "status": fm.get("status", "active") if fm else "active",
                "created": fm.get("date", "") if fm else _extract_file_date(f),
            }
            if from_sess:
                rels.append({"from": h_id, "to": from_sess, "type": "from_session"})

    # --- 6. EXP ---
    exps_seen = set()
    for eid, einfo in list(entities.items()):
        # 从 ID 中提取 EXP 部分：如 TASK-E001-001 → E001
        parts = eid.split("-")
        if len(parts) >= 2 and parts[1].startswith(("E", "EXP")):
            exp_part = parts[1]
            if exp_part.startswith("EXP"):
                exp_part = exp_part  # already has prefix
            exp_id = f"EXP{exp_part.lstrip('E')}" if not exp_part.startswith("EXP") else exp_part
            if exp_id not in exps_seen:
                exps_seen.add(exp_id)
                entities[exp_id] = {
                    "id": exp_id, "type": "EXP",
                    "title": f"Experiment {exp_part}",
                    "status": "active",
                    "created": "",
                }
            rels.append({"from": eid, "to": exp_id, "type": "belongs_to"})

    # --- 7. Issues ---
    issues_dir = ROOT / ".awp" / "issues"
    if issues_dir.exists():
        for f in sorted(issues_dir.glob("ISS-*.yaml")):
            iid = f.stem
            data, _ = load_yaml_file(str(f.relative_to(ROOT)))
            if not data:
                continue
            entities[iid] = {
                "id": iid, "type": "ISSUE",
                "title": data.get("title", iid),
                "status": data.get("status", "open"),
                "created": data.get("detected_by_session", "")[:10] if data.get("detected_by_session") else "",
            }
            # issue → run
            run_ref = data.get("detected_in_run", "")
            if run_ref:
                rels.append({"from": iid, "to": run_ref, "type": "detected_in"})
            # issue → suspected owner task
            owner_task = data.get("suspected_owner_task", "")
            if owner_task:
                rels.append({"from": iid, "to": owner_task, "type": "assigned_to"})
            # issue → detecting task
            det_task = data.get("detected_by_task", "")
            if det_task:
                rels.append({"from": iid, "to": det_task, "type": "detected_by"})

    # --- 8. Write files ---
    header = "# AUTO-GENERATED by validate_awp.py --sync. Do not edit manually.\n"
    id_list = sorted(entities.values(), key=lambda x: (x["type"], x["id"]))
    reg_content = header + yaml.dump({"ids": id_list}, default_flow_style=False, allow_unicode=True, sort_keys=False)
    (ROOT / ".awp" / "registry" / "id_registry.yaml").write_text(reg_content, encoding="utf-8")

    rels_sorted = sorted(rels, key=lambda x: (x["from"], x["to"]))
    rel_content = header + yaml.dump({"relations": rels_sorted}, default_flow_style=False, allow_unicode=True, sort_keys=False)
    (ROOT / ".awp" / "registry" / "relations.yaml").write_text(rel_content, encoding="utf-8")

    return len(entities), len(rels)


def _read_file_robust(filepath):
    """读取文件，尝试 utf-8 后 fallback 到 gbk（Windows 中文环境）"""
    try:
        return filepath.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return filepath.read_text(encoding="gbk", errors="replace")


def _extract_file_date(f):
    """从文件 mtime 提取日期字符串"""
    try:
        from datetime import date
        return date.fromtimestamp(f.stat().st_mtime).isoformat()
    except Exception:
        return ""


def validate_registry_consistency():
    """检查 registry 与实际文件的一致性"""
    errors = []
    reg_file = ROOT / ".awp" / "registry" / "id_registry.yaml"
    if not reg_file.exists():
        return errors  # 首次运行，registry 尚未生成

    reg_data, err = load_yaml_file(".awp/registry/id_registry.yaml")
    if err or not reg_data:
        errors.append("Cannot load id_registry.yaml")
        return errors

    reg_ids = {}
    for entry in reg_data.get("ids", []) or []:
        eid = entry.get("id", "")
        if eid:
            reg_ids[eid] = entry

    # 收集实际文件中的实体 ID
    actual_ids = set()

    # Tasks
    for t in collect_tasks():
        tid = t.get("task_id", "")
        if tid:
            actual_ids.add(tid)

    # Reviews
    reviews_dir = ROOT / ".awp" / "reviews"
    if reviews_dir.exists():
        for f in reviews_dir.glob("REV-*.md"):
            actual_ids.add(f.stem)

    # Runs
    runs_dir = ROOT / ".awp" / "runs"
    if runs_dir.exists():
        for f in runs_dir.glob("RUN-*.md"):
            actual_ids.add(f.stem)

    # Sessions
    sessions_dir = ROOT / ".awp" / "sessions"
    if sessions_dir.exists():
        for f in sessions_dir.glob("SESS-*.md"):
            actual_ids.add(f.stem)

    # Handoffs
    handoff_dir = ROOT / ".awp" / "handoffs"
    if handoff_dir.exists():
        for f in handoff_dir.glob("HO-*.md"):
            actual_ids.add(f.stem)

    # Issues
    issues_dir = ROOT / ".awp" / "issues"
    if issues_dir.exists():
        for f in issues_dir.glob("ISS-*.yaml"):
            actual_ids.add(f.stem)

    # EXP (derived)
    for eid in list(actual_ids):
        parts = eid.split("-")
        if len(parts) >= 2 and parts[1].startswith(("E", "EXP")):
            exp_id = "EXP" + parts[1].lstrip("E")
            actual_ids.add(exp_id)

    # 检查缺失实体
    missing = actual_ids - set(reg_ids.keys())
    if missing:
        errors.append(
            f"Registry missing {len(missing)} entity(s): "
            f"{', '.join(sorted(list(missing))[:5])}{'...' if len(missing) > 5 else ''}. "
            f"Run --sync to auto-register."
        )

    # 检查幽灵实体
    orphan = set(reg_ids.keys()) - actual_ids
    if orphan:
        errors.append(
            f"Registry has {len(orphan)} orphan entity(s): "
            f"{', '.join(sorted(list(orphan))[:5])}{'...' if len(orphan) > 5 else ''}. "
            f"Run --sync to clean up."
        )

    return errors


def cmd_sync():
    """自动修复可检测的状态不一致（--sync）"""
    tasks = collect_tasks()
    fixes = []
    tasks_dir = ROOT / ".awp" / "tasks"

    # 1. Task 有 GATE GAP 但 status 不是 blocked → 自动设 blocked
    for t in tasks:
        tid = t.get("task_id", "")
        vs = t.get("validation_status", {})
        status = t.get("status", "")
        target = t.get("target_validation_level", "")

        if status not in ("in_progress", "review"):
            continue
        if not target or target not in VALID_L_LEVELS:
            continue

        target_idx = VALID_L_LEVELS.index(target)
        has_gap = False
        for i in range(target_idx):
            level = VALID_L_LEVELS[i]
            lvl_status = vs.get(level, "pending")
            if lvl_status not in ("pass", "skip"):
                has_gap = True
                break

        if has_gap:
            # 修改 YAML 文件
            yaml_path = tasks_dir / f"{tid}.yaml"
            if yaml_path.exists():
                try:
                    content = yaml_path.read_text(encoding="utf-8")
                    new_content = content.replace(f"status: \"{status}\"", "status: \"blocked\"")
                    if new_content != content:
                        yaml_path.write_text(new_content, encoding="utf-8")
                        fixes.append(f"{tid}: status {status} -> blocked (GATE GAP detected)")
                except Exception as e:
                    fixes.append(f"{tid}: FAILED to fix ({e})")

    # 2. 模块级 task：若 done 但 L1b/L1c 仍 pending → 回退到 review
    #    done 意味着"模块已完成"，但 L1b/L1c 未跑时模块在集成中的正确性未确认
    for t in tasks:
        tid = t.get("task_id", "")
        agent = t.get("agent", "")
        scope = t.get("integration_scope", "module")
        status = t.get("status", "")
        vs = t.get("validation_status", {})
        if agent not in ("rtl_implementer",):
            continue
        if scope != "module":
            continue
        if status != "done":
            continue
        if vs.get("L1b") == "pending" or vs.get("L1c") == "pending":
            yaml_path = tasks_dir / f"{tid}.yaml"
            if yaml_path.exists():
                content = yaml_path.read_text(encoding="utf-8")
                new_content = content.replace('status: "done"', 'status: "review"')
                if new_content != content:
                    yaml_path.write_text(new_content, encoding="utf-8")
                    fixes.append(
                        f"{tid}: status done -> review (L1b/L1c pending, "
                        f"module not yet confirmed in integration)"
                    )

    # 3. 修复无效的 skip：rtl_implementer 模块级 task 的 L1b/L1c skip → pending
    for t in tasks:
        tid = t.get("task_id", "")
        agent = t.get("agent", "")
        scope = t.get("integration_scope", "module")
        vs = t.get("validation_status", {})
        if agent not in ("rtl_implementer",):
            continue
        if scope != "module":
            continue
        yaml_path = tasks_dir / f"{tid}.yaml"
        if not yaml_path.exists():
            continue
        content = yaml_path.read_text(encoding="utf-8")
        modified = False
        for level in ["L1b", "L1c"]:
            if vs.get(level) == "skip":
                # 精确替换 YAML 中的 "skip"
                new_content = content.replace(f"{level}: \"skip\"", f"{level}: \"pending\"")
                if new_content != content:
                    content = new_content
                    modified = True
        if modified:
            yaml_path.write_text(content, encoding="utf-8")
            fixes.append(f"{tid}: L1b/L1c skip -> pending (module tasks must not skip integration levels)")

    # 4. 同步 registry
    n_entities, n_rels = sync_registry()
    fixes.append(f"Registry synced: {n_entities} entities, {n_rels} relations")

    # 5. 重生 task board
    if fixes or True:
        board_ok = cmd_gen_task_board() == 0
        if board_ok:
            fixes.append("task_board.md regenerated")

    # 3. 报告 skeleton 文件
    sessions_dir = ROOT / ".awp" / "sessions"
    skeletons = list(sessions_dir.glob("SKELETON-*.md"))
    if skeletons:
        fixes.append(f"Note: {len(skeletons)} uncompleted skeleton(s) in .awp/sessions/")

    if fixes:
        print("\n[AWP-SYNC] Fixes applied:")
        for f in fixes:
            print(f"  - {f}")
        print()
    else:
        print("[AWP-SYNC] No inconsistencies detected.\n")

    return 0


def cmd_summary():
    """输出项目仪表盘（人类可读的全局视图）"""
    return cmd_dashboard()


def cmd_dashboard():
    """FPGA-AWP 项目全局仪表盘"""
    tasks = collect_tasks()
    today = date.today().isoformat()

    # === 项目信息 ===
    manifest_path = ROOT / ".awp" / "workspace_manifest.json"
    project_name = "未知项目"
    if manifest_path.exists():
        try:
            with open(manifest_path, "r", encoding="utf-8") as f:
                manifest = json.load(f)
            project_name = manifest.get("project", {}).get("name", project_name)
        except Exception:
            pass

    # EXP 信息
    registry_path = ROOT / ".awp" / "registry" / "id_registry.yaml"
    exp_info = ""
    if registry_path.exists():
        registry_data, _ = load_yaml_file(".awp/registry/id_registry.yaml")
        if registry_data:
            for entry in registry_data.get("ids", []):
                if entry.get("type") == "EXP":
                    exp_info = f"{entry['id']} - {entry.get('title', '')}"
                    break

    # Project charter
    charter_path = ROOT / "project_charter.md"
    charter_exists = charter_path.exists()

    print()
    print("=" * 70)
    print(f"  FPGA-AWP 项目仪表盘")
    print(f"  项目: {project_name}")
    if exp_info:
        print(f"  实验: {exp_info}")
    print(f"  时间: {today}")
    if charter_exists:
        print(f"  章程: project_charter.md ✓")
    else:
        print(f"  章程: 尚未创建（建议创建 project_charter.md）")
    print("=" * 70)

    # === 任务进度 ===
    print(f"\n  [任务进度]")
    if not tasks:
        print("  (暂无任务)")
    else:
        print(f"  {'Task ID':<20} {'Status':<12} {'Agent':<22} {'Target':<8} Validation")
        print(f"  {'-'*18} {'-'*10} {'-'*20} {'-'*6} {'-'*20}")
        for t in tasks:
            tid = t.get("task_id", "?")
            st = t.get("status", "?")
            agent = t.get("agent", "?")
            tv = t.get("target_validation_level", "?")
            vs = t.get("validation_status", {})
            # 验证进度条
            val_parts = []
            for level in VALID_L_LEVELS:
                status = vs.get(level, "pending")
                if status == "pass":
                    val_parts.append(f"{level}P")
                elif status == "fail":
                    val_parts.append(f"{level}F")
                elif status == "skip":
                    val_parts.append(f"{level}S")
                else:
                    val_parts.append(f"{level}.")
            val_str = " ".join(val_parts)
            print(f"  {tid:<20} {st:<12} {agent:<22} {tv:<8} {val_str}")

        # 统计
        counts = defaultdict(int)
        for t in tasks:
            counts[t.get("status", "?")] += 1
        stats_parts = [f"{v} {k}" for k, v in sorted(counts.items())]
        print(f"\n  统计: {len(tasks)} total | {' | '.join(stats_parts)}")

        # 下一步
        next_tasks = [t for t in tasks if t.get("status") in ("ready", "in_progress", "blocked")]
        if next_tasks:
            print(f"\n  [下一步]")
            for t in next_tasks:
                st = t.get("status", "?")
                icon = {"ready": "→", "in_progress": "⟳", "blocked": "⊘"}.get(st, "·")
                print(f"  {icon} {t.get('task_id', '?')} [{st}] {t.get('title', '?')}")
        else:
            done_count = len([t for t in tasks if t.get("status") == "done"])
            if done_count > 0:
                print(f"\n  [下一步]")
                print(f"  所有 {done_count} 个 task 已完成。建议运行复盘：spawn process_owner 编写 retrospective。")

    # === 最近 Session ===
    sessions_dir = ROOT / ".awp" / "sessions"
    session_files = []
    if sessions_dir.exists():
        for f in sorted(sessions_dir.glob("SESS-*.md"), reverse=True):
            if f.name.startswith("SESS-"):
                session_files.append(f)

    if session_files:
        print(f"\n  [最近 Session]")
        for sf in session_files[:5]:
            try:
                mtime = date.fromtimestamp(sf.stat().st_mtime).isoformat()
            except Exception:
                mtime = "?"
            # 提取第一行标题
            try:
                with open(sf, "r", encoding="utf-8") as f:
                    first_line = f.readline().strip().lstrip("#").strip()
            except Exception:
                first_line = sf.stem
            print(f"  {sf.stem:<25} {mtime}  {first_line}")
    else:
        print(f"\n  [最近 Session]")
        print(f"  (暂无)")

    # === 待解决问题 ===
    runs_dir = ROOT / ".awp" / "runs"
    issue_files = []
    if runs_dir.exists():
        for f in sorted(runs_dir.glob("ISS-*.md")):
            issue_files.append(f)

    if issue_files:
        print(f"\n  [待解决问题]")
        for iss in issue_files:
            print(f"  ⚠ {iss.stem}  {iss.name}")
    else:
        print(f"\n  [待解决问题]")
        print(f"  (无)")

    # === Git ===
    print(f"\n  [最近提交]")
    try:
        import subprocess
        result = subprocess.run(
            ["git", "log", "--oneline", "-5"],
            capture_output=True, text=True, cwd=ROOT, timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            for line in result.stdout.strip().split("\n"):
                print(f"  {line}")
        else:
            print(f"  (无法获取)")
    except Exception:
        print(f"  (无法获取)")

    # === 快速入口 ===
    print(f"\n  [快速入口]")
    print(f"  创建任务:     /task-bootstrap")
    print(f"  关闭 session: /session-close")
    print(f"  运行校验:     make validate-awp")
    print(f"  查看此面板:   make status")
    print()
    return 0


def cmd_gate_check():
    """验证门禁检查"""
    tasks = collect_tasks()
    issues = []

    # 内部递进检查：同一 task 内 level 之间不能有 skip
    for t in tasks:
        tid = t.get("task_id", "?")
        vs = t.get("validation_status", {})
        prev_pass = True
        for level in VALID_L_LEVELS:
            status = vs.get(level, "pending")
            if status == "pass" and not prev_pass:
                issues.append(f"{tid}: {level}=pass but previous level not passed (GATE VIOLATION)")
            if status != "pass" and status != "skip":
                prev_pass = False

    # target-gap 检查：target 以下不能有 pending（覆盖 in_progress/blocked/review/done）
    issues.extend(_collect_target_gaps(tasks, only_active=False))

    if issues:
        print(f"\n[GATE ISSUES] {len(issues)} gate issue(s):\n")
        for i in issues:
            print(f"  - {i}")
        print()
        return 1
    else:
        print("[GATE] All gates passed.\n")
        return 0


def cmd_gen_task_board():
    """根据 .awp/tasks/*.yaml 自动生成 task_board.md"""
    tasks = collect_tasks()
    board_path = ROOT / ".awp" / "task_board.md"

    buckets = {
        "Backlog": [],
        "Ready": [],
        "In Progress": [],
        "Blocked": [],
        "Review": [],
        "Done": [],
        "Retrospective Items": [],
    }

    status_map = {
        "ready": "Ready",
        "in_progress": "In Progress",
        "blocked": "Blocked",
        "review": "Review",
        "done": "Done",
    }

    for t in tasks:
        tid = t.get("task_id", "?")
        title = t.get("title", "?")
        agent = t.get("agent", "?")
        bucket = status_map.get(t.get("status", ""), "Backlog")
        task_file = f".awp/tasks/{tid}.yaml"
        buckets[bucket].append(f"[{tid}]({task_file}) | {agent} | {title}")

    lines = [
        "# 任务看板",
        "",
        "<!-- AUTO-GENERATED by make task-board. Do not edit manually. -->",
        "<!-- Last generated: {} -->".format(date.today().isoformat()),
        "",
    ]

    for section, items in buckets.items():
        lines.append(f"## {section}")
        lines.append("")
        if items:
            for item in items:
                lines.append(f"- [ ] {item}")
        else:
            lines.append("- [ ] *（暂无）*")
        lines.append("")

    try:
        with open(board_path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
        print(f"[OK] task_board.md generated with {len(tasks)} task(s).")
    except Exception as e:
        print(f"[ERROR] Failed to write task_board.md: {e}")
        return 1
    return 0


def cmd_guard_session_start():
    """SessionStart guard: gate-check + handoff Gate Status 校验（提醒级，永远 exit 0）"""
    print("\n" + "=" * 60)
    print("  [AWP-GUARD] Session Start -- Gate & Handoff Audit")
    print("=" * 60)

    # 1. Handoff 检测
    handoff_dir = ROOT / ".awp" / "handoffs"
    if handoff_dir.exists():
        handoffs = sorted(handoff_dir.glob("HO-*.md"))
        if handoffs:
            latest = handoffs[-1]
            print(f"\n  Handoff: {latest.name}")
            try:
                content = latest.read_text(encoding="utf-8")
                if "## Gate Status" not in content:
                    print("  [!] WARNING: Handoff missing Gate Status section!")
                    print("      Previous session handoff may be unreliable, trust task YAML.")
                else:
                    print("  [OK] Handoff Gate Status present")
            except Exception:
                pass
        else:
            print("\n  (no handoff files)")

    # 2. Gate check
    print()
    tasks = collect_tasks()
    gaps = _collect_target_gaps(tasks)
    if gaps:
        print(f"  [!] GATE GAP: {len(gaps)} gap(s) detected")
        for g in gaps:
            print(f"      - {g}")
        print("\n  Action: create prerequisite verification task(s) before spawning sub-agents.")
    else:
        print("  [OK] No gate gaps")

    # 3. Session 骨架提醒
    sessions_dir = ROOT / ".awp" / "sessions"
    skeletons = list(sessions_dir.glob("SKELETON-*.md"))
    if skeletons:
        print(f"\n  [!] {len(skeletons)} uncompleted session skeleton file(s).")

    print("=" * 60 + "\n")
    return 0  # 提醒级，永远不阻断 session 启动


def cmd_guard_pre_spawn():
    """PreToolUse(Agent) guard: 选择性阻断越级 spawn（v0.2）。
    读取 STDIN JSON 获取目标 agent 类型，L1b GAP 时：
    - 阻断 integration_verifier(L1c)/vivado/hardware → 越级推进
    - 允许 module_owner/planner/rtl_reviewer/process_owner → 修复/建 task/审查
    """
    # 尝试读取 hook 传递的 tool call JSON 获取 agent 类型
    target_agent = None
    if not sys.stdin.isatty():  # 仅在 hook 调用时读取 stdin
        try:
            hook_input = sys.stdin.read()
            if hook_input.strip():
                data = json.loads(hook_input)
                target_agent = data.get("subagent_type", data.get("agent", None))
        except (json.JSONDecodeError, Exception):
            pass

    gaps = _collect_target_gaps(collect_tasks(), only_active=True)
    if not gaps:
        return 0

    # L1b GAP 存在 → 判断是否应该阻断
    if target_agent and target_agent in GAP_SAFE_AGENTS:
        # 允许：修复、建 task、审查、流程修补
        return 0

    # 迭代刹车：检查 ISS issue 是否超过资源 + 轮次阈值
    issues_dir = ROOT / ".awp" / "issues"
    if issues_dir.exists():
        for f in sorted(issues_dir.glob("ISS-*.yaml")):
            data, _ = load_yaml_file(str(f.relative_to(ROOT)))
            if not data:
                continue
            rc = data.get("round_count", 0)
            mr = data.get("max_rounds", 3)
            if rc >= mr and data.get("status") not in ("resolved", "closed"):
                # 检查是否有资源警告
                thresholds = validate_resource_thresholds()
                if thresholds:
                    print("\n" + "=" * 60)
                    print("  [AWP-GUARD] Pre-Spawn BLOCKED -- Iteration Brake")
                    print("=" * 60)
                    print(f"  {f.stem}: round={rc} >= max_rounds={mr}")
                    print(f"  Resource warnings present:")
                    for t in thresholds[:3]:
                        print(f"    [!] {t}")
                    print(f"\n  Direction may be wrong -- escalate to human_owner.")
                    print("=" * 60 + "\n")
                    return 1

    # 无法判断 agent 类型（手动调用）或有 GAP 且非安全 agent → 阻断
    print("\n" + "=" * 60)
    print("  [AWP-GUARD] Pre-Spawn BLOCKED -- Gate Gap Detected")
    print("=" * 60)
    for g in gaps:
        print(f"  [X] {g}")
    if target_agent:
        print(f"\n  Agent '{target_agent}' blocked: resolve L1b GAP first.")
    print("\n  Allowed agents during GAP: planner, module_owner, rtl_reviewer, process_owner")
    print("=" * 60 + "\n")
    return 1


def cmd_guard_pre_stop():
    """Stop guard: handoff 完整性 + session 记录检查（提醒级，永远 exit 0）"""
    issues = []

    # 1. 活跃 task → 检查 handoff
    tasks = collect_tasks()
    active = [t for t in tasks if t.get("status") in ("in_progress", "blocked", "review")]
    if active:
        handoff_dir = ROOT / ".awp" / "handoffs"
        handoffs = sorted(handoff_dir.glob("HO-*.md")) if handoff_dir.exists() else []

        if not handoffs:
            issues.append("Active tasks present but no handoff file -- create handoff")
        else:
            latest = handoffs[-1]
            try:
                content = latest.read_text(encoding="utf-8")
                if "## Gate Status" not in content:
                    issues.append(f"Handoff {latest.name} missing Gate Status section")
            except Exception:
                issues.append(f"Cannot read handoff {latest.name}")

    # 2. Session 骨架检查
    sessions_dir = ROOT / ".awp" / "sessions"
    skeletons = list(sessions_dir.glob("SKELETON-*.md"))
    if skeletons:
        issues.append(f"{len(skeletons)} uncompleted session skeleton(s)")

    # 3. Gate gap 快照
    gaps = _collect_target_gaps(tasks)
    if gaps:
        issues.append(f"{len(gaps)} unresolved gate gap(s)")

    if issues:
        print("\n" + "=" * 60)
        print("  [AWP-GUARD] Pre-Stop -- Reminders Before Session End")
        print("=" * 60)
        for i in issues:
            print(f"  [!] {i}")
        print("=" * 60 + "\n")

    # 提醒级，永远不阻断 session 结束
    return 0


def _collect_target_gaps(tasks, only_active=False):
    """收集 task 的 target-gap，返回字符串列表。
    only_active=True 时仅检查 in_progress/review（用于 pre-spawn 阻断）。
    """
    gaps = []
    for t in tasks:
        tid = t.get("task_id", "?")
        vs = t.get("validation_status", {})
        status = t.get("status", "?")
        target = t.get("target_validation_level", "")

        if only_active:
            if status not in ("in_progress", "review"):
                continue
        else:
            if status not in ("in_progress", "blocked", "review", "done"):
                continue

        if target and target in VALID_L_LEVELS:
            target_idx = VALID_L_LEVELS.index(target)
            for i in range(target_idx):
                level = VALID_L_LEVELS[i]
                lvl_status = vs.get(level, "pending")
                if lvl_status not in ("pass", "skip"):
                    gaps.append(f"{tid}: targets {target} but {level}={lvl_status}")
    return gaps


def main():
    parser = argparse.ArgumentParser(description="FPGA-AWP Workspace Validator")
    parser.add_argument("--summary", action="store_true", help="Print project dashboard (alias for --dashboard)")
    parser.add_argument("--dashboard", action="store_true", help="Print human-readable project dashboard")
    parser.add_argument("--gate-check", action="store_true", help="Check L0-L7 gate progression")
    parser.add_argument("--gen-task-board", action="store_true", help="Generate task_board.md from YAML files")
    parser.add_argument("--sync", action="store_true", help="Auto-fix detectable state inconsistencies")
    parser.add_argument("--guard", choices=["session-start", "pre-spawn", "pre-stop"],
                        help="AWP guard: trigger-point automation for hooks")
    args = parser.parse_args()

    # 切换到项目根目录
    os.chdir(ROOT)

    if args.guard == "session-start":
        return cmd_guard_session_start()
    elif args.guard == "pre-spawn":
        return cmd_guard_pre_spawn()
    elif args.guard == "pre-stop":
        return cmd_guard_pre_stop()
    elif args.sync:
        return cmd_sync()
    elif args.dashboard or args.summary:
        return cmd_dashboard()
    elif args.gate_check:
        return cmd_gate_check()
    elif args.gen_task_board:
        return cmd_gen_task_board()
    else:
        return cmd_validate()


if __name__ == "__main__":
    sys.exit(main())
