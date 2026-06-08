#!/usr/bin/env python3
"""Inject canonical/obj/subj columns into agent-roi-benchmark-results.md tables."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from canonical_scores_lib import (  # noqa: E402
    STAGE_CONFIG,
    fmt_score,
    load_all_alias_runs,
    load_stage,
    load_stage1e,
    lookup_pipeline_score,
    na_cells,
)

STAGE_GRADER_NOTES = {
    "stage-1-canonical-v1": (
        "Canonical columns: `score_set_id=stage-1-canonical-v1`, grader `cursor-llm-blind-v1`\n"
        "(true LLM blind review of each bundle's `subjective-prompt.md` via `model-roi-grader-v1`).\n"
        "Legacy /100 columns retain the original holistic blind grades for comparison."
    ),
    "stage-1c-canonical-v1": (
        "Canonical columns: `score_set_id=stage-1c-canonical-v1`, grader `cursor-llm-blind-v1`\n"
        "(true LLM blind review of each bundle's `subjective-prompt.md` via `model-roi-grader-v1`)."
    ),
    "stage-1d-canonical-v1": (
        "Canonical columns: `score_set_id=stage-1d-canonical-v1`, grader `cursor-llm-blind-v1`\n"
        "(true LLM blind review of each bundle's `subjective-prompt.md` via `model-roi-grader-v1`)."
    ),
    "stage-1-pipeline-canonical-v1": (
        "Canonical columns: `score_set_id=stage-1-pipeline-canonical-v1`, grader `cursor-llm-blind-v1`\n"
        "(true LLM blind review; pipeline bundles use `rubric.pipeline.v1` including coordination)."
    ),
}
from roi_format_lib import parse_pipeline_tail, parse_row  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
RESULTS = REPO / ".context/benchmarks/model-roi/results/agent-roi-benchmark-results.md"

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


def inject_monolithic_table(lines: list[str], start: int, lookup: dict) -> int:
    header_idx = None
    for i in range(start, len(lines)):
        if lines[i].startswith("| Alias | Run | Gates |"):
            header_idx = i
            break
    if header_idx is None:
        return start

    if "Canonical /100" not in lines[header_idx]:
        lines[header_idx] = (
            "| Alias | Run | Gates | Correctness /30 | Quality /25 | Process /20 "
            "| Reliability /15 | Latency /10 | Legacy /100 | Canonical /100 "
            "| Objective /65 | Subjective /35 | score_set_id | Wall s | Cost status | Summary |"
        )
        if header_idx + 1 < len(lines) and lines[header_idx + 1].startswith("|---"):
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
        if "Canonical /100" in lines[header_idx] and len(parts) >= 13:
            new_parts = parts[:8] + [
                legacy,
                fmt_score(scores["canonical"]),
                fmt_score(scores["objective"]),
                fmt_score(scores["subjective"]),
                f"`{scores['score_set_id']}`" if scores["score_set_id"] != "N/A" else "N/A",
            ] + parts[13:]
        else:
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


def inject_stage1c_table(lines: list[str], start: int, lookup: dict) -> int:
    header_idx = None
    for i in range(start, len(lines)):
        if lines[i].startswith("| Injected alias | Baseline alias |"):
            header_idx = i
            break
    if header_idx is None:
        return start

    if "Canonical /100" not in lines[header_idx]:
        lines[header_idx] = (
            "| Injected alias | Baseline alias | Correctness /30 | Quality /25 | Process /20 "
            "| Reliability /15 | Latency /10 | Legacy /100 | Canonical /100 | Objective /65 "
            "| Subjective /35 | score_set_id | Score delta | Wall s | Wall delta | Marginal cost USD "
            "| Marginal ROI | ROI delta | Summary |"
        )
        if header_idx + 1 < len(lines) and lines[header_idx + 1].startswith("|---"):
            lines[header_idx + 1] = (
                "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---|"
            )

    i = header_idx + 2
    while i < len(lines) and lines[i].startswith("| `"):
        parts = [p.strip() for p in lines[i].strip("|").split("|")]
        alias = parts[0].strip("`")
        legacy = parts[7]
        scores = lookup.get((alias, 1), na_cells())
        if len(parts) >= 19:
            tail = parts[12:]
        else:
            tail = parts[8:]
        new_parts = parts[:7] + [
            legacy,
            fmt_score(scores["canonical"]),
            fmt_score(scores["objective"]),
            fmt_score(scores["subjective"]),
            f"`{scores['score_set_id']}`" if scores["score_set_id"] != "N/A" else "N/A",
        ] + tail
        lines[i] = "| " + " | ".join(new_parts) + " |"
        i += 1
    return i


def inject_stage1d_table(lines: list[str], start: int, lookup: dict) -> int:
    header_idx = None
    for i in range(start, len(lines)):
        if lines[i].startswith("| Alias | Platform / planner"):
            header_idx = i
            break
    if header_idx is None:
        return start

    if "Canonical /100" not in lines[header_idx]:
        lines[header_idx] = (
            "| Alias | Platform / planner -> implementer | Correctness /30 | Quality /25 "
            "| Process /20 | Reliability /15 | Latency /10 | Legacy /100 | Canonical /100 "
            "| Objective /65 | Subjective /35 | score_set_id | Wall s | Marginal cost USD "
            "| Marginal ROI | Summary |"
        )
        if header_idx + 1 < len(lines) and lines[header_idx + 1].startswith("|---"):
            lines[header_idx + 1] = (
                "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|"
            )

    i = header_idx + 2
    while i < len(lines) and lines[i].startswith("| `"):
        parts = [p.strip() for p in lines[i].strip("|").split("|")]
        alias = parts[0].strip("`")
        if not alias.endswith("-duo"):
            i += 1
            continue
        legacy = parts[7]
        scores = lookup.get((alias, 1), na_cells())
        tail = parts[12:] if len(parts) > 12 else parts[8:]
        new_parts = parts[:7] + [
            legacy,
            fmt_score(scores["canonical"]),
            fmt_score(scores["objective"]),
            fmt_score(scores["subjective"]),
            f"`{scores['score_set_id']}`" if scores["score_set_id"] != "N/A" else "N/A",
        ] + tail
        lines[i] = "| " + " | ".join(new_parts) + " |"
        i += 1
    return i


def inject_pipeline_table(lines: list[str], start: int, task_class: str) -> int:
    header_idx = None
    for i in range(start, len(lines)):
        if lines[i].startswith("| Alias | Platform / model | Run |"):
            header_idx = i
            break
    if header_idx is None:
        return start

    lines[header_idx] = (
        "| Alias | Platform / model | Run | Gates | Correctness /30 | Quality /20 "
        "| Process /15 | Reliability /15 | Coordination /10 | Latency /10 | Legacy /100 "
        "| Canonical /100 | Objective /58 | Subjective /42 | score_set_id | Wall s | Diff "
        "| Cost USD | ROI | Summary |"
    )
    if header_idx + 1 < len(lines) and lines[header_idx + 1].startswith("|---"):
        lines[header_idx + 1] = (
            "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---:|---|"
        )

    i = header_idx + 2
    while i < len(lines) and lines[i].startswith("| `"):
        parts = parse_row(lines[i])
        alias = parts[0].strip("`")
        run_s = parts[2].strip("`")
        run = int(run_s[1:]) if run_s.startswith("r") and run_s[1:].isdigit() else 1
        legacy = parts[10]
        scores = lookup_pipeline_score(task_class, alias, run) or na_cells()
        wall, diff, cost_s, roi_s, summary = parse_pipeline_tail(parts)
        lines[i] = (
            "| "
            + " | ".join(
                parts[:10]
                + [
                    legacy,
                    fmt_score(scores["canonical"]),
                    fmt_score(scores["objective"]),
                    fmt_score(scores["subjective"]),
                    f"`{scores['score_set_id']}`" if scores["score_set_id"] != "N/A" else "N/A",
                    wall,
                    diff,
                    cost_s,
                    roi_s,
                    summary,
                ]
            )
            + " |"
        )
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

    if "Legacy /100" not in lines[header_idx]:
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


def strip_legacy_grader_paragraphs(lines: list[str]) -> None:
    """Remove superseded results-md-legacy-v1 attribution blocks."""
    i = 0
    while i < len(lines):
        if lines[i].startswith("Legacy category columns are the original holistic blind grades"):
            end = i + 1
            while end < len(lines) and (
                lines[end].startswith("objective, and subjective columns")
                or lines[end].startswith("(`rubric.v1`")
                or (lines[end].strip() == "" and end + 1 < len(lines) and lines[end + 1].startswith("(`rubric.v1`"))
            ):
                end += 1
            if end < len(lines) and "results-md-legacy" in lines[end - 1]:
                del lines[i:end]
                continue
        i += 1


def inject_grader_notes(lines: list[str]) -> None:
    """Insert or refresh canonical grader attribution before scored tables."""
    markers = [
        ("## Class A: `opfit-281-class-a-premerge`", "stage-1-canonical-v1"),
        ("## Class B: `opfit-326-class-b-premerge`", "stage-1-canonical-v1"),
        ("### Stage 1C Class A: `opfit-281-class-a-premerge-context-injected`", "stage-1c-canonical-v1"),
        ("### Stage 1D Class A: `opfit-281-class-a-premerge`", "stage-1d-canonical-v1"),
        ("### Stage 1D Class B: `opfit-326-class-b-premerge`", "stage-1d-canonical-v1"),
        ("### Issue #376 Class A: `opfit-281-class-a-premerge-pipeline`", "stage-1-pipeline-canonical-v1"),
        ("### Issue #376 Class B: `opfit-326-class-b-premerge-pipeline`", "stage-1-pipeline-canonical-v1"),
    ]
    for marker, score_set in markers:
        note = STAGE_GRADER_NOTES.get(score_set)
        if not note:
            continue
        try:
            idx = next(i for i, ln in enumerate(lines) if ln == marker)
        except StopIteration:
            continue
        j = idx + 1
        while j < len(lines) and lines[j].strip() == "":
            j += 1
        if j < len(lines) and lines[j].startswith("Canonical columns:"):
            k = j + 1
            while k < len(lines) and lines[k].startswith("("):
                k += 1
            lines[j:k] = note.splitlines()
        else:
            lines.insert(j, note)
            k = j + len(note.splitlines())
        while k < len(lines) and lines[k].startswith("Legacy category columns"):
            end = k + 1
            while end < len(lines) and not lines[end].startswith("*Table sort:") and not lines[
                end
            ].startswith("| `") and not lines[end].startswith("##"):
                if lines[end].strip() == "":
                    end += 1
                    continue
                if (
                    "results-md-legacy" in lines[end]
                    or lines[end].startswith("objective, and subjective columns")
                    or lines[end].startswith("(`rubric.v1`")
                ):
                    end += 1
                    continue
                break
            del lines[k:end]


def update_score_set_section(text: str) -> str:
    old_fragments = [
        "Stage 1C/1D/pipeline rows remain legacy-only until regraded.",
        "Stage 1 monolithic Class A/B rows and Stage 1E CP-1 rows now include canonical",
    ]
    new = (
        "- Stage 1 monolithic, Stage 1C, Stage 1D, pipeline (#376), and Stage 1E CP-1 rows\n"
        "  support canonical `score_set_id`, objective, and subjective columns alongside legacy\n"
        "  category scores once regraded via the `regrade-stage-*.sh` scripts."
    )
    if any(f in text for f in old_fragments):
        lines = text.splitlines()
        out = []
        skip_next = False
        for line in lines:
            if line.strip().startswith("- Stage 1 monolithic") and "canonical" in line:
                if not out or out[-1] != new:
                    out.append(new)
                skip_next = True
                continue
            if skip_next and line.strip().startswith("category scores"):
                skip_next = False
                continue
            if "Stage 1C/1D/pipeline rows remain legacy-only" in line:
                continue
            out.append(line)
        text = "\n".join(out) + "\n"
    elif new not in text:
        text = text.replace(
            "- Exploratory Cursor/Codex regrades are separate cohorts",
            f"{new}\n- Exploratory Cursor/Codex regrades are separate cohorts",
            1,
        )
    return text


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else RESULTS
    lines = path.read_text(encoding="utf-8").splitlines()

    stage1 = load_stage(STAGE_CONFIG["1"]["score_set"], STAGE_CONFIG["1"]["tasks"])
    stage1c = load_stage(STAGE_CONFIG["1c"]["score_set"], STAGE_CONFIG["1c"]["tasks"])
    stage1d = load_stage(STAGE_CONFIG["1d"]["score_set"], STAGE_CONFIG["1d"]["tasks"])
    stage1e = load_stage1e()

    idx = 0
    while idx < len(lines):
        line = lines[idx]
        if line.startswith("## Class A: `opfit-281-class-a-premerge`"):
            idx = inject_monolithic_table(lines, idx, stage1)
        elif line.startswith("## Class B: `opfit-326-class-b-premerge`"):
            idx = inject_monolithic_table(lines, idx, stage1)
        elif line.startswith("### Stage 1C Class A:") or line.startswith("### Stage 1C Class B:"):
            idx = inject_stage1c_table(lines, idx, stage1c)
        elif line.startswith("### Stage 1D Class A:") or line.startswith("### Stage 1D Class B:"):
            idx = inject_stage1d_table(lines, idx, stage1d)
        elif line.startswith("### Issue #376 Class A:"):
            idx = inject_pipeline_table(lines, idx, "A")
        elif line.startswith("### Issue #376 Class B:"):
            idx = inject_pipeline_table(lines, idx, "B")
        elif line.startswith("### Stage 1E Class A:"):
            idx = inject_stage1e_table(lines, idx, VARIANT_TO_GROUP_A, stage1e)
        elif line.startswith("### Stage 1E Class B:"):
            idx = inject_stage1e_table(lines, idx, VARIANT_TO_GROUP_B, stage1e)
        else:
            idx += 1

    inject_grader_notes(lines)
    strip_legacy_grader_paragraphs(lines)
    out = update_score_set_section("\n".join(lines) + "\n")
    path.write_text(out, encoding="utf-8")
    print(f"updated {path}")


if __name__ == "__main__":
    main()
