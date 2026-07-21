#!/usr/bin/env python3
"""Validate per-run weekly review LLM JSON."""
from __future__ import annotations

import json
import sys
from pathlib import Path

LIB_DIR = Path(__file__).resolve().parents[1] / "lib"
sys.path.insert(0, str(LIB_DIR))

from finding_priority import validate_triage_item  # noqa: E402
from evidence_paths import validate_evidence_paths  # noqa: E402


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate-weekly-review.py <review.json>", file=sys.stderr)
        return 2

    data = json.load(open(sys.argv[1], encoding="utf-8"))
    if not isinstance(data, dict):
        print("Root must be object", file=sys.stderr)
        return 1

    summary = data.get("summary")
    if not isinstance(summary, str):
        print("summary must be a string", file=sys.stderr)
        return 1

    for retired in ("adr_updates", "context_pack_updates"):
        if retired in data:
            print(f"{retired} is retired; use follow_up_issues", file=sys.stderr)
            return 1
    items = data.get("follow_up_issues")
    if not isinstance(items, list):
        print("follow_up_issues must be an array", file=sys.stderr)
        return 1
    for i, item in enumerate(items):
        key = "follow_up_issues"
        if not isinstance(item, dict):
            print(f"{key}[{i}] must be object", file=sys.stderr)
            return 1
        try:
            validate_triage_item(item, f"{key}[{i}]", from_llm=True)
        except ValueError as exc:
            print(str(exc), file=sys.stderr)
            return 1
        for req in ("title", "body", "dedupe_key"):
            if not str(item.get(req, "")).strip():
                print(f"{key}[{i}].{req} required", file=sys.stderr)
                return 1
        steps = item.get("repro_steps")
        if not isinstance(steps, list) or not steps:
            print(f"{key}[{i}].repro_steps required", file=sys.stderr)
            return 1
        for j, step in enumerate(steps):
            if not isinstance(step, str) or not str(step).strip():
                print(f"{key}[{i}].repro_steps[{j}] must be non-empty string", file=sys.stderr)
                return 1
        try:
            validate_evidence_paths(item, f"{key}[{i}]")
        except ValueError as exc:
            print(str(exc), file=sys.stderr)
            return 1

    print(f"OK: weekly review valid ({len(data.get('follow_up_issues') or [])} follow-ups)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
