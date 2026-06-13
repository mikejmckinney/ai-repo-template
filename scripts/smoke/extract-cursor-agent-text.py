#!/usr/bin/env python3
"""Extract agent text from cursor-agent --output-format json (single JSON object)."""
import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: extract-cursor-agent-text.py <agent-output.json>", file=sys.stderr)
        return 2
    raw = Path(sys.argv[1]).read_text()
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        print(raw, end="")
        return 0
    if isinstance(data, dict) and "result" in data:
        print(data.get("result") or "", end="")
    else:
        print(raw, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
