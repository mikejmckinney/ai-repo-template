#!/usr/bin/env python3
"""Annotate daily-retro findings superseded on main HEAD (fix-prefilter helper)."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

LIB_DIR = Path(__file__).resolve().parents[1] / "lib"
sys.path.insert(0, str(LIB_DIR))

from superseded_findings import check_superseded  # noqa: E402


def annotate_daily(daily: dict, repo_root: Path) -> dict:
    changed_by_pr: dict[int, list[str]] = {}
    for row in daily.get("pr_changed_files") or []:
        pr = int(row.get("pr"))
        changed_by_pr[pr] = list(row.get("paths") or [])

    superseded: list[dict] = []
    for finding in daily.get("findings") or []:
        pr = int(finding.get("pr") or 0)
        changed = changed_by_pr.get(pr, [])
        ok, reason = check_superseded(finding, changed, repo_root)
        if ok:
            finding["superseded_on_main"] = True
            finding["superseded_reason"] = reason
            superseded.append(
                {
                    "dedupe_key": finding.get("dedupe_key", ""),
                    "reason": reason,
                }
            )
        else:
            finding.pop("superseded_on_main", None)
            finding.pop("superseded_reason", None)

    daily["superseded_findings"] = superseded
    return daily


def annotate_weekly(weekly: dict, repo_root: Path) -> dict:
    superseded: list[dict] = []
    for finding in weekly.get("findings") or []:
        candidates = [
            str(path)
            for path in finding.get("evidence") or []
            if isinstance(path, str)
        ]
        ok, reason = check_superseded(finding, candidates, repo_root)
        if ok:
            finding["superseded_on_main"] = True
            finding["superseded_reason"] = reason
            superseded.append(
                {"dedupe_key": finding.get("dedupe_key", ""), "reason": reason}
            )
        else:
            finding.pop("superseded_on_main", None)
            finding.pop("superseded_reason", None)
    weekly["superseded_findings"] = superseded
    return weekly


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("daily_json", type=Path)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--mode", choices=("auto", "daily", "weekly"), default="auto")
    parser.add_argument("-o", "--output", type=Path, help="default: overwrite input")
    args = parser.parse_args()

    daily = json.loads(args.daily_json.read_text(encoding="utf-8"))
    mode = args.mode
    if mode == "auto":
        mode = "weekly" if daily.get("run_week") else "daily"
    daily = (
        annotate_weekly(daily, args.repo_root.resolve())
        if mode == "weekly"
        else annotate_daily(daily, args.repo_root.resolve())
    )
    out = args.output or args.daily_json
    out.write_text(json.dumps(daily, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"superseded={len(daily.get('superseded_findings') or [])} "
        f"findings={len(daily.get('findings') or [])}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
