#!/usr/bin/env python3
"""Recompute Stage 1C score/ROI deltas from canonical numerators."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from canonical_scores_lib import lookup_stage_score  # noqa: E402
from roi_format_lib import fmt_delta, fmt_roi, parse_cost, parse_row  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
RESULTS = REPO / ".context/benchmarks/model-roi/results/agent-roi-benchmark-results.md"


def col_index(header: list[str], name: str) -> int | None:
    for i, h in enumerate(header):
        if name in h:
            return i
    return None


def load_marginal_costs(lines: list[str], section: str) -> dict[str, float]:
    """Parse one Class marginal ROI table for baseline alias costs."""
    costs: dict[str, float] = {}
    in_marginal = False
    cost_idx = None
    for line in lines:
        if line.startswith(section):
            in_marginal = True
            cost_idx = None
            continue
        if in_marginal and line.startswith("### ") and section not in line:
            break
        if in_marginal and line.startswith("| Alias | Platform/model |"):
            header = parse_row(line)
            cost_idx = col_index(header, "Marginal cost USD")
            continue
        if in_marginal and line.startswith("| `") and cost_idx is not None:
            parts = parse_row(line)
            if len(parts) <= cost_idx:
                continue
            alias = parts[0].strip("`")
            cost = parse_cost(parts[cost_idx])
            if cost is not None:
                costs[alias] = cost
    return costs


def process_table(
    lines: list[str],
    start: int,
    task_class: str,
    marginal_costs: dict[str, float],
) -> int:
    header_idx = None
    for j in range(start, min(start + 12, len(lines))):
        if lines[j].startswith("| Injected alias | Baseline alias |"):
            header_idx = j
            break
    if header_idx is None:
        return start + 1

    header = parse_row(lines[header_idx])
    idx_score_d = col_index(header, "Score delta")
    idx_cost = col_index(header, "Marginal cost USD")
    idx_roi = col_index(header, "Marginal ROI")
    idx_roi_d = col_index(header, "ROI delta")

    i = header_idx + 2
    while i < len(lines) and lines[i].startswith("| `"):
        parts = parse_row(lines[i])
        if len(parts) < 12:
            break
        inj = parts[0].strip("`")
        base = parts[1].strip("`")
        inj_row = lookup_stage_score("1c", task_class, inj, 1)
        base_row = lookup_stage_score("1", task_class, base, 1)
        canonical = int(inj_row["canonical"]) if inj_row else None
        base_c = int(base_row["canonical"]) if base_row else None
        inj_cost = parse_cost(parts[idx_cost]) if idx_cost is not None else None
        base_cost = marginal_costs.get(base)

        if canonical is not None and base_c is not None and idx_score_d is not None:
            parts[idx_score_d] = fmt_delta(float(canonical - base_c))
        if canonical is not None and inj_cost and idx_roi is not None:
            parts[idx_roi] = fmt_roi(canonical / inj_cost)
        if (
            canonical is not None
            and base_c is not None
            and inj_cost
            and base_cost
            and idx_roi_d is not None
        ):
            inj_roi = canonical / inj_cost
            base_roi = base_c / base_cost
            parts[idx_roi_d] = fmt_delta(inj_roi - base_roi)
        lines[i] = "| " + " | ".join(parts) + " |"
        i += 1
    return i


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else RESULTS
    lines = path.read_text(encoding="utf-8").splitlines()
    costs_a = load_marginal_costs(lines, "### Class A Marginal ROI")
    costs_b = load_marginal_costs(lines, "### Class B Marginal ROI")

    idx = 0
    while idx < len(lines):
        if lines[idx].startswith("### Stage 1C Class A:"):
            idx = process_table(lines, idx, "A", costs_a)
        elif lines[idx].startswith("### Stage 1C Class B:"):
            idx = process_table(lines, idx, "B", costs_b)
        else:
            idx += 1

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"updated Stage 1C ROI in {path} (cost keys: A={len(costs_a)} B={len(costs_b)})")


if __name__ == "__main__":
    main()
