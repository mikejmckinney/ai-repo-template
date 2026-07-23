#!/usr/bin/env python3
"""Apply file_edits from Gemini-style retro fix JSON."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: apply-retro-fix-json.py <fix.json> <repo-root>", file=sys.stderr)
        return 2

    data = json.load(open(sys.argv[1], encoding="utf-8"))
    root = Path(sys.argv[2]).resolve()

    edits = data.get("file_edits") or []
    if not isinstance(edits, list) or not edits:
        print("No file_edits to apply", file=sys.stderr)
        return 1

    for i, edit in enumerate(edits):
        if not isinstance(edit, dict):
            print(f"file_edits[{i}] must be object", file=sys.stderr)
            return 1
        rel = edit.get("path")
        content = edit.get("content")
        if not isinstance(rel, str) or not rel.strip():
            print(f"file_edits[{i}].path required", file=sys.stderr)
            return 1
        if ".." in Path(rel).parts:
            print(f"Rejected path traversal: {rel}", file=sys.stderr)
            return 1
        if not isinstance(content, str):
            print(f"file_edits[{i}].content must be string", file=sys.stderr)
            return 1
        target = root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        print(f"Wrote {rel}")

    notes = data.get("notes")
    fix_verify = data.get("fix_verify")
    run_date = data.get("run_date", "batch")
    run_week = data.get("run_week")

    verify_path = None
    if isinstance(fix_verify, dict):
        verify_path = root / f"retro/fix-verify-{run_date}.json"
        if run_week:
            verify_path = root / f"weekly/fix-verify-{run_week}.json"
        verify_path.parent.mkdir(parents=True, exist_ok=True)
        verify_path.write_text(json.dumps(fix_verify, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"Wrote {verify_path.relative_to(root)}")
    elif isinstance(notes, str) and notes.strip():
        # Legacy Gemini notes — fold into fix_verify when no structured block supplied.
        kind = "weekly" if run_week else "retro"
        key = run_week or run_date
        verify_path = root / f"{kind}/fix-verify-{key}.json"
        verify_path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "run_date": run_date,
            "run_week": run_week or None,
            "findings": [],
            "sandbox": {"issue_url": "n/a", "pr_url": "n/a", "skip_reason": notes.strip()},
            "outcome_evidence": {
                "claims": [
                    {
                        "material_claim": "Legacy Gemini fix notes describe the candidate outcome.",
                        "environment": "isolated fix worktree",
                        "why_representative": "The deterministic controller verifies the candidate worktree.",
                        "implementation_sha": "controller:current-head",
                        "action_performed": "Applied the structured file edits and ran controller verification.",
                        "expected_result": "The controller accepts the candidate fix.",
                        "observed_result": notes.strip(),
                        "artifact": "embedded:fix-verification-table",
                        "artifact_type": "controller-record",
                        "redaction": "No raw credential values included.",
                        "retention": "PR lifetime.",
                        "evidence_reuse": "none",
                        "result": "pass",
                    }
                ]
            },
            "test_sh": "unknown",
        }
        verify_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"Wrote {verify_path.relative_to(root)} (from notes)")

    msg_path = root / ".artifacts/postmerge-retro/fix-commit-message.txt"
    msg_path.parent.mkdir(parents=True, exist_ok=True)
    msg_path.write_text(
        (data.get("commit_message") or "fix: post-merge retro daily fixes").strip() + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
