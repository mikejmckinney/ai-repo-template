"""Parse agent-roi-benchmark-results.md rows and bootstrap legacy subjective JSON."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
RESULTS_MD = REPO_ROOT / ".context/benchmarks/model-roi/results/agent-roi-benchmark-results.md"
RUNNER = REPO_ROOT / "scripts/benchmark"

RUBRIC_PROFILES = {
    "standard": {
        "rubric_id": "rubric.v1",
        "legacy_keys": ["correctness", "quality", "process", "reliability", "latency"],
        "legacy_to_cat": {
            "correctness": "correctness",
            "quality": "quality",
            "process": "process",
            "reliability": "reliability",
            "latency": "latency",
        },
    },
    "pipeline": {
        "rubric_id": "rubric.pipeline.v1",
        "legacy_keys": [
            "correctness",
            "quality",
            "process",
            "reliability",
            "coordination",
            "latency",
        ],
        "legacy_to_cat": {
            "correctness": "correctness",
            "quality": "quality",
            "process": "process",
            "reliability": "reliability",
            "coordination": "coordination",
            "latency": "latency",
        },
    },
}

TASK_BY_SECTION = {
    "Class A:": "opfit-281-class-a-premerge",
    "Class B:": "opfit-326-class-b-premerge",
}

STAGE1C_TASK = {
    "Stage 1C Class A:": "opfit-281-class-a-premerge-context-injected",
    "Stage 1C Class B:": "opfit-326-class-b-premerge-context-injected",
}

STAGE1D_TASK = {
    "Stage 1D Class A:": "opfit-281-class-a-premerge",
    "Stage 1D Class B:": "opfit-326-class-b-premerge",
}

PIPELINE_TASK = {
    "Issue #376 Class A:": "opfit-281-class-a-premerge-pipeline",
    "Issue #376 Class B:": "opfit-326-class-b-premerge-pipeline",
}


def _parse_int(s: str) -> int:
    return int(s.strip().replace("`", ""))


def _parse_run_token(s: str) -> int:
    s = s.strip().strip("`")
    if s.startswith("r") and s[1:].isdigit():
        return int(s[1:])
    return 1


def parse_monolithic_rows(text: str) -> list[dict]:
    rows: list[dict] = []
    current_task: str | None = None
    in_table = False

    for line in text.splitlines():
        if line.startswith("## Class A:"):
            current_task = TASK_BY_SECTION["Class A:"]
            in_table = False
            continue
        if line.startswith("## Class B:"):
            current_task = TASK_BY_SECTION["Class B:"]
            in_table = False
            continue
        if line.startswith("### ") or line.startswith("## Stage 1C"):
            in_table = False
            continue
        if not current_task:
            continue
        if line.startswith("| Alias | Run | Gates |"):
            in_table = True
            continue
        if not in_table:
            continue
        if not line.startswith("|") or line.startswith("|---"):
            continue
        if "`" not in line:
            in_table = False
            continue
        parts = [p.strip() for p in line.strip("|").split("|")]
        if len(parts) < 9:
            continue
        alias = parts[0].strip("`")
        run = int(parts[1])
        gates = parts[2]
        scores = {
            "correctness": _parse_int(parts[3]),
            "quality": _parse_int(parts[4]),
            "process": _parse_int(parts[5]),
            "reliability": _parse_int(parts[6]),
            "latency": _parse_int(parts[7]),
            "total": _parse_int(parts[8]),
        }
        summary = parts[11] if len(parts) > 11 else ""
        rows.append(
            {
                "stage": "1",
                "task": current_task,
                "alias": alias,
                "run": run,
                "gates": gates,
                "scores": scores,
                "summary": summary,
                "rubric_profile": "standard",
            }
        )
    return rows


def parse_stage1c_rows(text: str) -> list[dict]:
    rows: list[dict] = []
    current_task: str | None = None
    in_table = False
    for line in text.splitlines():
        for prefix, task in STAGE1C_TASK.items():
            if line.startswith(f"### {prefix}"):
                current_task = task
                in_table = False
        if not current_task:
            continue
        if line.startswith("| Injected alias | Baseline alias |"):
            in_table = True
            continue
        if not in_table:
            continue
        if not line.startswith("|") or line.startswith("|---"):
            continue
        if "`" not in line:
            in_table = False
            continue
        parts = [p.strip() for p in line.strip("|").split("|")]
        if len(parts) < 8:
            continue
        alias = parts[0].strip("`")
        scores = {
            "correctness": _parse_int(parts[2]),
            "quality": _parse_int(parts[3]),
            "process": _parse_int(parts[4]),
            "reliability": _parse_int(parts[5]),
            "latency": _parse_int(parts[6]),
            "total": _parse_int(parts[7]),
        }
        rows.append(
            {
                "stage": "1c",
                "task": current_task,
                "alias": alias,
                "baseline_alias": parts[1].strip("`"),
                "run": 1,
                "gates": "pass",
                "scores": scores,
                "summary": parts[-1] if parts else "",
                "rubric_profile": "standard",
            }
        )
    return rows


def parse_stage1d_rows(text: str) -> list[dict]:
    rows: list[dict] = []
    current_task: str | None = None
    in_table = False
    for line in text.splitlines():
        for prefix, task in STAGE1D_TASK.items():
            if line.startswith(f"### {prefix}"):
                current_task = task
                in_table = False
        if not current_task:
            continue
        if line.startswith("| Alias | Platform / planner"):
            in_table = True
            continue
        if not in_table:
            continue
        if not line.startswith("|") or line.startswith("|---"):
            continue
        if "`" not in line:
            in_table = False
            continue
        parts = [p.strip() for p in line.strip("|").split("|")]
        if len(parts) < 8:
            continue
        alias = parts[0].strip("`")
        if not alias.endswith("-duo"):
            continue
        scores = {
            "correctness": _parse_int(parts[2]),
            "quality": _parse_int(parts[3]),
            "process": _parse_int(parts[4]),
            "reliability": _parse_int(parts[5]),
            "latency": _parse_int(parts[6]),
            "total": _parse_int(parts[7]),
        }
        rows.append(
            {
                "stage": "1d",
                "task": current_task,
                "alias": alias,
                "run": 1,
                "gates": "pass",
                "scores": scores,
                "summary": parts[-1] if parts else "",
                "rubric_profile": "standard",
            }
        )
    return rows


def parse_pipeline_rows(text: str) -> list[dict]:
    rows: list[dict] = []
    current_task: str | None = None
    in_table = False
    for line in text.splitlines():
        for prefix, task in PIPELINE_TASK.items():
            if line.startswith(f"### {prefix}"):
                current_task = task
                in_table = False
        if not current_task:
            continue
        if line.startswith("| Alias | Platform / model | Run |"):
            in_table = True
            continue
        if not in_table:
            continue
        if not line.startswith("|") or line.startswith("|---"):
            continue
        if "`" not in line:
            in_table = False
            continue
        parts = [p.strip() for p in line.strip("|").split("|")]
        if len(parts) < 11:
            continue
        alias = parts[0].strip("`")
        if not alias.endswith("-pipe"):
            continue
        run = _parse_run_token(parts[2])
        scores = {
            "correctness": _parse_int(parts[4]),
            "quality": _parse_int(parts[5]),
            "process": _parse_int(parts[6]),
            "reliability": _parse_int(parts[7]),
            "coordination": _parse_int(parts[8]),
            "latency": _parse_int(parts[9]),
            "total": _parse_int(parts[10]),
        }
        rows.append(
            {
                "stage": "pipeline",
                "task": current_task,
                "alias": alias,
                "run": run,
                "gates": parts[3],
                "scores": scores,
                "summary": parts[-1] if parts else "",
                "rubric_profile": "pipeline",
            }
        )
    return rows


def parse_rows_for_stage(stage: str, text: str) -> list[dict]:
    if stage == "1":
        return parse_monolithic_rows(text)
    if stage == "1c":
        return parse_stage1c_rows(text)
    if stage == "1d":
        return parse_stage1d_rows(text)
    if stage == "pipeline":
        return parse_pipeline_rows(text)
    raise ValueError(f"unknown stage: {stage}")


def write_manifest(rows: list[dict], out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    lines = ["# alias\trun_index\tlegacy_total\tgates"]
    for row in rows:
        lines.append(
            f"{row['alias']}\t{row['run']}\t{row['scores']['total']}\t{row['gates']}"
        )
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _subjective_max_for_profile(profile: str) -> dict[str, int]:
    import sys

    sys.path.insert(0, str(RUNNER))
    from grading_lib import load_rubric_by_id, rubric_limits  # noqa: E402

    rubric_id = RUBRIC_PROFILES[profile]["rubric_id"]
    _, sub_max, _ = rubric_limits(load_rubric_by_id(rubric_id))
    return {k: v for k, v in sub_max.items() if v > 0}


def generate_responses(
    rows: list[dict],
    *,
    task: str,
    score_set: str,
    grader_id: str,
    out_dir: Path,
    rubric_profile: str = "standard",
) -> None:
    bundle_root = RUNNER / "grade-bundles" / task / score_set
    eval_by_alias_run: dict[tuple[str, int], str] = {}
    for line in (bundle_root / "sealed-eval-map.tsv").read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or not line.strip():
            continue
        cols = line.split("\t")
        if cols[0] == "eval_candidate_id" or not cols[3].isdigit():
            continue
        eval_by_alias_run[(cols[2], int(cols[3]))] = cols[0]

    profile = RUBRIC_PROFILES[rubric_profile]
    legacy_to_cat = profile["legacy_to_cat"]
    sub_max = _subjective_max_for_profile(rubric_profile)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    for row in rows:
        if row["task"] != task:
            continue
        eval_id = eval_by_alias_run.get((row["alias"], row["run"]))
        if not eval_id:
            print(f"warn: no bundle for {row['alias']} r{row['run']}")
            continue
        obj_path = bundle_root / eval_id / "objective-grade.json"
        if not obj_path.is_file():
            print(f"warn: missing objective grade for {eval_id}")
            continue
        objective = json.loads(obj_path.read_text(encoding="utf-8"))
        cats: dict[str, Any] = {}
        sub_total = 0
        for leg, cat in legacy_to_cat.items():
            if cat not in sub_max:
                continue
            mx = sub_max[cat]
            obj_pts = int(objective["categories"].get(cat, {}).get("objective_points", 0))
            raw = row["scores"][leg] - obj_pts
            pts = max(0, min(mx, raw))
            cats[cat] = {
                "subjective_points": pts,
                "max_subjective_points": mx,
                "rationale": row["summary"]
                or f"Legacy results.md residual for {cat} ({leg}={row['scores'][leg]}, objective={obj_pts}).",
            }
            sub_total += pts
        doc = {
            "schema_version": "benchmark-subjective-grade.v1",
            "score_set_id": score_set,
            "eval_candidate_id": eval_id,
            "grader_id": grader_id,
            "grader_prompt_id": "model-roi-grader-v1",
            "rubric_id": profile["rubric_id"],
            "categories": cats,
            "subjective_total": sub_total,
            "citations": [
                {
                    "bundle_ref": "diff.patch",
                    "claim": row["summary"] or "Legacy blind grade from agent-roi-benchmark-results.md.",
                },
                {
                    "bundle_ref": "objective-grade.json#evidence",
                    "claim": "Objective automation applied before legacy subjective residual mapping.",
                },
            ],
            "graded_at": now,
        }
        group_dir = out_dir / task
        group_dir.mkdir(parents=True, exist_ok=True)
        out_path = group_dir / f"{eval_id}.json"
        out_path.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
