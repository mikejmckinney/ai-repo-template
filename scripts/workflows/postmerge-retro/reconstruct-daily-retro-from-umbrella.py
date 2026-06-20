#!/usr/bin/env python3
"""Reconstruct daily-retro.json from an umbrella issue findings table."""
from __future__ import annotations

import argparse
import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path

ROW_RE = re.compile(
    r"^\|\s*#(\d+)\s*\|\s*([^|]+)\|\s*`([^`]+)`\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*"
    r"([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|\s*$"
)
ROW_RE_LEGACY_8 = re.compile(
    r"^\|\s*#(\d+)\s*\|\s*([^|]+)\|\s*`([^`]+)`\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*"
    r"([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|\s*$"
)
MARKER_RE = re.compile(r"<!-- postmerge-retro:daily:(\d{4}-\d{2}-\d{2}) -->")


def _load_classifier():
    path = Path(__file__).resolve().parent / "classify-finding-priority.py"
    spec = importlib.util.spec_from_file_location("classify_finding_priority", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load classifier from {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_CL = _load_classifier()
derive_priority_band = _CL.derive_priority_band
apply_triage_to_item = _CL.apply_triage_to_item


def _labels_for(category: str) -> list[str]:
    if category == "adr_updates":
        return ["adr:update"]
    if category == "context_pack_updates":
        return ["context-pack"]
    return ["agent-suggested"]


def _parse_guard(raw: str) -> bool:
    val = raw.strip().lower()
    if val in ("true", "1", "yes"):
        return True
    if val in ("false", "0", "no", ""):
        return False
    raise ValueError(f"invalid regression_guard value: {raw!r}")


def _infer_fix_cost_and_guard(impact: str, trigger: str, table_band: str) -> tuple[str, bool]:
    for fix_cost in ("trivial", "moderate", "large"):
        for guard in (False, True):
            if guard and trigger == "fringe":
                continue
            if derive_priority_band(impact, trigger, fix_cost, regression_guard=guard) == table_band:
                return fix_cost, guard
    return "moderate", False


def _parse_row(match: re.Match[str], *, run_date: str) -> dict:
    groups = match.groups()
    if len(groups) == 10:
        pr, category, dedupe_key, impact, trigger, fix_cost, guard_raw, table_band, title, suggested = (
            groups
        )
        regression_guard = _parse_guard(guard_raw)
    else:
        pr, category, dedupe_key, impact, trigger, table_band, title, suggested = groups
        fix_cost, regression_guard = _infer_fix_cost_and_guard(
            impact.strip(), trigger.strip(), table_band.strip()
        )

    pr = int(pr)
    category = category.strip()
    dedupe_key = dedupe_key.strip()
    impact = impact.strip()
    trigger_likelihood = trigger.strip()
    table_band = table_band.strip()
    title = title.strip()
    suggested_fix = suggested.strip()

    finding_body = (
        f"Reconstructed from umbrella issue table for {run_date}.\n\n"
        f"**Finding:** {title}\n\n"
        f"**Suggested fix:** {suggested_fix}\n\n"
        f"**Dedupe key:** `{dedupe_key}`"
    )
    row: dict = {
        "pr": pr,
        "category": category,
        "title": title,
        "impact": impact,
        "trigger_likelihood": trigger_likelihood,
        "fix_cost": fix_cost.strip() if isinstance(fix_cost, str) else fix_cost,
        "regression_guard": regression_guard,
        "body": finding_body,
        "dedupe_key": dedupe_key,
        "evidence": [f"umbrella-table:{run_date}"],
        "labels": _labels_for(category),
    }
    if category == "follow_up_issues":
        row["repro_steps"] = [
            "Reconstructed from umbrella findings table; re-run per-PR retro for concrete repro steps."
        ]
    apply_triage_to_item(row, "finding")
    derived_band = row.get("priority_band")
    if derived_band != table_band:
        print(
            f"::warning::Reconstructed band for `{dedupe_key}` is {derived_band!r}; "
            f"umbrella table had {table_band!r}",
            file=sys.stderr,
        )
    return row


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
        stripped = line.strip()
        match = ROW_RE.match(stripped) or ROW_RE_LEGACY_8.match(stripped)
        if not match:
            continue
        row = _parse_row(match, run_date=run_date)
        prs.add(int(row["pr"]))
        findings.append(row)

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
