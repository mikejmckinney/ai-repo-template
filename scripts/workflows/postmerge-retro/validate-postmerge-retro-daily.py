#!/usr/bin/env python3
"""Validate daily post-merge retro batch JSON."""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path


def _load_classifier():
    path = Path(__file__).resolve().parent / "classify-finding-priority.py"
    spec = importlib.util.spec_from_file_location("classify_finding_priority", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load classifier from {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_CL = _load_classifier()
apply_triage_to_item = _CL.apply_triage_to_item
validate_triage_item = _CL.validate_triage_item


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate-postmerge-retro-daily.py <daily-retro.json>", file=sys.stderr)
        return 2

    path = sys.argv[1]
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
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

    try:
        for i, item in enumerate(findings):
            if not isinstance(item, dict):
                raise ValueError(f"findings[{i}] must be object")
            for key in ("pr", "category", "title", "body", "dedupe_key"):
                if key not in item or not str(item[key]).strip():
                    raise ValueError(f"findings[{i}].{key} required")
            if item.get("category") == "follow_up_issues":
                steps = item.get("repro_steps")
                if not isinstance(steps, list) or not steps:
                    raise ValueError(f"findings[{i}].repro_steps required for follow_up_issues")
                for j, step in enumerate(steps):
                    if not isinstance(step, str) or not str(step).strip():
                        raise ValueError(f"findings[{i}].repro_steps[{j}] must be non-empty string")
            for arr_key in ("labels", "evidence"):
                val = item.get(arr_key)
                if val is None:
                    continue
                if not isinstance(val, list):
                    raise ValueError(f"findings[{i}].{arr_key} must be an array when present")
                for j, entry in enumerate(val):
                    if not isinstance(entry, str):
                        raise ValueError(f"findings[{i}].{arr_key}[{j}] must be a string")
            validate_triage_item(item, f"findings[{i}]")
            apply_triage_to_item(item, f"findings[{i}]")
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    umbrella_issue = data.get("umbrella_issue")
    if umbrella_issue is not None:
        if not isinstance(umbrella_issue, int) or umbrella_issue < 1:
            print("umbrella_issue must be a positive integer when present", file=sys.stderr)
            return 1

    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    print(f"OK: daily retro valid for {run_date} ({len(findings)} findings, PRs={prs})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
