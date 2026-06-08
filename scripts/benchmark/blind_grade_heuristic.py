#!/usr/bin/env python3
"""Heuristic evidence-based subjective grading (offline fallback; not canonical LLM blind)."""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from grading_lib import load_rubric_by_id, rubric_limits  # noqa: E402

REPO = Path(__file__).resolve().parents[2]


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""


def score_standard(bundle: Path, objective: dict, diff: str, files: list[str]) -> dict:
    rubric_id = objective.get("rubric_id", "rubric.v1")
    _, sub_max, _ = rubric_limits(load_rubric_by_id(rubric_id))
    hard = objective.get("hard_gate_pass", True)

    if not hard:
        return {
            c: {
                "subjective_points": 0,
                "max_subjective_points": sub_max[c],
                "rationale": "Hard gate failed; 0 subjective per fail-closed policy.",
            }
            for c in sub_max
            if sub_max[c] > 0
        }

    scope_noise = any(
        re.search(p, f) for f in files for p in (r"^PLAN\.md$", r"^\.context/state/", r"^\.context/sessions/")
    )
    agents_churn = any("AGENTS.md" in f for f in files)
    guide_churn = any(f in ("AI_REPO_GUIDE.md", "README.md") for f in files)
    only_target = len(files) <= 2 and any("055-script-syntax.sh" in f for f in files)
    broad_class_b = len(files) >= 5 or sum(1 for f in files if f.endswith(".sh")) >= 3

    correctness = 8
    if "RESULT=" in diff or "bash -n" in diff:
        correctness = min(sub_max["correctness"], correctness + 1)
    if scope_noise or agents_churn:
        correctness = max(4, correctness - 2)

    quality = 10
    if only_target:
        quality = min(sub_max["quality"], quality + 3)
    if guide_churn and not only_target:
        quality = max(5, quality - 2)
    if broad_class_b and "pr-resolve" in diff:
        quality = min(sub_max["quality"], quality + 2)

    process = 4
    if scope_noise:
        process = 1
    elif agents_churn:
        process = 2
    elif only_target:
        process = 5

    reliability = 3
    obj_rel = int(objective["categories"].get("reliability", {}).get("objective_points", 0))
    if obj_rel >= 6:
        reliability = 5
    elif obj_rel >= 4:
        reliability = 4
    if "bats" in diff.lower() or ".bats" in diff:
        reliability = min(sub_max["reliability"], reliability + 1)

    return {
        "correctness": {
            "subjective_points": min(sub_max["correctness"], correctness),
            "max_subjective_points": sub_max["correctness"],
            "rationale": "Blind diff review: contract behavior and acceptance fit from patch evidence.",
        },
        "quality": {
            "subjective_points": min(sub_max["quality"], quality),
            "max_subjective_points": sub_max["quality"],
            "rationale": "Blind diff review: structure, scope, and repo-consistency of implementation.",
        },
        "process": {
            "subjective_points": min(sub_max["process"], process),
            "max_subjective_points": sub_max["process"],
            "rationale": "Blind diff review: scope noise and process-surface churn in changed files.",
        },
        "reliability": {
            "subjective_points": min(sub_max["reliability"], reliability),
            "max_subjective_points": sub_max["reliability"],
            "rationale": "Blind diff review: verification wiring and test/check signals in bundle.",
        },
    }


def score_pipeline(bundle: Path, objective: dict, diff: str, files: list[str]) -> dict:
    rubric_id = "rubric.pipeline.v1"
    _, sub_max, _ = rubric_limits(load_rubric_by_id(rubric_id))
    hard = objective.get("hard_gate_pass", True)
    if not hard:
        return {
            c: {
                "subjective_points": 0,
                "max_subjective_points": sub_max[c],
                "rationale": "Hard gate failed; 0 subjective per fail-closed policy.",
            }
            for c in sub_max
            if sub_max[c] > 0
        }

    scope_noise = any(".context/state" in f or ".context/sessions" in f for f in files)
    agents_churn = "AGENTS.md" in files
    orchestration_markers = bool(re.search(r"planner|implementer|handoff|orchestrat", diff, re.I))

    cats = score_standard(bundle, objective, diff, files)
    coordination = 4
    if orchestration_markers:
        coordination = 8
    if scope_noise:
        coordination = max(2, coordination - 2)
    cats["coordination"] = {
        "subjective_points": min(sub_max["coordination"], coordination),
        "max_subjective_points": sub_max["coordination"],
        "rationale": "Blind diff review: observable multi-role coordination vs monolithic execution.",
    }
    if scope_noise or agents_churn:
        cats["process"]["subjective_points"] = min(cats["process"]["subjective_points"], 2)
    return cats


def grade_bundle(bundle: Path, grader_id: str) -> dict:
    obj = json.loads((bundle / "objective-grade.json").read_text(encoding="utf-8"))
    diff = read_text(bundle / "diff.patch")
    files = [ln.strip() for ln in read_text(bundle / "files-changed.txt").splitlines() if ln.strip()]
    rubric_id = obj.get("rubric_id", "rubric.v1")
    categories = score_pipeline(bundle, obj, diff, files) if rubric_id == "rubric.pipeline.v1" else score_standard(bundle, obj, diff, files)
    sub_total = sum(int(c["subjective_points"]) for c in categories.values())
    return {
        "schema_version": "benchmark-subjective-grade.v1",
        "score_set_id": obj["score_set_id"],
        "eval_candidate_id": obj["eval_candidate_id"],
        "grader_id": grader_id,
        "grader_prompt_id": "model-roi-grader-v1",
        "rubric_id": rubric_id,
        "categories": categories,
        "subjective_total": sub_total,
        "citations": [
            {"bundle_ref": "diff.patch", "claim": f"Heuristic grade from {len(files)} changed files."},
            {"bundle_ref": "objective-grade.json#evidence", "claim": "Objective pre-graded; subjective from heuristic bundle review."},
        ],
        "graded_at": utc_now(),
    }
