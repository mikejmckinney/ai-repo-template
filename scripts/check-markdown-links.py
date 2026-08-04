#!/usr/bin/env python3

import argparse
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

INLINE_LINK = re.compile(r"!?\[[^\]]*\]\(([^)\n]+)\)")
REFERENCE_LINK = re.compile(r"^\s*\[[^\]]+\]:\s*(\S+)")
FENCE = re.compile(r"^\s*(```|~~~)")
ISSUE_PLAN_TEMPLATES = {
    Path(".github/PLAN_TEMPLATE.md"),
    Path(".github/templates/issue-implementation-plan.md"),
    Path(".github/ISSUE_TEMPLATE/bug_report.md"),
    Path(".github/ISSUE_TEMPLATE/feature_request.md"),
    Path(".github/ISSUE_TEMPLATE/agent_init.md"),
}


def link_destinations(path: Path):
    fenced = False
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if FENCE.match(line):
            fenced = not fenced
            continue
        if fenced:
            continue
        scrubbed = re.sub(r"`[^`]*`", "", line)
        for match in INLINE_LINK.finditer(scrubbed):
            yield number, match.group(1)
        reference = REFERENCE_LINK.match(scrubbed)
        if reference:
            yield number, reference.group(1)


def local_target(destination: str, source: Path, root: Path):
    destination = destination.strip()
    if destination.startswith("<") and ">" in destination:
        destination = destination[1 : destination.index(">")]
    else:
        destination = destination.split(maxsplit=1)[0]
    parsed = urlsplit(destination)
    if parsed.scheme or parsed.netloc or not parsed.path:
        return None
    try:
        source_path = source.relative_to(root)
    except ValueError:
        source_path = None
    if source_path in ISSUE_PLAN_TEMPLATES:
        for prefix in ("../blob/main/", "../tree/main/"):
            if parsed.path.startswith(prefix):
                return root / unquote(parsed.path.removeprefix(prefix))
    relative = Path(unquote(parsed.path).lstrip("/"))
    return root / relative if parsed.path.startswith("/") else source.parent / relative


def main():
    parser = argparse.ArgumentParser(description="Check repository-local Markdown link targets")
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("files", nargs="+", type=Path)
    args = parser.parse_args()
    root = args.repo_root.resolve()
    failures = []

    for supplied in args.files:
        source = supplied.resolve()
        for line, destination in link_destinations(source):
            target = local_target(destination, source, root)
            if target is None:
                continue
            try:
                target.resolve().relative_to(root)
            except ValueError:
                failures.append((source, line, destination, "target escapes repository"))
                continue
            if not target.exists():
                failures.append((source, line, destination, "target does not exist"))

    for source, line, destination, reason in failures:
        try:
            display = source.relative_to(root)
        except ValueError:
            display = source
        print(f"{display}:{line}: {reason}: {destination}", file=sys.stderr)
    if failures:
        return 1
    count = len(args.files)
    print(f"checked {count} Markdown file{'s' if count != 1 else ''}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
