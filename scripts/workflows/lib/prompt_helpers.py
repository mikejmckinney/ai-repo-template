#!/usr/bin/env python3
"""Shared helpers for advisory and retro LLM prompt assembly."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]

# AGENTS.md is always loaded. Add only task-specific durable references.
REVIEW_LENSES = ".github/prompts/shared-review-lenses.md"
STANDARD_MINIMUM = ["AGENTS.md", REVIEW_LENSES]

PR_REVIEW_MINIMUM = ["AGENTS.md", REVIEW_LENSES, ".github/pull_request_template.md"]

# Path-pattern → task-specific references.
PATH_TRIGGERED: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"^\.github/workflows/"), "docs/guides/agent-pipeline.md"),
    (re.compile(r"^docs/decisions/"), "docs/decisions/adr-template.md"),
]


def full_rules_context() -> list[str]:
    """Compatibility alias for the retired full-rules profile."""
    return ["AGENTS.md", REVIEW_LENSES]


def _apply_path_triggers(changed_files: list[str], selected: list[str], seen: set[str]) -> None:
    def add(path: str) -> None:
        if path not in seen:
            seen.add(path)
            selected.append(path)

    for changed in changed_files:
        changed = changed.strip()
        if not changed:
            continue
        for pattern, rule_path in PATH_TRIGGERED:
            if pattern.search(changed):
                add(rule_path)


def select_review_context(changed_files: list[str], profile: str = "pr-review") -> list[str]:
    if profile == "full-rules":
        return full_rules_context()

    selected: list[str] = []
    seen: set[str] = set()

    def add(path: str) -> None:
        if path not in seen:
            seen.add(path)
            selected.append(path)

    if profile == "standard":
        floor = STANDARD_MINIMUM
    elif profile == "pr-review":
        floor = PR_REVIEW_MINIMUM
    elif profile == "full":
        for path in full_rules_context():
            add(path)
        _apply_path_triggers(changed_files, selected, seen)
        return selected
    else:
        raise ValueError(f"unsupported profile: {profile}")

    for path in floor:
        add(path)

    _apply_path_triggers(changed_files, selected, seen)
    return selected


def _compact_json(data: object) -> bytes:
    return json.dumps(data, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def _fits(data: object, max_bytes: int) -> bool:
    return len(_compact_json(data)) <= max_bytes


def _shrink_single_item(one: dict, max_bytes: int) -> dict | None:
    if not isinstance(one, dict):
        return None

    candidate = dict(one)
    if "diff_hunk" in candidate:
        without_hunk = {k: v for k, v in candidate.items() if k != "diff_hunk"}
        if _fits([without_hunk], max_bytes):
            return without_hunk
        candidate = without_hunk

    if "body" in candidate and isinstance(candidate.get("body"), str):
        body = candidate["body"]
        budget = max(0, max_bytes - 512)
        if budget < len(body):
            body = body[:budget]
        while body:
            trial = {**candidate, "body": body, "_truncated": True}
            if _fits([trial], max_bytes):
                return trial
            body = body[: max(0, len(body) - 1024)]
        trial = {**candidate, "body": "", "_truncated": True}
        if _fits([trial], max_bytes):
            return trial

    minimal = {
        k: candidate[k]
        for k in ("id", "user", "body", "path", "line", "state", "commit_id")
        if k in candidate
    }
    minimal["_truncated"] = True
    if _fits([minimal], max_bytes):
        return minimal
    return None


def cap_jq_json(input_path: Path, jq_filter: str, max_bytes: int) -> str:
    raw = subprocess.check_output(
        ["jq", "-c", jq_filter, str(input_path)],
        text=True,
    ).rstrip()
    if len(raw.encode("utf-8")) <= max_bytes:
        return raw

    arr = json.loads(raw)
    if not isinstance(arr, list):
        raise ValueError("jq filter must produce a JSON array")

    trimmed = arr
    while trimmed:
        if _fits(trimmed, max_bytes):
            return _compact_json(trimmed).decode("utf-8")
        if len(trimmed) == 1:
            shrunk = _shrink_single_item(trimmed[0], max_bytes)
            if shrunk is not None:
                return _compact_json([shrunk]).decode("utf-8")
            break
        drop = max(1, len(trimmed) // 4)
        trimmed = trimmed[drop:]

    print(
        f"::warning::cap-json: could not fit review data under {max_bytes}-byte budget; "
        "returning empty array",
        file=sys.stderr,
    )
    return "[]"


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    sel = sub.add_parser("select-context", help="List rule files to inject for a review profile")
    sel.add_argument("--profile", default="pr-review")
    sel.add_argument("--changed-files", required=True, help="Newline-separated changed paths")

    cap = sub.add_parser("cap-json", help="Cap jq-mapped JSON array to max byte size")
    cap.add_argument("--input", required=True)
    cap.add_argument("--jq-filter", required=True)
    cap.add_argument("--max-bytes", type=int, default=120000)

    args = parser.parse_args()

    if args.cmd == "select-context":
        files = [ln for ln in Path(args.changed_files).read_text(encoding="utf-8").splitlines() if ln.strip()]
        for path in select_review_context(files, profile=args.profile):
            print(path)
        return 0

    if args.cmd == "cap-json":
        print(cap_jq_json(Path(args.input), args.jq_filter, args.max_bytes))
        return 0

    return 2


if __name__ == "__main__":
    sys.exit(main())
