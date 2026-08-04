#!/usr/bin/env python3
"""Recompute Stage 1E ROI / deltas from canonical scores and existing Cost USD columns."""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
RESULTS = REPO / "docs/benchmarks/agent-roi-benchmark-results.md"

VARIANT_TO_GROUP_A = {
    "baseline": "ctx-a-baseline",
    "full-rules-injected": "ctx-a-full-rules",
    "pack:core-min": "ctx-a-core-min",
    "pack:class-a-process": "ctx-a-class-a-process",
}
VARIANT_TO_GROUP_B = {
    "baseline": "ctx-b-baseline",
    "full-rules-injected": "ctx-b-full-rules",
    "pack:core-min": "ctx-b-core-min",
    "pack:class-b-implementation": "ctx-b-class-b-implementation",
}

COMPARISON_ROWS_A = [
    ("A", "baseline"),
    ("A", "pack:class-a-process"),
    ("A", "full-rules-injected"),
    ("A", "pack:core-min"),
]
COMPARISON_ROWS_B = [
    ("B", "pack:core-min"),
    ("B", "full-rules-injected"),
    ("B", "pack:class-b-implementation"),
    ("B", "baseline"),
]

# scope_noise / process_miss from locked TSV (unchanged)
COMPARISON_META = {
    ("A", "baseline"): (0, 1, "**Default for Class A** — best mean ROI; `ctx-gem` canonical leader"),
    ("A", "pack:class-a-process"): (1, 1, "Optional **cursor-only** pack — strong cursor ROI vs baseline"),
    ("A", "full-rules-injected"): (0, 1, "High `ctx-gem` ROI but tied mean score; avoid default injection"),
    ("A", "pack:core-min"): (2, 2, "Not recommended — weaker mean canonical score on both aliases"),
    ("B", "pack:core-min"): (1, 0, "**Default targeted pack for Class B** — best mean ROI; near top canonical scores"),
    ("B", "full-rules-injected"): (2, 1, "Highest `ctx-gem` canonical score but ~2× mean cost vs `core-min`"),
    ("B", "pack:class-b-implementation"): (4, 3, "Not recommended"),
    ("B", "baseline"): (5, 4, "Under-delivered on this task without targeted context"),
}


def parse_cost(s: str) -> float:
    return float(s.strip().replace("$", "").replace("`", ""))


def fmt_cost(v: float) -> str:
    return f"`${v:.6f}`"


def fmt_roi(v: float) -> str:
    return f"`{v:.2f}`"


def fmt_delta(v: float) -> str:
    if abs(v) < 0.005:
        return "0"
    sign = "+" if v > 0 else ""
    return f"{sign}{v:.2f}"


def parse_row(line: str) -> list[str]:
    return [p.strip() for p in line.strip("|").split("|")]


def is_stage1e_row(parts: list[str]) -> bool:
    canonical = parts[12].strip("`") if len(parts) > 12 else ""
    cost = parts[18] if len(parts) > 18 else ""
    return (
        len(parts) >= 22
        and parts[0].startswith("`ctx-")
        and canonical.isdigit()
        and ("$" in cost)
    )


def process_table(lines: list[str], start: int, task_class: str) -> int:
    header_idx = None
    for j in range(start, min(start + 12, len(lines))):
        if lines[j].startswith("| Alias | Platform/model |"):
            header_idx = j
            break
    if header_idx is None:
        return start + 1
    i = header_idx + 2
    rows: list[dict] = []
    while i < len(lines) and lines[i].startswith("| `ctx-"):
        parts = parse_row(lines[i])
        if not is_stage1e_row(parts):
            i += 1
            continue
        rows.append(
            {
                "i": i,
                "parts": parts,
                "alias": parts[0].strip("`"),
                "variant": parts[3].strip("`"),
                "canonical": int(parts[12].strip("`")),
                "cost": parse_cost(parts[18]),
            }
        )
        i += 1

    baseline_by_alias: dict[str, dict] = {}
    for row in rows:
        if row["variant"] == "baseline":
            baseline_by_alias[row["alias"]] = row

    for row in rows:
        base = baseline_by_alias.get(row["alias"])
        roi = row["canonical"] / row["cost"] if row["cost"] > 0 else 0.0
        if base:
            score_delta = row["canonical"] - base["canonical"]
            base_roi = base["canonical"] / base["cost"] if base["cost"] > 0 else 0.0
            roi_delta = roi - base_roi if row["variant"] != "baseline" else 0.0
        else:
            score_delta = 0
            roi_delta = 0.0

        parts = row["parts"]
        parts[16] = fmt_delta(float(score_delta))
        parts[19] = fmt_roi(roi)
        parts[20] = fmt_delta(roi_delta)
        lines[row["i"]] = "| " + " | ".join(parts) + " |"
        row["roi"] = roi
        row["score_delta"] = score_delta
        row["roi_delta"] = roi_delta

    # stash for comparison table
    if task_class == "A":
        process_table.last_a = rows  # type: ignore[attr-defined]
    else:
        process_table.last_b = rows  # type: ignore[attr-defined]
    return i


def build_comparison(
  rows: list[dict], variants: list[str]
) -> dict[str, tuple[float, float, float]]:
    out: dict[str, tuple[float, float, float]] = {}
    for variant in variants:
        subset = [r for r in rows if r["variant"] == variant]
        if not subset:
            continue
        mean_score = sum(r["canonical"] for r in subset) / len(subset)
        mean_cost = sum(r["cost"] for r in subset) / len(subset)
        mean_roi = sum(r["roi"] for r in subset) / len(subset)
        out[variant] = (mean_score, mean_cost, mean_roi)
    return out


def update_comparison_table(lines: list[str], start: int, stats: dict[tuple[str, str], tuple[float, float, float]]) -> int:
    i = start
    # find header
    while i < len(lines) and not lines[i].startswith("| Task class | Pack / variant |"):
        i += 1
    if i >= len(lines):
        return start
    i += 2
    order = COMPARISON_ROWS_A + COMPARISON_ROWS_B
    idx = 0
    while i < len(lines) and lines[i].startswith("|") and idx < len(order):
        tc, variant = order[idx]
        key = (tc, variant)
        if key in stats:
            mean_score, mean_cost, mean_roi = stats[key]
            scope, proc, rec = COMPARISON_META[key]
            lines[i] = (
                f"| {tc} | `{variant}` | {mean_score:.1f} | {fmt_cost(mean_cost)} | "
                f"{fmt_roi(mean_roi)} | {scope} | {proc} | {rec} |"
            )
        idx += 1
        i += 1
    # refresh header label if present
    for j in range(start, min(start + 12, len(lines))):
        if lines[j].startswith("| Task class | Pack / variant |"):
            lines[j] = lines[j].replace("Mean score", "Mean canonical /100")
            break
    return i


def update_notes(lines: list[str], rows_a: list[dict], rows_b: list[dict]) -> None:
    def best(rows, key):
        return max(rows, key=key)

    def find(rows_list, alias, variant):
        for r in rows_list:
            if r["alias"] == alias and r["variant"] == variant:
                return r
        return None

    gem_a_full = find(rows_a, "ctx-gem", "full-rules-injected")
    gem_b_full = find(rows_b, "ctx-gem", "full-rules-injected")
    cur_a_proc = find(rows_a, "ctx-cur", "pack:class-a-process")
    gem_b_core = find(rows_b, "ctx-gem", "pack:core-min")

    # compute mean baseline ROI class A
    a_base = [r for r in rows_a if r["variant"] == "baseline"]
    b_core = [r for r in rows_b if r["variant"] == "pack:core-min"]
    mean_a_base_roi = sum(r["roi"] for r in a_base) / len(a_base) if a_base else 0

    note_lines = {
        "Canonical-score leader (Class A):": (
            f"- **Canonical-score leader (Class A):** `full-rules-injected` / `ctx-gem` "
            f"({gem_a_full['canonical'] if gem_a_full else '?'}); legacy holistic was 92."
        ),
        "Canonical-score leader (Class B):": (
            f"- **Canonical-score leader (Class B):** `full-rules-injected` / `ctx-gem` "
            f"({gem_b_full['canonical'] if gem_b_full else '?'}); legacy holistic was 88."
        ),
        "ROI winner (Class A):": (
            f"- **ROI winner (Class A):** `baseline` on mean ROI ({fmt_roi(mean_a_base_roi)}); "
            f"per-alias peaks: `pack:class-a-process` / `ctx-cur` "
            f"({fmt_roi(cur_a_proc['roi']) if cur_a_proc else '?'}, "
            f"{fmt_delta(cur_a_proc['roi_delta']) if cur_a_proc else '?'} vs baseline) and "
            f"`full-rules-injected` / `ctx-gem` ({fmt_roi(gem_a_full['roi']) if gem_a_full else '?'}, "
            f"{fmt_delta(gem_a_full['roi_delta']) if gem_a_full else '?'} vs baseline)."
        ),
        "ROI winner (Class B):": (
            f"- **ROI winner (Class B):** `pack:core-min` / `ctx-gem` "
            f"({fmt_roi(gem_b_core['roi']) if gem_b_core else '?'}, "
            f"{fmt_delta(gem_b_core['roi_delta']) if gem_b_core else '?'} vs baseline) — "
            f"`full-rules` still leads canonical score on `ctx-gem` but trails on ROI at higher cost."
        ),
    }
    for i, line in enumerate(lines):
        for prefix, new_line in note_lines.items():
            if prefix in line and line.strip().startswith("-"):
                lines[i] = new_line
                break
        if line.startswith("Marginal cost/ROI"):
            lines[i] = (
                "Marginal cost/ROI from per-run `agent-output.jsonl` (JSON stats for Gemini; "
                "top-level `.usage` for Cursor) using Stage 1 rate cards. **ROI numerators use "
                "canonical /100 scores** (`cursor-llm-blind-v1`)."
            )
        if "`scripts/benchmark/grade-bundles/` (grader `cursor-session-stage-1e-v2`" in line:
            lines[i] = (
                "`scripts/benchmark/grade-bundles/` (grader `cursor-llm-blind-v1`, blind "
                "review of each bundle's `subjective-prompt.md` + diff)."
            )


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else RESULTS
    lines = path.read_text(encoding="utf-8").splitlines()

    idx = 0
    while idx < len(lines):
        if lines[idx].startswith("### Stage 1E Class A:"):
            idx = process_table(lines, idx, "A")
        elif lines[idx].startswith("### Stage 1E Class B:"):
            idx = process_table(lines, idx, "B")
        else:
            idx += 1

    rows_a = getattr(process_table, "last_a", [])
    rows_b = getattr(process_table, "last_b", [])

    stats: dict[tuple[str, str], tuple[float, float, float]] = {}
    for tc, variant in COMPARISON_ROWS_A:
        subset = [r for r in rows_a if r["variant"] == variant]
        if subset:
            stats[(tc, variant)] = (
                sum(r["canonical"] for r in subset) / len(subset),
                sum(r["cost"] for r in subset) / len(subset),
                sum(r["roi"] for r in subset) / len(subset),
            )
    for tc, variant in COMPARISON_ROWS_B:
        subset = [r for r in rows_b if r["variant"] == variant]
        if subset:
            stats[(tc, variant)] = (
                sum(r["canonical"] for r in subset) / len(subset),
                sum(r["cost"] for r in subset) / len(subset),
                sum(r["roi"] for r in subset) / len(subset),
            )

    for i, line in enumerate(lines):
        if line.startswith("### Context-pack comparison"):
            update_comparison_table(lines, i + 1, stats)
            break

    update_notes(lines, rows_a, rows_b)

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"updated Stage 1E ROI in {path}")
    print("\nClass B cursor snapshot:")
    for r in rows_b:
        if r["alias"] == "ctx-cur":
            print(
                f"  {r['variant']:30} canonical={r['canonical']} roi={r['roi']:.2f} "
                f"score_d={r['score_delta']:+.0f} roi_d={r['roi_delta']:+.2f}"
            )


if __name__ == "__main__":
    main()
