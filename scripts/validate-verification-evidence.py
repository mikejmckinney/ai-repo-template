#!/usr/bin/env python3
"""Validate PR user-outcome and sandbox-routing evidence."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


VALID_CLASSES = {
    "code-or-docs",
    "pull_request-triggered workflow",
    "default-branch-only workflow",
    "mixed",
}
VALID_TARGETS = {"PR branch", "preview", "dogfood", "sandbox repo", "both"}
CONTRACT_VERSION = 1
VAGUE_REASONS = {
    "n/a",
    "none",
    "not applicable",
    "representative test constraint",
    "same as above",
    "tbd",
    "todo",
}


def field_value(body: str, label: str) -> str:
    match = re.search(
        rf"^\*\*{re.escape(label)}:\*\*\s*(.+?)\s*$",
        body,
        flags=re.MULTILINE | re.IGNORECASE,
    )
    return match.group(1).strip() if match else ""


def sandbox_value(body: str, label: str) -> str:
    match = re.search(
        rf"^{re.escape(label)}:\s*(.+?)\s*$",
        body,
        flags=re.MULTILINE | re.IGNORECASE,
    )
    return match.group(1).strip() if match else ""


def specific_reason(value: str) -> bool:
    normalized = " ".join(value.lower().split())
    return bool(normalized) and not value.startswith("<") and normalized not in VAGUE_REASONS


def validate(
    contract_version: int,
    change_class: str,
    target: str,
    body: str,
    default_branch_constrained: bool | None = None,
) -> list[str]:
    errors: list[str] = []
    if contract_version != CONTRACT_VERSION:
        errors.append(
            f"unsupported verification evidence contract: {contract_version}"
        )
    if change_class not in VALID_CLASSES:
        errors.append(f"unsupported change class: {change_class}")
    if target not in VALID_TARGETS:
        errors.append(f"unsupported verification target: {target}")

    outcome_complete = (
        field_value(body, "Problem statement tested").lower() == "yes"
        and field_value(body, "User outcome / 15-minute test performed").lower()
        == "yes"
        and field_value(body, "Result").lower() == "problem statement resolved"
    )
    if not outcome_complete:
        errors.append("user-outcome validation is incomplete")

    declared_target = sandbox_value(body, "E2E target")
    declared_required = sandbox_value(body, "Sandbox required").lower()
    reason = sandbox_value(body, "Reason")
    declared_version = sandbox_value(body, "Evidence contract")
    declared_constraint = sandbox_value(body, "Default-branch constrained").lower()
    if declared_version != str(contract_version):
        errors.append("PR body Evidence contract does not match --contract-version")
    if change_class == "mixed" and default_branch_constrained is None:
        errors.append("mixed changes require --default-branch-constrained yes or no")
    if change_class == "mixed":
        expected_constraint = (
            "yes" if default_branch_constrained is True else "no"
        )
        if declared_constraint != expected_constraint:
            errors.append(
                "PR body Default-branch constrained value does not match the route"
            )
    elif (
        change_class == "default-branch-only workflow"
        and declared_constraint != "yes"
    ):
        errors.append(
            "default-branch-only workflow requires Default-branch constrained: yes"
        )

    sandbox_required = (
        change_class == "default-branch-only workflow"
        or default_branch_constrained is True
        or target in {"sandbox repo", "both"}
    )

    if declared_target != target:
        errors.append("PR body E2E target does not match the verification target")
    if declared_required != ("yes" if sandbox_required else "no"):
        errors.append("PR body Sandbox required value does not match the route")
    if not specific_reason(reason):
        errors.append("PR body requires a specific routing reason")

    if (
        change_class == "default-branch-only workflow"
        or default_branch_constrained is True
    ) and target not in {"sandbox repo", "both"}:
        errors.append(
            "default-branch-constrained changes must target sandbox repo or both"
        )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract-version", required=True, type=int)
    parser.add_argument("--change-class", required=True)
    parser.add_argument(
        "--default-branch-constrained",
        choices=("yes", "no"),
        help=(
            "Required for mixed changes; use yes when the changed behavior "
            "requires default-branch execution, otherwise no."
        ),
    )
    parser.add_argument("--verification-target", required=True)
    parser.add_argument("--pr-body", required=True, type=Path)
    args = parser.parse_args()

    if not args.pr_body.is_file():
        parser.error(f"PR body file does not exist: {args.pr_body}")

    errors = validate(
        args.contract_version,
        args.change_class,
        args.verification_target,
        args.pr_body.read_text(encoding="utf-8"),
        None
        if args.default_branch_constrained is None
        else args.default_branch_constrained == "yes",
    )
    if errors:
        for error in errors:
            print(f"verification evidence error: {error}")
        return 1

    print("verification evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
