#!/usr/bin/env python3
"""Detect adjudication needs and render adjudicator prompt packages."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ADJ_PROMPT = REPO_ROOT / ".github/prompts/model-roi-adjudicator-v1.md"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle-root", type=Path, required=True)
    parser.add_argument("--compare-report", type=Path, help="JSON from compare-grade-sets.py")
    parser.add_argument("--out-dir", type=Path, help="Default: bundle-root/adjudication")
    parser.add_argument("--validate-response", type=Path, help="Optional adjudicator JSON to validate")
    args = parser.parse_args()

    root = args.bundle_root.resolve()
    out_dir = args.out_dir or root / "adjudication"
    out_dir.mkdir(parents=True, exist_ok=True)

    needed: list[dict] = []

    if args.compare_report and args.compare_report.is_file():
        report = json.loads(args.compare_report.read_text(encoding="utf-8"))
        needed.extend(report.get("adjudication_required", []))

    # Subjective spread within bundle-root
    for bundle in sorted(root.glob("eval-*")):
        subs = sorted(bundle.glob("subjective-grade.*.json"))
        if len(subs) < 2:
            continue
        totals = [json.loads(p.read_text())["subjective_total"] for p in subs]
        spread = max(totals) - min(totals)
        if spread >= 10:
            needed.append(
                {
                    "eval_candidate_id": bundle.name,
                    "reason": f"subjective_spread={spread}",
                }
            )

    tsv_path = out_dir / "adjudication-needed.tsv"
    with tsv_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["eval_candidate_id", "reason"])
        for row in needed:
            w.writerow([row["eval_candidate_id"], row["reason"]])

    for row in needed:
        eval_id = row["eval_candidate_id"]
        bundle = root / eval_id if (root / eval_id).is_dir() else None
        if not bundle:
            continue
        pkg = out_dir / f"{eval_id}-adjudication-prompt.md"
        parts = [ADJ_PROMPT.read_text(encoding="utf-8"), "\n\n---\n\n"]
        for name in ("candidate.md", "objective-grade.json"):
            p = bundle / name
            if p.is_file():
                parts.append(f"## {name}\n\n{p.read_text(encoding='utf-8')}\n\n")
        for sub in sorted(bundle.glob("subjective-grade.*.json")):
            parts.append(f"## {sub.name}\n\n```json\n{sub.read_text(encoding='utf-8')}\n```\n\n")
        pkg.write_text("".join(parts), encoding="utf-8")

    if args.validate_response:
        data = json.loads(args.validate_response.read_text(encoding="utf-8"))
        if data.get("schema_version") != "benchmark-adjudication.v1":
            print("error: invalid adjudication schema_version", file=sys.stderr)
            sys.exit(2)
        out = out_dir / f"{data.get('eval_candidate_id', 'unknown')}-adjudication.json"
        out.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        print(f"validated and wrote {out}")

    print(f"wrote {tsv_path} ({len(needed)} rows)")


if __name__ == "__main__":
    main()
