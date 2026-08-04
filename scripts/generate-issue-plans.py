#!/usr/bin/env python3

import argparse
import sys
from pathlib import Path


SOURCE = Path(".github/templates/issue-implementation-plan.md")
TARGETS = (
    Path(".github/ISSUE_TEMPLATE/bug_report.md"),
    Path(".github/ISSUE_TEMPLATE/feature_request.md"),
    Path(".github/ISSUE_TEMPLATE/agent_init.md"),
)
BEGIN = "<!-- implementation-plan:v2:begin -->"
END = "<!-- implementation-plan:v2:end -->"


def generated_template(template: str, fragment: str, path: Path) -> str:
    if template.count(BEGIN) != 1 or template.count(END) != 1:
        raise ValueError(f"{path}: missing marker or marker is not unique")
    before, remainder = template.split(BEGIN, 1)
    _, after = remainder.split(END, 1)
    return f"{before}{BEGIN}\n\n{fragment.strip()}\n\n{END}{after}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate issue-template implementation-plan blocks."
    )
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    try:
        fragment = (args.repo / SOURCE).read_text()
        generated = {
            target: generated_template(
                (args.repo / target).read_text(), fragment, target
            )
            for target in TARGETS
        }
    except (OSError, ValueError) as error:
        print(f"generate-issue-plans: {error}", file=sys.stderr)
        return 2

    stale = [target for target, content in generated.items() if content != (args.repo / target).read_text()]
    if args.check:
        if not stale:
            return 0
        print(
            "stale generated issue-plan blocks: "
            + ", ".join(str(path) for path in stale)
            + f"; canonical source: {SOURCE}; run: python3 scripts/generate-issue-plans.py",
            file=sys.stderr,
        )
        return 1

    for target in stale:
        (args.repo / target).write_text(generated[target])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
