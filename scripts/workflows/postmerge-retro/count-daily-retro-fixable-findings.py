#!/usr/bin/env python3
"""Count non-superseded daily findings eligible for automated fixes."""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib"))

from verification_capability import is_fix_eligible  # noqa: E402


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
            is_fix_eligible(item)
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
