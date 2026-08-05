#!/usr/bin/env python3

import argparse
import importlib.util
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

from jsonschema import Draft202012Validator


REPO_ROOT = Path(__file__).resolve().parents[3]
PROTOCOL_ROOT = REPO_ROOT / ".context/benchmarks/model-roi/task-parallelism"
RESULT_ROOT = PROTOCOL_ROOT / "results/phase-0b"
SCHEMA_PATH = PROTOCOL_ROOT / "phase-0b-diagnostic-summary.schema.json"
BASE_SHA = "acffeb51f6ba6d16be6872413a0fa9010d2547a2"
RUN_IDS = [f"vs-p0b-{index:03d}" for index in range(1, 11)]


def load_runner():
    path = Path(__file__).with_name("run-phase-0b.py")
    spec = importlib.util.spec_from_file_location("phase0b_runner", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("unable to load Phase 0B runner")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def changed_files(ref: str) -> list[str]:
    completed = subprocess.run(
        ["git", "diff", "--name-only", BASE_SHA, ref],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        check=True,
    )
    return completed.stdout.splitlines()


def candidate_report(run_id: str) -> dict | None:
    path = REPO_ROOT / f".artifacts/task-parallelism/phase-0b/{run_id}/final-report.json"
    return load_json(path) if path.is_file() else None


def diagnose_run(runner, run_id: str) -> dict:
    ref = f"origin/benchmark/vector-siege/{run_id}"
    official = load_json(RESULT_ROOT / f"{run_id}.json")
    changed = changed_files(ref)
    report = candidate_report(run_id)
    result = {
        "run_id": run_id,
        "arm": official["arm"],
        "official_terminal_status": official["terminal_status"],
        "official_quality_score": official["quality_score"],
        "produced_work": bool(changed),
        "changed_file_count": len(changed),
        "candidate_completion_status": report.get("completion_status") if report else None,
        "fanout_elected": report.get("fanout_elected") if report else official["fanout_elected"],
        "fanout_reason": report.get("fanout_reason") if report else None,
        "diagnostic_quality_score": 0,
        "checks": {},
    }
    if not runner.should_evaluate_candidate(bool(changed), result["candidate_completion_status"]):
        return result

    temporary_root = Path(tempfile.mkdtemp(prefix=f"phase-0b-diagnostic-{run_id}-"))
    worktree = temporary_root / "candidate"
    artifact_dir = REPO_ROOT / f".artifacts/task-parallelism/phase-0b-diagnostic/{run_id}"
    try:
        subprocess.run(
            ["git", "worktree", "add", "--detach", str(worktree), ref],
            cwd=REPO_ROOT,
            check=True,
        )
        score, checks = runner.evaluate_candidate(worktree, artifact_dir, True)
        result["diagnostic_quality_score"] = score
        result["checks"] = checks
    finally:
        subprocess.run(
            ["git", "worktree", "remove", "--force", str(worktree)],
            cwd=REPO_ROOT,
            check=False,
        )
        shutil.rmtree(temporary_root, ignore_errors=True)
    return result


def validate_summary(summary: dict) -> None:
    schema = load_json(SCHEMA_PATH)
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema).validate(summary)


def main() -> int:
    parser = argparse.ArgumentParser()
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--output", type=Path)
    action.add_argument("--validate", type=Path)
    args = parser.parse_args()
    if args.validate:
        validate_summary(load_json(args.validate))
        print(f"retained-branch diagnostic summary valid: {args.validate}")
        return 0
    runner = load_runner()
    results = [diagnose_run(runner, run_id) for run_id in RUN_IDS]
    aggregate = {
        "produced_runs": sum(item["produced_work"] for item in results),
        "parent_e2e_passes": sum(item["checks"].get("e2e", {}).get("exit_code") == 0 for item in results),
        "candidate_reports_with_sandbox_block": sum(
            "sandbox" in (item["fanout_reason"] or "").lower() for item in results
        ),
        "arms": {
            arm: {
                "runs": sum(item["arm"] == arm for item in results),
                "produced_runs": sum(item["arm"] == arm and item["produced_work"] for item in results),
                "official_quality_total": sum(
                    item["official_quality_score"] for item in results if item["arm"] == arm
                ),
                "diagnostic_quality_total": sum(
                    item["diagnostic_quality_score"] for item in results if item["arm"] == arm
                ),
            }
            for arm in ("A", "B")
        },
    }
    summary = {
        "schema_version": "task-parallelism-phase-0b-diagnostic-summary.v1",
        "source_pilot_commit": "af1e279866f3e2c9e46c345632a2db32f58254a2",
        "official_scores_modified": False,
        "confirmatory_evidence": False,
        "aggregate": aggregate,
        "runs": results,
    }
    validate_summary(summary)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(f"wrote retained-branch diagnostic summary: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
