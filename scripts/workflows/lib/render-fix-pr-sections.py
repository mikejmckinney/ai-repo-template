#!/usr/bin/env python3
"""Render fix verification and auditable outcome evidence from fix-verify.json."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def _md_verify_table(findings: list[dict]) -> str:
    lines = [
        "## Fix verification",
        "",
        "| dedupe_key | disposition | harness | controller status | reasoning |",
        "|---|---|---|---|---|",
    ]
    for row in findings:
        key = row.get("dedupe_key", "")
        execution = row.get("controller_execution") or {}
        if not isinstance(execution, dict):
            execution = {}
        lines.append(
            "| `{key}` | {disposition} | {harness} | {status} | {reasoning} |".format(
                key=key,
                disposition=row.get("disposition", "pending"),
                harness=execution.get("harness_id", "n/a"),
                status=execution.get("status", "pending"),
                reasoning=(row.get("implementation_reasoning") or "").replace("|", "\\|").replace("\n", " "),
            )
        )
    lines.append("")
    lines.append(
        "Reviewer: remove ephemeral `fix-verify.json` on the fix branch before undraft/merge."
    )
    lines.append("")
    return "\n".join(lines)


def _clean(value: object) -> str:
    return str(value or "").replace("|", "\\|").replace("\n", " ").strip()


def _current_head() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else "unavailable"


def _md_outcome_section(evidence: dict) -> str:
    claims = evidence.get("claims") or []
    lines = ["## User outcome evidence", ""]
    head = _current_head()
    for index, claim in enumerate(claims, start=1):
        if not isinstance(claim, dict):
            continue
        sha = _clean(claim.get("implementation_sha"))
        if sha == "controller:current-head":
            sha = head
        lines.extend(
            [
                f"### Material claim {index}",
                "",
                f"- **Material claim:** {_clean(claim.get('material_claim'))}",
                f"- **Environment:** {_clean(claim.get('environment'))}",
                f"- **Why representative:** {_clean(claim.get('why_representative'))}",
                f"- **Implementation SHA:** `{sha}`",
                f"- **Action performed:** {_clean(claim.get('action_performed'))}",
                f"- **Expected result:** {_clean(claim.get('expected_result'))}",
                f"- **Observed result:** {_clean(claim.get('observed_result'))}",
                f"- **Artifact:** {_clean(claim.get('artifact'))}",
                f"- **Artifact type:** {_clean(claim.get('artifact_type'))}",
                f"- **Redaction:** {_clean(claim.get('redaction'))}",
                f"- **Retention:** {_clean(claim.get('retention'))}",
                f"- **Evidence reuse:** {_clean(claim.get('evidence_reuse'))}",
                f"- **Result:** {_clean(claim.get('result'))}",
                "",
            ]
        )
    return "\n".join(lines)


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print(
            "Usage: render-fix-pr-sections.py <fix-verify.json> [section: all|verify|outcome]",
            file=sys.stderr,
        )
        return 2

    path = Path(sys.argv[1])
    section = sys.argv[2] if len(sys.argv) == 3 else "all"
    if not path.is_file():
        print(f"Missing fix-verify.json at {path}", file=sys.stderr)
        return 1

    data = json.loads(path.read_text(encoding="utf-8"))
    findings = data.get("findings") or []
    evidence = data.get("outcome_evidence") or {}
    if not isinstance(findings, list):
        print("fix-verify.json findings must be array", file=sys.stderr)
        return 1
    if not isinstance(evidence, dict) or not isinstance(evidence.get("claims"), list):
        print("fix-verify.json outcome_evidence.claims must be array", file=sys.stderr)
        return 1

    out_parts: list[str] = []
    if section in ("all", "verify"):
        out_parts.append(_md_verify_table(findings))
    if section in ("all", "outcome"):
        out_parts.append(_md_outcome_section(evidence))

    sys.stdout.write("\n".join(out_parts).rstrip() + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
