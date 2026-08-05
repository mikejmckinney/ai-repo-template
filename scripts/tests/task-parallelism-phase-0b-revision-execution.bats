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
    .arm_c_authorization.treatment == "prompt-gated-autonomous" and
    .arm_c_authorization.replacement_authorized == false and
    .official_pilot_scores_modified == false and
    .candidate_processes_started == (.attempts | length) and
    .replacement_processes_started <= 1 and
    .completed_runs == ["vs-p0b-next-a", "vs-p0b-next-b"] and
    .status == "ready"
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

@test "Arm C prompt mandates autonomous work-graph gating before fan-out" {
	run python3 - "${REPO_ROOT}/scripts/benchmark/task-parallelism/prepare-phase-0b.py" \
		"${RUNNER}" <<'PY'
import importlib.util
import sys

prepare_spec = importlib.util.spec_from_file_location("phase0b_prepare", sys.argv[1])
prepare = importlib.util.module_from_spec(prepare_spec)
prepare_spec.loader.exec_module(prepare)
runner_spec = importlib.util.spec_from_file_location("phase0b_revision", sys.argv[2])
runner = importlib.util.module_from_spec(runner_spec)
runner_spec.loader.exec_module(runner)

instructions = prepare.render_candidate_instructions("C")
normalized = " ".join(instructions.split())
assert "create and self-check a work graph" in normalized
assert "predicted write sets" in normalized
assert "Use native subagents" in normalized
assert runner.ASSIGNMENTS[-1] == ("vs-p0b-next-c", "C")
prompt = runner.build_candidate_prompt({
    "prompts": {"common": {"path": "prompts/common-v2.md"}}
}, "C")
assert "Prompt-Gated Autonomous Fan-Out" in prompt
assert "shared contracts" in prompt
PY
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

arm_c_failed = {
    "replacement_processes_started": 0,
    "attempts": [{
        "attempt_id": "vs-p0b-next-c-attempt-1",
        "run_id": "vs-p0b-next-c",
        "attempt_number": 1,
        "terminal_status": "harness-failed",
        "replacement_eligible": True,
    }],
}
try:
    module.plan_attempt(arm_c_failed, "vs-p0b-next-c")
except ValueError as error:
    assert "no eligible replacement" in str(error)
else:
    raise AssertionError("Arm C received an unauthorized replacement")

state = {
    "attempts": [{
        "attempt_id": "vs-p0b-next-c-attempt-1",
        "run_id": "vs-p0b-next-c",
    }],
    "completed_runs": ["vs-p0b-next-a", "vs-p0b-next-b"],
    "status": "running",
}
module.finalize_attempt_state(
    state,
    "vs-p0b-next-c-attempt-1",
    {
        "run_id": "vs-p0b-next-c",
        "terminal_status": "harness-failed",
        "replacement_eligible": False,
        "replacement_disposition": "not-eligible",
        "wall_clock_seconds": 1,
        "produced_work": False,
    },
    "attempt.json",
    None,
    "evaluation.json",
    "2026-08-05T00:00:00Z",
)
assert state["completed_runs"] == [
    "vs-p0b-next-a", "vs-p0b-next-b", "vs-p0b-next-c"
]
assert state["status"] == "completed"
PY
	[ "${status}" -eq 0 ]
}

@test "directional summary calculates official-rate ROI for B and C" {
	run python3 - "${RUNNER}" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("phase0b_revision", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
state = {
    "attempts": [
        {"run_id": "vs-p0b-next-a"},
        {"run_id": "vs-p0b-next-b"},
        {"run_id": "vs-p0b-next-c"},
    ],
    "completed_runs": ["vs-p0b-next-a", "vs-p0b-next-b", "vs-p0b-next-c"],
    "replacement_processes_started": 0,
}
results = [
    {
        "run_id": "vs-p0b-next-a", "arm": "A", "terminal_status": "completed",
        "quality_score": 100, "wall_clock_seconds": 100, "wall_clock_comparable": True,
        "tokens": {"input": 1000, "cached_input": 500, "output": 100},
        "coordination_seconds": 0, "skill_loads": 1, "fanout_elected": False,
        "worker_count": 1, "produced_work": True, "evaluator_result_path": "a.json",
    },
    {
        "run_id": "vs-p0b-next-b", "arm": "B", "terminal_status": "completed",
        "quality_score": 100, "wall_clock_seconds": 120, "wall_clock_comparable": True,
        "tokens": {"input": 1500, "cached_input": 750, "output": 100},
        "coordination_seconds": 20, "skill_loads": 2, "fanout_elected": True,
        "worker_count": 3, "produced_work": True, "evaluator_result_path": "b.json",
    },
    {
        "run_id": "vs-p0b-next-c", "arm": "C", "terminal_status": "completed",
        "quality_score": 95, "wall_clock_seconds": 90, "wall_clock_comparable": True,
        "tokens": {"input": 1200, "cached_input": 600, "output": 90},
        "coordination_seconds": 15, "skill_loads": 2, "fanout_elected": True,
        "worker_count": 2, "produced_work": True, "evaluator_result_path": "c.json",
    },
]
evaluations = [
    {"run_id": "vs-p0b-next-a", "wall_clock_seconds": 20, "objective_score": 100},
    {"run_id": "vs-p0b-next-b", "wall_clock_seconds": 30, "objective_score": 100},
    {"run_id": "vs-p0b-next-c", "wall_clock_seconds": 30, "objective_score": 95},
]
summary = module.build_summary(state, results, evaluations)
assert summary["assigned_runs"] == 3
assert summary["pricing"]["model"] == "gpt-5.6-luna"
assert summary["pricing"]["per_request_context_band_available"] is False
assert [item["candidate_arm"] for item in summary["roi_comparisons"]] == ["B", "C"]
for comparison in summary["roi_comparisons"]:
    assert comparison["baseline_arm"] == "A"
    assert comparison["cost_ratio"]["short_context"] > 0
    assert comparison["cost_ratio"]["all_long_context_upper_bound"] > 0
    assert comparison["roi_index"]["short_context"]["cost_50_time_50"] > 0
    assert comparison["roi_index"]["all_long_context_upper_bound"]["cost_75_time_25"] > 0
assert summary["roi_comparisons"][0]["quality_ratio"] == 1
assert summary["roi_comparisons"][0]["integrated_time_ratio"] == 1.25
assert summary["roi_comparisons"][0]["speedup"] == 0.8
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
        "wall_clock_comparable": True,
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
        "wall_clock_comparable": True,
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
assert summary["roi_comparisons"][0]["quality_ratio"] == 0
assert summary["candidate_wall_clock_comparable"] is True
assert all(item["candidate_wall_clock_comparable"] for item in summary["arms"])
results[1]["wall_clock_comparable"] = False
summary = module.build_summary(state, results, evaluations)
assert summary["candidate_wall_clock_comparable"] is False
assert summary["candidate_wall_clock_seconds"] is None
assert summary["arms"][1]["candidate_wall_clock_seconds"] is None
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

@test "interrupted recovery reconstructs retained terminal evidence without reevaluation" {
	run python3 - "${RUNNER}" "${BATS_TEST_TMPDIR}" <<'PY'
import importlib.util
import json
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("phase0b_revision", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
root = Path(sys.argv[2])
module.PROTOCOL_ROOT = root
module.RESULT_ROOT = root / "results"
module.ARTIFACT_ROOT = root / "artifacts"
module.STATE_PATH = root / "state.json"
module.RESULT_SCHEMA = root / "result.schema.json"
module.EVALUATOR_SCHEMA = root / "evaluation.schema.json"
state = {
    "status": "running",
    "completed_runs": [],
    "candidate_base": {"sha": "0" * 40},
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
        "process_metadata_path": "results/process/vs-p0b-next-a-attempt-1.json",
        "evaluator_result_path": None,
    }],
}
result = {
    "attempt_id": "vs-p0b-next-a-attempt-1",
    "run_id": "vs-p0b-next-a",
    "terminal_status": "completed",
    "replacement_eligible": False,
    "replacement_disposition": "not-eligible",
    "wall_clock_seconds": 100,
    "produced_work": True,
    "candidate_report_path": "results/report.json",
    "evaluator_result_path": "results/evaluations/vs-p0b-next-a-attempt-1.json",
}
module.write_json(module.RESULT_ROOT / "attempts/vs-p0b-next-a-attempt-1.json", result)
module.write_json(root / result["evaluator_result_path"], {"evaluated": True})
module.write_json(root / state["attempts"][0]["process_metadata_path"], {"published": True})
module.record_instruction_integrity(
    "vs-p0b-next-a-attempt-1", "1" * 64, "1" * 64, True
)
module.load_state = lambda: state
module.validate_document = lambda value, schema: None
module.validate_state = lambda value: None
module.evaluate_candidate = lambda *args: (_ for _ in ()).throw(AssertionError("reevaluated"))
module.publish_candidate = lambda *args: (_ for _ in ()).throw(AssertionError("republished"))
assert module.recover_interrupted("vs-p0b-next-a-attempt-1") == 0
persisted = json.loads(module.STATE_PATH.read_text())
process = json.loads((root / state["attempts"][0]["process_metadata_path"]).read_text())
assert persisted["completed_runs"] == ["vs-p0b-next-a"]
assert persisted["status"] == "ready"
assert persisted["attempts"][0]["terminal_status"] == "completed"
assert process["state_recovery"] == "terminal state reconstructed from retained evidence"
assert (module.RESULT_ROOT / "final/vs-p0b-next-a.json").is_file()
assert not module.instruction_integrity_path("vs-p0b-next-a-attempt-1").exists()
PY
	[ "${status}" -eq 0 ]
}

@test "interrupted recovery records failed publication and unknown candidate duration" {
	run python3 - "${RUNNER}" "${BATS_TEST_TMPDIR}" <<'PY'
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("phase0b_revision", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
root = Path(sys.argv[2])
module.REPO_ROOT = root
module.PROTOCOL_ROOT = root
module.RESULT_ROOT = root / "results"
module.ARTIFACT_ROOT = root / "artifacts"
module.STATE_PATH = root / "state.json"
module.RESULT_SCHEMA = root / "result.schema.json"
module.EVALUATOR_SCHEMA = root / "evaluation.schema.json"
attempt_id = "vs-p0b-next-a-attempt-1"
checkout = module.ARTIFACT_ROOT / "clones" / attempt_id
checkout.mkdir(parents=True)
state = {
    "status": "running",
    "completed_runs": [],
    "candidate_base": {"sha": "0" * 40},
    "attempts": [{
        "attempt_id": attempt_id,
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
        "process_metadata_path": f"results/process/{attempt_id}.json",
        "evaluator_result_path": None,
    }],
}
module.load_state = lambda: state
module.validate_document = lambda value, schema: None
module.validate_state = lambda value: None
module.snapshot_interrupted_candidate = lambda *args: (["src/app.js"], "1" * 40, 0, "2" * 64, "3" * 64, False)
module.evaluate_candidate = lambda *args: {
    "run_id": "vs-p0b-next-a",
    "evaluated": True,
    "wall_clock_seconds": 1,
    "objective_score": 0,
}
module.PILOT.parse_usage = lambda path: ({"input": 0, "cached_input": 0, "output": 0}, None)
subprocess_calls = []
def fake_subprocess_run(args, **kwargs):
    subprocess_calls.append((args, kwargs))
    assert args == ["git", "remote", "get-url", "origin"]
    assert kwargs["check"] is True
    assert kwargs["text"] is True
    return type("Result", (), {"stdout": "origin\n", "returncode": 0})()
module.subprocess.run = fake_subprocess_run
module.publish_candidate = lambda *args: (_ for _ in ()).throw(subprocess.CalledProcessError(1, ["git", "push"]))
module.record_instruction_integrity(attempt_id, "2" * 64, "2" * 64, True)
assert module.recover_interrupted(attempt_id) == 0
result = json.loads((module.RESULT_ROOT / f"attempts/{attempt_id}.json").read_text())
process = json.loads((module.RESULT_ROOT / f"process/{attempt_id}.json").read_text())
persisted = json.loads(module.STATE_PATH.read_text())
assert result["terminal_status"] == "harness-failed"
assert result["failure_class"] == "interrupted-harness"
assert "publication failed" in result["failure_reason"]
assert result["replacement_eligible"] is True
assert result["wall_clock_seconds"] == 0
assert result["wall_clock_comparable"] is False
assert process["elapsed_since_start_seconds"] > 0
assert process["published"] is False
assert process["instruction_sha256"] == "2" * 64
assert process["observed_instruction_sha256"] == "3" * 64
assert process["instruction_override_intact"] is False
assert persisted["status"] == "ready"
assert persisted["attempts"][0]["terminal_status"] == "harness-failed"
assert len(subprocess_calls) == 1
assert not module.instruction_integrity_path(attempt_id).exists()
PY
	[ "${status}" -eq 0 ]
}

@test "recover-interrupted CLI routes to recovery" {
	run python3 - "${RUNNER}" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("phase0b_revision", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
called = []
module.recover_interrupted = lambda attempt_id: called.append(attempt_id) or 0
sys.argv = [sys.argv[1], "--recover-interrupted", "vs-p0b-next-a-attempt-1"]
assert module.main() == 0
assert called == ["vs-p0b-next-a-attempt-1"]
PY
	[ "${status}" -eq 0 ]
}

@test "interrupted snapshot checks instructions and delegates drift scoring" {
	run python3 - "${RUNNER}" "${BATS_TEST_TMPDIR}" <<'PY'
import importlib.util
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("phase0b_revision", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
checkout = Path(sys.argv[2]) / "checkout"
checkout.mkdir()
module.RESULT_ROOT = Path(sys.argv[2]) / "results"
instructions = "candidate instructions\n"
override = checkout / "AGENTS.override.md"
override.write_text(instructions)
module.PREPARE.render_candidate_instructions = lambda arm: instructions
delegated = []
module.PILOT.snapshot_candidate = lambda *args: delegated.append(args) or (["src/app.js"], "1" * 40, 2)
changed, sha, drift, expected, observed, intact = module.snapshot_interrupted_candidate(
    checkout, "0" * 40, "vs-p0b-next-a-attempt-1", "A"
)
assert delegated == [(checkout, "0" * 40, "vs-p0b-next-a-attempt-1")]
assert not override.exists()
assert changed == ["src/app.js"]
assert sha == "1" * 40
assert drift == 2
assert expected == module.sha256_bytes(instructions.encode())
assert observed == expected
assert intact is True
override.write_text("tampered\n")
_, _, _, expected, observed, intact = module.snapshot_interrupted_candidate(
    checkout, "0" * 40, "vs-p0b-next-a-attempt-1", "A"
)
assert observed != expected
assert intact is False
PY
	[ "${status}" -eq 0 ]
}

@test "interrupted snapshot accepts precommitted work without an override" {
	run python3 - "${RUNNER}" "${BATS_TEST_TMPDIR}" <<'PY'
import importlib.util
import subprocess
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("phase0b_revision", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
checkout = Path(sys.argv[2]) / "precommitted"
checkout.mkdir()
module.RESULT_ROOT = Path(sys.argv[2]) / "results"
subprocess.run(["git", "init", "--quiet"], cwd=checkout, check=True)
subprocess.run(["git", "config", "user.name", "Benchmark Test"], cwd=checkout, check=True)
subprocess.run(["git", "config", "user.email", "benchmark@example.invalid"], cwd=checkout, check=True)
(checkout / "base.txt").write_text("base\n")
subprocess.run(["git", "add", "base.txt"], cwd=checkout, check=True)
subprocess.run(["git", "commit", "--quiet", "-m", "base"], cwd=checkout, check=True)
base_sha = subprocess.run(
    ["git", "rev-parse", "HEAD"], cwd=checkout, check=True, text=True, stdout=subprocess.PIPE
).stdout.strip()
(checkout / "candidate.txt").write_text("work\n")
subprocess.run(["git", "add", "candidate.txt"], cwd=checkout, check=True)
subprocess.run(["git", "commit", "--quiet", "-m", "candidate"], cwd=checkout, check=True)
module.PREPARE.render_candidate_instructions = lambda arm: "candidate instructions\n"
changed, candidate_sha, _, _, observed, intact = module.snapshot_interrupted_candidate(
    checkout, base_sha, "vs-p0b-next-a-attempt-1", "A"
)
assert changed == ["candidate.txt"]
assert candidate_sha != base_sha
assert observed is None
assert intact is False
PY
	[ "${status}" -eq 0 ]
}

@test "interrupted snapshot strictly trusts transient harness integrity verification" {
	run python3 - "${RUNNER}" "${BATS_TEST_TMPDIR}" <<'PY'
import importlib.util
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("phase0b_revision", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
root = Path(sys.argv[2])
attempt_id = "vs-p0b-next-a-attempt-1"
checkout = root / "checkout"
checkout.mkdir()
module.RESULT_ROOT = root / "results"
module.ARTIFACT_ROOT = root / "artifacts"
instructions = "candidate instructions\n"
expected = module.sha256_bytes(instructions.encode())
module.record_instruction_integrity(attempt_id, expected, expected, True)
integrity_path = module.instruction_integrity_path(attempt_id)
assert integrity_path == module.ARTIFACT_ROOT / "recovery-state" / f"{attempt_id}.json"
assert integrity_path.is_file()
module.PREPARE.render_candidate_instructions = lambda arm: instructions
module.PILOT.snapshot_candidate = lambda *args: (["candidate.txt"], "1" * 40, 0)
_, _, _, instruction_sha, observed, intact = module.snapshot_interrupted_candidate(
    checkout, "0" * 40, attempt_id, "A"
)
assert instruction_sha == expected
assert observed == expected
assert intact is True

module.record_instruction_integrity(attempt_id, expected, "0" * 64, True)
_, _, _, _, observed, intact = module.snapshot_interrupted_candidate(
    checkout, "0" * 40, attempt_id, "A"
)
assert observed is None
assert intact is False

module.record_instruction_integrity(attempt_id, expected, expected, False)
_, _, _, _, observed, intact = module.snapshot_interrupted_candidate(
    checkout, "0" * 40, attempt_id, "A"
)
assert observed is None
assert intact is False
PY
	[ "${status}" -eq 0 ]
}
