#!/usr/bin/env python3
"""Atomically add weekly triage rows and detail blocks to an umbrella body."""
from __future__ import annotations

import re
import sys
from pathlib import Path

TRIAGE_END = "<!-- weekly-review:triage:end -->"
TRIAGE_SECTION = """## Triage summary

| Category | Key | Impact | Trigger | Cost | Guard | Band | Finding |
|---|---|---|---|---|---|---|---|
<!-- weekly-review:triage:end -->
"""


def _upgrade_layout(body: str) -> str:
    if TRIAGE_END in body:
        return body
    if "## Findings" in body:
        return body.replace(
            "## Findings",
            f"{TRIAGE_SECTION}\n## Finding details",
            1,
        )
    if "## Meta" in body:
        return body.replace("## Meta", f"{TRIAGE_SECTION}\n## Finding details\n\n## Meta", 1)
    return body.rstrip() + f"\n\n{TRIAGE_SECTION}\n## Finding details\n"


def merge_content(body: str, rows: str, blocks: str) -> str:
    merged = _upgrade_layout(body)
    clean_rows = rows.strip()
    clean_blocks = blocks.strip()
    if clean_rows:
        merged = merged.replace(TRIAGE_END, f"{clean_rows}\n{TRIAGE_END}", 1)
    if clean_blocks:
        meta = re.search(r"(?m)^## Meta[ \t]*$", merged)
        if meta:
            head = merged[: meta.start()]
            tail = merged[meta.end() :]
            merged = f"{head.rstrip()}\n\n{clean_blocks}\n\n## Meta{tail}"
        else:
            merged = f"{merged.rstrip()}\n\n{clean_blocks}\n"
    return merged.rstrip() + "\n"


def main() -> int:
    if len(sys.argv) != 5:
        print(
            "Usage: merge-umbrella-content.py <body.md> <rows.md> <blocks.md> <out.md>",
            file=sys.stderr,
        )
        return 2
    body_path, rows_path, blocks_path, output_path = map(Path, sys.argv[1:])
    Path(output_path).write_text(
        merge_content(
            body_path.read_text(encoding="utf-8"),
            rows_path.read_text(encoding="utf-8"),
            blocks_path.read_text(encoding="utf-8"),
        ),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
