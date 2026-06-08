#!/usr/bin/env python3
"""Recompute Stage 1D marginal ROI from canonical numerators."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from canonical_scores_lib import STAGE_CONFIG, load_stage  # noqa: E402
from roi_format_lib import fmt_roi, parse_cost, parse_row  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
RESULTS = REPO / ".context/benchmarks/model-roi/results/agent-roi-benchmark-results.md"


def process_table(lines: list[str], start: int, lookup: dict) -> int:
    header_idx = None
    for j in range(start, min(start + 8, len(lines))):
        if lines[j].startswith("| Alias | Platform / planner"):
            header_idx = j
            break
    if header_idx is None:
        return start + 1

    i = header_idx + 2
    while i < len(lines) and lines[i].startswith("| `"):
        parts = parse_row(lines[i])
        alias = parts[0].strip("`")
        if not alias.endswith("-duo") or len(parts) < 12:
            break
        row = lookup.get((alias, 1))
        cost = parse_cost(parts[14] if len(parts) > 14 else parts[9])
        if row and cost:
            parts[15 if len(parts) > 15 else 10] = fmt_roi(int(row["canonical"]) / cost)
        lines[i] = "| " + " | ".join(parts) + " |"
        i += 1
    return i


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else RESULTS
    lines = path.read_text(encoding="utf-8").splitlines()
    lookup = load_stage(STAGE_CONFIG["1d"]["score_set"], STAGE_CONFIG["1d"]["tasks"])

    idx = 0
    while idx < len(lines):
        if lines[idx].startswith("### Stage 1D Class"):
            idx = process_table(lines, idx, lookup)
        else:
            idx += 1

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"updated Stage 1D ROI in {path}")


if __name__ == "__main__":
    main()
