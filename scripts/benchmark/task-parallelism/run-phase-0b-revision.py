#!/usr/bin/env python3

import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError, ValidationError


REPO_ROOT = Path(__file__).resolve().parents[3]
PROTOCOL_ROOT = REPO_ROOT / ".context/benchmarks/model-roi/task-parallelism"
REVISION_PATH = PROTOCOL_ROOT / "campaign.phase-0b.revision.json"
STATE_PATH = PROTOCOL_ROOT / "campaign.phase-0b.revision.execution.json"
STATE_SCHEMA = PROTOCOL_ROOT / "phase-0b-revision-execution.schema.json"
REPORT_SCHEMA = PROTOCOL_ROOT / "phase-0b-revision-candidate-report.schema.json"
RESULT_SCHEMA = PROTOCOL_ROOT / "phase-0b-revision-candidate-result.schema.json"
EVALUATOR_SCHEMA = PROTOCOL_ROOT / "phase-0b-revision-evaluator-result.schema.json"
SUMMARY_SCHEMA = PROTOCOL_ROOT / "phase-0b-revision-summary.schema.json"
RESULT_ROOT = PROTOCOL_ROOT / "results/phase-0b-revision"
ARTIFACT_ROOT = REPO_ROOT / ".artifacts/task-parallelism/phase-0b-revision"
ASSIGNMENTS = (("vs-p0b-next-a", "A"), ("vs-p0b-next-b", "B"))
MAX_TRACKED_LOG_BYTES = 200_000


def import_script(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ValueError(f"cannot import benchmark helper: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


PILOT = import_script("phase0b_pilot", Path(__file__).with_name("run-phase-0b.py"))
PREPARE = import_script("phase0b_prepare", Path(__file__).with_name("prepare-phase-0b.py"))


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)


def validate_document(value: dict, schema_path: Path) -> None:
    schema = load_json(schema_path)
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema).validate(value)


def relative_to_protocol(path: Path) -> str:
    return str(path.relative_to(PROTOCOL_ROOT))


def validate_state(state: dict) -> None:
    validate_document(state, STATE_SCHEMA)
    completed = state["completed_runs"]
    expected_prefixes = [[], [ASSIGNMENTS[0][0]], [item[0] for item in ASSIGNMENTS]]
    if completed not in expected_prefixes:
        raise ValueError("completed runs are not a sequential assignment prefix")
    if state["candidate_processes_started"] != len(state["attempts"]):
        raise ValueError("candidate process count does not match retained attempts")
    replacements = sum(item["is_replacement"] for item in state["attempts"])
    if replacements != state["replacement_processes_started"]:
        raise ValueError("replacement process count does not match retained attempts")
    allowed = set(completed)
    if len(completed) < len(ASSIGNMENTS):
        allowed.add(ASSIGNMENTS[len(completed)][0])
    seen = set()
    for attempt in state["attempts"]:
        expected_id = f"{attempt['run_id']}-attempt-{attempt['attempt_number']}"
        if attempt["attempt_id"] != expected_id:
            raise ValueError("attempt identifier is inconsistent")
        if attempt["attempt_id"] in seen:
            raise ValueError("attempt identifiers must be unique")
        if attempt["run_id"] not in allowed:
            raise ValueError("attempts are not confined to the sequential assignment prefix")
        if attempt["is_replacement"] != (attempt["attempt_number"] == 2):
            raise ValueError("replacement marker does not match attempt number")
        seen.add(attempt["attempt_id"])
    if state["status"] == "completed" and completed != [item[0] for item in ASSIGNMENTS]:
        raise ValueError("completed status requires both terminal assignments")


def load_state() -> dict:
    state = load_json(STATE_PATH)
    validate_state(state)
    return state


def finalize_attempt_state(
    state: dict,
    attempt_id: str,
    result: dict,
    result_path: str,
    candidate_report_path: str | None,
    evaluator_result_path: str,
    finished_at: str,
) -> None:
    attempt = next(item for item in state["attempts"] if item["attempt_id"] == attempt_id)
    attempt.update(
        {
            "terminal_status": result["terminal_status"],
            "replacement_eligible": result["replacement_eligible"],
            "replacement_disposition": result["replacement_disposition"],
            "finished_at": finished_at,
            "wall_clock_seconds": result["wall_clock_seconds"],
            "produced_work": result["produced_work"],
            "result_path": result_path,
            "candidate_report_path": candidate_report_path,
            "evaluator_result_path": evaluator_result_path,
        }
    )
    if not result["replacement_eligible"] and result["run_id"] not in state["completed_runs"]:
        state["completed_runs"].append(result["run_id"])
    state["status"] = "completed" if len(state["completed_runs"]) == 2 else "ready"


def plan_attempt(state: dict, run_id: str) -> dict:
    prior = [item for item in state["attempts"] if item["run_id"] == run_id]
    if not prior:
        return {
            "attempt_id": f"{run_id}-attempt-1",
            "run_id": run_id,
            "attempt_number": 1,
            "is_replacement": False,
        }
    if (
        len(prior) != 1
        or prior[0].get("terminal_status") not in {"provider-failed", "harness-failed"}
        or not prior[0].get("replacement_eligible", False)
    ):
        raise ValueError("run has no eligible replacement")
    if state["replacement_processes_started"] >= 1:
        raise ValueError("campaign replacement budget is exhausted")
    return {
        "attempt_id": f"{run_id}-attempt-2",
        "run_id": run_id,
        "attempt_number": 2,
        "is_replacement": True,
    }


def clone_candidate_base(source: str, branch: str, sha: str, destination: Path) -> None:
    subprocess.run(
        [
            "git",
            "clone",
            "--quiet",
            "--no-local",
            "--single-branch",
            "--branch",
            branch,
            "--no-tags",
            source,
            str(destination),
        ],
        check=True,
    )
    observed = subprocess.run(
        ["git", "-C", str(destination), "rev-parse", "HEAD"],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.strip()
    if observed != sha:
        raise ValueError("standalone clone does not match frozen candidate base")
    alternates = destination / ".git/objects/info/alternates"
    if alternates.exists():
        raise ValueError("standalone clone shares an object database")
    refs = subprocess.run(
        ["git", "-C", str(destination), "for-each-ref", "--format=%(refname)", "refs/remotes/origin"],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.splitlines()
    if refs != [f"refs/remotes/origin/{branch}"]:
        raise ValueError("standalone clone exposes unexpected remote refs")
    subprocess.run(
        ["git", "-C", str(destination), "remote", "set-url", "origin", "disabled://candidate-fetch-prohibited"],
        check=True,
    )
    subprocess.run(
        ["git", "-C", str(destination), "config", "user.name", "Benchmark Candidate"],
        check=True,
    )
    subprocess.run(
        ["git", "-C", str(destination), "config", "user.email", "benchmark@example.invalid"],
        check=True,
    )


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def redact(text: str) -> str:
    patterns = (
        (r"(?i)(authorization:\s*(?:bearer|token)\s+)[^\s]+", r"\1[REDACTED]"),
        (r"(?i)((?:token|password|secret|api[_-]?key)\s*[=:]\s*)[^\s]+", r"\1[REDACTED]"),
        (r"gh[opsu]_[A-Za-z0-9_]{20,}", "[REDACTED_GITHUB_TOKEN]"),
    )
    for pattern, replacement in patterns:
        text = re.sub(pattern, replacement, text)
    return text


def run_tracked_command(command: list[str], cwd: Path, log_path: Path, timeout: int) -> dict:
    started = time.monotonic()
    try:
        completed = subprocess.run(
            command,
            cwd=cwd,
            env=PILOT.candidate_environment(os.environ),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
        output = completed.stdout
        exit_code = completed.returncode
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or "") + f"\ncommand timed out after {timeout} seconds\n"
        exit_code = 124
    except OSError as error:
        output = f"command could not start: {error}\n"
        exit_code = 127
    lines = [line.rstrip() for line in redact(output).splitlines()]
    while lines and not lines[-1]:
        lines.pop()
    bounded = "\n".join(lines) + ("\n" if lines else "")
    encoded = bounded.encode("utf-8", errors="replace")
    truncated = len(encoded) > MAX_TRACKED_LOG_BYTES
    if truncated:
        encoded = encoded[:MAX_TRACKED_LOG_BYTES] + b"\n[tracked log truncated]\n"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_bytes(encoded)
    return {
        "exit_code": exit_code,
        "elapsed_seconds": int(time.monotonic() - started),
        "log_sha256": sha256_bytes(encoded),
        "log_truncated": truncated,
    }


def evaluate_candidate(
    checkout: Path,
    run_id: str,
    attempt_id: str,
    candidate_sha: str,
    produced_work: bool,
    candidate_completed: bool,
) -> dict:
    if not produced_work:
        return {
            "schema_version": "task-parallelism-phase-0b-revision-evaluator-result.v1",
            "campaign_id": "vector-siege-phase-0b-revision",
            "run_id": run_id,
            "attempt_id": attempt_id,
            "candidate_sha": candidate_sha,
            "produced_work": False,
            "evaluated": False,
            "skip_reason": "no-candidate-work",
            "wall_clock_seconds": 0,
            "objective_score": 10 if candidate_completed else 0,
            "checks": {},
        }
    checks = (
        ("install", ["npm", "ci", "--ignore-scripts"], 10),
        ("browser", ["npx", "playwright", "install", "chromium"], 0),
        ("unit", ["npm", "test"], 20),
        ("build", ["npm", "run", "build"], 20),
        ("e2e", ["npm", "run", "test:e2e"], 30),
    )
    started = time.monotonic()
    score = (10 if candidate_completed else 0) + 10
    observed = {}
    for name, command, points in checks:
        log_path = RESULT_ROOT / "evaluations" / attempt_id / f"{name}.txt"
        outcome = run_tracked_command(command, checkout, log_path, 300)
        awarded = points if outcome["exit_code"] == 0 else 0
        score += awarded
        observed[name] = {
            "command": command,
            "timeout_seconds": 300,
            "exit_code": outcome["exit_code"],
            "points_awarded": awarded,
            "log_path": relative_to_protocol(log_path),
            "log_sha256": outcome["log_sha256"],
            "log_truncated": outcome["log_truncated"],
        }
    return {
        "schema_version": "task-parallelism-phase-0b-revision-evaluator-result.v1",
        "campaign_id": "vector-siege-phase-0b-revision",
        "run_id": run_id,
        "attempt_id": attempt_id,
        "candidate_sha": candidate_sha,
        "produced_work": True,
        "evaluated": True,
        "skip_reason": None,
        "wall_clock_seconds": int(time.monotonic() - started),
        "objective_score": score,
        "checks": observed,
    }


def candidate_command(revision: dict, checkout: Path, artifact_dir: Path) -> list[str]:
    command = list(revision["candidate_runtime"]["candidate_command"])
    if command[-1] != "-":
        raise ValueError("candidate command must read its prompt from stdin")
    return command[:-1] + [
        "--ignore-user-config",
        "--color",
        "never",
        "-C",
        str(checkout),
        "--output-schema",
        str(REPORT_SCHEMA),
        "--output-last-message",
        str(artifact_dir / "final-report.json"),
        "-",
    ]


def load_candidate_report(path: Path, arm: str) -> dict:
    report = load_json(path)
    validate_document(report, REPORT_SCHEMA)
    if arm == "A" and (report["fanout_elected"] or report["worker_count"] != 1):
        raise ValueError("Arm A candidate reported fan-out")
    if not report["fanout_elected"] and report["worker_count"] != 1:
        raise ValueError("candidate reported multiple workers without fan-out")
    return report


def count_spawned_subagents(jsonl_path: Path) -> int:
    receiver_ids = set()
    for line in jsonl_path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        item = event.get("item", {})
        if (
            event.get("type") == "item.completed"
            and item.get("type") == "collab_tool_call"
            and item.get("tool") == "spawn_agent"
        ):
            receiver_ids.update(item.get("receiver_thread_ids", []))
    return len(receiver_ids)


def classify_candidate(rc: int, jsonl_path: Path, report: dict | None) -> tuple[str, str | None, bool]:
    if report is not None and report["completion_status"] != "completed":
        return "candidate-failed", f"candidate reported {report['completion_status']}", False
    if rc == 0 and report is not None:
        return "completed", None, False
    terminal, harness, replacement = PILOT.classify_failure(rc, jsonl_path)
    failure_class = "harness-invalid" if harness else terminal.removesuffix("-failed")
    return terminal, failure_class, replacement


def blank_telemetry() -> dict:
    return {
        "skill_loads": 0,
        "skill_context_tokens": 0,
        "coordination_seconds": 0,
        "provider_wait_seconds": 0,
        "rescue_events": 0,
        "duplicate_or_abandoned_work": 0,
        "semantic_conflicts": 0,
        "interface_conflicts": 0,
        "asset_conflicts": 0,
        "dependency_conflicts": 0,
        "fanout_elected": False,
        "worker_count": 1,
    }


def publish_candidate(checkout: Path, source: str, branch: str) -> None:
    subprocess.run(
        ["git", "-C", str(checkout), "remote", "add", "evaluator-publish", source], check=True
    )
    subprocess.run(
        ["git", "-C", str(checkout), "push", "evaluator-publish", f"HEAD:refs/heads/{branch}"],
        check=True,
    )
    subprocess.run(["git", "-C", str(checkout), "remote", "remove", "evaluator-publish"], check=True)


def execute_run(run_id: str) -> int:
    state = load_state()
    revision = load_json(REVISION_PATH)
    next_index = len(state["completed_runs"])
    if next_index >= len(ASSIGNMENTS) or ASSIGNMENTS[next_index][0] != run_id:
        raise ValueError("run is not the next sequential assignment")
    if state["implementation_sha"] is None:
        raise ValueError("activation implementation SHA is not frozen")
    if subprocess.run(
        ["git", "merge-base", "--is-ancestor", state["implementation_sha"], "HEAD"],
        cwd=REPO_ROOT,
        check=False,
    ).returncode != 0:
        raise ValueError("activation implementation SHA is not an ancestor of HEAD")
    attempt = plan_attempt(state, run_id)
    PILOT.verify_remote_base(state)
    arm = ASSIGNMENTS[next_index][1]
    attempt_id = attempt["attempt_id"]
    artifact_dir = ARTIFACT_ROOT / attempt_id
    checkout = ARTIFACT_ROOT / "clones" / attempt_id
    if artifact_dir.exists() or checkout.exists():
        raise ValueError("attempt artifacts already exist")
    artifact_dir.mkdir(parents=True)
    source = subprocess.run(
        ["git", "remote", "get-url", "origin"],
        cwd=REPO_ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    ).stdout.strip()
    clone_candidate_base(
        source,
        state["candidate_base"]["branch"],
        state["candidate_base"]["sha"],
        checkout,
    )
    override_path = checkout / "AGENTS.override.md"
    override_path.write_text(PREPARE.render_candidate_instructions(arm), encoding="utf-8")
    override_sha = sha256_file(override_path)
    process_path = RESULT_ROOT / "process" / f"{attempt_id}.json"
    state_attempt = {
        **attempt,
        "terminal_status": None,
        "replacement_eligible": False,
        "replacement_disposition": "pending",
        "started_at": now(),
        "finished_at": None,
        "wall_clock_seconds": None,
        "produced_work": None,
        "result_path": None,
        "candidate_report_path": None,
        "process_metadata_path": relative_to_protocol(process_path),
        "evaluator_result_path": None,
    }
    state["attempts"].append(state_attempt)
    state["candidate_processes_started"] += 1
    if attempt["is_replacement"]:
        state["replacement_processes_started"] += 1
    state["status"] = "running"
    write_json(STATE_PATH, state)

    started = time.monotonic()
    jsonl_path = artifact_dir / "agent-output.jsonl"
    stderr_path = artifact_dir / "stderr.txt"
    report = None
    report_error = None
    invocation_error = None
    thread_id = None
    usage = {"input": 0, "cached_input": 0, "output": 0}
    rc = 70
    with jsonl_path.open("w", encoding="utf-8") as stdout, stderr_path.open(
        "w", encoding="utf-8"
    ) as stderr:
        try:
            completed = subprocess.run(
                candidate_command(revision, checkout, artifact_dir),
                cwd=checkout,
                input=PILOT.build_prompt(revision, arm),
                text=True,
                stdout=stdout,
                stderr=stderr,
                env=PILOT.candidate_environment(os.environ),
                timeout=1800,
                check=False,
            )
            rc = completed.returncode
        except subprocess.TimeoutExpired:
            rc = 124
            stderr.write("candidate timed out after 1800 seconds\n")
        except OSError as error:
            rc = 127
            invocation_error = f"candidate process could not start: {error}"
            stderr.write(f"{invocation_error}\n")
    usage, thread_id = PILOT.parse_usage(jsonl_path)
    observed_spawn_agent_calls = count_spawned_subagents(jsonl_path)
    report_path = artifact_dir / "final-report.json"
    if report_path.is_file():
        try:
            report = load_candidate_report(report_path, arm)
        except (OSError, ValueError, json.JSONDecodeError, SchemaError, ValidationError) as error:
            report_error = str(error)
    elif rc == 0:
        report_error = "candidate completed without a final report"
    if not override_path.is_file() or sha256_file(override_path) != override_sha:
        invocation_error = "candidate instruction override was modified or removed"
    if override_path.is_file():
        override_path.unlink()

    changed = []
    candidate_sha = state["candidate_base"]["sha"]
    drift_count = 0
    try:
        changed, candidate_sha, drift_count = PILOT.snapshot_candidate(
            checkout, state["candidate_base"]["sha"], attempt_id
        )
    except (OSError, subprocess.CalledProcessError) as error:
        invocation_error = f"candidate evidence snapshot failed: {error}"
    produced_work = bool(changed)
    terminal, failure_class, replacement_eligible = classify_candidate(rc, jsonl_path, report)
    failure_reason = None
    if report_error or invocation_error:
        terminal = "harness-failed"
        failure_class = "harness-invalid"
        failure_reason = report_error or invocation_error
        replacement_eligible = True
    elif terminal != "completed":
        failure_reason = failure_class
    if attempt["is_replacement"]:
        replacement_eligible = False

    evaluation = evaluate_candidate(
        checkout,
        run_id,
        attempt_id,
        candidate_sha,
        produced_work,
        terminal == "completed",
    )
    evaluation_path = RESULT_ROOT / "evaluations" / f"{attempt_id}.json"
    validate_document(evaluation, EVALUATOR_SCHEMA)
    write_json(evaluation_path, evaluation)
    candidate_branch = f"benchmark/vector-siege/{attempt_id}"
    published = False
    try:
        publish_candidate(checkout, source, candidate_branch)
        published = True
    except subprocess.CalledProcessError as error:
        terminal = "harness-failed"
        failure_class = "harness-invalid"
        failure_reason = f"candidate evidence publication failed: {error}"
        replacement_eligible = not attempt["is_replacement"]

    tracked_report_path = None
    if report is not None:
        tracked = RESULT_ROOT / "candidate-reports" / f"{attempt_id}.json"
        write_json(tracked, report)
        tracked_report_path = relative_to_protocol(tracked)
    telemetry = blank_telemetry()
    if report is not None:
        telemetry.update({key: report[key] for key in telemetry})
    elapsed = int(time.monotonic() - started)
    replacement_disposition = (
        "replacement-consumed"
        if attempt["is_replacement"]
        else "eligible" if replacement_eligible else "not-eligible"
    )
    result = {
        "schema_version": "task-parallelism-phase-0b-revision-candidate-result.v1",
        "campaign_id": "vector-siege-phase-0b-revision",
        "run_id": run_id,
        "attempt_id": attempt_id,
        "arm": arm,
        "terminal_status": terminal,
        "failure_class": failure_class,
        "failure_reason": redact(failure_reason)[:500] if failure_reason else None,
        "base_sha": state["candidate_base"]["sha"],
        "candidate_sha": candidate_sha,
        "candidate_branch": candidate_branch,
        "produced_work": produced_work,
        "changed_files": sorted(changed),
        "quality_score": evaluation["objective_score"] if terminal == "completed" else 0,
        "wall_clock_seconds": elapsed,
        "wall_clock_comparable": True,
        "tokens": usage,
        **telemetry,
        "predicted_path_drift_count": drift_count,
        "candidate_report_path": tracked_report_path,
        "evaluator_result_path": relative_to_protocol(evaluation_path),
        "replacement_eligible": replacement_eligible,
        "replacement_disposition": replacement_disposition,
        "official_pilot_score_modified": False,
    }
    validate_document(result, RESULT_SCHEMA)
    attempt_result_path = RESULT_ROOT / "attempts" / f"{attempt_id}.json"
    write_json(attempt_result_path, result)
    write_json(
        process_path,
        {
            "schema_version": "task-parallelism-phase-0b-revision-process.v1",
            "run_id": run_id,
            "attempt_id": attempt_id,
            "arm": arm,
            "thread_id": thread_id,
            "codex_exit_code": rc,
            "candidate_branch": candidate_branch,
            "candidate_sha": candidate_sha,
            "instruction_sha256": override_sha,
            "observed_spawn_agent_calls": observed_spawn_agent_calls,
            "parent_worker_token_split_available": False,
            "published": published,
            "clone_retained": produced_work and not published,
            "raw_artifact_path": str(artifact_dir.relative_to(REPO_ROOT)),
            "token_usage_scope": "aggregate-candidate-turn",
        },
    )
    if not replacement_eligible:
        final_result_path = RESULT_ROOT / "final" / f"{run_id}.json"
        write_json(final_result_path, result)
    finalize_attempt_state(
        state,
        attempt_id,
        result,
        relative_to_protocol(attempt_result_path),
        tracked_report_path,
        relative_to_protocol(evaluation_path),
        now(),
    )
    validate_state(state)
    write_json(STATE_PATH, state)
    if published or not produced_work:
        shutil.rmtree(checkout)
    note = " replacement-eligible" if replacement_eligible else ""
    print(f"{attempt_id}: {terminal} quality={result['quality_score']}{note}")
    return 0


def snapshot_interrupted_candidate(
    checkout: Path, base_sha: str, attempt_id: str, arm: str
) -> tuple[list[str], str, int, str, str | None, bool | None]:
    override = checkout / "AGENTS.override.md"
    instruction_sha = sha256_bytes(
        PREPARE.render_candidate_instructions(arm).encode("utf-8")
    )
    observed_instruction_sha = sha256_file(override) if override.is_file() else None
    instruction_override_intact = observed_instruction_sha == instruction_sha
    if override.is_file():
        override.unlink()
    changed, candidate_sha, drift_count = PILOT.snapshot_candidate(
        checkout, base_sha, attempt_id
    )
    return (
        changed,
        candidate_sha,
        drift_count,
        instruction_sha,
        observed_instruction_sha,
        instruction_override_intact,
    )


def recover_interrupted(attempt_id: str) -> int:
    state = load_state()
    attempts = [item for item in state["attempts"] if item["attempt_id"] == attempt_id]
    if len(attempts) != 1 or attempts[0]["terminal_status"] is not None:
        raise ValueError("attempt is not an interrupted in-progress attempt")
    attempt = attempts[0]
    run_id = attempt["run_id"]
    arm = dict(ASSIGNMENTS)[run_id]
    attempt_result_path = RESULT_ROOT / "attempts" / f"{attempt_id}.json"
    if attempt_result_path.is_file():
        result = load_json(attempt_result_path)
        validate_document(result, RESULT_SCHEMA)
        evaluation_path = PROTOCOL_ROOT / result["evaluator_result_path"]
        validate_document(load_json(evaluation_path), EVALUATOR_SCHEMA)
        if not result["replacement_eligible"]:
            write_json(RESULT_ROOT / "final" / f"{run_id}.json", result)
        process_path = PROTOCOL_ROOT / attempt["process_metadata_path"]
        if process_path.is_file():
            process = load_json(process_path)
            process["state_recovery"] = "terminal state reconstructed from retained evidence"
            write_json(process_path, process)
        finalize_attempt_state(
            state,
            attempt_id,
            result,
            relative_to_protocol(attempt_result_path),
            result["candidate_report_path"],
            result["evaluator_result_path"],
            now(),
        )
        validate_state(state)
        write_json(STATE_PATH, state)
        print(f"recovered terminal state from retained evidence: {attempt_id}")
        return 0

    checkout = ARTIFACT_ROOT / "clones" / attempt_id
    artifact_dir = ARTIFACT_ROOT / attempt_id
    base_sha = state["candidate_base"]["sha"]
    changed = []
    candidate_sha = base_sha
    drift_count = 0
    instruction_sha = sha256_bytes(
        PREPARE.render_candidate_instructions(arm).encode("utf-8")
    )
    observed_instruction_sha = None
    instruction_override_intact = None
    if checkout.is_dir():
        (
            changed,
            candidate_sha,
            drift_count,
            instruction_sha,
            observed_instruction_sha,
            instruction_override_intact,
        ) = snapshot_interrupted_candidate(checkout, base_sha, attempt_id, arm)
    produced_work = bool(changed)
    report = None
    report_path = artifact_dir / "final-report.json"
    if report_path.is_file():
        try:
            report = load_candidate_report(report_path, arm)
        except (OSError, ValueError, json.JSONDecodeError, SchemaError, ValidationError):
            report = None
    tracked_report_path = None
    if report is not None:
        tracked_report = RESULT_ROOT / "candidate-reports" / f"{attempt_id}.json"
        write_json(tracked_report, report)
        tracked_report_path = relative_to_protocol(tracked_report)
    jsonl_path = artifact_dir / "agent-output.jsonl"
    usage, thread_id = PILOT.parse_usage(jsonl_path)
    observed_spawn_agent_calls = count_spawned_subagents(jsonl_path) if jsonl_path.is_file() else 0
    evaluation = evaluate_candidate(
        checkout,
        run_id,
        attempt_id,
        candidate_sha,
        produced_work,
        False,
    )
    evaluation_path = RESULT_ROOT / "evaluations" / f"{attempt_id}.json"
    validate_document(evaluation, EVALUATOR_SCHEMA)
    write_json(evaluation_path, evaluation)
    candidate_branch = f"benchmark/vector-siege/{attempt_id}"
    published = False
    publication_failure = None
    if checkout.is_dir():
        try:
            source = subprocess.run(
                ["git", "remote", "get-url", "origin"],
                cwd=REPO_ROOT,
                check=True,
                text=True,
                stdout=subprocess.PIPE,
            ).stdout.strip()
            publish_candidate(checkout, source, candidate_branch)
            published = True
        except (OSError, subprocess.CalledProcessError) as error:
            publication_failure = f"candidate evidence publication failed: {error}"
    started = datetime.fromisoformat(attempt["started_at"].replace("Z", "+00:00"))
    elapsed = max(0, int((datetime.now(timezone.utc) - started).total_seconds()))
    replacement_eligible = not attempt["is_replacement"]
    replacement_disposition = "eligible" if replacement_eligible else "replacement-consumed"
    telemetry = blank_telemetry()
    if report is not None:
        telemetry.update({key: report[key] for key in telemetry})
    result = {
        "schema_version": "task-parallelism-phase-0b-revision-candidate-result.v1",
        "campaign_id": "vector-siege-phase-0b-revision",
        "run_id": run_id,
        "attempt_id": attempt_id,
        "arm": arm,
        "terminal_status": "harness-failed",
        "failure_class": "interrupted-harness",
        "failure_reason": redact(
            publication_failure or "execution interrupted before terminal state was recorded"
        )[:500],
        "base_sha": base_sha,
        "candidate_sha": candidate_sha,
        "candidate_branch": candidate_branch,
        "produced_work": produced_work,
        "changed_files": sorted(changed),
        "quality_score": 0,
        "wall_clock_seconds": 0,
        "wall_clock_comparable": False,
        "tokens": usage,
        **telemetry,
        "predicted_path_drift_count": drift_count,
        "candidate_report_path": tracked_report_path,
        "evaluator_result_path": relative_to_protocol(evaluation_path),
        "replacement_eligible": replacement_eligible,
        "replacement_disposition": replacement_disposition,
        "official_pilot_score_modified": False,
    }
    validate_document(result, RESULT_SCHEMA)
    write_json(attempt_result_path, result)
    process_path = RESULT_ROOT / "process" / f"{attempt_id}.json"
    write_json(
        process_path,
        {
            "schema_version": "task-parallelism-phase-0b-revision-process.v1",
            "run_id": run_id,
            "attempt_id": attempt_id,
            "arm": arm,
            "thread_id": thread_id,
            "candidate_branch": candidate_branch,
            "candidate_sha": candidate_sha,
            "instruction_sha256": instruction_sha,
            "observed_instruction_sha256": observed_instruction_sha,
            "instruction_override_intact": instruction_override_intact,
            "observed_spawn_agent_calls": observed_spawn_agent_calls,
            "parent_worker_token_split_available": False,
            "published": published,
            "clone_retained": produced_work and not published,
            "raw_artifact_path": str(artifact_dir.relative_to(REPO_ROOT)),
            "elapsed_since_start_seconds": elapsed,
            "state_recovery": "interrupted attempt captured and classified harness-failed",
            "token_usage_scope": "aggregate-candidate-turn",
        },
    )
    if not replacement_eligible:
        write_json(RESULT_ROOT / "final" / f"{run_id}.json", result)
    finalize_attempt_state(
        state,
        attempt_id,
        result,
        relative_to_protocol(attempt_result_path),
        tracked_report_path,
        relative_to_protocol(evaluation_path),
        now(),
    )
    validate_state(state)
    write_json(STATE_PATH, state)
    if published or not produced_work:
        shutil.rmtree(checkout, ignore_errors=True)
    print(f"recovered interrupted attempt as harness-failed: {attempt_id}")
    return 0


def build_summary(state: dict, results: list[dict], evaluations: list[dict]) -> dict:
    evaluation_by_run = {item["run_id"]: item for item in evaluations}
    arms = []
    for result in results:
        evaluation = evaluation_by_run[result["run_id"]]
        wall_clock_comparable = result["wall_clock_comparable"]
        arms.append(
            {
                "run_id": result["run_id"],
                "arm": result["arm"],
                "terminal_status": result["terminal_status"],
                "produced_work": result["produced_work"],
                "fanout_elected": result["fanout_elected"],
                "worker_count": result["worker_count"],
                "coordination_seconds": result["coordination_seconds"],
                "skill_loads": result["skill_loads"],
                "tokens": result["tokens"],
                "candidate_wall_clock_seconds": (
                    result["wall_clock_seconds"] if wall_clock_comparable else None
                ),
                "candidate_wall_clock_comparable": wall_clock_comparable,
                "evaluator_wall_clock_seconds": evaluation["wall_clock_seconds"],
                "candidate_quality_score": result["quality_score"],
                "evaluator_objective_score": evaluation["objective_score"],
                "evaluator_result_path": result["evaluator_result_path"],
            }
        )
    candidate_wall_clock_comparable = all(
        item["wall_clock_comparable"] for item in results
    )
    return {
        "schema_version": "task-parallelism-phase-0b-revision-summary.v1",
        "campaign_id": "vector-siege-phase-0b-revision",
        "official_pilot_scores_modified": False,
        "directional_only": True,
        "confirmatory_evidence": False,
        "adoption_claim": False,
        "assigned_runs": 2,
        "terminal_runs": len(state["completed_runs"]),
        "attempts_started": len(state["attempts"]),
        "replacement_processes_started": state["replacement_processes_started"],
        "candidate_wall_clock_seconds": (
            sum(item["wall_clock_seconds"] for item in results)
            if candidate_wall_clock_comparable
            else None
        ),
        "candidate_wall_clock_comparable": candidate_wall_clock_comparable,
        "evaluator_wall_clock_seconds": sum(item["wall_clock_seconds"] for item in evaluations),
        "tokens": {
            key: sum(item["tokens"][key] for item in results)
            for key in ("input", "cached_input", "output")
        },
        "token_usage_scope": "aggregate-candidate-turn",
        "parent_worker_token_split_available": False,
        "arms": arms,
        "redaction": {
            "credentials_excluded": True,
            "raw_environment_excluded": True,
            "raw_model_transcript_excluded": True,
        },
    }


def summarize(output: Path) -> int:
    state = load_state()
    if state["completed_runs"] != [item[0] for item in ASSIGNMENTS]:
        raise ValueError("both revision assignments must be terminal before summarization")
    results = []
    evaluations = []
    for run_id, _ in ASSIGNMENTS:
        result = load_json(RESULT_ROOT / "final" / f"{run_id}.json")
        validate_document(result, RESULT_SCHEMA)
        evaluation = load_json(PROTOCOL_ROOT / result["evaluator_result_path"])
        validate_document(evaluation, EVALUATOR_SCHEMA)
        results.append(result)
        evaluations.append(evaluation)
    summary = build_summary(state, results, evaluations)
    validate_document(summary, SUMMARY_SCHEMA)
    write_json(output, summary)
    print(f"wrote Phase 0B revision summary: {output}")
    return 0


def verify_local_base_if_available(state: dict) -> bool:
    return PILOT.verify_local_base_if_available(state)


def main() -> int:
    parser = argparse.ArgumentParser()
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--validate-state", action="store_true")
    action.add_argument("--run-id")
    action.add_argument("--recover-interrupted")
    action.add_argument("--summarize", action="store_true")
    parser.add_argument("--output", type=Path, default=RESULT_ROOT / "paired-summary.json")
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args()
    if args.offline and not args.validate_state:
        parser.error("--offline is valid only with --validate-state")
    try:
        if args.validate_state:
            state = load_state()
            if args.offline:
                local = verify_local_base_if_available(state)
                note = "local frozen base task blob verified" if local else "frozen base unavailable locally"
                print(
                    f"revision execution state valid: {state['status']}; "
                    f"candidate processes started: {state['candidate_processes_started']}; {note}"
                )
            else:
                PILOT.verify_remote_base(state)
                print(
                    f"revision execution state valid: {state['status']}; "
                    f"candidate processes started: {state['candidate_processes_started']}"
                )
            return 0
        if args.run_id:
            return execute_run(args.run_id)
        if args.recover_interrupted:
            return recover_interrupted(args.recover_interrupted)
        return summarize(args.output.resolve())
    except (
        OSError,
        ValueError,
        json.JSONDecodeError,
        SchemaError,
        ValidationError,
        subprocess.CalledProcessError,
    ) as error:
        print(f"Phase 0B revision execution failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
