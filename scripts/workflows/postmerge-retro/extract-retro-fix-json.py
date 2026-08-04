#!/usr/bin/env python3
"""Extract fix JSON from LLM output."""
from __future__ import annotations

import json
import re
import sys


def _strip_fences(text: str) -> str:
    text = text.strip()
    m = re.match(r"^```(?:json)?\s*\n?(.*?)```\s*$", text, re.DOTALL | re.IGNORECASE)
    if m:
        return m.group(1).strip()
    return text


def _find_json_object(text: str) -> str:
    text = _strip_fences(text)
    if text.startswith("{") and text.endswith("}"):
        return text
    start = text.find("{")
    if start < 0:
        raise ValueError("No JSON object found in LLM output")
    depth = 0
    in_str = False
    escape = False
    for i in range(start, len(text)):
        ch = text[i]
        if in_str:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_str = False
            continue
        if ch == '"':
            in_str = True
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start : i + 1]
    raise ValueError("Unbalanced JSON object in LLM output")


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: extract-retro-fix-json.py <llm-output> <fix-json-out>", file=sys.stderr)
        return 2

    raw = open(sys.argv[1], encoding="utf-8").read()
    data = json.loads(_find_json_object(raw))
    if not isinstance(data, dict):
        print("Fix output must be object", file=sys.stderr)
        return 1
    if not isinstance(data.get("file_edits"), list):
        print("file_edits must be array", file=sys.stderr)
        return 1

    with open(sys.argv[2], "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
