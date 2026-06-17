#!/usr/bin/env python3
"""Render ## Fix verification and ## Sandbox dogfood evidence from fix-verify.json."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def _md_verify_table(findings: list[dict]) -> str:
    lines = [
        "## Fix verification",
        "",
        "| dedupe_key | pre | post | sandbox | notes |",
        "|---|---|---|---|---|",
    ]
    for row in findings:
        key = row.get("dedupe_key", "")
        verify = row.get("verify") or {}
        if not isinstance(verify, dict):
            verify = {}
        lines.append(
            "| `{key}` | {pre} | {post} | {sandbox} | {notes} |".format(
                key=key,
                pre=verify.get("pre", "pending"),
                post=verify.get("post", "pending"),
                sandbox=verify.get("sandbox", "n/a"),
                notes=(verify.get("notes") or "").replace("|", "\\|").replace("\n", " "),
            )
        )
    lines.append("")
    lines.append(
        "Reviewer: remove ephemeral `fix-verify.json` on the fix branch before undraft/merge."
    )
    lines.append("")
    return "\n".join(lines)


def _md_sandbox_section(sandbox: dict) -> str:
    issue = (sandbox.get("issue_url") or "n/a").strip()
    pr = (sandbox.get("pr_url") or "n/a").strip()
    skip = (sandbox.get("skip_reason") or "").strip()
    runs = sandbox.get("workflow_runs") or []
    lines = [
        "## Sandbox dogfood evidence",
        "",
        f"Sandbox issue: {issue}",
        f"Sandbox PR: {pr}",
        "",
    ]
    if skip:
        lines.append(f"Skip rationale: {skip}")
        lines.append("")
    if runs:
        lines.append("Workflow runs:")
        for url in runs:
            if isinstance(url, str) and url.strip():
                lines.append(f"- {url.strip()}")
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print(
            "Usage: render-fix-pr-sections.py <fix-verify.json> [section: all|verify|sandbox]",
            file=sys.stderr,
        )
        return 2

    path = Path(sys.argv[1])
    section = sys.argv[2] if len(sys.argv) == 3 else "all"
    if not path.is_file():
        print(f"Missing fix-verify.json at {path}", file=sys.stderr)
        return 1

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"Invalid fix-verify.json at {path}: {exc}", file=sys.stderr)
        return 1
    findings = data.get("findings") or []
    sandbox = data.get("sandbox") or {}
    if not isinstance(findings, list):
        print("fix-verify.json findings must be array", file=sys.stderr)
        return 1
    if not isinstance(sandbox, dict):
        sandbox = {}

    out_parts: list[str] = []
    if section in ("all", "verify"):
        out_parts.append(_md_verify_table(findings))
    if section in ("all", "sandbox"):
        out_parts.append(_md_sandbox_section(sandbox))

    sys.stdout.write("\n".join(out_parts).rstrip() + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
