#!/usr/bin/env python3
"""Validate per-run weekly review LLM JSON."""
from __future__ import annotations

import json
import sys


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

    for key in ("follow_up_issues", "adr_updates", "context_pack_updates"):
        items = data.get(key)
        if not isinstance(items, list):
            print(f"{key} must be an array", file=sys.stderr)
            return 1
        for i, item in enumerate(items):
            if not isinstance(item, dict):
                print(f"{key}[{i}] must be object", file=sys.stderr)
                return 1
            if key == "follow_up_issues":
                for req in ("title", "body", "dedupe_key"):
                    if not str(item.get(req, "")).strip():
                        print(f"{key}[{i}].{req} required", file=sys.stderr)
                        return 1
            elif key == "adr_updates":
                for req in ("title", "body", "dedupe_key"):
                    if not str(item.get(req, "")).strip():
                        print(f"{key}[{i}].{req} required", file=sys.stderr)
                        return 1
            elif key == "context_pack_updates":
                for req in ("pack", "reason", "dedupe_key"):
                    if not str(item.get(req, "")).strip():
                        print(f"{key}[{i}].{req} required", file=sys.stderr)
                        return 1

    print(f"OK: weekly review valid ({len(data.get('follow_up_issues') or [])} follow-ups)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
