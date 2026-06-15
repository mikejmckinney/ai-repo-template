#!/usr/bin/env python3
"""Count actionable findings in a weekly review batch."""
from __future__ import annotations

import json
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: count-weekly-findings.py <weekly-review.json>", file=sys.stderr)
        return 2

    data = json.load(open(sys.argv[1], encoding="utf-8"))
    findings = data.get("findings") or []
    count = len(findings) if isinstance(findings, list) else 0
    print(count)
    return 0


if __name__ == "__main__":
    sys.exit(main())
