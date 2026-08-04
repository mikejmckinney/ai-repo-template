#!/usr/bin/env bats

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
	RUNNER="${REPO_ROOT}/scripts/benchmark/task-parallelism"
	PROTOCOL="${REPO_ROOT}/.context/benchmarks/model-roi/task-parallelism"
	REPORT="${REPO_ROOT}/.artifacts/task-parallelism/preflight-report.json"
}

@test "Phase 0A tracks the production campaign and declared schemas" {
	required=(
		"${PROTOCOL}/campaign.schema.json"
		"${PROTOCOL}/campaign.phase-0a.json"
		"${PROTOCOL}/asset-manifest.schema.json"
		"${PROTOCOL}/assets/manifest.json"
		"${PROTOCOL}/tasks/vector-siege.md"
		"${RUNNER}/requirements.txt"
	)

	for path in "${required[@]}"; do
		[ -f "${path}" ]
	done

	run python3 "${RUNNER}/preflight.py" --validate-only
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'Draft 2020-12'* ]]
	[[ "${output}" == *'jsonschema 4.26.0'* ]]
}

@test "placeholder assets reproduce byte-for-byte" {
	run make -C "${RUNNER}" assets-check
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'asset bundle is byte-stable'* ]]
}

@test "argument-free preflight validates real state and keeps Phase 0B blocked" {
	rm -f "${REPORT}"

	run env \
		OPENAI_API_KEY='fixture-openai-secret' \
		CLOUDFLARE_API_TOKEN='fixture-cloudflare-secret' \
		CAMPAIGN="${RUNNER}/fixtures/unresolved-freeze.json" \
		make -C "${RUNNER}" preflight

	[ "${status}" -eq 0 ]
	[ -f "${REPORT}" ]
	run jq -e '
    .status == "pass" and
    .campaign == "vector-siege-phase-0a" and
    .freeze_state == "resolved" and
    .assets.status == "pass" and
    .isolation.network_namespace == "active" and
    .isolation.provider_credentials_present == [] and
    .phase_0b == "blocked"
  ' "${REPORT}"
	[ "${status}" -eq 0 ]
	! grep -Fq 'fixture-openai-secret' "${REPORT}"
	! grep -Fq 'fixture-cloudflare-secret' "${REPORT}"
}

@test "negative campaign fixtures fail closed with redacted reasons" {
	fixtures=(
		"${RUNNER}/fixtures/unresolved-freeze.json"
		"${RUNNER}/fixtures/approval-enabled.json"
		"${RUNNER}/fixtures/forbidden-operation.json"
		"${RUNNER}/fixtures/secret-payload.json"
		"${RUNNER}/fixtures/invalid-asset-manifest.json"
	)

	run "${RUNNER}/run-preflight.sh" --fixtures "${fixtures[@]}"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *'freeze state is unresolved'* ]]
	[[ "${output}" == *'Phase 0B approval must remain blocked'* ]]
	[[ "${output}" == *'external operation is forbidden'* ]]
	[[ "${output}" == *'secret-shaped value is forbidden'* ]]
	[[ "${output}" == *'asset manifest is invalid'* ]]
	[[ "${output}" != *'fixture-secret-value'* ]]
}

@test "socket control succeeds outside isolation and is blocked inside" {
	port_file="${BATS_TEST_TMPDIR}/listener.port"
	python3 - "${port_file}" <<'PY' &
import socket
import sys

listener = socket.socket()
listener.bind(("127.0.0.1", 0))
listener.listen(2)
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    handle.write(str(listener.getsockname()[1]))
connection, _ = listener.accept()
connection.close()
PY
	listener_pid=$!

	for _ in $(seq 1 50); do
		[ -s "${port_file}" ] && break
		sleep 0.02
	done
	[ -s "${port_file}" ]
	port="$(<"${port_file}")"

	run python3 - "${port}" <<'PY'
import socket
import sys

with socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=1):
    pass
PY
	[ "${status}" -eq 0 ]

	run "${RUNNER}/run-preflight.sh" --probe-socket 127.0.0.1 "${port}"
	[ "${status}" -ne 0 ]
	[[ "${output}" == *'socket access blocked inside isolation'* ]]

	kill "${listener_pid}" 2>/dev/null || true
	wait "${listener_pid}" 2>/dev/null || true
}

@test "child process creation is blocked inside the production launcher" {
	run "${RUNNER}/run-preflight.sh" --probe-subprocess
	[ "${status}" -ne 0 ]
	[[ "${output}" == *'child process blocked inside isolation'* ]]
}
