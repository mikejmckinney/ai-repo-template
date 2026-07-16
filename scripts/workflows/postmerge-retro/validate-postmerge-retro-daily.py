#!/usr/bin/env python3
"""Validate daily post-merge retro batch JSON."""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path


def _load_classifier():
    path = Path(__file__).resolve().parent / "classify-finding-priority.py"
    spec = importlib.util.spec_from_file_location("classify_finding_priority", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load classifier from {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_CL = _load_classifier()
apply_triage_to_item = _CL.apply_triage_to_item
validate_triage_item = _CL.validate_triage_item

EVIDENCE_ROUTES = {
    "bounded",
    "full-evidence-opencode",
    "full-evidence-cursor",
    "full-evidence-antigravity",
    "bounded-fallback",
}
SCHEMA_PATH = (
    Path(__file__).resolve().parents[3] / ".github/schemas/postmerge-retro-daily.schema.json"
)


def _validate_evidence_coverage(item: dict, path: str) -> None:
    if not isinstance(item, dict):
        raise ValueError(f"{path} must be an object")
    for key in (
        "pr",
        "diff_included",
        "diff_total",
        "head_included",
        "head_total",
        "would_truncate",
        "evidence_route",
        "routing_context",
    ):
        if key not in item:
            raise ValueError(f"{path}.{key} required")
    pr = item["pr"]
    if not isinstance(pr, int) or pr < 1:
        raise ValueError(f"{path}.pr must be a positive integer")
    for key in (
        "diff_included",
        "diff_total",
        "head_included",
        "head_total",
    ):
        val = item[key]
        if not isinstance(val, int) or val < 0:
            raise ValueError(f"{path}.{key} must be a non-negative integer")
    if not isinstance(item["would_truncate"], bool):
        raise ValueError(f"{path}.would_truncate must be a boolean")
    route = item["evidence_route"]
    if route not in EVIDENCE_ROUTES:
        raise ValueError(f"{path}.evidence_route invalid: {route!r}")
    ctx = item["routing_context"]
    if not isinstance(ctx, dict):
        raise ValueError(f"{path}.routing_context must be an object")
    for key in (
        "adaptive_enabled",
        "provider_resolved",
        "cursor_available",
        "antigravity_available",
    ):
        if key not in ctx:
            raise ValueError(f"{path}.routing_context.{key} required")
    if not isinstance(ctx["adaptive_enabled"], bool):
        raise ValueError(f"{path}.routing_context.adaptive_enabled must be boolean")
    if not isinstance(ctx["provider_resolved"], str) or not ctx["provider_resolved"].strip():
        raise ValueError(f"{path}.routing_context.provider_resolved must be a non-empty string")
    if "opencode_available" in ctx and not isinstance(ctx["opencode_available"], bool):
        raise ValueError(f"{path}.routing_context.opencode_available must be boolean")
    if not isinstance(ctx["cursor_available"], bool):
        raise ValueError(f"{path}.routing_context.cursor_available must be boolean")
    if not isinstance(ctx["antigravity_available"], bool):
        raise ValueError(f"{path}.routing_context.antigravity_available must be boolean")
    omitted = item.get("omitted_head_paths")
    if omitted is not None:
        if not isinstance(omitted, list):
            raise ValueError(f"{path}.omitted_head_paths must be an array when present")
        for i, entry in enumerate(omitted):
            if not isinstance(entry, str):
                raise ValueError(f"{path}.omitted_head_paths[{i}] must be a string")
    attempts = item.get("provider_attempts")
    if attempts is not None:
        if not isinstance(attempts, list):
            raise ValueError(f"{path}.provider_attempts must be an array when present")
        for i, attempt in enumerate(attempts):
            if not isinstance(attempt, dict):
                raise ValueError(f"{path}.provider_attempts[{i}] must be an object")
            for key in ("provider", "status", "evidence_route"):
                if not isinstance(attempt.get(key), str) or not attempt[key].strip():
                    raise ValueError(f"{path}.provider_attempts[{i}].{key} must be a non-empty string")
            if attempt["status"] not in ("success", "failed"):
                raise ValueError(f"{path}.provider_attempts[{i}].status invalid")


def _validate_with_schema(data: dict) -> None:
    if not SCHEMA_PATH.is_file():
        return
    try:
        import jsonschema  # type: ignore[import-not-found]
    except ImportError:
        return
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    jsonschema.validate(instance=data, schema=schema)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate-postmerge-retro-daily.py <daily-retro.json>", file=sys.stderr)
        return 2

    path = sys.argv[1]
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        print("Root must be object", file=sys.stderr)
        return 1

    run_date = data.get("run_date")
    if not isinstance(run_date, str) or len(run_date) != 10:
        print("run_date must be YYYY-MM-DD", file=sys.stderr)
        return 1

    prs = data.get("prs")
    if not isinstance(prs, list):
        print("prs must be an array", file=sys.stderr)
        return 1

    findings = data.get("findings")
    if not isinstance(findings, list):
        print("findings must be an array", file=sys.stderr)
        return 1

    try:
        for i, item in enumerate(findings):
            if not isinstance(item, dict):
                raise ValueError(f"findings[{i}] must be object")
            for key in ("pr", "category", "title", "body", "dedupe_key"):
                if key not in item or not str(item[key]).strip():
                    raise ValueError(f"findings[{i}].{key} required")
            if item.get("category") == "follow_up_issues":
                steps = item.get("repro_steps")
                if not isinstance(steps, list) or not steps:
                    raise ValueError(f"findings[{i}].repro_steps required for follow_up_issues")
                for j, step in enumerate(steps):
                    if not isinstance(step, str) or not str(step).strip():
                        raise ValueError(f"findings[{i}].repro_steps[{j}] must be non-empty string")
            for arr_key in ("labels", "evidence"):
                val = item.get(arr_key)
                if val is None:
                    continue
                if not isinstance(val, list):
                    raise ValueError(f"findings[{i}].{arr_key} must be an array when present")
                for j, entry in enumerate(val):
                    if not isinstance(entry, str):
                        raise ValueError(f"findings[{i}].{arr_key}[{j}] must be a string")
            validate_triage_item(item, f"findings[{i}]")
            apply_triage_to_item(item, f"findings[{i}]")
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    coverage = data.get("pr_evidence_coverage")
    if coverage is not None:
        if not isinstance(coverage, list):
            print("pr_evidence_coverage must be an array when present", file=sys.stderr)
            return 1
        try:
            for i, item in enumerate(coverage):
                _validate_evidence_coverage(item, f"pr_evidence_coverage[{i}]")
        except ValueError as exc:
            print(str(exc), file=sys.stderr)
            return 1

    failed_prs = data.get("failed_prs")
    if failed_prs is not None:
        if not isinstance(failed_prs, list):
            print("failed_prs must be an array when present", file=sys.stderr)
            return 1
        for i, item in enumerate(failed_prs):
            if not isinstance(item, dict):
                print(f"failed_prs[{i}] must be an object", file=sys.stderr)
                return 1
            if not isinstance(item.get("pr"), int) or item["pr"] < 1:
                print(f"failed_prs[{i}].pr must be a positive integer", file=sys.stderr)
                return 1
            for key in ("stage", "reason"):
                if not isinstance(item.get(key), str) or not item[key].strip():
                    print(f"failed_prs[{i}].{key} must be a non-empty string", file=sys.stderr)
                    return 1

    try:
        _validate_with_schema(data)
    except Exception as exc:  # noqa: BLE001 — surface schema failures
        print(f"schema validation failed: {exc}", file=sys.stderr)
        return 1

    umbrella_issue = data.get("umbrella_issue")
    if umbrella_issue is not None:
        if not isinstance(umbrella_issue, int) or umbrella_issue < 1:
            print("umbrella_issue must be a positive integer when present", file=sys.stderr)
            return 1

    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")

    print(f"OK: daily retro valid for {run_date} ({len(findings)} findings, PRs={prs})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
