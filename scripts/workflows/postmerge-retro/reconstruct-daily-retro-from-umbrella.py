#!/usr/bin/env python3
"""Reconstruct daily-retro.json from an umbrella issue findings table."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROW_RE = re.compile(
    r"^\|\s*#(\d+)\s*\|\s*([^|]+)\|\s*`([^`]+)`\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*[^|]*\|\s*$"
)
MARKER_RE = re.compile(r"<!-- postmerge-retro:daily:(\d{4}-\d{2}-\d{2}) -->")


def _labels_for(category: str) -> list[str]:
    if category == "adr_updates":
        return ["adr:update"]
    if category == "context_pack_updates":
        return ["context-pack"]
    return ["agent-suggested"]


def parse_umbrella_body(body: str, run_date: str | None) -> dict:
    marker_dates = MARKER_RE.findall(body)
    if not run_date:
        if len(marker_dates) != 1:
            print(
                f"Expected exactly one daily marker; found {len(marker_dates)}",
                file=sys.stderr,
            )
            sys.exit(1)
        run_date = marker_dates[0]

    marker = f"<!-- postmerge-retro:daily:{run_date} -->"
    if marker not in body:
        print(f"Umbrella body missing marker {marker}", file=sys.stderr)
        sys.exit(1)

    findings: list[dict] = []
    prs: set[int] = set()
    for line in body.splitlines():
        match = ROW_RE.match(line.strip())
        if not match:
            continue
        pr = int(match.group(1))
        category = match.group(2).strip()
        dedupe_key = match.group(3).strip()
        severity = match.group(4).strip() or "medium"
        title = match.group(5).strip()
        prs.add(pr)
        findings.append(
            {
                "pr": pr,
                "category": category,
                "title": title,
                "severity": severity,
                "body": (
                    f"Reconstructed from umbrella issue table for {run_date}.\n\n"
                    f"**Finding:** {title}\n\n"
                    f"**Dedupe key:** `{dedupe_key}`"
                ),
                "dedupe_key": dedupe_key,
                "evidence": [f"umbrella-table:{run_date}"],
                "labels": _labels_for(category),
            }
        )

    if not findings:
        print("No findings rows parsed from umbrella table", file=sys.stderr)
        sys.exit(1)

    return {
        "run_date": run_date,
        "window_hours": 24,
        "summary": (
            f"Reconstructed daily retro for {run_date} from umbrella issue "
            f"(PRs {sorted(prs)}; {len(findings)} findings)."
        ),
        "prs": sorted(prs),
        "findings": findings,
    }


def fetch_issue_body(repo: str, issue_num: int) -> str:
    out = subprocess.check_output(
        ["gh", "issue", "view", str(issue_num), "-R", repo, "--json", "body", "--jq", ".body"],
        text=True,
    )
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", help="owner/repo (default: GITHUB_REPOSITORY)")
    parser.add_argument("--issue", type=int, help="Umbrella issue number")
    parser.add_argument("--run-date", help="YYYY-MM-DD (default: from marker)")
    parser.add_argument("-o", "--output", required=True, help="Output daily-retro.json path")
    parser.add_argument("--body-file", help="Read issue body from file instead of gh")
    args = parser.parse_args()

    if args.body_file:
        body = Path(args.body_file).read_text(encoding="utf-8")
    else:
        repo = args.repo or __import__("os").environ.get("GITHUB_REPOSITORY")
        if not repo or not args.issue:
            print("--repo and --issue required without --body-file", file=sys.stderr)
            return 2
        body = fetch_issue_body(repo, args.issue)

    data = parse_umbrella_body(body, args.run_date)
    if args.issue:
        data["umbrella_issue"] = args.issue
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {out} ({len(data['findings'])} findings, run_date={data['run_date']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
