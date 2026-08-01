#!/usr/bin/env python3
"""Prepare and finalize controller-owned fix verification records."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def load_object(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def batch_rows(batch: dict[str, Any]) -> list[dict[str, Any]]:
    findings = batch.get("findings")
    if not isinstance(findings, list):
        raise ValueError("batch.findings must be an array")
    return [row for row in findings if isinstance(row, dict)]


def prepared_finding(finding: dict[str, Any]) -> dict[str, Any]:
    capability = finding.get("verification_capability") or {}
    return {
        "dedupe_key": finding.get("dedupe_key", ""),
        "implementation_reasoning": "",
        "proposed_harness_id": capability.get("harness_id"),
        "disposition": "pending",
        "controller_execution": {
            "harness_id": capability.get("harness_id"),
            "baseline_exit_code": None,
            "candidate_exit_code": None,
            "status": "pending",
        },
    }


def provider_fields(row: object) -> dict[str, Any]:
    if not isinstance(row, dict):
        return {}
    reasoning = row.get("implementation_reasoning")
    disposition = row.get("disposition")
    harness = row.get("proposed_harness_id")
    legacy_verify = row.get("verify")
    if isinstance(legacy_verify, dict):
        reasoning = reasoning or legacy_verify.get("notes")
        if legacy_verify.get("pre") == "cant_reproduce":
            disposition = "cant_reproduce"
        elif legacy_verify.get("post") == "fixed":
            disposition = "implemented"
    fields = {
        "implementation_reasoning": reasoning if isinstance(reasoning, str) else "",
        "disposition": disposition if disposition in {"implemented", "cant_reproduce"} else "pending",
    }
    if isinstance(harness, str):
        fields["proposed_harness_id"] = harness
    return fields


def prepare(batch_path: Path, output_path: Path) -> None:
    batch = load_object(batch_path)
    existing = load_object(output_path)
    existing_by_key = {
        row.get("dedupe_key"): provider_fields(row)
        for row in existing.get("findings", [])
        if isinstance(row, dict) and isinstance(row.get("dedupe_key"), str)
    }
    findings = []
    for source in batch_rows(batch):
        row = prepared_finding(source)
        row.update(existing_by_key.get(source.get("dedupe_key"), {}))
        findings.append(row)
    sandbox = existing.get("sandbox") if isinstance(existing.get("sandbox"), dict) else {}
    payload = {
        "version": 2,
        "findings": findings,
        "sandbox": {
            "needs_sync": sandbox.get("needs_sync") is True,
            "skip_reason": str(sandbox.get("skip_reason") or "controller verification only"),
        },
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def finalize(args: argparse.Namespace) -> None:
    batch = load_object(args.batch)
    provider = load_object(args.output)
    provider_by_key = {
        row.get("dedupe_key"): provider_fields(row)
        for row in provider.get("findings", [])
        if isinstance(row, dict) and isinstance(row.get("dedupe_key"), str)
    }
    provider_sandbox = provider.get("sandbox")
    if not isinstance(provider_sandbox, dict):
        provider_sandbox = {}
    findings = []
    for source in batch_rows(batch):
        row = prepared_finding(source)
        row.update(provider_by_key.get(source.get("dedupe_key"), {}))
        capability = source.get("verification_capability") or {}
        supported = capability.get("environment") == "isolated-worktree"
        row["controller_execution"] = {
            "harness_id": capability.get("harness_id"),
            "baseline_exit_code": args.baseline_exit_code if supported else None,
            "candidate_exit_code": args.candidate_exit_code if supported else None,
            "status": "passed" if supported and args.candidate_exit_code == 0 else "not_run",
        }
        findings.append(row)

    payload = {
        "version": 2,
        "findings": findings,
        "controller": {
            "provider": args.provider,
            "requested_model": args.requested_model,
            "observed_model": "unknown",
        },
        "sandbox": {
            "needs_sync": provider_sandbox.get("needs_sync") is True,
            "issue_url": "n/a",
            "pr_url": "n/a",
            "skip_reason": str(provider_sandbox.get("skip_reason") or "controller verification only"),
            "workflow_runs": [],
        },
        "outcome_evidence": {
            "claims": [
                {
                    "material_claim": "The candidate passed its repository-owned verification harness.",
                    "environment": "isolated fix worktree",
                    "why_representative": "The controller executed the allowlisted repository test suite against the candidate worktree.",
                    "implementation_sha": "controller:current-head",
                    "action_performed": "Ran the clean-HEAD baseline and candidate verification commands without provider credentials.",
                    "expected_result": "The candidate verification command exits zero.",
                    "observed_result": f"Baseline exited {args.baseline_exit_code}; candidate exited {args.candidate_exit_code}.",
                    "artifact": "embedded:controller-execution",
                    "artifact_type": "controller-command-record",
                    "redaction": "Only command identities and exit codes are retained.",
                    "retention": "PR lifetime.",
                    "evidence_reuse": "none",
                    "result": "pass" if args.candidate_exit_code == 0 else "fail",
                }
            ]
        },
    }
    args.output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    prepare_parser = subparsers.add_parser("prepare")
    prepare_parser.add_argument("batch", type=Path)
    prepare_parser.add_argument("output", type=Path)
    finalize_parser = subparsers.add_parser("finalize")
    finalize_parser.add_argument("batch", type=Path)
    finalize_parser.add_argument("output", type=Path)
    finalize_parser.add_argument("--provider", required=True)
    finalize_parser.add_argument("--requested-model", required=True)
    finalize_parser.add_argument("--baseline-exit-code", required=True, type=int)
    finalize_parser.add_argument("--candidate-exit-code", required=True, type=int)
    args = parser.parse_args()
    try:
        if args.command == "prepare":
            prepare(args.batch, args.output)
        else:
            finalize(args)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"fix verification management failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
