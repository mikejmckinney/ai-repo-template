#!/usr/bin/env python3

import argparse
import sys
from pathlib import Path


SOURCE = Path("docs/guides/repo-orchestration-patterns-reference.md")
TARGET = Path("AGENTS.md")
SOURCE_BEGIN = "<!-- canonical:pap-catalog:begin -->"
SOURCE_END = "<!-- canonical:pap-catalog:end -->"
TARGET_BEGIN = "<!-- generated:pap-catalog:begin -->"
TARGET_END = "<!-- generated:pap-catalog:end -->"


def marked_content(text: str, begin: str, end: str, path: Path) -> str:
    if text.count(begin) != 1 or text.count(end) != 1:
        raise ValueError(f"{path}: missing marker or marker is not unique")
    before, remainder = text.split(begin, 1)
    content, after = remainder.split(end, 1)
    if not before or not after:
        raise ValueError(f"{path}: markers must delimit content")
    return content.strip("\n")


def generated_agents(source_text: str, target_text: str) -> str:
    catalog = marked_content(source_text, SOURCE_BEGIN, SOURCE_END, SOURCE)
    marked_content(target_text, TARGET_BEGIN, TARGET_END, TARGET)
    before, remainder = target_text.split(TARGET_BEGIN, 1)
    _, after = remainder.split(TARGET_END, 1)
    return f"{before}{TARGET_BEGIN}\n{catalog}\n{TARGET_END}{after}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate the bounded AGENTS.md P/AP catalog from its canonical guide."
    )
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    source_path = args.repo / SOURCE
    target_path = args.repo / TARGET
    try:
        source_text = source_path.read_text()
        target_text = target_path.read_text()
        expected = generated_agents(source_text, target_text)
    except (OSError, ValueError) as error:
        print(f"generate-pap-catalog: {error}", file=sys.stderr)
        return 2

    if args.check:
        if expected == target_text:
            return 0
        print(
            f"{TARGET} generated P/AP catalog is stale; canonical source: {SOURCE}; "
            "run: python3 scripts/generate-pap-catalog.py",
            file=sys.stderr,
        )
        return 1

    target_path.write_text(expected)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
