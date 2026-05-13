#!/usr/bin/env python3
"""Validate fenced ADR-026 YAML examples in docs/compliance_schemas.md."""

from __future__ import annotations

import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR / "lib"))

from compliance_schema import ComplianceError, load_markdown_yaml_blocks, validate_loaded_block  # noqa: E402


def resolve_input_path(path: Path) -> Path:
    if not path.is_absolute():
        path = REPO_ROOT / path
    return path.resolve()


def source_name(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def main(argv: list[str]) -> int:
    target = resolve_input_path(Path(argv[1])) if len(argv) > 1 else REPO_ROOT / "docs" / "compliance_schemas.md"
    if not target.exists():
        print(f"missing target: {source_name(target)}", file=sys.stderr)
        return 1

    count = 0
    for line, data in load_markdown_yaml_blocks(target):
        validate_loaded_block(data, f"{source_name(target)}:{line}", REPO_ROOT)
        count += 1

    if count == 0:
        print(f"no yaml examples found in {source_name(target)}", file=sys.stderr)
        return 1

    print(f"validated {count} compliance example(s) in {source_name(target)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except ComplianceError as exc:
        print(f"compliance example validation failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
