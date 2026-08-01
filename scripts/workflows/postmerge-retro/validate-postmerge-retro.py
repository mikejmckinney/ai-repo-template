#!/usr/bin/env python3
"""Lightweight validator for postmerge-retro.json (stdlib only)."""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

LIB_DIR = Path(__file__).resolve().parents[1] / "lib"
sys.path.insert(0, str(LIB_DIR))

from verification_capability import validate_capability  # noqa: E402


def _load_classifier():
    path = Path(__file__).resolve().parent / "classify-finding-priority.py"
    spec = importlib.util.spec_from_file_location("classify_finding_priority", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load classifier from {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_CL = _load_classifier()
apply_triage_to_retro = _CL.apply_triage_to_retro
validate_triage_item = _CL.validate_triage_item


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


def _validate_follow_up(item: dict, path: str, *, from_llm: bool) -> None:
    if not isinstance(item, dict):
        raise ValueError(f"{path} must be an object")
    _require_str(item, "title", path)
    _require_str(item, "body", path)
    _require_str(item, "dedupe_key", path)
    _require_repro_steps(item, path)
    capability = item.get("verification_capability")
    if capability is not None:
        validate_capability(capability, f"{path}.verification_capability")
    validate_triage_item(item, path, from_llm=from_llm)
    _require_str_array(item, "labels", path)
    _require_str_array(item, "evidence", path)


def main() -> int:
    args = sys.argv[1:]
    require_evidence_complete = False
    allow_derived_priority = False
    while args and args[0].startswith("--"):
        if args[0] == "--require-evidence-complete":
            require_evidence_complete = True
        elif args[0] == "--allow-derived-priority":
            allow_derived_priority = True
        else:
            break
        args = args[1:]
    if len(args) != 1:
        print(
            "Usage: validate-postmerge-retro.py [--require-evidence-complete] "
            "[--allow-derived-priority] <retro.json>",
            file=sys.stderr,
        )
        return 2

    path = args[0]
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
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

    try:
        if require_evidence_complete and data.get("evidence_complete") is not True:
            raise ValueError("evidence_complete must be true for full-evidence output")
        for retired in ("adr_updates", "context_pack_updates"):
            if retired in data:
                raise ValueError(f"{retired} is retired; use follow_up_issues")
        arr = data.get("follow_up_issues")
        if not isinstance(arr, list):
            raise ValueError("follow_up_issues must be an array")
        for i, item in enumerate(arr):
            _validate_follow_up(
                item,
                f"follow_up_issues[{i}]",
                from_llm=not allow_derived_priority,
            )
        apply_triage_to_retro(data)
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print(f"OK: retro.json valid for PR #{pr}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
