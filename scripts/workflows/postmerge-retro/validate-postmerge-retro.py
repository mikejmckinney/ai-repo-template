#!/usr/bin/env python3
"""Lightweight validator for postmerge-retro.json (stdlib only)."""
from __future__ import annotations

import json
import sys


def _require_str(obj: dict, key: str, path: str) -> None:
    val = obj.get(key)
    if not isinstance(val, str) or not val.strip():
        raise ValueError(f"{path}.{key} must be a non-empty string")


def _require_str_array(obj: dict, key: str, path: str) -> None:
    val = obj.get(key)
    if val is None:
        return
    if not isinstance(val, list):
        raise ValueError(f"{path}.{key} must be an array when present")
    for i, item in enumerate(val):
        if not isinstance(item, str):
            raise ValueError(f"{path}.{key}[{i}] must be a string")


def _require_repro_steps(item: dict, path: str) -> None:
    steps = item.get("repro_steps")
    if not isinstance(steps, list) or not steps:
        raise ValueError(f"{path}.repro_steps must be a non-empty array of strings")
    for i, step in enumerate(steps):
        if not isinstance(step, str) or not step.strip():
            raise ValueError(f"{path}.repro_steps[{i}] must be a non-empty string")


def _validate_follow_up(item: dict, path: str) -> None:
    if not isinstance(item, dict):
        raise ValueError(f"{path} must be an object")
    _require_str(item, "title", path)
    _require_str(item, "body", path)
    _require_str(item, "dedupe_key", path)
    _require_repro_steps(item, path)
    sev = item.get("severity")
    if sev is not None and sev not in ("low", "medium", "high"):
        raise ValueError(f"{path}.severity invalid: {sev}")
    _require_str_array(item, "labels", path)
    _require_str_array(item, "evidence", path)


def _validate_adr(item: dict, path: str) -> None:
    if not isinstance(item, dict):
        raise ValueError(f"{path} must be an object")
    _require_str(item, "title", path)
    _require_str(item, "body", path)
    _require_str(item, "dedupe_key", path)
    _require_str_array(item, "labels", path)
    _require_str_array(item, "evidence", path)


def _validate_context(item: dict, path: str) -> None:
    if not isinstance(item, dict):
        raise ValueError(f"{path} must be an object")
    _require_str(item, "pack", path)
    _require_str(item, "reason", path)
    _require_str(item, "dedupe_key", path)
    _require_str_array(item, "labels", path)
    _require_str_array(item, "evidence", path)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate-postmerge-retro.py <retro.json>", file=sys.stderr)
        return 2

    path = sys.argv[1]
    data = json.load(open(path, encoding="utf-8"))
    if not isinstance(data, dict):
        print("Root must be object", file=sys.stderr)
        return 1

    pr = data.get("pr")
    if not isinstance(pr, int) or pr < 1:
        print("pr must be a positive integer", file=sys.stderr)
        return 1

    if not isinstance(data.get("summary"), str):
        print("summary must be a string", file=sys.stderr)
        return 1

    for key, validator in (
        ("follow_up_issues", _validate_follow_up),
        ("adr_updates", _validate_adr),
        ("context_pack_updates", _validate_context),
    ):
        arr = data.get(key)
        if not isinstance(arr, list):
            print(f"{key} must be an array", file=sys.stderr)
            return 1
        for i, item in enumerate(arr):
            validator(item, f"{key}[{i}]")

    print(f"OK: retro.json valid for PR #{pr}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
