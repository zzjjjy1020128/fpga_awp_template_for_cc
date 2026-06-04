#!/usr/bin/env python3
"""
Session skeleton generator —— 由 SessionStart hook 调用，创建 session 记录骨架。
读取 stdin JSON，提取 session_id，在 .awp/sessions/ 下创建骨架文件。
"""
import json
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SESSIONS_DIR = ROOT / ".awp" / "sessions"


def main():
    try:
        data = json.loads(sys.stdin.read())
    except json.JSONDecodeError:
        print("[session_skeleton] WARNING: Could not parse hook input", file=sys.stderr)
        return 0

    session_id = data.get("session_id", "unknown")
    today = date.today().isoformat()
    skeleton_name = f"SKELETON-{today}-{session_id[:8]}.md"
    skeleton_path = SESSIONS_DIR / skeleton_name

    # 如果已存在则跳过
    if skeleton_path.exists():
        return 0

    content = f"""# Session 记录（骨架）

> 自动生成于 {today}，Session ID: `{session_id}`
> **请在 session 进行中边工作边填写，结束前重命名为正式文件名。**

## Session Goal
`<本次 session 的目标，一句话>`

## Assigned Task
- Task ID：`<TASK-E001-001>`
- Agent：`<agent name>`（本 session 中 spawn 的子智能体）

## Files Read
- `<文件路径>`

## Files Modified
- `<文件路径>` —— `<修改原因>`

## Commands Run
```text
<命令>
```

## Key Decisions
- `<决策>`

## Issues Found
- `<问题和影响>`

## Gate Check
- [ ] 目标验证级别：`<L0-L7>`
- [ ] 前一级别已通过确认

## Validation Status
- [ ] L0: 静态审查
- [ ] L1: 仿真
- [ ] `make validate-awp` 通过（退出码 0）

## Open Questions
- `<待解决问题>`

## Handoff
- Next Task：`<下一 session 需继续的 task_id>`
- Handoff File：`<路径>`
- 备注：`<交接注意事项>`
"""

    try:
        SESSIONS_DIR.mkdir(parents=True, exist_ok=True)
        with open(skeleton_path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"[session_skeleton] Created: {skeleton_path}")
    except Exception as e:
        print(f"[session_skeleton] ERROR: {e}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
