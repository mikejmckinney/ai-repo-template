#!/usr/bin/env python3
"""Merge per-PR retro.json files into one daily batch document."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def _flatten_pr_retro(data: dict) -> list[dict]:
    pr = int(data["pr"])
    findings: list[dict] = []
    for item in data.get("follow_up_issues") or []:
        if not isinstance(item, dict):
            continue
        findings.append(
            {
                "pr": pr,
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
                "pr": pr,
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
                "pr": pr,
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
    if len(sys.argv) < 3:
        print(
            "Usage: merge-daily-retro-json.py <run-date YYYY-MM-DD> <retro.json> [...]",
            file=sys.stderr,
        )
        return 2

    run_date = sys.argv[1]
    paths = [Path(p) for p in sys.argv[2:]]
    if not paths:
        print("No retro.json inputs", file=sys.stderr)
        return 1

    all_findings: list[dict] = []
    prs: list[int] = []
    summaries: list[str] = []
    pr_merges: list[dict] = []
    pr_changed_files: list[dict] = []

    for path in paths:
        data = json.loads(path.read_text(encoding="utf-8"))
        pr = int(data["pr"])
        prs.append(pr)
        merge_sha = str(data.get("merge_commit_sha") or "").strip()
        if merge_sha:
            pr_merges.append({"pr": pr, "merge_commit_sha": merge_sha})

        changed_path = path.parent / f"pr-{pr}-changed-files.txt"
        if changed_path.is_file():
            paths_list = [
                ln.strip()
                for ln in changed_path.read_text(encoding="utf-8").splitlines()
                if ln.strip()
            ]
            if paths_list:
                pr_changed_files.append({"pr": pr, "paths": paths_list})

        summary = (data.get("summary") or "").strip()
        if summary:
            summaries.append(f"PR #{pr}: {summary}")
        all_findings.extend(_flatten_pr_retro(data))

    prs = sorted(set(prs))
    batch = {
        "run_date": run_date,
        "window_hours": 24,
        "summary": " ".join(summaries) if summaries else f"Daily retro for {len(prs)} merged PR(s).",
        "prs": prs,
        "findings": all_findings,
    }
    if pr_merges:
        batch["pr_merges"] = pr_merges
    if pr_changed_files:
        batch["pr_changed_files"] = pr_changed_files
    json.dump(batch, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
