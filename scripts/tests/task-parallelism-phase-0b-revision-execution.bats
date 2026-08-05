#!/usr/bin/env bats

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
	RUNNER="${REPO_ROOT}/scripts/benchmark/task-parallelism/run-phase-0b-revision.py"
	PROTOCOL="${REPO_ROOT}/.context/benchmarks/model-roi/task-parallelism"
	STATE="${PROTOCOL}/campaign.phase-0b.revision.execution.json"
	REPORT_SCHEMA="${PROTOCOL}/phase-0b-revision-candidate-report.schema.json"
	RESULT_SCHEMA="${PROTOCOL}/phase-0b-revision-candidate-result.schema.json"
	EVALUATOR_SCHEMA="${PROTOCOL}/phase-0b-revision-evaluator-result.schema.json"
	SUMMARY_SCHEMA="${PROTOCOL}/phase-0b-revision-summary.schema.json"
}

@test "revision execution state records approval and remains a sequential prefix" {
	[ -f "${RUNNER}" ]
	[ -f "${STATE}" ]
	[ -f "${PROTOCOL}/phase-0b-revision-execution.schema.json" ]
	[ -f "${RESULT_SCHEMA}" ]
	[ -f "${EVALUATOR_SCHEMA}" ]
	[ -f "${SUMMARY_SCHEMA}" ]

	run python3 "${RUNNER}" --validate-state --offline
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'revision execution state valid:'* ]]

	run jq -e '
    .approval_source == "https://github.com/mikejmckinney/ai-repo-template/issues/545" and
    .official_pilot_scores_modified == false and
    .candidate_processes_started == (.attempts | length) and
    .replacement_processes_started <= 1 and
    (.completed_runs == [] or
      .completed_runs == ["vs-p0b-next-a"] or
      .completed_runs == ["vs-p0b-next-a", "vs-p0b-next-b"])
  ' "${STATE}"
	[ "${status}" -eq 0 ]

	run jq -e '
    .candidate_runtime.candidate_command as $command |
    ($command | index("danger-full-access")) != null and
    ($command | index("multi_agent")) != null and
    ($command | index("project_doc_max_bytes=65536")) != null
  ' "${PROTOCOL}/campaign.phase-0b.revision.json"
	[ "${status}" -eq 0 ]
}

@test "revision candidate report permits uncapped Arm B worker counts" {
	[ -f "${REPORT_SCHEMA}" ]
	run jq -e '[.. | objects | select(has("allOf"))] | length == 0' "${REPORT_SCHEMA}"
	[ "${status}" -eq 0 ]

	run python3 - "${REPORT_SCHEMA}" <<'PY'
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

schema = json.loads(Path(sys.argv[1]).read_text())
report = {
    "completion_status": "completed",
    "fanout_elected": True,
    "fanout_reason": "Independent simulation and browser work",
    "worker_count": 7,
    "skill_loads": 2,
    "skill_context_tokens": 300,
    "coordination_seconds": 90,
    "provider_wait_seconds": 10,
    "rescue_events": 0,
    "duplicate_or_abandoned_work": 0,
    "semantic_conflicts": 0,
    "interface_conflicts": 0,
    "asset_conflicts": 0,
    "dependency_conflicts": 0,
}
Draft202012Validator(schema).validate(report)
PY
	[ "${status}" -eq 0 ]
}

@test "standalone clone exposes only the frozen candidate branch" {
	run python3 - "${RUNNER}" "${BATS_TEST_TMPDIR}" <<'PY'
import importlib.util
import subprocess
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("phase0b_revision", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
root = Path(sys.argv[2])
source = root / "source"
remote = root / "remote.git"
clone = root / "candidate"
source.mkdir()
subprocess.run(["git", "init", "-q", "-b", "frozen-base", str(source)], check=True)
subprocess.run(["git", "-C", str(source), "config", "user.name", "Benchmark"], check=True)
subprocess.run(["git", "-C", str(source), "config", "user.email", "benchmark@example.invalid"], check=True)
(source / "TASK.md").write_text("frozen\n")
subprocess.run(["git", "-C", str(source), "add", "TASK.md"], check=True)
subprocess.run(["git", "-C", str(source), "commit", "--no-gpg-sign", "-q", "-m", "base"], check=True)
base_sha = subprocess.run(
    ["git", "-C", str(source), "rev-parse", "HEAD"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
).stdout.strip()
subprocess.run(["git", "-C", str(source), "switch", "-q", "-c", "prior-candidate"], check=True)
(source / "leaked.txt").write_text("must not be visible\n")
subprocess.run(["git", "-C", str(source), "add", "leaked.txt"], check=True)
subprocess.run(["git", "-C", str(source), "commit", "--no-gpg-sign", "-q", "-m", "leak"], check=True)
subprocess.run(["git", "clone", "-q", "--bare", str(source), str(remote)], check=True)

module.clone_candidate_base(str(remote), "frozen-base", base_sha, clone)
refs = subprocess.run(
    ["git", "-C", str(clone), "for-each-ref", "--format=%(refname)", "refs/remotes/origin"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
).stdout
assert "prior-candidate" not in refs
assert "origin/frozen-base" in refs
assert not (clone / "leaked.txt").exists()
assert not (clone / ".git/objects/info/alternates").exists()
assert subprocess.run(
    ["git", "-C", str(clone), "remote", "get-url", "origin"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
).stdout.strip() == "disabled://candidate-fetch-prohibited"
assert subprocess.run(
    ["git", "-C", str(clone), "rev-parse", "HEAD"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
).stdout.strip() == base_sha
PY
	[ "${status}" -eq 0 ]
}

@test "candidate failures are final and one invalid replacement is retained" {
	run python3 - "${RUNNER}" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("phase0b_revision", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

assert module.plan_attempt({"replacement_processes_started": 0, "attempts": []}, "vs-p0b-next-a") == {
    "attempt_id": "vs-p0b-next-a-attempt-1",
    "run_id": "vs-p0b-next-a",
    "attempt_number": 1,
    "is_replacement": False,
}

candidate_failed = {
    "replacement_processes_started": 0,
    "attempts": [{
        "attempt_id": "vs-p0b-next-a-attempt-1",
        "run_id": "vs-p0b-next-a",
        "attempt_number": 1,
        "terminal_status": "candidate-failed",
        "replacement_eligible": False,
    }],
}
try:
    module.plan_attempt(candidate_failed, "vs-p0b-next-a")
except ValueError as error:
    assert "no eligible replacement" in str(error)
else:
    raise AssertionError("candidate failure received a replacement")

harness_failed = {
    "replacement_processes_started": 0,
    "attempts": [{
        "attempt_id": "vs-p0b-next-a-attempt-1",
        "run_id": "vs-p0b-next-a",
        "attempt_number": 1,
        "terminal_status": "harness-failed",
        "replacement_eligible": True,
    }],
}
assert module.plan_attempt(harness_failed, "vs-p0b-next-a") == {
    "attempt_id": "vs-p0b-next-a-attempt-2",
    "run_id": "vs-p0b-next-a",
    "attempt_number": 2,
    "is_replacement": True,
}
harness_failed["attempts"][0]["terminal_status"] = "provider-failed"
assert module.plan_attempt(harness_failed, "vs-p0b-next-a")["is_replacement"] is True
harness_failed["replacement_processes_started"] = 1
try:
    module.plan_attempt(harness_failed, "vs-p0b-next-a")
except ValueError as error:
    assert "replacement budget" in str(error)
else:
    raise AssertionError("second replacement was permitted")
PY
	[ "${status}" -eq 0 ]
}

@test "directional summary preserves the official pilot and adoption boundaries" {
	run python3 - "${RUNNER}" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("phase0b_revision", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
state = {
    "attempts": [
        {"attempt_id": "vs-p0b-next-a-attempt-1", "run_id": "vs-p0b-next-a"},
        {"attempt_id": "vs-p0b-next-b-attempt-1", "run_id": "vs-p0b-next-b"},
    ],
    "completed_runs": ["vs-p0b-next-a", "vs-p0b-next-b"],
    "replacement_processes_started": 0,
}
results = [
    {
        "run_id": "vs-p0b-next-a",
        "arm": "A",
        "terminal_status": "completed",
        "quality_score": 100,
        "wall_clock_seconds": 100,
        "tokens": {"input": 10, "cached_input": 2, "output": 3},
        "coordination_seconds": 0,
        "skill_loads": 1,
        "fanout_elected": False,
        "worker_count": 1,
        "produced_work": True,
        "evaluator_result_path": "results/phase-0b-revision/evaluations/a.json",
    },
    {
        "run_id": "vs-p0b-next-b",
        "arm": "B",
        "terminal_status": "candidate-failed",
        "quality_score": 0,
        "wall_clock_seconds": 120,
        "tokens": {"input": 20, "cached_input": 4, "output": 6},
        "coordination_seconds": 90,
        "skill_loads": 3,
        "fanout_elected": True,
        "worker_count": 7,
        "produced_work": True,
        "evaluator_result_path": "results/phase-0b-revision/evaluations/b.json",
    },
]
evaluations = [
    {"run_id": "vs-p0b-next-a", "evaluated": True, "wall_clock_seconds": 30, "objective_score": 90},
    {"run_id": "vs-p0b-next-b", "evaluated": True, "wall_clock_seconds": 40, "objective_score": 70},
]
summary = module.build_summary(state, results, evaluations)
assert summary["official_pilot_scores_modified"] is False
assert summary["directional_only"] is True
assert summary["confirmatory_evidence"] is False
assert summary["adoption_claim"] is False
assert summary["terminal_runs"] == 2
assert summary["candidate_wall_clock_seconds"] == 220
assert summary["evaluator_wall_clock_seconds"] == 70
assert summary["tokens"] == {"input": 30, "cached_input": 6, "output": 9}
assert summary["token_usage_scope"] == "aggregate-candidate-turn"
assert summary["parent_worker_token_split_available"] is False
assert [item["arm"] for item in summary["arms"]] == ["A", "B"]
assert summary["arms"][1]["tokens"] == {"input": 20, "cached_input": 4, "output": 6}
assert summary["arms"][1]["coordination_seconds"] == 90
assert summary["arms"][1]["candidate_quality_score"] == 0
assert summary["arms"][1]["evaluator_objective_score"] == 70
PY
	[ "${status}" -eq 0 ]
}

@test "parent evaluation runs every check for failed candidates that produced work" {
	run python3 - "${RUNNER}" "${BATS_TEST_TMPDIR}" <<'PY'
import importlib.util
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("phase0b_revision", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
root = Path(sys.argv[2])
module.PROTOCOL_ROOT = root
module.RESULT_ROOT = root / "results"
commands = []
def fake_run(command, cwd, log_path, timeout):
    commands.append(command)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text("pass\n")
    return {
        "exit_code": 0,
        "elapsed_seconds": 1,
        "log_sha256": module.sha256_bytes(b"pass\n"),
        "log_truncated": False,
    }
module.run_tracked_command = fake_run
skipped = module.evaluate_candidate(root, "vs-p0b-next-a", "vs-p0b-next-a-attempt-1", "0" * 40, False, True)
assert skipped["evaluated"] is False
assert skipped["skip_reason"] == "no-candidate-work"
evaluated = module.evaluate_candidate(root, "vs-p0b-next-b", "vs-p0b-next-b-attempt-1", "1" * 40, True, False)
assert evaluated["evaluated"] is True
assert evaluated["objective_score"] == 90
assert len(commands) == 5
PY
	[ "${status}" -eq 0 ]
}

@test "process metadata counts unique native subagent threads" {
	run python3 - "${RUNNER}" "${BATS_TEST_TMPDIR}" <<'PY'
import importlib.util
import json
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("phase0b_revision", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
path = Path(sys.argv[2]) / "events.jsonl"
events = [
    {"type": "item.completed", "item": {"type": "collab_tool_call", "tool": "spawn_agent", "receiver_thread_ids": ["worker-a"]}},
    {"type": "item.completed", "item": {"type": "collab_tool_call", "tool": "spawn_agent", "receiver_thread_ids": ["worker-b"]}},
    {"type": "item.completed", "item": {"type": "collab_tool_call", "tool": "spawn_agent", "receiver_thread_ids": ["worker-a"]}},
]
path.write_text("\n".join(json.dumps(event) for event in events) + "\n")
assert module.count_spawned_subagents(path) == 2
PY
	[ "${status}" -eq 0 ]
}

@test "interrupted state can be reconstructed from retained terminal evidence" {
	run python3 - "${RUNNER}" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("phase0b_revision", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
state = {
    "status": "running",
    "completed_runs": [],
    "attempts": [{
        "attempt_id": "vs-p0b-next-a-attempt-1",
        "run_id": "vs-p0b-next-a",
        "attempt_number": 1,
        "is_replacement": False,
        "terminal_status": None,
        "replacement_eligible": False,
        "replacement_disposition": "pending",
        "started_at": "2026-08-05T00:00:00Z",
        "finished_at": None,
        "wall_clock_seconds": None,
        "produced_work": None,
        "result_path": None,
        "candidate_report_path": None,
        "process_metadata_path": "results/process.json",
        "evaluator_result_path": None,
    }],
}
result = {
    "run_id": "vs-p0b-next-a",
    "terminal_status": "completed",
    "replacement_eligible": False,
    "replacement_disposition": "not-eligible",
    "wall_clock_seconds": 100,
    "produced_work": True,
}
module.finalize_attempt_state(
    state,
    "vs-p0b-next-a-attempt-1",
    result,
    "results/attempt.json",
    "results/report.json",
    "results/evaluation.json",
    "2026-08-05T00:02:00Z",
)
assert state["completed_runs"] == ["vs-p0b-next-a"]
assert state["status"] == "ready"
assert state["attempts"][0]["terminal_status"] == "completed"
assert state["attempts"][0]["result_path"] == "results/attempt.json"
PY
	[ "${status}" -eq 0 ]
}
