#!/usr/bin/env python3
"""Split monolithic multi-PR retro LLM output into per-PR retro.json files."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path


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


def _validate_retro(data: dict, expected_pr: int) -> None:
    if int(data.get("pr", 0)) != expected_pr:
        raise ValueError(f"retro pr={data.get('pr')} does not match expected {expected_pr}")
    for key in ("follow_up_issues", "adr_updates", "context_pack_updates"):
        if key not in data or not isinstance(data[key], list):
            raise ValueError(f"Missing or invalid array field: {key}")


def main() -> int:
    if len(sys.argv) < 3:
        print(
            "Usage: split-monolithic-retro-json.py <llm-output> <out-dir> [pr ...]",
            file=sys.stderr,
        )
        return 2

    llm_path = Path(sys.argv[1])
    out_dir = Path(sys.argv[2])
    expected_prs = [int(p) for p in sys.argv[3:]] if len(sys.argv) > 3 else []

    raw = llm_path.read_text(encoding="utf-8")
    data = json.loads(_find_json_object(raw))
    if not isinstance(data, dict):
        raise ValueError("Monolithic retro output must be a JSON object")

    retros = data.get("retros")
    if not isinstance(retros, list) or not retros:
        raise ValueError("Monolithic retro output missing non-empty retros array")

    out_dir.mkdir(parents=True, exist_ok=True)
    seen: set[int] = set()
    for item in retros:
        if not isinstance(item, dict):
            raise ValueError("Each retros[] entry must be an object")
        pr = int(item["pr"])
        _validate_retro(item, pr)
        seen.add(pr)
        out_path = out_dir / f"pr-{pr}-retro.json"
        with out_path.open("w", encoding="utf-8") as fh:
            json.dump(item, fh, indent=2, ensure_ascii=False)
            fh.write("\n")

    if expected_prs:
        missing = sorted(set(expected_prs) - seen)
        if missing:
            print(f"Monolithic output missing retros for PR(s): {missing}", file=sys.stderr)
            return 1

    print(f"Wrote {len(seen)} per-PR retro.json file(s) to {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
