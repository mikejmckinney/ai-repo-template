#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
	RUNNER="${REPO_ROOT}/scripts/benchmark/task-parallelism/run-phase-0b.py"
	PROTOCOL="${REPO_ROOT}/.context/benchmarks/model-roi/task-parallelism"
	STATE="${PROTOCOL}/campaign.phase-0b.execution.json"
}

@test "candidate report schema stays within the Codex response-schema subset" {
	run jq -e '[.. | objects | select(has("allOf"))] | length == 0' \
		"${PROTOCOL}/phase-0b-candidate-report.schema.json"
	[ "${status}" -eq 0 ]
}

@test "Codex schema rejection is a retryable harness failure" {
	run python3 - "${RUNNER}" <<'PY'
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

spec = importlib.util.spec_from_file_location("phase0b", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with tempfile.TemporaryDirectory() as directory:
    jsonl = Path(directory) / "agent-output.jsonl"
    jsonl.write_text(json.dumps({
        "type": "error",
        "message": "invalid_json_schema: 'allOf' is not permitted",
    }) + "\n")
    assert module.classify_failure(1, jsonl) == ("harness-failed", True, True)
PY
	[ "${status}" -eq 0 ]
}

@test "active work at the deadline is a candidate failure, not a provider failure" {
	run python3 - "${RUNNER}" <<'PY'
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

spec = importlib.util.spec_from_file_location("phase0b", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with tempfile.TemporaryDirectory() as directory:
    jsonl = Path(directory) / "agent-output.jsonl"
    jsonl.write_text(json.dumps({
        "type": "item.started",
        "item": {"type": "command_execution"},
    }) + "\n")
    assert module.classify_failure(124, jsonl) == ("candidate-failed", False, False)
    jsonl.write_text(json.dumps({"type": "turn.started"}) + "\n")
    assert module.classify_failure(124, jsonl) == ("provider-failed", False, True)
PY
	[ "${status}" -eq 0 ]
}

@test "timeout snapshot preserves partial candidate work" {
	run python3 - "${RUNNER}" "${BATS_TEST_TMPDIR}" <<'PY'
import importlib.util
import subprocess
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("phase0b", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
repo = Path(sys.argv[2]) / "candidate"
repo.mkdir()
subprocess.run(["git", "init", "-q", str(repo)], check=True)
subprocess.run(["git", "-C", str(repo), "config", "user.name", "Benchmark"], check=True)
subprocess.run(["git", "-C", str(repo), "config", "user.email", "benchmark@example.invalid"], check=True)
(repo / "base.txt").write_text("base\n")
subprocess.run(["git", "-C", str(repo), "add", "base.txt"], check=True)
subprocess.run(
    ["git", "-C", str(repo), "commit", "--no-gpg-sign", "-q", "-m", "base"],
    check=True,
)
base = subprocess.run(
    ["git", "-C", str(repo), "rev-parse", "HEAD"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
).stdout.strip()
(repo / "partial.txt").write_text("retained\n")
changed, candidate_sha, drift = module.snapshot_candidate(
    repo, base, "vs-p0b-001-attempt-1"
)
assert changed == ["partial.txt"]
assert candidate_sha != base
assert drift == 0
assert subprocess.run(
    ["git", "-C", str(repo), "show", "HEAD:partial.txt"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
).stdout == "retained\n"
PY
	[ "${status}" -eq 0 ]
}

@test "partial candidates retain self-reported coordination telemetry" {
	run python3 - "${RUNNER}" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("phase0b", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
result = module.write_failure_result("vs-p0b-007", "B", 120, "candidate-failed", False)
report = {
    "skill_loads": 6,
    "skill_context_tokens": 3900,
    "coordination_seconds": 35,
    "provider_wait_seconds": 31,
    "rescue_events": 1,
    "duplicate_or_abandoned_work": 0,
    "semantic_conflicts": 0,
    "interface_conflicts": 0,
    "asset_conflicts": 0,
    "dependency_conflicts": 0,
    "fanout_elected": True,
    "worker_count": 1,
}
module.apply_report_telemetry(
    result,
    report,
    {"input": 100, "cached_input": 50, "output": 20},
    2,
)
assert result["terminal_status"] == "candidate-failed"
assert result["quality_score"] == 0
assert result["fanout_elected"] is True
assert result["coordination_seconds"] == 35
assert result["provider_wait_seconds"] == 31
assert result["skill_loads"] == 6
assert result["predicted_path_drift_count"] == 2
assert result["tokens"]["input"] == 100
PY
	[ "${status}" -eq 0 ]
}

@test "one harness retry retains the original attempt" {
	run python3 - "${RUNNER}" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("phase0b", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
state = {
    "retry_processes_started": 0,
    "attempts": [{
        "attempt_id": "vs-p0b-001-attempt-1",
        "run_id": "vs-p0b-001",
        "attempt_number": 1,
        "terminal_status": "harness-failed",
        "retry_eligible": True,
        "result_path": "results/phase-0b/attempts/vs-p0b-001-attempt-1.json",
    }],
}
attempt = module.plan_attempt(state, "vs-p0b-001")
assert attempt == {
    "attempt_id": "vs-p0b-001-attempt-2",
    "attempt_number": 2,
    "is_retry": True,
}
state["retry_processes_started"] = 1
try:
    module.plan_attempt(state, "vs-p0b-001")
except ValueError as error:
    assert "retry budget" in str(error)
else:
    raise AssertionError("second retry was permitted")
PY
	[ "${status}" -eq 0 ]
}

@test "candidate environment excludes inherited credentials" {
	run python3 - "${RUNNER}" <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("phase0b", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
environment = module.candidate_environment({
    "HOME": "/home/test",
    "PATH": "/usr/bin",
    "LANG": "C.UTF-8",
    "GH_TOKEN": "secret",
    "GITHUB_TOKEN": "secret",
    "OPENAI_API_KEY": "secret",
})
assert environment["HOME"] == "/home/test"
assert environment["PATH"] == "/usr/bin"
assert environment["LANG"] == "C.UTF-8"
assert "GH_TOKEN" not in environment
assert "GITHUB_TOKEN" not in environment
assert "OPENAI_API_KEY" not in environment
PY
	[ "${status}" -eq 0 ]
}

@test "approved execution state validates the frozen candidate base" {
	[ -f "${PROTOCOL}/phase-0b-execution.schema.json" ]
	[ -f "${PROTOCOL}/phase-0b-candidate-report.schema.json" ]
	[ -f "${PROTOCOL}/candidate-base.gitignore" ]
	[ -f "${PROTOCOL}/tasks/vector-siege-stage-1-candidate.md" ]
	[ -f "${RUNNER}" ]
	base_sha="$(jq -r '.candidate_base.sha' "${STATE}")"
	base_branch="$(jq -r '.candidate_base.branch' "${STATE}")"
	if ! git -C "${REPO_ROOT}" cat-file -e "${base_sha}^{commit}" 2>/dev/null; then
		skip "frozen candidate base is unavailable in this repository copy"
	fi
	remote_sha="$(git -C "${REPO_ROOT}" ls-remote --heads origin "${base_branch}" 2>/dev/null | cut -f1)"
	if [ "${remote_sha}" != "${base_sha}" ]; then
		skip "origin does not expose the frozen candidate base"
	fi

	run python3 "${RUNNER}" --validate-state
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'execution state valid:'*'candidate processes started:'* ]]

	run jq -e '
	    .status == (if (.completed_runs | length) == 10 then "completed" else "ready" end) and
	    (.candidate_base.sha | test("^[0-9a-f]{40}$")) and
	    .candidate_processes_started == (.attempts | length) and
	    .retry_processes_started == 1
	  ' "${STATE}"
	[ "${status}" -eq 0 ]
}

@test "offline execution validation supports derived repository copies" {
	run python3 "${RUNNER}" --validate-state --offline
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'offline structural execution state valid:'* ]]
	base_sha="$(jq -r '.candidate_base.sha' "${STATE}")"
	if git -C "${REPO_ROOT}" cat-file -e "${base_sha}^{commit}" 2>/dev/null; then
		[[ "${output}" == *'local frozen base task blob verified'* ]]
	else
		[[ "${output}" == *'frozen base unavailable locally'* ]]
	fi
}

@test "offline validation rejects a local task-blob mismatch" {
	run python3 - "${RUNNER}" "${BATS_TEST_TMPDIR}" <<'PY'
import importlib.util
import subprocess
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("phase0b", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
repo = Path(sys.argv[2]) / "local-base"
repo.mkdir()
subprocess.run(["git", "init", "-q", str(repo)], check=True)
subprocess.run(["git", "-C", str(repo), "config", "user.name", "Benchmark"], check=True)
subprocess.run(["git", "-C", str(repo), "config", "user.email", "benchmark@example.invalid"], check=True)
(repo / "TASK.md").write_text("frozen task\n")
subprocess.run(["git", "-C", str(repo), "add", "TASK.md"], check=True)
subprocess.run(
    ["git", "-C", str(repo), "commit", "--no-gpg-sign", "-q", "-m", "base"],
    check=True,
)
sha = subprocess.run(
    ["git", "-C", str(repo), "rev-parse", "HEAD"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
).stdout.strip()
module.REPO_ROOT = repo
try:
    module.verify_local_base_if_available({
        "candidate_base": {"sha": sha, "task_blob_sha": "0" * 40}
    })
except ValueError as error:
    assert "task does not match" in str(error)
else:
    raise AssertionError("task-blob mismatch was accepted")
(repo / "TASK.md").unlink()
subprocess.run(["git", "-C", str(repo), "add", "TASK.md"], check=True)
subprocess.run(
    ["git", "-C", str(repo), "commit", "--no-gpg-sign", "-q", "-m", "missing task"],
    check=True,
)
missing_task_sha = subprocess.run(
    ["git", "-C", str(repo), "rev-parse", "HEAD"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
).stdout.strip()
try:
    module.verify_local_base_if_available({
        "candidate_base": {"sha": missing_task_sha, "task_blob_sha": "0" * 40}
    })
except ValueError as error:
    assert "missing required path: TASK.md" in str(error)
else:
    raise AssertionError("missing TASK.md was accepted")
PY
	[ "${status}" -eq 0 ]
}

@test "offline flag is rejected outside structural state validation" {
	results="${BATS_TEST_TMPDIR}/offline-results"
	mkdir -p "${results}"
	run python3 "${RUNNER}" --summarize "${results}" \
		--output "${BATS_TEST_TMPDIR}/offline-summary.json" --offline
	[ "${status}" -eq 2 ]
	[[ "${output}" == *'--offline is valid only with --validate-state'* ]]
}

@test "pilot summary derives Gate 0 inputs from terminal result documents" {
	results="${BATS_TEST_TMPDIR}/results"
	summary="${BATS_TEST_TMPDIR}/summary.json"
	mkdir -p "${results}"

	python3 - "${results}" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
for index in range(1, 11):
    arm = "A" if index in {1, 4, 5, 8, 9} else "B"
    result = {
        "schema_version": "task-parallelism-phase-0b-candidate-result.v1",
        "run_id": f"vs-p0b-{index:03d}",
        "arm": arm,
        "terminal_status": "completed",
        "quality_score": 80,
        "model_cost_usd": None,
        "wall_clock_seconds": 600,
        "human_intervention_minutes": 0,
        "infrastructure_cost_usd": 0,
        "tokens": {"input": 1000, "cached_input": 500, "output": 200},
        "skill_loads": 1,
        "skill_context_tokens": 100,
        "coordination_seconds": 20 if arm == "B" else 0,
        "provider_wait_seconds": 0,
        "rescue_events": 0,
        "duplicate_or_abandoned_work": 0,
        "predicted_path_drift_count": 0,
        "semantic_conflicts": 0,
        "interface_conflicts": 0,
        "asset_conflicts": 0,
        "dependency_conflicts": 0,
        "merge_conflicts": 0,
        "fanout_elected": arm == "B" and index in {2, 6},
        "worker_count": 2 if arm == "B" and index in {2, 6} else 1,
        "harness_failure": False,
    }
    (root / f"vs-p0b-{index:03d}.json").write_text(json.dumps(result) + "\n")
PY

	run python3 "${RUNNER}" --summarize "${results}" --output "${summary}"
	[ "${status}" -eq 0 ]
	run jq -e '
	    .assigned_runs == 10 and
	    .terminal_runs == 10 and
	    .required_telemetry_fraction == 1 and
	    .harness_reliability_fraction == 1 and
	    .arm_b_fanout_elections == 2
	  ' "${summary}"
	[ "${status}" -eq 0 ]
}

@test "pilot summary diagnoses invalid result documents" {
	results="${BATS_TEST_TMPDIR}/invalid-results"
	summary="${BATS_TEST_TMPDIR}/invalid-summary.json"
	mkdir -p "${results}"
	printf '%s\n' '{"schema_version":"wrong"}' >"${results}/vs-p0b-001.json"

	run python3 "${RUNNER}" --summarize "${results}" --output "${summary}"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'rejected result vs-p0b-001.json:'* ]]
	run jq -e '
	    .terminal_runs == 0 and
	    .required_telemetry_fraction == 0 and
	    .harness_reliability_fraction == 0
	  ' "${summary}"
	[ "${status}" -eq 0 ]
}
