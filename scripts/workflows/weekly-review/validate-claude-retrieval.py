#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

LINE_SUFFIX = re.compile(r"(?::\d+(?:-\d+)?|#L\d+(?:-L?\d+)?)$")


def normalized(raw: str, repo_root: Path) -> Path:
    location = raw.strip()
    while True:
        stripped = LINE_SUFFIX.sub("", location)
        if stripped == location:
            break
        location = stripped
    candidate = Path(location)
    if not candidate.is_absolute():
        candidate = repo_root / candidate
    return candidate.resolve()


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "Usage: validate-claude-retrieval.py <trace.json> <review.json> <repo-root>",
            file=sys.stderr,
        )
        return 2

    trace_path, review_path, repo_root = map(Path, sys.argv[1:])
    repo_root = repo_root.resolve()
    try:
        trace = json.loads(trace_path.read_text(encoding="utf-8"))
        review = json.loads(review_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"invalid Claude weekly retrieval evidence: {exc}", file=sys.stderr)
        return 1

    raw_paths = trace.get("paths")
    if not isinstance(raw_paths, list) or not all(
        isinstance(path, str) for path in raw_paths
    ):
        print("Claude retrieval trace paths must be an array of strings", file=sys.stderr)
        return 1
    raw_directories = trace.get("directories", [])
    if not isinstance(raw_directories, list) or not all(
        isinstance(path, str) for path in raw_directories
    ):
        print(
            "Claude retrieval trace directories must be an array of strings",
            file=sys.stderr,
        )
        return 1
    observed_paths = {normalized(path, repo_root) for path in raw_paths}
    observed_directories = {normalized(path, repo_root) for path in raw_directories}
    repository_reads = {
        path
        for path in observed_paths
        if path.is_file() and repo_root in path.parents
    }
    repository_searches = {
        path
        for path in observed_directories
        if path.is_dir() and (path == repo_root or repo_root in path.parents)
    }
    if not repository_reads and not repository_searches:
        print(
            "Claude weekly retrieval trace must include at least one repository read",
            file=sys.stderr,
        )
        return 1

    missing: set[str] = set()
    for finding in review.get("follow_up_issues", []):
        for evidence in finding.get("evidence", []):
            evidence_path = normalized(evidence, repo_root)
            if not evidence_path.is_file() or not (
                evidence_path == repo_root or repo_root in evidence_path.parents
            ):
                missing.add(evidence)
    if missing:
        print(
            "Claude weekly findings cite invalid or missing repository file paths: "
            + ", ".join(sorted(missing)),
            file=sys.stderr,
        )
        return 1

    print(
        "OK: Claude weekly retrieval observed "
        f"{len(repository_reads)} file reads and {len(repository_searches)} directory searches"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
