#!/usr/bin/env python3
"""Validate daily post-merge retro batch JSON."""
from __future__ import annotations

import json
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate-postmerge-retro-daily.py <daily-retro.json>", file=sys.stderr)
        return 2

    data = json.load(open(sys.argv[1], encoding="utf-8"))
    if not isinstance(data, dict):
        print("Root must be object", file=sys.stderr)
        return 1

    run_date = data.get("run_date")
    if not isinstance(run_date, str) or len(run_date) != 10:
        print("run_date must be YYYY-MM-DD", file=sys.stderr)
        return 1

    prs = data.get("prs")
    if not isinstance(prs, list):
        print("prs must be an array", file=sys.stderr)
        return 1

    findings = data.get("findings")
    if not isinstance(findings, list):
        print("findings must be an array", file=sys.stderr)
        return 1

    for i, item in enumerate(findings):
        if not isinstance(item, dict):
            print(f"findings[{i}] must be object", file=sys.stderr)
            return 1
        for key in ("pr", "category", "title", "body", "dedupe_key"):
            if key not in item or not str(item[key]).strip():
                print(f"findings[{i}].{key} required", file=sys.stderr)
                return 1
        for arr_key in ("labels", "evidence"):
            val = item.get(arr_key)
            if val is None:
                continue
            if not isinstance(val, list):
                print(f"findings[{i}].{arr_key} must be an array when present", file=sys.stderr)
                return 1
            for j, entry in enumerate(val):
                if not isinstance(entry, str):
                    print(f"findings[{i}].{arr_key}[{j}] must be a string", file=sys.stderr)
                    return 1

    print(f"OK: daily retro valid for {run_date} ({len(findings)} findings, PRs={prs})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
