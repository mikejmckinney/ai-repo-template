#!/usr/bin/env python3
"""Validate auditable evidence for material user-outcome claims."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


REQUIRED_FIELDS = (
    "material_claim",
    "environment",
    "why_representative",
    "implementation_sha",
    "action_performed",
    "expected_result",
    "observed_result",
    "artifact",
    "artifact_type",
    "redaction",
    "retention",
    "evidence_reuse",
    "result",
)
SHA_PATTERN = re.compile(r"^[0-9a-f]{7,40}$")
RESULTS = {"pass", "fail", "blocked"}


def load_payload(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"evidence file not found: {path}") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read evidence file {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise ValueError("outcome evidence must be a JSON object")
    return payload


def validate(payload: dict[str, Any]) -> int:
    claims = payload.get("claims")
    if not isinstance(claims, list) or not claims:
        raise ValueError("claims must be a non-empty array")

    failures = []
    for index, claim in enumerate(claims):
        label = f"claims[{index}]"
        if not isinstance(claim, dict):
            failures.append(f"{label} must be an object")
            continue
        for field in REQUIRED_FIELDS:
            value = claim.get(field)
            if not isinstance(value, str) or not value.strip():
                failures.append(f"{label}.{field} is required")
        sha = claim.get("implementation_sha")
        if (
            isinstance(sha, str)
            and sha.strip()
            and sha != "controller:current-head"
            and not SHA_PATTERN.fullmatch(sha)
        ):
            failures.append(
                f"{label}.implementation_sha must be a 7-40 character lowercase Git SHA"
            )
        result = claim.get("result")
        if isinstance(result, str) and result.strip() and result not in RESULTS:
            failures.append(f"{label}.result must be pass, fail, or blocked")

    if failures:
        raise ValueError("; ".join(failures))
    return len(claims)


def main() -> int:
    if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and sys.argv[2] != "--from-fix-verify"):
        print(
            "Usage: validate-outcome-evidence.py <evidence.json> [--from-fix-verify]",
            file=sys.stderr,
        )
        return 2
    try:
        payload = load_payload(Path(sys.argv[1]))
        if len(sys.argv) == 3:
            nested = payload.get("outcome_evidence")
            if not isinstance(nested, dict):
                raise ValueError("outcome_evidence must be an object")
            payload = nested
        count = validate(payload)
    except ValueError as exc:
        print(f"outcome evidence invalid: {exc}", file=sys.stderr)
        return 1
    suffix = "claim" if count == 1 else "claims"
    print(f"outcome evidence valid for {count} material {suffix}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
