#!/usr/bin/env python3
"""Merge per-PR retro.json files into one daily batch document."""
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
copy_triage_fields = _CL.copy_triage_fields


def _flatten_item(
    pr: int,
    category: str,
    item: dict,
    *,
    title: str,
    body: str,
    labels: list[str],
    evidence: list[str],
    repro_steps: list[str] | None = None,
    path: str,
) -> dict:
    triage = copy_triage_fields(item, path)
    row: dict = {
        "pr": pr,
        "category": category,
        "title": title,
        "body": body,
        "dedupe_key": item.get("dedupe_key", ""),
        "evidence": evidence,
        "labels": labels,
        **triage,
    }
    if repro_steps is not None:
        row["repro_steps"] = repro_steps
    return row


def _flatten_pr_retro(data: dict) -> list[dict]:
    pr = int(data["pr"])
    findings: list[dict] = []
    for i, item in enumerate(data.get("follow_up_issues") or []):
        if not isinstance(item, dict):
            continue
        findings.append(
            _flatten_item(
                pr,
                "follow_up_issues",
                item,
                title=item.get("title", ""),
                body=item.get("body", ""),
                labels=item.get("labels") or [],
                evidence=item.get("evidence") or [],
                repro_steps=item.get("repro_steps") or [],
                path=f"follow_up_issues[{i}]",
            )
        )
    for i, item in enumerate(data.get("adr_updates") or []):
        if not isinstance(item, dict):
            continue
        findings.append(
            _flatten_item(
                pr,
                "adr_updates",
                item,
                title=item.get("title", ""),
                body=item.get("body", ""),
                labels=["adr:update"],
                evidence=[item.get("adr") or ""],
                path=f"adr_updates[{i}]",
            )
        )
    for i, item in enumerate(data.get("context_pack_updates") or []):
        if not isinstance(item, dict):
            continue
        body = f"**Pack:** {item.get('pack', '')}\n\n**Reason:** {item.get('reason', '')}"
        findings.append(
            _flatten_item(
                pr,
                "context_pack_updates",
                item,
                title=f"Context pack update: {item.get('pack', '')}",
                body=body,
                labels=["context-pack"],
                evidence=item.get("evidence") or [],
                path=f"context_pack_updates[{i}]",
            )
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
    pr_evidence_coverage: list[dict] = []

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

        coverage_path = path.parent / f"pr-{pr}-evidence-coverage.json"
        if coverage_path.is_file():
            coverage = json.loads(coverage_path.read_text(encoding="utf-8"))
            if isinstance(coverage, dict):
                pr_evidence_coverage.append(coverage)

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
    if pr_evidence_coverage:
        batch["pr_evidence_coverage"] = sorted(
            pr_evidence_coverage, key=lambda item: int(item["pr"])
        )
    json.dump(batch, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
