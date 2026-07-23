#!/usr/bin/env python3
"""Validate per-finding evidence before promoting or publishing a fix pass."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


def load_object(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"{label} not found: {path}") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read {label} {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{label} must contain a JSON object: {path}")
    return value


def indexed_findings(payload: dict[str, Any], label: str) -> dict[str, dict[str, Any]]:
    findings = payload.get("findings")
    if not isinstance(findings, list):
        raise ValueError(f"{label}.findings must be an array")

    indexed: dict[str, dict[str, Any]] = {}
    for position, finding in enumerate(findings):
        if not isinstance(finding, dict):
            raise ValueError(f"{label}.findings[{position}] must be an object")
        key = finding.get("dedupe_key")
        if not isinstance(key, str) or not key.strip():
            raise ValueError(f"{label}.findings[{position}].dedupe_key is required")
        if key in indexed:
            raise ValueError(f"{label} contains duplicate dedupe_key: {key}")
        indexed[key] = finding
    return indexed


def validate_fix(
    batch: dict[str, Any], verification: dict[str, Any], substantive_diff: bool
) -> int:
    actionable = {
        key: finding
        for key, finding in indexed_findings(batch, "batch").items()
        if finding.get("category") == "follow_up_issues"
    }
    outcomes = indexed_findings(verification, "fix-verify")

    failures = []
    fixed_count = 0
    for key in actionable:
        outcome = outcomes.get(key)
        if outcome is None:
            failures.append(f"{key}: missing fix-verify finding")
            continue
        verify = outcome.get("verify")
        if not isinstance(verify, dict):
            failures.append(f"{key}: verify must be an object")
            continue
        pre = verify.get("pre")
        post = verify.get("post")
        if pre == "cant_reproduce":
            if post not in (None, "n/a"):
                failures.append(f"{key}: cant_reproduce verify.post must be n/a")
        elif (
            substantive_diff
            and pre in ("reproduced", "skipped_collateral")
            and post == "fixed"
        ):
            fixed_count += 1
        elif substantive_diff:
            failures.append(
                f"{key}: verify must be reproduced/fixed, "
                "skipped_collateral/fixed, or cant_reproduce"
            )
        else:
            failures.append(
                f"{key}: verify.pre must be cant_reproduce for a no-diff pass"
            )
        notes = verify.get("notes")
        if not isinstance(notes, str) or not notes.strip():
            failures.append(f"{key}: verify.notes must explain the resolved outcome")

    if substantive_diff and actionable and fixed_count == 0:
        failures.append(
            "substantive diff requires at least one reproduced/fixed finding"
        )
    if failures:
        raise ValueError("; ".join(failures))
    return len(actionable)


def main() -> int:
    if len(sys.argv) != 4 or sys.argv[3] not in {
        "--substantive-diff",
        "--no-substantive-diff",
    }:
        print(
            "Usage: validate-fix-verification.py <batch.json> <fix-verify.json> "
            "<--substantive-diff|--no-substantive-diff>",
            file=sys.stderr,
        )
        return 2
    try:
        count = validate_fix(
            load_object(Path(sys.argv[1]), "batch"),
            load_object(Path(sys.argv[2]), "fix-verify"),
            sys.argv[3] == "--substantive-diff",
        )
    except ValueError as exc:
        print(f"::error::Fix verification failed: {exc}", file=sys.stderr)
        return 1
    mode = "substantive" if sys.argv[3] == "--substantive-diff" else "no-diff"
    print(f"Fix verification passed for {count} actionable finding(s) ({mode})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
