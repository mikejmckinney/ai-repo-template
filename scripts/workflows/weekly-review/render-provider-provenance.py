#!/usr/bin/env python3
"""Render and merge weekly review provider/model provenance."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


HEADING = "**Review provenance**"


def render_line(data: dict) -> str:
    provenance = data.get("provenance") or {}
    provider = str(provenance.get("provider") or "unknown")
    requested = str(provenance.get("requested_model") or "unknown")
    observed = str(provenance.get("observed_model") or "unknown")
    attempts = data.get("provider_attempts") or []
    attempt_text = ", ".join(
        f"{item.get('provider', 'unknown')}:{item.get('status', 'unknown')}"
        for item in attempts
        if isinstance(item, dict)
    ) or "none"
    run_date = str(data.get("run_date") or "unknown")
    return (
        f"- {run_date} — provider: {provider}; requested: {requested}; "
        f"observed: {observed}; attempts: {attempt_text}"
    )


def render_block(data: dict) -> str:
    return f"{HEADING}\n\n{render_line(data)}\n"


def merge_into_body(body: str, data: dict) -> str:
    line = render_line(data)
    run_date = str(data.get("run_date") or "unknown")
    line_prefix = f"- {run_date} —"
    if HEADING in body:
        before, after = body.split(HEADING, 1)
        lines = after.lstrip("\n").splitlines()
        if any(existing.startswith(line_prefix) for existing in lines):
            replaced = False
            merged_lines = []
            for existing in lines:
                if existing.startswith(line_prefix):
                    if not replaced:
                        merged_lines.append(line)
                        replaced = True
                    continue
                merged_lines.append(existing)
            return before + HEADING + "\n\n" + "\n".join(merged_lines)
        insert_at = 0
        while insert_at < len(lines) and lines[insert_at].startswith("-"):
            insert_at += 1
        lines.insert(insert_at, line)
        return before + HEADING + "\n\n" + "\n".join(lines)
    if "## Meta" in body:
        before, after = body.split("## Meta", 1)
        return before.rstrip() + "\n\n## Meta\n\n" + render_block(data) + "\n" + after.lstrip()
    return body.rstrip() + "\n\n## Meta\n\n" + render_block(data)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("weekly_json", type=Path)
    parser.add_argument("--merge", type=Path)
    args = parser.parse_args()
    data = json.loads(args.weekly_json.read_text(encoding="utf-8"))
    if args.merge:
        body = args.merge.read_text(encoding="utf-8")
        print(merge_into_body(body, data), end="")
    else:
        print(render_block(data), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
