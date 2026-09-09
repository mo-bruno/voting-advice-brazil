from __future__ import annotations

import ast
from pathlib import Path

FORBIDDEN_PREFIXES = (
    "app.infrastructure",
    "fastapi",
    "sqlalchemy",
    "httpx",
    "paho",
    "apscheduler",
)


def test_core_does_not_import_frameworks_or_infrastructure() -> None:
    core_dir = Path(__file__).parents[1] / "app" / "core"
    violations: list[str] = []
    for path in core_dir.rglob("*.py"):
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for node in ast.walk(tree):
            names: list[str] = []
            if isinstance(node, ast.Import):
                names = [alias.name for alias in node.names]
            elif isinstance(node, ast.ImportFrom) and node.module:
                names = [node.module]
            for name in names:
                if name.startswith(FORBIDDEN_PREFIXES):
                    violations.append(f"{path.relative_to(core_dir)} imports {name}")
    assert violations == []
