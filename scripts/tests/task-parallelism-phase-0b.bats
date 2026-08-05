#!/usr/bin/env bats

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
	RUNNER="${REPO_ROOT}/scripts/benchmark/task-parallelism"
	PROTOCOL="${REPO_ROOT}/.context/benchmarks/model-roi/task-parallelism"
	CAMPAIGN="${PROTOCOL}/campaign.phase-0b.preparation.json"
	REVISION="${PROTOCOL}/campaign.phase-0b.revision.json"
	PLAN="${BATS_TEST_TMPDIR}/phase-0b-run-plan.json"
}

@test "revised Phase 0B plan uses one assignment per arm and invalid-attempt-only replacement" {
	run python3 "${RUNNER}/prepare-phase-0b.py" --manifest "${REVISION}" --plan "${PLAN}"
	[ "${status}" -eq 0 ]
	[ -f "${PLAN}" ]

	run jq -e '
    .execution_status == "blocked" and
    .candidate_processes_started == 0 and
    ([.assignments[].arm] == ["A", "B"]) and
    (.retries.candidate_failure == 0) and
    (.retries.provider_transient == 1) and
    (.retries.verified_harness_failure == 1) and
    (.candidate_command | index("danger-full-access") != null) and
    (.candidate_command | index("workspace-write") == null) and
    (.candidate_command | index("multi_agent") != null) and
    (.candidate_command | index("project_doc_max_bytes=65536") != null) and
    (.candidate_checkout.location == "standalone-temporary-clone") and
    (.candidate_checkout.instructions_source == "AGENTS.md") and
    (.candidate_checkout.instructions_target == "AGENTS.override.md") and
    (.candidate_instruction_sha256.A | test("^[0-9a-f]{64}$")) and
    (.candidate_instruction_sha256.B | test("^[0-9a-f]{64}$")) and
    (.candidate_verification == ["build", "unit", "e2e"]) and
    (.parent_evaluation | index("e2e") != null)
  ' "${PLAN}"
	[ "${status}" -eq 0 ]

	common_prompt="$(jq -r '.prompts.common.path' "${REVISION}")"
	run grep -F "Use Playwright or Chrome" "${PROTOCOL}/${common_prompt}"
	[ "${status}" -eq 0 ]
	run grep -F "Run the scaffold build, unit tests, and browser journey." \
		"${PROTOCOL}/${common_prompt}"
	[ "${status}" -eq 0 ]
}

@test "Phase 0B plan is deterministic, counterbalanced, and non-executing" {
	run python3 "${RUNNER}/prepare-phase-0b.py" --plan "${PLAN}"
	[ "${status}" -eq 0 ]
	[ -f "${PLAN}" ]
	[[ "${output}" == *'wrote blocked Phase 0B run plan'* ]]

	run jq -e '
    .execution_status == "blocked" and
    .candidate_processes_started == 0 and
    (.assignments | length) == 10 and
    ([.assignments[].arm] == ["A", "B", "B", "A", "A", "B", "B", "A", "A", "B"]) and
    ([.assignments[] | select(.arm == "A")] | length) == 5 and
    ([.assignments[] | select(.arm == "B")] | length) == 5 and
    (.candidate_command | index("--sandbox")) != null and
    (.candidate_command | index("workspace-write")) != null and
    (.candidate_command | index("danger-full-access")) == null
  ' "${PLAN}"
	[ "${status}" -eq 0 ]
}

@test "Phase 0B preparation rejects approval drift and scaffold drift" {
	approved="${BATS_TEST_TMPDIR}/approved.json"
	jq '.execution.status = "approved" | .execution.approval_source = "fixture"' \
		"${CAMPAIGN}" >"${approved}"

	run python3 "${RUNNER}/prepare-phase-0b.py" --validate --manifest "${approved}"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *'execution approval must remain blocked during preparation'* ]]

	scaffold="${BATS_TEST_TMPDIR}/scaffold"
	mkdir -p "${scaffold}"
	scaffold_relative=".context/benchmarks/model-roi/task-parallelism/scaffold"
	while IFS= read -r -d '' path; do
		destination="${scaffold}/${path#${scaffold_relative}/}"
		mkdir -p "$(dirname "${destination}")"
		cp "${REPO_ROOT}/${path}" "${destination}"
	done < <(git -C "${REPO_ROOT}" ls-files -z -- "${scaffold_relative}")

	run python3 "${RUNNER}/prepare-phase-0b.py" --validate --scaffold-root "${scaffold}"
	[ "${status}" -eq 0 ]
	printf '\n// drift\n' >>"${scaffold}/src/main.ts"

	run python3 "${RUNNER}/prepare-phase-0b.py" --validate --scaffold-root "${scaffold}"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *'scaffold digest mismatch'* ]]
}

@test "Gate 0 applies the approved feasibility thresholds" {
	passing="${BATS_TEST_TMPDIR}/passing-summary.json"
	failing="${BATS_TEST_TMPDIR}/failing-summary.json"
	python3 - "${passing}" "${failing}" <<'PY'
import json
import sys

passing = {
    "schema_version": "task-parallelism-phase-0b-summary.v1",
    "assigned_runs": 10,
    "terminal_runs": 10,
    "required_telemetry_fraction": 1.0,
    "harness_reliability_fraction": 0.9,
    "arm_b_fanout_elections": 2,
}
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(passing, handle)
passing["harness_reliability_fraction"] = 0.89
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(passing, handle)
PY

	run python3 "${RUNNER}/prepare-phase-0b.py" --evaluate-gate "${passing}"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'Gate 0: go'* ]]

	run python3 "${RUNNER}/prepare-phase-0b.py" --evaluate-gate "${failing}"
	[ "${status}" -eq 3 ]
	[[ "${output}" == *'Gate 0: no-go'* ]]
	[[ "${output}" == *'harness reliability 0.89 is below 0.9'* ]]
}

@test "candidate result contract retains ROI and coordination evidence" {
	run python3 - "${PROTOCOL}/phase-0b-candidate-result.schema.json" <<'PY'
import copy
import json
import sys

from jsonschema import Draft202012Validator

with open(sys.argv[1], encoding="utf-8") as handle:
    schema = json.load(handle)
result = {
    "schema_version": "task-parallelism-phase-0b-candidate-result.v1",
    "run_id": "vs-p0b-001",
    "arm": "A",
    "terminal_status": "completed",
    "quality_score": 91,
    "model_cost_usd": None,
    "wall_clock_seconds": 900,
    "human_intervention_minutes": 0,
    "infrastructure_cost_usd": 0,
    "tokens": {"input": 1000, "cached_input": 500, "output": 200},
    "skill_loads": 2,
    "skill_context_tokens": 400,
    "coordination_seconds": 0,
    "provider_wait_seconds": 10,
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
    "harness_failure": False,
}
validator = Draft202012Validator(schema)
validator.validate(result)
missing_coordination = copy.deepcopy(result)
del missing_coordination["coordination_seconds"]
if not list(validator.iter_errors(missing_coordination)):
    raise SystemExit("missing coordination evidence was accepted")
failed_with_score = copy.deepcopy(result)
failed_with_score["terminal_status"] = "candidate-failed"
if not list(validator.iter_errors(failed_with_score)):
    raise SystemExit("failed candidate retained nonzero quality")
print("candidate result contract valid")
PY
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'candidate result contract valid'* ]]
}
