#!/usr/bin/env python3
"""Annotate daily-retro findings superseded on main HEAD (fix-prefilter helper)."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

MISSING_HINTS = (
    "missing",
    "absent",
    "not found",
    "does not exist",
    "doesn't exist",
    "lack ",
    "without ",
    "no longer present",
)

def _is_path_char(ch: str) -> bool:
    return ch.isalnum() or ch in "/._-"


def path_token_in_text(path: str, text: str) -> bool:
    """Return True when path appears as its own token, not as a substring of a longer path."""
    norm = path.strip().lstrip("./")
    if not norm:
        return False
    start = 0
    while True:
        idx = text.find(norm, start)
        if idx == -1:
            return False
        before_ok = idx == 0 or not _is_path_char(text[idx - 1])
        after_idx = idx + len(norm)
        after_ok = after_idx >= len(text) or not _is_path_char(text[after_idx])
        if before_ok and after_ok:
            return True
        start = idx + 1


def _paths_in_text(text: str, candidates: list[str]) -> list[str]:
    found: list[str] = []
    for path in candidates:
        if path and path_token_in_text(path, text):
            found.append(path)
    return found


def _finding_text(finding: dict) -> str:
    parts = [
        finding.get("body") or "",
        finding.get("title") or "",
        " ".join(str(x) for x in finding.get("evidence") or []),
        " ".join(str(x) for x in finding.get("repro_steps") or []),
    ]
    return "\n".join(parts)


def check_superseded(finding: dict, changed_files: list[str], repo_root: Path) -> tuple[bool, str]:
    if finding.get("category") != "follow_up_issues":
        return False, ""
    blob = _finding_text(finding)
    blob_lower = blob.lower()
    if not any(hint in blob_lower for hint in MISSING_HINTS):
        return False, ""

    paths = _paths_in_text(blob, changed_files)
    if not paths:
        # Also match backtick paths in body (exact token, not substring).
        for match in re.findall(r"`([^`]+)`", blob):
            candidate = match.strip()
            if ("/" in candidate or "." in candidate) and path_token_in_text(candidate, blob):
                paths.append(candidate)

    for rel in paths:
        rel = rel.strip().lstrip("./")
        if not rel or rel.startswith("http"):
            continue
        target = repo_root / rel
        if target.is_file() or target.is_dir():
            kind = "directory" if target.is_dir() else "file"
            return True, f"{rel} exists on main HEAD as {kind} (finding described missing/absent state)"
    return False, ""


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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("daily_json", type=Path)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("-o", "--output", type=Path, help="default: overwrite input")
    args = parser.parse_args()

    daily = json.loads(args.daily_json.read_text(encoding="utf-8"))
    daily = annotate_daily(daily, args.repo_root.resolve())
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
