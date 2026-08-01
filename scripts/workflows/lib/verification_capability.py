#!/usr/bin/env python3
"""Validate and route repository-owned fix verification capabilities."""
from __future__ import annotations

from typing import Any

SUPPORTED_HARNESSES = {
    "repository-test-suite": {
        "environment": "isolated-worktree",
        "command": "./test.sh",
    }
}
ENVIRONMENTS = {
    "isolated-worktree",
    "codespaces",
    "external-state",
    "unsupported-runtime",
}


def validate_capability(value: object, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"{path} must be an object")
    environment = value.get("environment")
    harness_id = value.get("harness_id")
    reason = value.get("reason")
    if environment not in ENVIRONMENTS:
        raise ValueError(f"{path}.environment is unsupported")
    if not isinstance(reason, str) or not reason.strip():
        raise ValueError(f"{path}.reason must be a non-empty string")
    if environment == "isolated-worktree":
        harness = SUPPORTED_HARNESSES.get(harness_id)
        if harness is None or harness["environment"] != environment:
            raise ValueError(f"{path}.harness_id is not allowlisted for {environment}")
    elif harness_id is not None:
        raise ValueError(f"{path}.harness_id must be null outside isolated-worktree")
    return value


def routing_reason(finding: dict[str, Any]) -> str | None:
    capability = finding.get("verification_capability")
    if capability is None:
        return "missing verification_capability"
    try:
        validate_capability(capability, "verification_capability")
    except ValueError as error:
        return str(error)
    if capability["environment"] != "isolated-worktree":
        return f"{capability['environment']} verification is unavailable to automated fixes"
    return None


def is_fix_eligible(finding: dict[str, Any]) -> bool:
    return (
        finding.get("superseded_on_main") is not True
        and finding.get("priority_band") in {"should-fix", "fix-now"}
        and routing_reason(finding) is None
    )
