"""Load canonical final-grades.json rows for benchmark results sync and ROI."""

from __future__ import annotations

import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
BUNDLES = REPO / "scripts/benchmark/grade-bundles"

STAGE_CONFIG = {
    "1": {
        "score_set": "stage-1-canonical-v1",
        "tasks": ("opfit-281-class-a-premerge", "opfit-326-class-b-premerge"),
    },
    "1c": {
        "score_set": "stage-1c-canonical-v1",
        "tasks": (
            "opfit-281-class-a-premerge-context-injected",
            "opfit-326-class-b-premerge-context-injected",
        ),
    },
    "1d": {
        "score_set": "stage-1d-canonical-v1",
        "tasks": ("opfit-281-class-a-premerge", "opfit-326-class-b-premerge"),
    },
    "pipeline": {
        "score_set": "stage-1-pipeline-canonical-v1",
        "tasks": (
            "opfit-281-class-a-premerge-pipeline",
            "opfit-326-class-b-premerge-pipeline",
        ),
    },
    "1e": {
        "score_set_prefix": "stage-1e-canonical-v1",
    },
}


def load_sealed_map(path: Path) -> dict[str, tuple[str, int]]:
    out: dict[str, tuple[str, int]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or not line.strip() or line.startswith("eval_candidate_id"):
            continue
        cols = line.split("\t")
        out[cols[0]] = (cols[2], int(cols[3]))
    return out


def load_final_grades(bundle_root: Path) -> dict:
    fg = json.loads((bundle_root / "final-grades.json").read_text(encoding="utf-8"))
    sealed = load_sealed_map(bundle_root / "sealed-eval-map.tsv")
    by_alias_run: dict[tuple[str, int], dict] = {}
    by_eval: dict[str, dict] = {}
    for row in fg["rows"]:
        if not row.get("complete"):
            continue
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
    return {
        "by_alias_run": by_alias_run,
        "by_eval": by_eval,
        "sealed": sealed,
        "score_set_id": fg["score_set_id"],
    }


def load_stage(score_set: str, tasks: tuple[str, ...]) -> dict[tuple[str, int], dict]:
    out: dict[tuple[str, int], dict] = {}
    for task in tasks:
        root = BUNDLES / task / score_set
        if not (root / "final-grades.json").is_file():
            continue
        out.update(load_final_grades(root)["by_alias_run"])
    return out


def load_stage1e() -> dict[tuple[str, str], dict]:
    """Key: (run_group, alias) e.g. ('ctx-a-baseline', 'ctx-cur')."""
    variant_to_group_a = {
        "baseline": "ctx-a-baseline",
        "full-rules-injected": "ctx-a-full-rules",
        "pack:core-min": "ctx-a-core-min",
        "pack:class-a-process": "ctx-a-class-a-process",
    }
    variant_to_group_b = {
        "baseline": "ctx-b-baseline",
        "full-rules-injected": "ctx-b-full-rules",
        "pack:core-min": "ctx-b-core-min",
        "pack:class-b-implementation": "ctx-b-class-b-implementation",
    }
    prefix = STAGE_CONFIG["1e"]["score_set_prefix"]
    out: dict[tuple[str, str], dict] = {}
    for group in list(variant_to_group_a.values()) + list(variant_to_group_b.values()):
        task = (
            "opfit-281-class-a-premerge"
            if group.startswith("ctx-a-")
            else "opfit-326-class-b-premerge"
        )
        root = BUNDLES / task / f"{prefix}-{group}"
        if not (root / "final-grades.json").is_file():
            continue
        data = load_final_grades(root)
        for eid, (alias, _run) in data["sealed"].items():
            if eid in data["by_eval"]:
                out[(group, alias)] = data["by_eval"][eid]
    return out


def load_all_alias_runs() -> dict[tuple[str, int], dict]:
    """Merge Stage 1 / 1C / 1D / pipeline canonical rows keyed by (alias, run)."""
    merged: dict[tuple[str, int], dict] = {}
    for key in ("1", "1c", "1d", "pipeline"):
        cfg = STAGE_CONFIG[key]
        merged.update(load_stage(cfg["score_set"], cfg["tasks"]))
    return merged


def lookup_alias(alias: str, run: int = 1, merged: dict | None = None) -> dict | None:
    merged = merged or load_all_alias_runs()
    return merged.get((alias, run))


def marginal_stage_for_alias(alias: str) -> str:
    if alias.endswith("-pipe"):
        return "pipeline"
    if alias.endswith("-injected") or alias.endswith("-agents"):
        return "1c"
    if alias.endswith("-duo"):
        return "1d"
    return "1"


def task_for_class(stage_key: str, task_class: str) -> str:
    tasks = STAGE_CONFIG[stage_key]["tasks"]
    return tasks[0] if task_class == "A" else tasks[1]


def load_task_scores(stage_key: str, task: str) -> dict | None:
    cfg = STAGE_CONFIG[stage_key]
    root = BUNDLES / task / cfg["score_set"]
    if not (root / "final-grades.json").is_file():
        return None
    return load_final_grades(root)


def lookup_pipeline_score(task_class: str, alias: str, run: int) -> dict | None:
    """Pipeline Class A/B share alias+run keys; scope lookup to the task for task_class."""
    data = load_task_scores("pipeline", task_for_class("pipeline", task_class))
    if not data:
        return None
    row = data["by_alias_run"].get((alias, run))
    if row:
        return row
    for eid, (a, r) in data["sealed"].items():
        if a == alias and r == run and eid in data["by_eval"]:
            return data["by_eval"][eid]
    return None


def lookup_marginal_score(task_class: str, alias: str) -> dict | None:
    """Resolve canonical score for a marginal ROI row within one task class.

    Extended-stage aliases (`-pipe`, `-injected`, `-duo`) can share the same
    alias string across Class A/B with different run indices. Always scope lookup
    to the task for ``task_class`` instead of merging global (alias, run) keys.
    """
    stage_key = marginal_stage_for_alias(alias)
    task = task_for_class(stage_key, task_class)
    data = load_task_scores(stage_key, task)
    if not data:
        return None

    matches = [
        data["by_eval"][eid]
        for eid, (a, _run) in data["sealed"].items()
        if a == alias and eid in data["by_eval"]
    ]
    if matches:
        return matches[0]

    for run in (3, 2, 1):
        row = data["by_alias_run"].get((alias, run))
        if row:
            return row
    return None


def na_cells() -> dict:
    return {
        "canonical": "N/A",
        "objective": "N/A",
        "subjective": "N/A",
        "score_set_id": "N/A",
    }


def fmt_score(v) -> str:
    return str(v) if v != "N/A" else "N/A"
