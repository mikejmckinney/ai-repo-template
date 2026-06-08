#!/usr/bin/env python3
"""Shared helpers for model-ROI benchmark grading scripts (stdlib only)."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
GRADING_DIR = REPO_ROOT / ".context/benchmarks/model-roi/grading"
RUNNER_DIR = REPO_ROOT / "scripts/benchmark"
BUNDLES_DIR = RUNNER_DIR / "grade-bundles"

SUBJECTIVE_MAX = {
    "correctness": 10,
    "quality": 15,
    "process": 5,
    "reliability": 5,
}

OBJECTIVE_MAX = {
    "correctness": 20,
    "quality": 10,
    "process": 15,
    "reliability": 10,
    "latency": 10,
}

RUBRIC_FILES = {
    "rubric.v1": GRADING_DIR / "rubric.v1.json",
    "rubric.pipeline.v1": GRADING_DIR / "rubric.pipeline.v1.json",
}


def load_rubric_by_id(rubric_id: str) -> dict:
    path = RUBRIC_FILES.get(rubric_id)
    if path and path.is_file():
        return load_json(path)
    die(f"unknown or missing rubric: {rubric_id}")


def rubric_limits(rubric: dict) -> tuple[dict[str, int], dict[str, int], list[str]]:
    """Return (objective_max, subjective_max, category_ids) for a rubric document."""
    obj: dict[str, int] = {}
    sub: dict[str, int] = {}
    cats: list[str] = []
    for block in rubric.get("categories", []):
        cid = block["id"]
        cats.append(cid)
        obj[cid] = int(block["objective_points"])
        sub[cid] = int(block["subjective_points"])
    return obj, sub, cats


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def die(msg: str, code: int = 2) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(code)


def validate_required(obj: dict, keys: list[str], label: str) -> None:
    missing = [k for k in keys if k not in obj]
    if missing:
        die(f"{label} missing keys: {', '.join(missing)}")


def load_rubric(path: Path | None = None) -> dict:
    return load_json(path or GRADING_DIR / "rubric.v1.json")


def load_task_spec(task_id: str) -> dict:
    spec_path = GRADING_DIR / "tasks" / f"{task_id}.json"
    if not spec_path.is_file():
        die(f"task grading spec not found: {spec_path}")
    return load_json(spec_path)


def parse_changed_files(bundle: Path) -> list[str]:
    files_path = bundle / "files-changed.txt"
    if not files_path.is_file():
        return []
    return [ln.strip() for ln in files_path.read_text(encoding="utf-8").splitlines() if ln.strip()]


def path_in_diff(changed: list[str], pattern: str) -> bool:
    rx = re.compile(pattern)
    return any(rx.search(p) for p in changed)


def run_cmd(cmd: str, cwd: Path | None = None, timeout: int = 120) -> tuple[int, str, str]:
    proc = subprocess.run(
        cmd,
        shell=True,
        cwd=str(cwd or REPO_ROOT),
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    return proc.returncode, proc.stdout, proc.stderr


def latency_points(wall_seconds: int | float | None, bands: list[dict]) -> int:
    if wall_seconds is None:
        return 0
    for band in bands:
        mx = band.get("max")
        if mx is None or wall_seconds <= mx:
            return int(band.get("points", 0))
    return 0


def empty_category_scores(rubric: dict | None = None) -> dict[str, dict]:
    rubric = rubric or load_rubric()
    obj_max, _, cats = rubric_limits(rubric)
    return {
        cat: {"objective_points": 0, "max_objective_points": obj_max.get(cat, 0), "notes": []}
        for cat in cats
    }


def grade_objective_bundle(
    bundle: Path,
    *,
    rubric: dict | None = None,
    task_spec: dict | None = None,
    run_checks: bool = False,
    repo_root: Path | None = None,
) -> dict:
    bundle = bundle.resolve()
    repo_root = repo_root or REPO_ROOT
    obj_in = load_json(bundle / "objective-input.json")
    task_id = obj_in["task_id"]
    score_set_id = obj_in["score_set_id"]
    eval_id = obj_in["eval_candidate_id"]
    task_spec = task_spec or load_task_spec(task_id)
    rubric = rubric or load_rubric()
    obj_max, _, _ = rubric_limits(rubric)

    blind = load_json(bundle / "meta-blind-sanitized.json")
    changed = parse_changed_files(bundle)
    diff_text = (bundle / "diff.patch").read_text(encoding="utf-8", errors="replace")
    evidence: list[dict] = []
    categories = empty_category_scores(rubric)

    work_produced = bool(blind.get("work_produced", False))
    hard_gate_pass = work_produced or not task_spec.get("hard_gate", {}).get("require_work_produced", True)
    hard_gate_reason = None if hard_gate_pass else "no work produced (hard gate)"

    if not hard_gate_pass:
        evidence.append(
            {
                "check_id": "hard_gate_work_produced",
                "status": "fail",
                "detail": hard_gate_reason,
                "points_awarded": 0,
                "points_possible": 100,
            }
        )
        return _finalize_objective(
            score_set_id,
            eval_id,
            task_id,
            categories,
            evidence,
            False,
            hard_gate_reason,
            rubric=rubric,
        )

    evidence.append(
        {
            "check_id": "hard_gate_work_produced",
            "status": "pass",
            "detail": "work_produced=true",
            "points_awarded": 0,
            "points_possible": 0,
        }
    )

    # Required paths (correctness objective)
    req_points_each = 4
    req_max = min(obj_max["correctness"], len(task_spec.get("required_paths", [])) * req_points_each)
    req_awarded = 0
    for req in task_spec.get("required_paths", []):
        present = req in changed or f"+++ b/{req}" in diff_text or f"diff --git a/{req}" in diff_text
        if present:
            req_awarded += req_points_each
            evidence.append(
                {
                    "check_id": f"required_path:{req}",
                    "status": "pass",
                    "detail": "path present in diff",
                    "points_awarded": req_points_each,
                    "points_possible": req_points_each,
                }
            )
        else:
            evidence.append(
                {
                    "check_id": f"required_path:{req}",
                    "status": "fail",
                    "detail": "missing from diff",
                    "points_awarded": 0,
                    "points_possible": req_points_each,
                }
            )
    req_awarded = min(req_awarded, obj_max["correctness"])
    categories["correctness"]["objective_points"] += req_awarded
    categories["correctness"]["notes"].append(f"required_paths={req_awarded}/{req_max}")

    # Forbidden paths (process objective penalties)
    penalties = task_spec.get("scope_penalties", {})
    process_points = obj_max.get("process", 0)
    for pat in task_spec.get("forbidden_path_patterns", []):
        if path_in_diff(changed, pat):
            pts = 2
            process_points = max(0, process_points - pts)
            evidence.append(
                {
                    "check_id": f"forbidden:{pat}",
                    "status": "fail",
                    "detail": "forbidden path in diff",
                    "points_awarded": -pts,
                    "points_possible": 0,
                }
            )
    if path_in_diff(changed, r"^PLAN\.md$") and penalties.get("plan_md_points"):
        process_points = max(0, process_points - int(penalties["plan_md_points"]))
        evidence.append(
            {
                "check_id": "scope:plan_md",
                "status": "warn",
                "detail": "PLAN.md in diff",
                "points_awarded": -int(penalties["plan_md_points"]),
                "points_possible": 0,
            }
        )
    if path_in_diff(changed, r"^\.context/state/") and penalties.get("context_state_points"):
        process_points = max(0, process_points - int(penalties["context_state_points"]))
        evidence.append(
            {
                "check_id": "scope:context_state",
                "status": "warn",
                "detail": ".context/state in diff",
                "points_awarded": -int(penalties["context_state_points"]),
                "points_possible": 0,
            }
        )
    if path_in_diff(changed, r"^AGENTS\.md$") and penalties.get("agents_md_points"):
        process_points = max(0, process_points - int(penalties["agents_md_points"]))
        evidence.append(
            {
                "check_id": "scope:agents_md",
                "status": "warn",
                "detail": "AGENTS.md in diff",
                "points_awarded": -int(penalties["agents_md_points"]),
                "points_possible": 0,
            }
        )
    if path_in_diff(changed, r"scripts/tests/fixtures/compliance/") and penalties.get(
        "compliance_fixture_points"
    ):
        process_points = max(0, process_points - int(penalties["compliance_fixture_points"]))
        evidence.append(
            {
                "check_id": "scope:compliance_fixtures",
                "status": "warn",
                "detail": "compliance fixture churn",
                "points_awarded": -int(penalties["compliance_fixture_points"]),
                "points_possible": 0,
            }
        )
    categories["process"]["objective_points"] = process_points

    # Doc companions (quality objective partial)
    doc_paths = task_spec.get("doc_companion_paths", [])
    if doc_paths:
        doc_hits = sum(1 for p in doc_paths if p in changed)
        doc_pts = min(obj_max["quality"], int(4 * doc_hits / max(1, len(doc_paths))))
        categories["quality"]["objective_points"] += doc_pts
        evidence.append(
            {
                "check_id": "doc_companions",
                "status": "pass" if doc_hits == len(doc_paths) else "warn",
                "detail": f"{doc_hits}/{len(doc_paths)} companions touched",
                "points_awarded": doc_pts,
                "points_possible": 4,
            }
        )

    # Acceptance commands
    for cmd_spec in task_spec.get("acceptance_commands", []):
        if not cmd_spec.get("enabled", False) and not run_checks:
            evidence.append(
                {
                    "check_id": cmd_spec["id"],
                    "status": "skip",
                    "detail": cmd_spec.get("note", "disabled in task spec"),
                    "points_awarded": 0,
                    "points_possible": cmd_spec.get("max_points", 0),
                }
            )
            continue
        req_path = cmd_spec.get("requires_path")
        if req_path and req_path not in changed and f"b/{req_path}" not in diff_text:
            evidence.append(
                {
                    "check_id": cmd_spec["id"],
                    "status": "skip",
                    "detail": f"requires_path {req_path} not in diff",
                    "points_awarded": 0,
                    "points_possible": cmd_spec.get("max_points", 0),
                }
            )
            continue
        if not cmd_spec.get("enabled", False):
            continue
        rc, out, err = run_cmd(cmd_spec["cmd"], cwd=repo_root)
        cat = cmd_spec.get("category", "quality")
        max_pts = int(cmd_spec.get("max_points", 0))
        if rc == 0:
            categories[cat]["objective_points"] = min(
                obj_max.get(cat, 0), categories[cat]["objective_points"] + max_pts
            )
            evidence.append(
                {
                    "check_id": cmd_spec["id"],
                    "status": "pass",
                    "detail": (out or err)[:500],
                    "points_awarded": max_pts,
                    "points_possible": max_pts,
                }
            )
        else:
            evidence.append(
                {
                    "check_id": cmd_spec["id"],
                    "status": "fail",
                    "detail": (err or out)[:500],
                    "points_awarded": 0,
                    "points_possible": max_pts,
                }
            )

    # Test wiring (reliability objective)
    patterns = task_spec.get("test_wiring_patterns", [])
    wiring_hits = sum(1 for p in patterns if path_in_diff(changed, p) or p in diff_text)
    if patterns:
        rel_pts = min(obj_max["reliability"], int(6 * wiring_hits / max(1, len(patterns))))
        categories["reliability"]["objective_points"] += rel_pts
        evidence.append(
            {
                "check_id": "test_wiring",
                "status": "pass" if wiring_hits else "fail",
                "detail": f"{wiring_hits}/{len(patterns)} patterns matched",
                "points_awarded": rel_pts,
                "points_possible": 6,
            }
        )

    # RESULT= line pattern for class B
    result_pat = task_spec.get("result_line_pattern")
    if result_pat and "scripts/pr-resolve-all-poll.sh" in diff_text:
        if result_pat in diff_text:
            categories["correctness"]["objective_points"] = min(
                obj_max["correctness"],
                categories["correctness"]["objective_points"] + 2,
            )
            evidence.append(
                {
                    "check_id": "result_line_contract",
                    "status": "pass",
                    "detail": f"found {result_pat} in diff",
                    "points_awarded": 2,
                    "points_possible": 2,
                }
            )

    # Cap category objective points
    for cat in obj_max:
        categories[cat]["objective_points"] = min(
            obj_max[cat], max(0, round(categories[cat]["objective_points"]))
        )

    # Latency
    wall = blind.get("wall_clock_seconds")
    lat_pts = latency_points(wall, task_spec.get("latency_bands_seconds", []))
    categories["latency"]["objective_points"] = lat_pts
    evidence.append(
        {
            "check_id": "wall_clock_bands",
            "status": "pass" if wall is not None else "fail",
            "detail": f"wall_clock_seconds={wall}",
            "points_awarded": lat_pts,
            "points_possible": obj_max.get("latency", 0),
        }
    )

    return _finalize_objective(
        score_set_id,
        eval_id,
        task_id,
        categories,
        evidence,
        hard_gate_pass,
        hard_gate_reason,
        rubric=rubric,
    )


def _finalize_objective(
    score_set_id: str,
    eval_id: str,
    task_id: str,
    categories: dict,
    evidence: list,
    hard_gate_pass: bool,
    hard_gate_reason: str | None,
    *,
    rubric: dict | None = None,
) -> dict:
    rubric = rubric or load_rubric()
    obj_max, _, cats = rubric_limits(rubric)
    if not hard_gate_pass:
        categories = empty_category_scores(rubric)
        objective_total = 0
    else:
        objective_total = sum(int(categories[c]["objective_points"]) for c in cats)
    return {
        "schema_version": "benchmark-objective-grade.v1",
        "score_set_id": score_set_id,
        "eval_candidate_id": eval_id,
        "task_id": task_id,
        "rubric_id": rubric.get("rubric_id", "rubric.v1"),
        "hard_gate_pass": hard_gate_pass,
        "hard_gate_reason": hard_gate_reason,
        "categories": categories,
        "objective_total": objective_total,
        "evidence": evidence,
        "graded_at": utc_now(),
    }


def validate_subjective_grade(data: dict, bundle: Path) -> list[str]:
    errors: list[str] = []
    validate_required(
        data,
        [
            "schema_version",
            "score_set_id",
            "eval_candidate_id",
            "grader_id",
            "grader_prompt_id",
            "rubric_id",
            "categories",
            "subjective_total",
            "citations",
            "graded_at",
        ],
        "subjective grade",
    )
    if data.get("schema_version") != "benchmark-subjective-grade.v1":
        errors.append("invalid schema_version")
    obj_in = load_json(bundle / "objective-input.json")
    if data.get("eval_candidate_id") != obj_in.get("eval_candidate_id"):
        errors.append("eval_candidate_id mismatch")
    rubric = load_rubric_by_id(data.get("rubric_id", "rubric.v1"))
    _, sub_max, _ = rubric_limits(rubric)
    total = 0
    for cat, mx in sub_max.items():
        if mx <= 0:
            continue
        block = data.get("categories", {}).get(cat, {})
        pts = int(block.get("subjective_points", -1))
        max_pts = int(block.get("max_subjective_points", mx))
        if max_pts != mx:
            errors.append(f"{cat} max_subjective_points must be {mx}")
        if pts < 0 or pts > mx:
            errors.append(f"{cat} subjective_points out of range")
        total += max(0, pts)
    if int(data.get("subjective_total", -1)) != total:
        errors.append("subjective_total does not match category sum")
    if not data.get("citations"):
        errors.append("citations required")
    return errors


def compile_final_row(
    bundle: Path, grader_id: str, *, median: bool = False
) -> dict | None:
    obj_path = bundle / "objective-grade.json"
    if not obj_path.is_file():
        return None
    objective = load_json(obj_path)
    eval_id = objective["eval_candidate_id"]
    sub_files = sorted(bundle.glob("subjective-grade.*.json"))
    if not sub_files:
        return {
            "eval_candidate_id": eval_id,
            "complete": False,
            "hard_gate_pass": objective.get("hard_gate_pass", False),
            "objective_total": objective.get("objective_total", 0),
            "subjective_total": None,
            "final_total": None,
            "categories": _empty_final_categories(objective.get("rubric_id", "rubric.v1")),
        }
    if median and len(sub_files) > 1:
        subjective = _median_subjective([load_json(p) for p in sub_files])
    else:
        match = bundle / f"subjective-grade.{grader_id}.json"
        if match.is_file():
            subjective = load_json(match)
        elif sub_files:
            subjective = load_json(sub_files[0])
        else:
            subjective = None
    if subjective is None:
        return None
    rubric = load_rubric_by_id(objective.get("rubric_id", "rubric.v1"))
    _, sub_max, cats = rubric_limits(rubric)
    categories = {}
    final_total = 0
    for cat in cats:
        obj_pts = int(objective["categories"].get(cat, {}).get("objective_points", 0))
        sub_pts = (
            int(subjective["categories"].get(cat, {}).get("subjective_points", 0))
            if sub_max.get(cat, 0) > 0
            else 0
        )
        total = obj_pts + sub_pts
        categories[cat] = {"total": total, "objective": obj_pts, "subjective": sub_pts}
        final_total += total
    if not objective.get("hard_gate_pass", True):
        final_total = 0
        for cat in categories:
            categories[cat] = {"total": 0, "objective": 0, "subjective": 0}
    return {
        "eval_candidate_id": eval_id,
        "complete": True,
        "hard_gate_pass": objective.get("hard_gate_pass", False),
        "objective_total": objective.get("objective_total", 0),
        "subjective_total": int(subjective.get("subjective_total", 0)),
        "final_total": final_total,
        "categories": categories,
    }


def _empty_final_categories(rubric_id: str = "rubric.v1") -> dict:
    _, _, cats = rubric_limits(load_rubric_by_id(rubric_id))
    return {c: {"total": 0, "objective": 0, "subjective": 0} for c in cats}


def _median_subjective(grades: list[dict]) -> dict:
    import statistics

    base = grades[0].copy()
    cats = {}
    total = 0
    for cat, mx in SUBJECTIVE_MAX.items():
        vals = [int(g["categories"][cat]["subjective_points"]) for g in grades]
        med = int(round(statistics.median(vals)))
        cats[cat] = {
            "subjective_points": med,
            "max_subjective_points": mx,
            "rationale": "median across graders",
            "uncertain": False,
        }
        total += med
    base["categories"] = cats
    base["subjective_total"] = total
    return base


def spearman_rho(left: list[float], right: list[float]) -> float | None:
    if len(left) < 2 or len(left) != len(right):
        return None

    def ranks(vals: list[float]) -> list[float]:
        order = sorted((v, i) for i, v in enumerate(vals))
        r = [0.0] * len(vals)
        i = 0
        while i < len(order):
            j = i
            while j + 1 < len(order) and order[j + 1][0] == order[i][0]:
                j += 1
            avg_rank = (i + j) / 2.0 + 1.0
            for k in range(i, j + 1):
                r[order[k][1]] = avg_rank
            i = j + 1
        return r

    rl, rr = ranks(left), ranks(right)
    n = len(rl)
    mean_l = sum(rl) / n
    mean_r = sum(rr) / n
    num = sum((a - mean_l) * (b - mean_r) for a, b in zip(rl, rr))
    den_l = sum((a - mean_l) ** 2 for a in rl) ** 0.5
    den_r = sum((b - mean_r) ** 2 for b in rr) ** 0.5
    if den_l == 0 or den_r == 0:
        return None
    return num / (den_l * den_r)
