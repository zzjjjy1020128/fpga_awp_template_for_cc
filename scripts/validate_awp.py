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
    "RUN": re.compile(r"^RUN-[A-Z]\d{3}-[A-Z]+-\d{3}$"),
    "DECISION": re.compile(r"^DEC-[A-Z]+-\d{4}$"),
    "ISSUE": re.compile(r"^ISS-[A-Z]\d{3}-\d{3}$"),
    "ARTIFACT": re.compile(r"^ART-[A-Z]\d{3}-[A-Z]+-\d{3}$"),
}

VALID_TASK_STATUSES = {"ready", "in_progress", "blocked", "review", "done"}
VALID_VAL_STATUSES = {"pending", "pass", "fail", "skip"}
VALID_L_LEVELS = ["L0", "L1", "L2", "L3", "L4", "L5", "L6", "L7"]


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


def check_id_format(id_str):
    """检查 ID 字符串是否符合任一已知 namespace 格式"""
    for ns, pattern in NAMESPACE_PATTERNS.items():
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
            if status != "pass":
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

    if all_errors:
        print(f"\n[FAIL] {len(all_errors)} validation error(s):\n")
        for e in all_errors:
            print(f"  - {e}")
        print()
        return 1
    else:
        print("[PASS] All validations passed.\n")
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
                    val_parts.append(f"{level}✓")
                elif status == "fail":
                    val_parts.append(f"{level}✗")
                elif status == "skip":
                    val_parts.append(f"{level}−")
                else:
                    val_parts.append(f"{level}·")
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
    for t in tasks:
        tid = t.get("task_id", "?")
        vs = t.get("validation_status", {})
        prev_pass = True
        for level in VALID_L_LEVELS:
            status = vs.get(level, "pending")
            if status == "pass" and not prev_pass:
                issues.append(f"{tid}: {level}=pass but previous level not passed (GATE VIOLATION)")
            if status != "pass":
                prev_pass = False

        # 检查是否达到 target level（仅对活跃状态的 task）
        status = t.get("status", "?")
        if status in ("in_progress", "blocked", "review"):
            target = t.get("target_validation_level", "")
            if target and vs.get(target, "pending") != "pass":
                issues.append(f"{tid}: target {target} not yet passed (current: {vs.get(target, 'pending')})")

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


def main():
    parser = argparse.ArgumentParser(description="FPGA-AWP Workspace Validator")
    parser.add_argument("--summary", action="store_true", help="Print project dashboard (alias for --dashboard)")
    parser.add_argument("--dashboard", action="store_true", help="Print human-readable project dashboard")
    parser.add_argument("--gate-check", action="store_true", help="Check L0-L7 gate progression")
    parser.add_argument("--gen-task-board", action="store_true", help="Generate task_board.md from YAML files")
    args = parser.parse_args()

    # 切换到项目根目录
    os.chdir(ROOT)

    if args.dashboard or args.summary:
        return cmd_dashboard()
    elif args.gate_check:
        return cmd_gate_check()
    elif args.gen_task_board:
        return cmd_gen_task_board()
    else:
        return cmd_validate()


if __name__ == "__main__":
    sys.exit(main())
