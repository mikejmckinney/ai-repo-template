#!/usr/bin/env python3
"""Validate observed provider reads against the full-evidence inventory."""
from __future__ import annotations

import json
import sys
from pathlib import Path


EVIDENCE_FILES = (
    "diff.patch",
    "pr.json",
    "summary.txt",
    "changed-files.txt",
    "reviews.json",
    "review-comments.json",
    "checks.json",
    "advisory-comments.md",
    "prior-inbox.md",
)
AUTO_LOADED_CONTEXT = {"AGENTS.md"}


def listed_paths(path: Path) -> list[str]:
    if not path.is_file():
        return []
    return [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def normalized(path: str, repo_root: Path) -> Path:
    candidate = Path(path)
    if not candidate.is_absolute():
        candidate = repo_root / candidate
    return candidate.resolve()


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "Usage: validate-opencode-retrieval.py <trace.json> <workdir> <repo-root>",
            file=sys.stderr,
        )
        return 2

    trace_path = Path(sys.argv[1])
    workdir = Path(sys.argv[2]).resolve()
    repo_root = Path(sys.argv[3]).resolve()
    try:
        trace = json.loads(trace_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"invalid review retrieval trace: {exc}", file=sys.stderr)
        return 1

    paths = trace.get("paths")
    if not isinstance(paths, list) or not all(isinstance(path, str) for path in paths):
        print("review retrieval trace paths must be an array of strings", file=sys.stderr)
        return 1
    observed = {normalized(path, repo_root) for path in paths}

    required = {workdir / name for name in EVIDENCE_FILES if (workdir / name).is_file()}
    for rel in listed_paths(workdir / "context-files.txt"):
        # OpenCode injects the root AGENTS.md through Instruction.system().
        if rel in AUTO_LOADED_CONTEXT:
            continue
        target = repo_root / rel
        if target.is_file():
            required.add(target.resolve())
    for rel in listed_paths(workdir / "changed-files.txt"):
        target = repo_root / rel
        if target.is_file():
            required.add(target.resolve())

    missing = sorted(str(path) for path in required - observed)
    if missing:
        print(
            "missing required review retrieval sources: " + ", ".join(missing),
            file=sys.stderr,
        )
        return 1

    print(f"OK: review retrieval trace covers {len(required)} required sources")
    return 0


if __name__ == "__main__":
    sys.exit(main())
