#!/usr/bin/env python3
"""Inject canonical/obj/subj columns into agent-roi-benchmark-results.md tables."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
RESULTS = REPO / ".context/benchmarks/model-roi/results/agent-roi-benchmark-results.md"
BUNDLES = REPO / "scripts/benchmark/grade-bundles"

STAGE1_SCORE_SET = "stage-1-canonical-v1"
STAGE1E_PREFIX = "stage-1e-canonical-v1"
STAGE1E_GRADER = "stage-1e-locked-v1"

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


def load_sealed_map(path: Path) -> dict[str, tuple[str, int]]:
    out: dict[str, tuple[str, int]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or not line.strip() or line.startswith("eval_candidate_id"):
            continue
        cols = line.split("\t")
        out[cols[0]] = (cols[2], int(cols[3]))
    return out


def load_final_grades(bundle_root: Path) -> dict[str, dict]:
    fg = json.loads((bundle_root / "final-grades.json").read_text(encoding="utf-8"))
    sealed = load_sealed_map(bundle_root / "sealed-eval-map.tsv")
    by_alias_run: dict[tuple[str, int], dict] = {}
    by_eval: dict[str, dict] = {}
    for row in fg["rows"]:
        eid = row["eval_candidate_id"]
        payload = {
            "canonical": row["final_total"],
            "objective": row["objective_total"],
            "subjective": row["subjective_total"],
            "score_set_id": fg["score_set_id"],
        }
        by_eval[eid] = payload
        if eid in sealed:
            by_alias_run[sealed[eid]] = payload
    return {"by_alias_run": by_alias_run, "by_eval": by_eval, "sealed": sealed}


def load_stage1() -> dict[str, dict[tuple[str, int], dict]]:
    out = {}
    for task in ("opfit-281-class-a-premerge", "opfit-326-class-b-premerge"):
        root = BUNDLES / task / STAGE1_SCORE_SET
        out[task] = load_final_grades(root)["by_alias_run"]
    return out


def load_stage1e() -> dict[tuple[str, str], dict]:
    """Key: (run_group, alias) e.g. ('ctx-a-baseline', 'ctx-cur')."""
    out: dict[tuple[str, str], dict] = {}
    groups = list(VARIANT_TO_GROUP_A.values()) + list(VARIANT_TO_GROUP_B.values())
    for group in groups:
        task = (
            "opfit-281-class-a-premerge"
            if group.startswith("ctx-a-")
            else "opfit-326-class-b-premerge"
        )
        score_set = f"{STAGE1E_PREFIX}-{group}"
        root = BUNDLES / task / score_set
        if not (root / "final-grades.json").is_file():
            continue
        data = load_final_grades(root)
        for eid, (alias, _run) in data["sealed"].items():
            if eid in data["by_eval"]:
                out[(group, alias)] = data["by_eval"][eid]
    return out


def na_cells() -> dict:
    return {
        "canonical": "N/A",
        "objective": "N/A",
        "subjective": "N/A",
        "score_set_id": "N/A",
    }


def fmt_score(v) -> str:
    return str(v) if v != "N/A" else "N/A"


def inject_monolithic_table(lines: list[str], start: int, task: str, lookup: dict) -> int:
    """Return index after table."""
    header_idx = None
    for i in range(start, len(lines)):
        if lines[i].startswith("| Alias | Run | Gates |"):
            header_idx = i
            break
    if header_idx is None:
        return start

    old_header = lines[header_idx]
    if "Canonical /100" in old_header:
        return header_idx + 1

    lines[header_idx] = (
        "| Alias | Run | Gates | Correctness /30 | Quality /25 | Process /20 "
        "| Reliability /15 | Latency /10 | Legacy /100 | Canonical /100 "
        "| Objective /65 | Subjective /35 | score_set_id | Wall s | Cost status | Summary |"
    )
    sep = lines[header_idx + 1]
    if sep.startswith("|---"):
        lines[header_idx + 1] = (
            "|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|"
        )

    i = header_idx + 2
    while i < len(lines) and lines[i].startswith("| `"):
        parts = [p.strip() for p in lines[i].strip("|").split("|")]
        alias = parts[0].strip("`")
        run = int(parts[1])
        legacy = parts[8]
        scores = lookup.get((alias, run), na_cells())
        new_parts = parts[:8] + [
            legacy,
            fmt_score(scores["canonical"]),
            fmt_score(scores["objective"]),
            fmt_score(scores["subjective"]),
            f"`{scores['score_set_id']}`" if scores["score_set_id"] != "N/A" else "N/A",
        ] + parts[9:]
        lines[i] = "| " + " | ".join(new_parts) + " |"
        i += 1
    return i


def inject_stage1e_table(
    lines: list[str], start: int, variant_map: dict[str, str], lookup: dict
) -> int:
    header_idx = None
    for i in range(start, len(lines)):
        if lines[i].startswith("| Alias | Platform/model |"):
            header_idx = i
            break
    if header_idx is None:
        return start

    old_header = lines[header_idx]
    needs_refresh = "Canonical /100" in old_header and header_idx + 2 < len(lines) and "N/A" in lines[header_idx + 2]
    if "Canonical /100" in old_header and not needs_refresh:
        return header_idx + 1

    if "Legacy /100" not in old_header:
        lines[header_idx] = (
            "| Alias | Platform/model | Observed model | Context variant | Pack files | Pack bytes "
            "| Correctness /30 | Quality /25 | Process /20 | Reliability /15 | Latency /10 "
            "| Legacy /100 | Canonical /100 | Objective /65 | Subjective /35 | score_set_id "
            "| Score delta | Wall s | Cost USD | ROI | ROI delta | Summary |"
        )
    if header_idx + 1 < len(lines) and lines[header_idx + 1].startswith("|---"):
        lines[header_idx + 1] = (
            "|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
            "---:|---:|---:|---:|---|"
        )

    i = header_idx + 2
    while i < len(lines) and lines[i].startswith("| `"):
        parts = [p.strip() for p in lines[i].strip("|").split("|")]
        alias = parts[0].strip("`")
        variant = parts[3].strip("`")
        legacy = parts[11]
        group = variant_map.get(variant)
        scores = lookup.get((group, alias), na_cells()) if group else na_cells()
        tail_start = 16 if len(parts) >= 16 else 12
        new_parts = parts[:11] + [
            legacy,
            fmt_score(scores["canonical"]),
            fmt_score(scores["objective"]),
            fmt_score(scores["subjective"]),
            f"`{scores['score_set_id']}`" if scores["score_set_id"] != "N/A" else "N/A",
        ] + parts[tail_start:]
        lines[i] = "| " + " | ".join(new_parts) + " |"
        i += 1
    return i


def update_score_set_section(text: str) -> str:
    old = (
        "- Stage 1E context-pack conclusions require regrading under one canonical score set\n"
        "  before routing decisions."
    )
    new = (
        "- Stage 1 monolithic Class A/B rows and Stage 1E CP-1 rows now include canonical\n"
        "  `score_set_id`, objective (/65), and subjective (/35) columns alongside legacy\n"
        "  category scores. Stage 1C/1D/pipeline rows remain legacy-only until regraded."
    )
    if old in text:
        text = text.replace(old, new)
    return text


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else RESULTS
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    stage1 = load_stage1()
    stage1e = load_stage1e()

    idx = 0
    while idx < len(lines):
        line = lines[idx]
        if line.startswith("## Class A: `opfit-281-class-a-premerge`"):
            idx = inject_monolithic_table(
                lines, idx, "opfit-281-class-a-premerge", stage1["opfit-281-class-a-premerge"]
            )
        elif line.startswith("## Class B: `opfit-326-class-b-premerge`"):
            idx = inject_monolithic_table(
                lines, idx, "opfit-326-class-b-premerge", stage1["opfit-326-class-b-premerge"]
            )
        elif line.startswith("### Stage 1E Class A:"):
            idx = inject_stage1e_table(lines, idx, VARIANT_TO_GROUP_A, stage1e)
        elif line.startswith("### Stage 1E Class B:"):
            idx = inject_stage1e_table(lines, idx, VARIANT_TO_GROUP_B, stage1e)
        else:
            idx += 1

    out = update_score_set_section("\n".join(lines) + "\n")
    path.write_text(out, encoding="utf-8")
    print(f"updated {path}")


if __name__ == "__main__":
    main()
