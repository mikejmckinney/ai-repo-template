#!/usr/bin/env python3
"""Flatten weekly review JSON into batch document (retro-compatible findings shape)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

LIB_DIR = Path(__file__).resolve().parents[1] / "lib"
sys.path.insert(0, str(LIB_DIR))

from finding_priority import copy_triage_fields  # noqa: E402


def _flatten_item(item: dict, path: str, **fields: object) -> dict:
    return {**fields, **copy_triage_fields(item, path)}


def _flatten(data: dict) -> list[dict]:
    findings: list[dict] = []
    for index, item in enumerate(data.get("follow_up_issues") or []):
        if not isinstance(item, dict):
            continue
        findings.append(
            _flatten_item(
                item,
                f"follow_up_issues[{index}]",
                pr=0,
                scope="repo",
                category="follow_up_issues",
                title=item.get("title", ""),
                body=item.get("body", ""),
                dedupe_key=item.get("dedupe_key", ""),
                repro_steps=item.get("repro_steps") or [],
                evidence=item.get("evidence") or [],
                labels=item.get("labels") or [],
            )
        )
    for index, item in enumerate(data.get("adr_updates") or []):
        if not isinstance(item, dict):
            continue
        findings.append(
            _flatten_item(
                item,
                f"adr_updates[{index}]",
                pr=0,
                scope="repo",
                category="adr_updates",
                title=item.get("title", ""),
                body=item.get("body", ""),
                dedupe_key=item.get("dedupe_key", ""),
                evidence=[item.get("adr") or ""],
                labels=["adr:update"],
            )
        )
    for index, item in enumerate(data.get("context_pack_updates") or []):
        if not isinstance(item, dict):
            continue
        body = f"**Pack:** {item.get('pack', '')}\n\n**Reason:** {item.get('reason', '')}"
        findings.append(
            _flatten_item(
                item,
                f"context_pack_updates[{index}]",
                pr=0,
                scope="repo",
                category="context_pack_updates",
                title=f"Context pack update: {item.get('pack', '')}",
                body=body,
                dedupe_key=item.get("dedupe_key", ""),
                evidence=item.get("evidence") or [],
                labels=["context-pack"],
            )
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
