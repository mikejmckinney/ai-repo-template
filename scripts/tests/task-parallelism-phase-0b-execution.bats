#!/usr/bin/env bats

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
	RUNNER="${REPO_ROOT}/scripts/benchmark/task-parallelism/run-phase-0b.py"
	PROTOCOL="${REPO_ROOT}/.context/benchmarks/model-roi/task-parallelism"
	STATE="${PROTOCOL}/campaign.phase-0b.execution.json"
}

@test "approved execution state remains unable to start before base freeze" {
	[ -f "${PROTOCOL}/phase-0b-execution.schema.json" ]
	[ -f "${PROTOCOL}/phase-0b-candidate-report.schema.json" ]
	[ -f "${PROTOCOL}/candidate-base.gitignore" ]
	[ -f "${PROTOCOL}/tasks/vector-siege-stage-1-candidate.md" ]
	[ -f "${RUNNER}" ]

	run python3 "${RUNNER}" --validate-state
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'authorized; candidate base pending; candidate processes started: 0'* ]]

	run python3 "${RUNNER}" --run-id vs-p0b-001
	[ "${status}" -eq 2 ]
	[[ "${output}" == *'candidate base is not frozen'* ]]

	run jq -e '
	    .status == "base-pending" and
	    .candidate_base.sha == null and
	    .candidate_processes_started == 0 and
	    .completed_runs == []
	  ' "${STATE}"
	[ "${status}" -eq 0 ]
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
