#!/usr/bin/env python3
"""Flatten weekly review JSON into batch document (retro-compatible findings shape)."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def _flatten(data: dict) -> list[dict]:
    findings: list[dict] = []
    for item in data.get("follow_up_issues") or []:
        if not isinstance(item, dict):
            continue
        findings.append(
            {
                "pr": 0,
                "scope": "repo",
                "category": "follow_up_issues",
                "title": item.get("title", ""),
                "severity": item.get("severity") or "medium",
                "body": item.get("body", ""),
                "dedupe_key": item.get("dedupe_key", ""),
                "repro_steps": item.get("repro_steps") or [],
                "evidence": item.get("evidence") or [],
                "labels": item.get("labels") or [],
            }
        )
    for item in data.get("adr_updates") or []:
        if not isinstance(item, dict):
            continue
        findings.append(
            {
                "pr": 0,
                "scope": "repo",
                "category": "adr_updates",
                "title": item.get("title", ""),
                "severity": "medium",
                "body": item.get("body", ""),
                "dedupe_key": item.get("dedupe_key", ""),
                "evidence": [item.get("adr") or ""],
                "labels": ["adr:update"],
            }
        )
    for item in data.get("context_pack_updates") or []:
        if not isinstance(item, dict):
            continue
        body = f"**Pack:** {item.get('pack', '')}\n\n**Reason:** {item.get('reason', '')}"
        findings.append(
            {
                "pr": 0,
                "scope": "repo",
                "category": "context_pack_updates",
                "title": f"Context pack update: {item.get('pack', '')}",
                "severity": "medium",
                "body": body,
                "dedupe_key": item.get("dedupe_key", ""),
                "evidence": item.get("evidence") or [],
                "labels": ["context-pack"],
            }
        )
    return findings


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "Usage: build-weekly-review-batch.py <run-week> <run-date> <review.json>",
            file=sys.stderr,
        )
        return 2

    run_week, run_date, review_path = sys.argv[1], sys.argv[2], Path(sys.argv[3])
    data = json.loads(review_path.read_text(encoding="utf-8"))
    findings = _flatten(data)
    batch = {
        "run_week": run_week,
        "run_date": run_date,
        "scan_type": "full-repo",
        "summary": (data.get("summary") or "").strip()
        or f"Weekly full-repo review for {run_week}.",
        "prs": [],
        "findings": findings,
    }
    json.dump(batch, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
