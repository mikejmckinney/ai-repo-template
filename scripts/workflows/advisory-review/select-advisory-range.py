#!/usr/bin/env python3

import argparse
import json
import re
import subprocess
from pathlib import Path


MEMORY_PATTERN = re.compile(r"<!-- ai-advisory-memory:v1 (\{.*?\}) -->")
SHA_PATTERN = re.compile(r"^[0-9a-f]{40}$")


def result(base: str, basis: str, reason: str) -> int:
    print(json.dumps({"diff_base": base, "review_basis": basis, "reason": reason}))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--snapshot", required=True)
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--expected-provider", required=True)
    parser.add_argument("--event-action", default="")
    parser.add_argument("--full", action="store_true")
    args = parser.parse_args()

    if args.full:
        return result(args.base, "full", "full-mode")
    if args.event_action == "ready_for_review":
        return result(args.base, "full", "ready-for-review")

    snapshot_path = Path(args.snapshot)
    if not snapshot_path.is_file():
        return result(args.base, "full", "no-memory")
    match = MEMORY_PATTERN.search(snapshot_path.read_text(encoding="utf-8"))
    if not match:
        return result(args.base, "full", "no-memory")
    try:
        memory = json.loads(match.group(1))
    except json.JSONDecodeError:
        return result(args.base, "full", "invalid-memory")

    if memory.get("base_sha") != args.base:
        return result(args.base, "full", "base-changed")
    if memory.get("provider") != args.expected_provider:
        return result(args.base, "full", "provider-changed")
    reviewed_head = memory.get("reviewed_head", "")
    if not isinstance(reviewed_head, str) or not SHA_PATTERN.fullmatch(reviewed_head):
        return result(args.base, "full", "invalid-memory")
    if reviewed_head == args.head:
        return result(args.base, "full", "same-head")

    completed = subprocess.run(
        ["git", "-C", args.repo, "merge-base", "--is-ancestor", reviewed_head, args.head],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if completed.returncode != 0:
        return result(args.base, "full", "non-ancestor-memory")
    return result(reviewed_head, "incremental", "compatible-memory")


if __name__ == "__main__":
    raise SystemExit(main())
