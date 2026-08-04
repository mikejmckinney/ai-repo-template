#!/usr/bin/env bats

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-300}"

setup() {
	REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
	RUNNER="${REPO_ROOT}/scripts/benchmark/task-parallelism"
	PROTOCOL="${REPO_ROOT}/.context/benchmarks/model-roi/task-parallelism"
	REPORT="${REPO_ROOT}/.artifacts/task-parallelism/preflight-report.json"
}

isolation_available() {
	unshare -Urn true 2>/dev/null
}

@test "placeholder assets reproduce byte-for-byte" {
	run make -C "${RUNNER}" assets-check
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'asset bundle is byte-stable'* ]]
}

@test "failed asset replacement restores the tracked bundle" {
	fixture_repo="${BATS_TEST_TMPDIR}/repo"
	fixture_runner="${fixture_repo}/scripts/benchmark/task-parallelism"
	fixture_assets="${fixture_repo}/.context/benchmarks/model-roi/task-parallelism/assets"
	mkdir -p "${fixture_runner}" "${fixture_assets}"
	cp "${RUNNER}/generate-placeholder-assets.py" "${fixture_runner}/"
	printf 'preserve me\n' >"${fixture_assets}/marker.txt"

	run python3 - "${fixture_runner}/generate-placeholder-assets.py" <<'PY'
import importlib.util
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("generate_placeholder_assets", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.verify_ffmpeg = lambda: None
module.generate = lambda path: path.mkdir(parents=True)
real_rename = Path.rename

def interrupt_generated_rename(path, target):
    if path.name == "generated":
        raise KeyboardInterrupt
    return real_rename(path, target)

Path.rename = interrupt_generated_rename
sys.argv = [sys.argv[1]]
try:
    module.main()
except KeyboardInterrupt:
    print("injected asset replacement failure")
finally:
    Path.rename = real_rename
PY
	[ "${status}" -eq 0 ]
	[[ "${output}" == *'injected asset replacement failure'* ]]
	[ -f "${fixture_assets}/marker.txt" ]
}

@test "argument-free preflight validates real state and keeps Phase 0B blocked" {
	rm -f "${REPORT}"
	unisolated_report="${BATS_TEST_TMPDIR}/unisolated-report.json"
	run env REPO_ROOT="${REPO_ROOT}" REPORT_PATH="${unisolated_report}" \
		python3 - "${RUNNER}" <<'PY'
import sys

sys.path.insert(0, sys.argv[1])
from preflight import run_preflight

raise SystemExit(run_preflight(audit_hook_active=False))
PY
	[ "${status}" -ne 0 ]
	[[ "${output}" == *'preflight isolation is inactive'* ]]
	[ ! -e "${unisolated_report}" ]

	run env \
		OPENAI_API_KEY='fixture-openai-secret' \
		CLOUDFLARE_API_TOKEN='fixture-cloudflare-secret' \
		make -C "${RUNNER}" preflight

	if ! isolation_available; then
		printf '# isolation unavailable; validating fail-closed path only\n' >&3
		[ "${status}" -eq 2 ]
		[[ "${output}" == *'unshare -Urn is unavailable'* ]]
		[ ! -e "${REPORT}" ]
		return 0
	fi

	[ "${status}" -eq 0 ]
	[ -f "${REPORT}" ]
	run jq -e '
    .status == "pass" and
    .campaign == "vector-siege-phase-0a" and
    .campaign_source == ".context/benchmarks/model-roi/task-parallelism/campaign.phase-0a.json" and
    (.campaign_sha256 | test("^[0-9a-f]{64}$")) and
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

	if isolation_available; then
		run "${RUNNER}/run-preflight.sh" --fixtures "${fixtures[@]}"
	else
		printf '# isolation unavailable; validating fixtures in-process\n' >&3
		run env REPO_ROOT="${REPO_ROOT}" python3 - "${RUNNER}" "${fixtures[@]}" <<'PY'
import sys

sys.path.insert(0, sys.argv[1])
from preflight import run_fixture_suite

raise SystemExit(run_fixture_suite(sys.argv[2:]))
PY
	fi
	[ "${status}" -ne 0 ]
	[[ "${output}" == *'freeze state is unresolved'* ]]
	[[ "${output}" == *'Phase 0B approval must remain blocked'* ]]
	[[ "${output}" == *'external operation is forbidden'* ]]
	[[ "${output}" == *'secret-shaped value is forbidden'* ]]
	[[ "${output}" == *'asset manifest is invalid'* ]]
	[[ "${output}" != *'sk-fixture-dummy-token'* ]]
}

@test "socket control succeeds outside isolation and is blocked inside" {
	isolation_available || skip "unshare -Urn unavailable"

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
	isolation_available || skip "unshare -Urn unavailable"

	run "${RUNNER}/run-preflight.sh" --probe-subprocess
	[ "${status}" -ne 0 ]
	[[ "${output}" == *'child process blocked inside isolation'* ]]
}
