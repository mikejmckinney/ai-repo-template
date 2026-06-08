#!/usr/bin/env python3
"""Recompute sealed marginal ROI tables from canonical /100 numerators."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from canonical_scores_lib import lookup_marginal_score  # noqa: E402
from roi_format_lib import fmt_roi, parse_cost, parse_row  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
RESULTS = REPO / ".context/benchmarks/model-roi/results/agent-roi-benchmark-results.md"

MARGINAL_HEADER = (
    "| Alias | Platform/model | Legacy /100 | Canonical /100 | Objective | Subjective "
    "| Marginal cost USD | Marginal ROI | Cost caveat |"
)
MARGINAL_SEP = "|---|---|---:|---:|---:|---:|---:|---:|---|"


def find_marginal_header(lines: list[str], start: int) -> int | None:
    for j in range(start + 1, len(lines)):
        line = lines[j]
        if line.startswith("## "):
            break
        if line.startswith("### ") and j != start:
            break
        if line.startswith("| Alias | Platform/model |"):
            return j
    return None


def process_marginal_table(lines: list[str], start: int, task_class: str) -> int:
    header_idx = find_marginal_header(lines, start)
    if header_idx is None:
        return start + 1

    lines[header_idx] = MARGINAL_HEADER
    if header_idx + 1 < len(lines) and lines[header_idx + 1].startswith("|---"):
        lines[header_idx + 1] = MARGINAL_SEP

    header = parse_row(lines[header_idx])

    def col(name: str) -> int | None:
        for k, h in enumerate(header):
            if name in h:
                return k
        return None

    i = header_idx + 2
    while i < len(lines) and lines[i].startswith("| `") and not lines[i].startswith("| Alias |"):
        parts = parse_row(lines[i])
        if len(parts) < 6:
            break
        alias = parts[0].strip("`")
        platform = parts[1]
        if len(parts) >= 9:
            legacy, cost_s, caveat = parts[2], parts[6], parts[8]
        elif len(parts) >= 6:
            legacy, cost_s, caveat = parts[2], parts[3], parts[5]
        else:
            legacy, cost_s, caveat = parts[2], parts[4], parts[6]

        row = lookup_marginal_score(task_class, alias)
        canonical_cell = str(row["canonical"]) if row else "N/A"
        obj_cell = str(row["objective"]) if row else "N/A"
        sub_cell = str(row["subjective"]) if row else "N/A"
        cost = parse_cost(cost_s)
        roi_cell = "N/A"
        if row and cost:
            roi_cell = fmt_roi(int(row["canonical"]) / cost)
        lines[i] = (
            f"| {parts[0]} | {platform} | {legacy} | {canonical_cell} | "
            f"{obj_cell} | {sub_cell} | {cost_s} | {roi_cell} | {caveat} |"
        )
        i += 1
    return max(i, start + 1)


def update_note(lines: list[str]) -> None:
    note = (
        "Numeric marginal ROI uses **canonical /100** numerators when `final-grades.json` "
        "exists for the alias (`stage-1-canonical-v1`, `stage-1c-canonical-v1`, "
        "`stage-1d-canonical-v1`, `stage-1-pipeline-canonical-v1`). Extended-stage aliases "
        "(`-pipe`, `-injected`, `-duo`) resolve within the matching task class so Class A "
        "and Class B rows do not collide on run index. Legacy holistic scores remain in the "
        "Legacy /100 column; Objective and Subjective are from the same compiled canonical score set."
    )
    for i, line in enumerate(lines):
        if "Numeric marginal ROI uses **canonical /100**" in line:
            lines[i] = note
            return
    for i, line in enumerate(lines):
        if line.startswith("Stage 1 has no measured review-loop costs"):
            lines.insert(i + 1, "")
            lines.insert(i + 2, note)
            return


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else RESULTS
    lines = path.read_text(encoding="utf-8").splitlines()

    idx = 0
    while idx < len(lines):
        if lines[idx].startswith("### Class A Marginal ROI"):
            idx = process_marginal_table(lines, idx, "A")
        elif lines[idx].startswith("### Class B Marginal ROI"):
            idx = process_marginal_table(lines, idx, "B")
        else:
            idx += 1

    update_note(lines)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"updated marginal ROI in {path} (task-class-scoped lookup)")


if __name__ == "__main__":
    main()
