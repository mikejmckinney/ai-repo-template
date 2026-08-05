#!/usr/bin/env python3

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError, ValidationError


REPO_ROOT = Path(__file__).resolve().parents[3]
PROTOCOL_ROOT = REPO_ROOT / ".context/benchmarks/model-roi/task-parallelism"
PREPARATION_PATH = PROTOCOL_ROOT / "campaign.phase-0b.preparation.json"
EXECUTION_PATH = PROTOCOL_ROOT / "campaign.phase-0b.execution.json"
EXECUTION_SCHEMA = PROTOCOL_ROOT / "phase-0b-execution.schema.json"
RESULT_SCHEMA = PROTOCOL_ROOT / "phase-0b-candidate-result.schema.json"
REPORT_SCHEMA = PROTOCOL_ROOT / "phase-0b-candidate-report.schema.json"
SUMMARY_SCHEMA = PROTOCOL_ROOT / "phase-0b-pilot-summary.schema.json"
TASK_PATH = PROTOCOL_ROOT / "tasks/vector-siege-stage-1-candidate.md"
ARTIFACT_ROOT = REPO_ROOT / ".artifacts/task-parallelism/phase-0b"
RESULT_ROOT = PROTOCOL_ROOT / "results/phase-0b"
ATTEMPT_RESULT_ROOT = RESULT_ROOT / "attempts"
RESULT_NAME = re.compile(r"^vs-p0b-[0-9]{3}\.json$")
CANDIDATE_ENV_KEYS = {
    "CODEX_HOME",
    "HOME",
    "LANG",
    "LC_ALL",
    "NODE_EXTRA_CA_CERTS",
    "PATH",
    "SHELL",
    "SSL_CERT_DIR",
    "SSL_CERT_FILE",
    "TERM",
    "TMPDIR",
    "XDG_RUNTIME_DIR",
}


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def validate_document(value: dict, schema_path: Path) -> None:
    schema = load_json(schema_path)
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema).validate(value)


def load_state() -> tuple[dict, dict]:
    state = load_json(EXECUTION_PATH)
    preparation = load_json(PREPARATION_PATH)
    validate_document(state, EXECUTION_SCHEMA)
    assignments = preparation["run_policy"]["assignments"]
    expected_completed = [item["run_id"] for item in assignments[: len(state["completed_runs"])]]
    if state["completed_runs"] != expected_completed:
        raise ValueError("completed runs are not a sequential assignment prefix")
    if state["candidate_processes_started"] < len(state["completed_runs"]):
        raise ValueError("candidate process count is below completed run count")
    if state["candidate_processes_started"] != len(state["attempts"]):
        raise ValueError("candidate process count does not match retained attempts")
    retry_attempts = sum(item["attempt_number"] == 2 for item in state["attempts"])
    if retry_attempts != state["retry_processes_started"]:
        raise ValueError("retry process count does not match retained attempts")
    for index, attempt in enumerate(state["attempts"]):
        expected_attempt_id = f"{attempt['run_id']}-attempt-{attempt['attempt_number']}"
        if attempt["attempt_id"] != expected_attempt_id:
            raise ValueError(f"attempt {index + 1} has an inconsistent identifier")
    active_run_ids = {item["run_id"] for item in state["attempts"]}
    allowed_run_ids = set(expected_completed)
    if len(state["completed_runs"]) < len(assignments):
        allowed_run_ids.add(assignments[len(state["completed_runs"])]["run_id"])
    if not active_run_ids <= allowed_run_ids:
        raise ValueError("attempts are not confined to the sequential assignment prefix")
    return state, preparation


def candidate_environment(source: dict[str, str]) -> dict[str, str]:
    environment = {key: value for key, value in source.items() if key in CANDIDATE_ENV_KEYS}
    environment.update(
        {
            "GIT_CONFIG_COUNT": "1",
            "GIT_CONFIG_KEY_0": "remote.origin.pushurl",
            "GIT_CONFIG_VALUE_0": "disabled://candidate-push-prohibited",
            "GIT_TERMINAL_PROMPT": "0",
        }
    )
    return environment


def classify_failure(rc: int, jsonl_path: Path) -> tuple[str, bool, bool]:
    output = jsonl_path.read_text(encoding="utf-8", errors="replace") if jsonl_path.is_file() else ""
    if rc == 124:
        model_activity = ('"type":"item.started"', '"type": "item.started"')
        if any(marker in output for marker in model_activity):
            return "candidate-failed", False, False
        return "provider-failed", False, True
    harness_markers = ("invalid_json_schema", "codex_output_schema", "output schema")
    if any(marker in output.lower() for marker in harness_markers):
        return "harness-failed", True, True
    return "candidate-failed", False, False


def plan_attempt(state: dict, run_id: str) -> dict:
    prior = [item for item in state["attempts"] if item["run_id"] == run_id]
    if not prior:
        return {"attempt_id": f"{run_id}-attempt-1", "attempt_number": 1, "is_retry": False}
    if len(prior) != 1 or not prior[0]["retry_eligible"]:
        raise ValueError("run has no eligible retry")
    if state["retry_processes_started"] >= 1:
        raise ValueError("campaign retry budget is exhausted")
    return {"attempt_id": f"{run_id}-attempt-2", "attempt_number": 2, "is_retry": True}


def run_command(command: list[str], cwd: Path, log_path: Path, timeout: int) -> int:
    try:
        completed = subprocess.run(
            command,
            cwd=cwd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
        output = completed.stdout
        rc = completed.returncode
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or "") + f"\ncommand timed out after {timeout} seconds\n"
        rc = 124
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(output, encoding="utf-8")
    return rc


def parse_usage(jsonl_path: Path) -> tuple[dict, str | None]:
    usage = {"input": 0, "cached_input": 0, "output": 0}
    thread_id = None
    if not jsonl_path.is_file():
        return usage, thread_id
    for line in jsonl_path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") == "thread.started":
            thread_id = event.get("thread_id")
        event_usage = event.get("usage")
        if isinstance(event_usage, dict):
            usage = {
                "input": int(event_usage.get("input_tokens", usage["input"])),
                "cached_input": int(event_usage.get("cached_input_tokens", usage["cached_input"])),
                "output": int(event_usage.get("output_tokens", usage["output"])),
            }
    return usage, thread_id


def load_report(path: Path, arm: str) -> dict:
    report = load_json(path)
    validate_document(report, REPORT_SCHEMA)
    if arm == "A" and (report["fanout_elected"] or report["worker_count"] != 1):
        raise ValueError("Arm A candidate reported fan-out")
    if not report["fanout_elected"] and report["worker_count"] != 1:
        raise ValueError("candidate reported multiple workers without fan-out")
    return report


def build_prompt(preparation: dict, arm: str) -> str:
    common = (PROTOCOL_ROOT / preparation["prompts"]["common"]["path"]).read_text(encoding="utf-8")
    common = common.replace("tasks/vector-siege.md", "TASK.md")
    arm_key = "arm_a" if arm == "A" else "arm_b"
    treatment = (PROTOCOL_ROOT / preparation["prompts"][arm_key]["path"]).read_text(encoding="utf-8")
    task = TASK_PATH.read_text(encoding="utf-8")
    reporting = """
## Required Final Report

Return only JSON matching the supplied output schema. Report measured values;
use zero when no event occurred. Do not estimate monetary cost.
"""
    return "\n\n".join([common, treatment, task, reporting])


def verify_remote_base(state: dict) -> None:
    base = state["candidate_base"]
    sha = base["sha"]
    local = subprocess.run(
        ["git", "cat-file", "-e", f"{sha}^{{commit}}"],
        cwd=REPO_ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if local.returncode != 0:
        raise ValueError("candidate base commit is unavailable locally")
    remote = subprocess.run(
        ["git", "ls-remote", "--heads", "origin", base["branch"]],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        check=False,
    )
    observed = remote.stdout.split()[0] if remote.stdout.strip() else None
    if remote.returncode != 0 or observed != sha:
        raise ValueError("remote candidate base does not match frozen SHA")
    required = [
        ".agents/skills",
        ".gitignore",
        "TASK.md",
        "package-lock.json",
        "package.json",
        "public/benchmark-assets/vector-siege/manifest.json",
        "skills-lock.json",
    ]
    for path in required:
        present = subprocess.run(
            ["git", "cat-file", "-e", f"{sha}:{path}"],
            cwd=REPO_ROOT,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if present.returncode != 0:
            raise ValueError(f"candidate base is missing required path: {path}")
    task_blob = subprocess.run(
        ["git", "rev-parse", f"{sha}:TASK.md"],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        check=True,
    ).stdout.strip()
    if task_blob != base["task_blob_sha"]:
        raise ValueError("candidate base task does not match the frozen task blob")


def verify_local_base_if_available(state: dict) -> bool:
    base = state["candidate_base"]
    sha = base["sha"]
    local = subprocess.run(
        ["git", "cat-file", "-e", f"{sha}^{{commit}}"],
        cwd=REPO_ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if local.returncode != 0:
        return False
    task_blob = subprocess.run(
        ["git", "rev-parse", f"{sha}:TASK.md"],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if task_blob.returncode != 0:
        raise ValueError("local candidate base is missing required path: TASK.md")
    task_blob_sha = task_blob.stdout.strip()
    if task_blob_sha != base["task_blob_sha"]:
        raise ValueError("local candidate base task does not match the frozen task blob")
    return True


def candidate_command(preparation: dict, worktree: Path, artifact_dir: Path) -> list[str]:
    command = list(preparation["candidate_runtime"]["candidate_command"])
    if command[-1] != "-":
        raise ValueError("candidate command must read its prompt from stdin")
    return command[:-1] + [
        "--ignore-user-config",
        "--color",
        "never",
        "-C",
        str(worktree),
        "--output-schema",
        str(REPORT_SCHEMA),
        "--output-last-message",
        str(artifact_dir / "final-report.json"),
        "-",
    ]


def evaluate_candidate(worktree: Path, artifact_dir: Path, work_produced: bool) -> tuple[int, dict]:
    checks = [
        ("install", ["npm", "ci", "--ignore-scripts"], 10, 300),
        ("browser", ["npx", "playwright", "install", "chromium"], 0, 300),
        ("unit", ["npm", "test"], 20, 300),
        ("build", ["npm", "run", "build"], 20, 300),
        ("e2e", ["npm", "run", "test:e2e"], 30, 300),
    ]
    score = 10 + (10 if work_produced else 0)
    statuses = {}
    for name, command, points, timeout in checks:
        rc = run_command(command, worktree, artifact_dir / "evaluation" / f"{name}.log", timeout)
        statuses[name] = {"exit_code": rc, "points": points if rc == 0 else 0}
        if rc == 0:
            score += points
    return score, statuses


def snapshot_candidate(worktree: Path, base_sha: str, attempt_id: str) -> tuple[list[str], str, int]:
    subprocess.run(["git", "add", "-A"], cwd=worktree, check=True)
    changed = subprocess.run(
        ["git", "diff", "--cached", "--name-only", base_sha],
        cwd=worktree,
        text=True,
        stdout=subprocess.PIPE,
        check=True,
    ).stdout.splitlines()
    forbidden = (".agents/", "TASK.md", "public/benchmark-assets/vector-siege/")
    drift_count = sum(
        path == forbidden[1] or path.startswith((forbidden[0], forbidden[2])) for path in changed
    )
    if changed:
        subprocess.run(
            ["git", "commit", "--no-gpg-sign", "-m", f"candidate: {attempt_id}"],
            cwd=worktree,
            check=True,
        )
    candidate_sha = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=worktree,
        text=True,
        stdout=subprocess.PIPE,
        check=True,
    ).stdout.strip()
    return changed, candidate_sha, drift_count


def write_failure_result(run_id: str, arm: str, wall: int, terminal_status: str, harness: bool) -> dict:
    return {
        "schema_version": "task-parallelism-phase-0b-candidate-result.v1",
        "run_id": run_id,
        "arm": arm,
        "terminal_status": terminal_status,
        "quality_score": 0,
        "model_cost_usd": None,
        "wall_clock_seconds": wall,
        "human_intervention_minutes": 0,
        "infrastructure_cost_usd": 0,
        "tokens": {"input": 0, "cached_input": 0, "output": 0},
        "skill_loads": 0,
        "skill_context_tokens": 0,
        "coordination_seconds": 0,
        "provider_wait_seconds": 0,
        "rescue_events": 0,
        "duplicate_or_abandoned_work": 0,
        "predicted_path_drift_count": 0,
        "semantic_conflicts": 0,
        "interface_conflicts": 0,
        "asset_conflicts": 0,
        "dependency_conflicts": 0,
        "merge_conflicts": 0,
        "fanout_elected": False,
        "worker_count": 1,
        "harness_failure": harness,
    }


def apply_report_telemetry(result: dict, report: dict, usage: dict, drift_count: int) -> None:
    result.update(
        {
            "tokens": usage,
            "skill_loads": report["skill_loads"],
            "skill_context_tokens": report["skill_context_tokens"],
            "coordination_seconds": report["coordination_seconds"],
            "provider_wait_seconds": report["provider_wait_seconds"],
            "rescue_events": report["rescue_events"],
            "duplicate_or_abandoned_work": report["duplicate_or_abandoned_work"],
            "predicted_path_drift_count": drift_count,
            "semantic_conflicts": report["semantic_conflicts"],
            "interface_conflicts": report["interface_conflicts"],
            "asset_conflicts": report["asset_conflicts"],
            "dependency_conflicts": report["dependency_conflicts"],
            "fanout_elected": report["fanout_elected"],
            "worker_count": report["worker_count"],
        }
    )


def should_diagnose_candidate(work_produced: bool, completion_status: str | None) -> bool:
    del completion_status
    return work_produced


def execute_run(run_id: str) -> int:
    state, preparation = load_state()
    if state["status"] == "base-pending" or state["candidate_base"]["sha"] is None:
        print("candidate base is not frozen", file=sys.stderr)
        return 2
    assignments = preparation["run_policy"]["assignments"]
    next_index = len(state["completed_runs"])
    if next_index >= len(assignments) or assignments[next_index]["run_id"] != run_id:
        print("run is not the next sequential assignment", file=sys.stderr)
        return 2
    attempt = plan_attempt(state, run_id)
    verify_remote_base(state)
    assignment = assignments[next_index]
    arm = assignment["arm"]
    base_sha = state["candidate_base"]["sha"]
    artifact_name = attempt["attempt_id"] if attempt["is_retry"] else run_id
    artifact_dir = ARTIFACT_ROOT / artifact_name
    worktree = ARTIFACT_ROOT / "worktrees" / attempt["attempt_id"]
    final_result_path = RESULT_ROOT / f"{run_id}.json"
    attempt_result_path = ATTEMPT_RESULT_ROOT / f"{attempt['attempt_id']}.json"
    if artifact_dir.exists() or worktree.exists() or attempt_result_path.exists() or final_result_path.exists():
        print("attempt artifacts already exist", file=sys.stderr)
        return 2
    artifact_dir.mkdir(parents=True)
    subprocess.run(
        ["git", "worktree", "add", "-B", f"phase-0b/{attempt['attempt_id']}", str(worktree), base_sha],
        cwd=REPO_ROOT,
        check=True,
    )
    state["status"] = "running"
    state["candidate_processes_started"] += 1
    if attempt["is_retry"]:
        state["retry_processes_started"] += 1
    write_json(EXECUTION_PATH, state)
    started = time.monotonic()
    jsonl_path = artifact_dir / "agent-output.jsonl"
    stderr_path = artifact_dir / "stderr.log"
    prompt = build_prompt(preparation, arm)
    env = candidate_environment(os.environ)
    usage = {"input": 0, "cached_input": 0, "output": 0}
    thread_id = None
    evaluation = {}
    candidate_sha = base_sha
    candidate_branch = f"benchmark/vector-siege/{artifact_name}"
    rc = 70
    harness_error = None
    try:
        with jsonl_path.open("w", encoding="utf-8") as stdout, stderr_path.open(
            "w", encoding="utf-8"
        ) as stderr:
            completed = subprocess.run(
                candidate_command(preparation, worktree, artifact_dir),
                cwd=worktree,
                input=prompt,
                text=True,
                stdout=stdout,
                stderr=stderr,
                env=env,
                timeout=1800,
                check=False,
            )
        rc = completed.returncode
        usage, thread_id = parse_usage(jsonl_path)
        changed, candidate_sha, drift_count = snapshot_candidate(
            worktree, base_sha, attempt["attempt_id"]
        )
        report_path = artifact_dir / "final-report.json"
        report = load_report(report_path, arm) if rc == 0 else None
        if rc == 0 and report is not None and report["completion_status"] == "completed":
            score, evaluation = evaluate_candidate(worktree, artifact_dir, bool(changed))
            result = {
                "schema_version": "task-parallelism-phase-0b-candidate-result.v1",
                "run_id": run_id,
                "arm": arm,
                "terminal_status": "completed",
                "quality_score": score,
                "model_cost_usd": None,
                "wall_clock_seconds": int(time.monotonic() - started),
                "human_intervention_minutes": 0,
                "infrastructure_cost_usd": 0,
                "tokens": usage,
                "skill_loads": report["skill_loads"],
                "skill_context_tokens": report["skill_context_tokens"],
                "coordination_seconds": report["coordination_seconds"],
                "provider_wait_seconds": report["provider_wait_seconds"],
                "rescue_events": report["rescue_events"],
                "duplicate_or_abandoned_work": report["duplicate_or_abandoned_work"],
                "predicted_path_drift_count": drift_count,
                "semantic_conflicts": report["semantic_conflicts"],
                "interface_conflicts": report["interface_conflicts"],
                "asset_conflicts": report["asset_conflicts"],
                "dependency_conflicts": report["dependency_conflicts"],
                "merge_conflicts": 0,
                "fanout_elected": report["fanout_elected"],
                "worker_count": report["worker_count"],
                "harness_failure": False,
            }
            retry_eligible = False
        else:
            terminal_status, harness, retry_eligible = classify_failure(rc, jsonl_path)
            if report is not None:
                terminal_status, harness, retry_eligible = "candidate-failed", False, False
            result = write_failure_result(
                run_id, arm, int(time.monotonic() - started), terminal_status, harness
            )
            if report is not None:
                apply_report_telemetry(result, report, usage, drift_count)
            else:
                result["tokens"] = usage
        validate_document(result, RESULT_SCHEMA)
        subprocess.run(
            ["git", "push", "origin", f"HEAD:refs/heads/{candidate_branch}"],
            cwd=worktree,
            check=True,
        )
    except subprocess.TimeoutExpired:
        rc = 124
        with stderr_path.open("a", encoding="utf-8") as stderr:
            stderr.write("candidate timed out after 1800 seconds\n")
        usage, thread_id = parse_usage(jsonl_path)
        terminal_status, harness, retry_eligible = classify_failure(rc, jsonl_path)
        result = write_failure_result(
            run_id, arm, int(time.monotonic() - started), terminal_status, harness
        )
        result["tokens"] = usage
        try:
            _, candidate_sha, _ = snapshot_candidate(worktree, base_sha, attempt["attempt_id"])
            subprocess.run(
                ["git", "push", "origin", f"HEAD:refs/heads/{candidate_branch}"],
                cwd=worktree,
                check=True,
            )
        except (OSError, subprocess.CalledProcessError) as error:
            harness_error = f"candidate evidence snapshot failed: {error}"
            result = write_failure_result(
                run_id, arm, int(time.monotonic() - started), "harness-failed", True
            )
            result["tokens"] = usage
            retry_eligible = True
    except (
        OSError,
        ValueError,
        json.JSONDecodeError,
        SchemaError,
        ValidationError,
        subprocess.CalledProcessError,
    ) as error:
        harness_error = str(error)
        result = write_failure_result(
            run_id, arm, int(time.monotonic() - started), "harness-failed", True
        )
        result["tokens"] = usage
        retry_eligible = True
    finally:
        subprocess.run(
            ["git", "worktree", "remove", "--force", str(worktree)],
            cwd=REPO_ROOT,
            check=False,
        )
    if attempt["is_retry"]:
        retry_eligible = False
    validate_document(result, RESULT_SCHEMA)
    write_json(attempt_result_path, result)
    write_json(
        artifact_dir / "run-metadata.json",
        {
            "run_id": run_id,
            "attempt_id": attempt["attempt_id"],
            "arm": arm,
            "thread_id": thread_id,
            "candidate_branch": candidate_branch,
            "candidate_sha": candidate_sha,
            "evaluation": evaluation,
            "codex_exit_code": rc,
            "harness_error": harness_error,
        },
    )
    state["attempts"].append(
        {
            "attempt_id": attempt["attempt_id"],
            "run_id": run_id,
            "attempt_number": attempt["attempt_number"],
            "terminal_status": result["terminal_status"],
            "retry_eligible": retry_eligible,
            "result_path": str(attempt_result_path.relative_to(PROTOCOL_ROOT)),
        }
    )
    if not retry_eligible:
        write_json(final_result_path, result)
        state["completed_runs"].append(run_id)
    state["status"] = "completed" if len(state["completed_runs"]) == 10 else "ready"
    write_json(EXECUTION_PATH, state)
    retry_note = " retry-eligible" if retry_eligible else ""
    print(
        f"{attempt['attempt_id']}: {result['terminal_status']} "
        f"quality={result['quality_score']} branch={candidate_branch}{retry_note}"
    )
    return 0


def summarize(results_dir: Path, output: Path) -> int:
    valid = []
    for path in sorted(path for path in results_dir.iterdir() if RESULT_NAME.fullmatch(path.name)):
        try:
            result = load_json(path)
            validate_document(result, RESULT_SCHEMA)
        except (OSError, ValueError, json.JSONDecodeError, SchemaError, ValidationError) as error:
            print(f"rejected result {path.name}: {error}", file=sys.stderr)
            continue
        valid.append(result)
    expected_ids = {f"vs-p0b-{index:03d}" for index in range(1, 11)}
    terminal = sum(item["run_id"] in expected_ids for item in valid)
    attempt_results = []
    attempt_root = results_dir / "attempts"
    if attempt_root.is_dir():
        for path in sorted(attempt_root.glob("vs-p0b-*-attempt-*.json")):
            try:
                attempt = load_json(path)
                validate_document(attempt, RESULT_SCHEMA)
            except (OSError, ValueError, json.JSONDecodeError, SchemaError, ValidationError) as error:
                print(f"rejected attempt result {path.name}: {error}", file=sys.stderr)
                continue
            attempt_results.append(attempt)
    reliability_source = attempt_results or valid
    summary = {
        "schema_version": "task-parallelism-phase-0b-summary.v1",
        "assigned_runs": 10,
        "terminal_runs": terminal,
        "required_telemetry_fraction": len(valid) / 10,
        "harness_reliability_fraction": (
            sum(not item["harness_failure"] for item in reliability_source) / len(reliability_source)
            if reliability_source
            else 0
        ),
        "arm_b_fanout_elections": sum(item["arm"] == "B" and item["fanout_elected"] for item in valid),
    }
    validate_document(summary, SUMMARY_SCHEMA)
    write_json(output, summary)
    print(f"wrote Phase 0B summary: {output}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--validate-state", action="store_true")
    action.add_argument("--run-id")
    action.add_argument("--summarize", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args()
    if args.offline and not args.validate_state:
        parser.error("--offline is valid only with --validate-state")
    try:
        if args.validate_state:
            state, _ = load_state()
            if args.offline:
                local_base = verify_local_base_if_available(state)
                base_note = (
                    "local frozen base task blob verified"
                    if local_base
                    else "frozen base unavailable locally"
                )
                print(
                    f"offline structural execution state valid: {state['status']}; "
                    f"candidate processes started: {state['candidate_processes_started']}; {base_note}"
                )
                return 0
            if state["status"] == "base-pending":
                print(
                    "authorized; candidate base pending; "
                    f"candidate processes started: {state['candidate_processes_started']}"
                )
            else:
                verify_remote_base(state)
                print(
                    f"execution state valid: {state['status']}; "
                    f"candidate processes started: {state['candidate_processes_started']}"
                )
            return 0
        if args.run_id:
            return execute_run(args.run_id)
        if args.output is None:
            parser.error("--output is required with --summarize")
        return summarize(args.summarize.resolve(), args.output.resolve())
    except (
        OSError,
        ValueError,
        json.JSONDecodeError,
        SchemaError,
        ValidationError,
        subprocess.CalledProcessError,
    ) as error:
        print(f"Phase 0B execution failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
