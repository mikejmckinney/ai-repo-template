#!/usr/bin/env python3
"""Write a bounded, redacted record for a rejected fix-provider attempt."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

MAX_EXCERPT = 2000
SECRET_PATTERNS = (
    re.compile(r"(?i)\b(bearer)\s+\S+"),
    re.compile(r"(?i)\b(token|secret|password|authorization|api[_-]?key)\s*[:=]\s*\S+"),
)
HIGH_ENTROPY_VALUE = re.compile(r"(?<![A-Za-z0-9])[A-Za-z0-9_./+=-]{32,}(?![A-Za-z0-9])")


def redact(text: str) -> str:
    value = text
    for pattern in SECRET_PATTERNS:
        value = pattern.sub(lambda match: f"{match.group(1)}=<redacted>", value)
    value = HIGH_ENTROPY_VALUE.sub("<redacted-value>", value)
    return value[:MAX_EXCERPT]


def git_output(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.stdout.rstrip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--attempt", type=int, required=True)
    parser.add_argument("--provider", required=True)
    parser.add_argument("--requested-model", required=True)
    parser.add_argument("--failed-stage", required=True)
    parser.add_argument("--exit-status", type=int, required=True)
    parser.add_argument("--stage-log", type=Path, required=True)
    args = parser.parse_args()

    try:
        stage_text = args.stage_log.read_text(encoding="utf-8", errors="replace")
    except OSError:
        stage_text = ""
    excerpt = redact(stage_text)
    failing_checks = [
        line.strip()[:300]
        for line in excerpt.splitlines()
        if re.search(r"(?i)(?:^not ok\b|\bfail(?:ed|ure)?\b|\berror\b)", line)
    ][:20]
    changed_paths = []
    for line in git_output(args.repo, "status", "--porcelain", "--untracked-files=all").splitlines():
        path = line[3:].strip() if len(line) > 3 else ""
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        if path.startswith(".artifacts/") or re.match(r"^(?:retro|weekly)/fix-verify-", path):
            continue
        if path:
            changed_paths.append(redact(path))
    payload = {
        "version": 1,
        "provider": args.provider,
        "requested_model": args.requested_model,
        "observed_model": "unknown",
        "failed_stage": args.failed_stage,
        "exit_status": args.exit_status,
        "changed_paths": changed_paths,
        "diff_statistics": redact(git_output(args.repo, "diff", "HEAD", "--stat")),
        "failing_checks": failing_checks,
        "excerpt": excerpt,
        "retention": "bounded metadata only; raw model output and full patch omitted",
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    destination = args.output_dir / f"attempt-{args.attempt:02d}-{args.provider}.json"
    destination.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Retained failed-attempt diagnostic: {destination}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
