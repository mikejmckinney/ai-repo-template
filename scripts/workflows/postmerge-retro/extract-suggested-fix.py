#!/usr/bin/env python3
"""Extract a short Suggested fix cell from a finding body."""
from __future__ import annotations

import re
import sys


def _strip_md_links(text: str) -> str:
    return re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)


def _first_meaningful_line(block: str) -> str:
    for line in block.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("<!--"):
            continue
        if stripped.startswith(("-", "*", "#")):
            stripped = re.sub(r"^[-*#]+\s*", "", stripped)
        return _strip_md_links(stripped)
    return ""


def extract_suggested_fix(body: str, *, max_len: int = 120) -> str:
    text = body or ""
    section = re.search(
        r"(?im)^##\s+Suggested fix\s*\n+(.*?)(?=^##\s|\Z)",
        text,
        re.DOTALL,
    )
    if section:
        line = _first_meaningful_line(section.group(1))
        if line:
            return _truncate(line, max_len)

    problem = re.search(
        r"(?im)^##\s+Problem\s*\n+(.*?)(?=^##\s|\Z)",
        text,
        re.DOTALL,
    )
    if problem:
        line = _first_meaningful_line(problem.group(1))
        if line:
            return _truncate(line, max_len)

    return "See finding body"


def _truncate(line: str, max_len: int) -> str:
    line = line.replace("|", "/").strip()
    if len(line) <= max_len:
        return line
    return line[: max_len - 3].rstrip() + "..."


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: extract-suggested-fix.py <body-file|->", file=sys.stderr)
        return 2
    if sys.argv[1] == "-":
        body = sys.stdin.read()
    else:
        body = open(sys.argv[1], encoding="utf-8").read()
    print(extract_suggested_fix(body))
    return 0


if __name__ == "__main__":
    sys.exit(main())
