#!/usr/bin/env python3
"""Extract a JSON object from LLM text output for post-merge retro."""
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
    if len(sys.argv) != 4:
        print(
            "Usage: extract-retro-json.py <llm-output-file> <expected-pr> <retro-json-out>",
            file=sys.stderr,
        )
        return 2

    llm_path, expected_pr, out_path = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    raw = open(llm_path, encoding="utf-8").read()
    blob = _find_json_object(raw)
    data = json.loads(blob)

    if not isinstance(data, dict):
        print("Retro output must be a JSON object", file=sys.stderr)
        return 1

    if int(data.get("pr", 0)) != expected_pr:
        print(
            f"Retro JSON pr={data.get('pr')} does not match expected PR #{expected_pr}",
            file=sys.stderr,
        )
        return 1

    for key in ("follow_up_issues", "adr_updates", "context_pack_updates"):
        if key not in data or not isinstance(data[key], list):
            print(f"Missing or invalid array field: {key}", file=sys.stderr)
            return 1

    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
