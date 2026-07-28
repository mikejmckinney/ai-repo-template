#!/usr/bin/env python3
"""Count non-superseded daily findings eligible for automated fixes."""
from __future__ import annotations

import json
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print(
            "Usage: count-daily-retro-fixable-findings.py <daily-retro.json>",
            file=sys.stderr,
        )
        return 2

    data = json.load(open(sys.argv[1], encoding="utf-8"))
    findings = data.get("findings") or []
    count = (
        sum(
            item.get("superseded_on_main") is not True
            and item.get("priority_band") in {"should-fix", "fix-now"}
            for item in findings
            if isinstance(item, dict)
        )
        if isinstance(findings, list)
        else 0
    )
    print(count)
    return 0


if __name__ == "__main__":
    sys.exit(main())
