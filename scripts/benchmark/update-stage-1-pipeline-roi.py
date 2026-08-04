#!/usr/bin/env python3
"""Recompute issue #376 pipeline Cost and ROI from canonical numerators."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from canonical_scores_lib import lookup_pipeline_score  # noqa: E402
from roi_format_lib import fmt_roi, parse_cost, parse_pipeline_tail, parse_row  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
RESULTS = REPO / "docs/benchmarks/agent-roi-benchmark-results.md"

PIPELINE_HEADER = (
    "| Alias | Platform / model | Run | Gates | Correctness /30 | Quality /20 "
    "| Process /15 | Reliability /15 | Coordination /10 | Latency /10 | Legacy /100 "
    "| Canonical /100 | Objective /58 | Subjective /42 | score_set_id | Wall s | Diff "
    "| Cost USD | ROI | Summary |"
)
PIPELINE_SEP = (
    "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---:|---|"
)


def process_table(lines: list[str], start: int, task_class: str) -> int:
    header_idx = None
    for j in range(start, min(start + 30, len(lines))):
        if lines[j].startswith("| Alias | Platform / model | Run |"):
            header_idx = j
            break
    if header_idx is None:
        return start + 1

    lines[header_idx] = PIPELINE_HEADER
    if header_idx + 1 < len(lines) and lines[header_idx + 1].startswith("|---"):
        lines[header_idx + 1] = PIPELINE_SEP

    i = header_idx + 2
    while i < len(lines) and lines[i].startswith("| `"):
        parts = parse_row(lines[i])
        alias = parts[0].strip("`")
        run_s = parts[2].strip("`")
        run = int(run_s[1:]) if run_s.startswith("r") and run_s[1:].isdigit() else 1
        row = lookup_pipeline_score(task_class, alias, run)
        wall, diff, cost_s, roi_s, summary = parse_pipeline_tail(parts)
        cost = parse_cost(cost_s)
        if row and cost:
            roi_s = fmt_roi(int(row["canonical"]) / cost)
        lines[i] = (
            "| "
            + " | ".join(parts[:15] + [wall, diff, cost_s, roi_s, summary])
            + " |"
        )
        i += 1
    return i


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else RESULTS
    lines = path.read_text(encoding="utf-8").splitlines()
    idx = 0
    while idx < len(lines):
        if lines[idx].startswith("### Issue #376 Class A:"):
            idx = process_table(lines, idx, "A")
        elif lines[idx].startswith("### Issue #376 Class B:"):
            idx = process_table(lines, idx, "B")
        else:
            idx += 1

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"updated pipeline ROI in {path}")


if __name__ == "__main__":
    main()
