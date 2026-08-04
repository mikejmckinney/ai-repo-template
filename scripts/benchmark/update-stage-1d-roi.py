#!/usr/bin/env python3
"""Recompute Stage 1D marginal ROI from canonical numerators."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from canonical_scores_lib import lookup_stage_score  # noqa: E402
from roi_format_lib import fmt_roi, parse_cost, parse_row  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
RESULTS = REPO / "docs/benchmarks/agent-roi-benchmark-results.md"


def col_index(header: list[str], name: str) -> int | None:
    for i, h in enumerate(header):
        if name in h:
            return i
    return None


def process_table(lines: list[str], start: int, task_class: str) -> int:
    header_idx = None
    for j in range(start, min(start + 8, len(lines))):
        if lines[j].startswith("| Alias | Platform / planner"):
            header_idx = j
            break
    if header_idx is None:
        return start + 1

    header = parse_row(lines[header_idx])
    idx_cost = col_index(header, "Marginal cost USD")
    idx_roi = col_index(header, "Marginal ROI")

    i = header_idx + 2
    while i < len(lines) and lines[i].startswith("| `"):
        parts = parse_row(lines[i])
        alias = parts[0].strip("`")
        if not alias.endswith("-duo") or len(parts) < 12:
            break
        row = lookup_stage_score("1d", task_class, alias, 1)
        if row and idx_cost is not None and idx_roi is not None and len(parts) > idx_cost:
            cost = parse_cost(parts[idx_cost])
            if cost:
                parts[idx_roi] = fmt_roi(int(row["canonical"]) / cost)
        lines[i] = "| " + " | ".join(parts) + " |"
        i += 1
    return i


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else RESULTS
    lines = path.read_text(encoding="utf-8").splitlines()

    idx = 0
    while idx < len(lines):
        if lines[idx].startswith("### Stage 1D Class A:"):
            idx = process_table(lines, idx, "A")
        elif lines[idx].startswith("### Stage 1D Class B:"):
            idx = process_table(lines, idx, "B")
        else:
            idx += 1

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"updated Stage 1D ROI in {path}")


if __name__ == "__main__":
    main()
