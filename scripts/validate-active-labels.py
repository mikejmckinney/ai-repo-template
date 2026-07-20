#!/usr/bin/env python3

import argparse
import re
import sys
from pathlib import Path


LABEL_SOURCE = Path("scripts/setup/40-ensure-labels.sh")
WORKFLOWS = Path(".github/workflows")
LABEL_NAME = r"[A-Za-z0-9][A-Za-z0-9:._-]*"


def declared_labels(text: str) -> set[str]:
    return set(
        re.findall(rf"^({LABEL_NAME})\|[0-9A-Fa-f]{{6}}\|", text, re.MULTILINE)
    )


def quoted_labels(text: str) -> list[str]:
    return re.findall(rf"['\"]({LABEL_NAME})['\"]", text)


def workflow_labels(text: str) -> set[str]:
    labels: set[str] = set()
    block_indent: int | None = None
    for line in text.splitlines():
        if block_indent is not None:
            if not line.strip():
                continue
            indent = len(line) - len(line.lstrip())
            if indent > block_indent and re.fullmatch(LABEL_NAME, line.strip()):
                labels.add(line.strip())
                continue
            block_indent = None

        match = re.match(r"^(\s*)labels:\s*(.*)$", line)
        if match:
            value = match.group(2).strip()
            if value in {"|", ">"}:
                block_indent = len(match.group(1))
            elif value.startswith("["):
                labels.update(quoted_labels(value))
            elif value:
                labels.update(part.strip() for part in value.strip("'\"").split(","))

        labels.update(
            re.findall(rf"labels\.\*\.name\s*,\s*['\"]({LABEL_NAME})['\"]", line)
        )
        labels.update(
            re.findall(rf"--(?:add-)?labels?(?:=|\s+)['\"]?({LABEL_NAME})", line)
        )
    return {label for label in labels if label}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate bounded active workflow label references."
    )
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    args = parser.parse_args()

    try:
        declarations = declared_labels((args.repo / LABEL_SOURCE).read_text())
    except OSError as error:
        print(f"validate-active-labels: {error}", file=sys.stderr)
        return 2
    if not declarations:
        print(f"validate-active-labels: no labels found in {LABEL_SOURCE}", file=sys.stderr)
        return 2

    failures: list[str] = []
    workflow_dir = args.repo / WORKFLOWS
    for path in sorted((*workflow_dir.glob("*.yml"), *workflow_dir.glob("*.yaml"))):
        for label in sorted(workflow_labels(path.read_text()) - declarations):
            failures.append(f"{path.relative_to(args.repo)}: undeclared label '{label}'")

    if failures:
        print("\n".join(failures), file=sys.stderr)
        print(f"declare labels in {LABEL_SOURCE}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
