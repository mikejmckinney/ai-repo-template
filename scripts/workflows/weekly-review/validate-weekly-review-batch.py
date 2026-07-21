#!/usr/bin/env python3
"""Validate weekly review batch JSON."""
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
        print("Usage: validate-weekly-review-batch.py <weekly-review.json>", file=sys.stderr)
        return 2

    data = json.load(open(sys.argv[1], encoding="utf-8"))
    if not isinstance(data, dict):
        print("Root must be object", file=sys.stderr)
        return 1

    run_week = data.get("run_week")
    if not isinstance(run_week, str) or len(run_week) < 8:
        print("run_week must be YYYY-Www", file=sys.stderr)
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
        for key in ("category", "title", "body", "dedupe_key"):
            if key not in item or not str(item[key]).strip():
                print(f"findings[{i}].{key} required", file=sys.stderr)
                return 1
        if item.get("priority_band") is None:
            print(f"findings[{i}].priority_band required", file=sys.stderr)
            return 1
        try:
            validate_triage_item(item, f"findings[{i}]", from_llm=False)
        except ValueError as exc:
            print(str(exc), file=sys.stderr)
            return 1
        if item.get("category") == "follow_up_issues":
            steps = item.get("repro_steps")
            if not isinstance(steps, list) or not steps:
                print(f"findings[{i}].repro_steps required for follow_up_issues", file=sys.stderr)
                return 1
            for j, step in enumerate(steps):
                if not isinstance(step, str) or not str(step).strip():
                    print(f"findings[{i}].repro_steps[{j}] must be non-empty string", file=sys.stderr)
                    return 1
        try:
            validate_evidence_paths(item, f"findings[{i}]")
        except ValueError as exc:
            print(str(exc), file=sys.stderr)
            return 1
        pr_val = item.get("pr", 0)
        if pr_val is None:
            continue
        if not isinstance(pr_val, int) or pr_val < 0:
            print(f"findings[{i}].pr must be a non-negative integer", file=sys.stderr)
            return 1

    umbrella_issue = data.get("umbrella_issue")
    if umbrella_issue is not None:
        if not isinstance(umbrella_issue, int) or umbrella_issue < 1:
            print("umbrella_issue must be a positive integer when present", file=sys.stderr)
            return 1

    print(f"OK: weekly batch valid for {run_week} ({len(findings)} findings)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
