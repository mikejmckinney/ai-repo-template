#!/usr/bin/env python3
"""Render weekly review findings as detailed markdown with repo file links."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import quote


def _normalize_relpath(relpath: str) -> str:
    path = relpath.strip()
    if path.startswith("./"):
        return path[2:]
    if path.startswith("/"):
        return path[1:]
    return path


def _blob_url(repo: str, sha: str, relpath: str) -> str:
    # Evidence may include :line suffixes; keep those in the link label only.
    path_part = relpath.strip().split(":", 1)[0]
    path = _normalize_relpath(path_part)
    if not path or path.startswith("http"):
        return relpath.strip()
    return f"https://github.com/{repo}/blob/{sha}/{quote(path, safe='/')}"


def _is_repo_path(text: str) -> bool:
    text = text.strip().split(":", 1)[0]
    if not text or text.startswith("http"):
        return False
    return bool(re.match(r"^[\w./-]+\.(md|sh|py|yml|yaml|json|toml|txt)$", text)) or "/" in text


def _evidence_lines(repo: str, sha: str, evidence: list) -> list[str]:
    lines: list[str] = []
    for item in evidence or []:
        if not isinstance(item, str) or not item.strip():
            continue
        item = item.strip()
        if _is_repo_path(item):
            url = _blob_url(repo, sha, item)
            lines.append(f"- [`{item}`]({url})")
        else:
            lines.append(f"- {item}")
    return lines


def render_finding(repo: str, sha: str, finding: dict) -> str:
    key = str(finding.get("dedupe_key") or "").strip()
    title = str(finding.get("title") or "").strip()
    category = str(finding.get("category") or "").strip()
    impact = str(finding.get("impact") or "").strip()
    trigger = str(finding.get("trigger_likelihood") or "").strip()
    fix_cost = str(finding.get("fix_cost") or "").strip()
    guard = "true" if finding.get("regression_guard") is True else "false"
    band = str(finding.get("priority_band") or "").strip()
    body = str(finding.get("body") or "").strip()
    evidence = finding.get("evidence") or []

    marker = f"<!-- weekly-review:finding:{key} -->"
    parts = [
        marker,
        f"### `{key}` — {title}",
        "",
        f"**Category:** `{category}` · **Band:** `{band}`",
        "",
        f"**Triage:** impact `{impact}` · trigger `{trigger}` · cost `{fix_cost}` · guard `{guard}`",
        "",
    ]
    if body:
        parts.extend([body, ""])
    ev_lines = _evidence_lines(repo, sha, evidence if isinstance(evidence, list) else [])
    if ev_lines:
        parts.extend(["**Evidence:**", "", *ev_lines, ""])
    repro_steps = finding.get("repro_steps") or []
    if isinstance(repro_steps, list) and repro_steps:
        parts.extend(["**Reproduction:**", ""])
        parts.extend(
            f"{index}. {step}"
            for index, step in enumerate(repro_steps, start=1)
            if isinstance(step, str) and step.strip()
        )
        parts.append("")
    parts.append("**Suggested action:** Review in draft fix PR")
    parts.append("")
    return "\n".join(parts)


def render_all(data: dict, repo: str, sha: str, only_key: str | None = None) -> str:
    findings = data.get("findings") or []
    if not isinstance(findings, list):
        return ""
    blocks: list[str] = []
    for f in findings:
        if not isinstance(f, dict):
            continue
        key = str(f.get("dedupe_key") or "").strip()
        if only_key is not None and key != only_key:
            continue
        blocks.append(render_finding(repo, sha, f))
    return "\n".join(blocks).rstrip() + ("\n" if blocks else "")


def main() -> int:
    if len(sys.argv) not in (5, 6):
        print(
            "Usage: render-umbrella-findings.py <weekly-review.json> <repo> <head-sha> <out.md> [dedupe-key]",
            file=sys.stderr,
        )
        return 2

    weekly_path, repo, sha, out_path = sys.argv[1:5]
    only_key = sys.argv[5] if len(sys.argv) == 6 else None
    data = json.loads(Path(weekly_path).read_text(encoding="utf-8"))
    Path(out_path).write_text(render_all(data, repo, sha, only_key), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
