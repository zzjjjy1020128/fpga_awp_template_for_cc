#!/usr/bin/env python3
"""安装 pre-commit hook —— 在 .git/hooks/pre-commit 中设置自动 validate-awp"""
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HOOK_SRC = ROOT / "scripts" / "pre-commit"
HOOK_DST = ROOT / ".git" / "hooks" / "pre-commit"

try:
    shutil.copy2(HOOK_SRC, HOOK_DST)
    # Unix 下需要可执行权限
    if hasattr(HOOK_DST, "chmod"):
        HOOK_DST.chmod(0o755)
    print(f"[OK] Pre-commit hook installed: {HOOK_DST}")
    print("     Commit 前将自动运行 --sync + validate-awp")
except Exception as e:
    print(f"[ERROR] Failed to install pre-commit hook: {e}", file=sys.stderr)
    sys.exit(1)
