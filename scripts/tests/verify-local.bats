#!/usr/bin/env bats

export BATS_TEST_TIMEOUT="${BATS_TEST_TIMEOUT:-60}"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TEST_ROOT="$(mktemp -d)"
  RUNNER="$REPO_ROOT/scripts/verify-local.sh"
  LOG_DIR="$TEST_ROOT/logs"

  cat >"$TEST_ROOT/suite.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

trap 'printf "terminated\n" >"$TERM_FILE"; exit 143' TERM INT
printf '%s\n' "$$" >"$PID_FILE"
touch "$STARTED_FILE"

if [[ -n "${PEER_STARTED:-}" ]]; then
  for _ in $(seq 1 200); do
    [[ -f "$PEER_STARTED" ]] && break
    sleep 0.01
  done
  [[ -f "$PEER_STARTED" ]] || {
    echo "peer suite did not start" >&2
    exit 98
  }
fi

if [[ "${SUITE_MODE:-complete}" == "hang" ]]; then
  bash -c 'trap "" TERM; sleep 30' &
  printf '%s\n' "$!" >"$GRANDCHILD_PID_FILE"
  wait "$!"
fi

sleep "${SUITE_DELAY:-0}"
if [[ "$SUITE_NAME" == "bats" ]]; then
  printf '1..1\nok 1 fixture\n'
else
  printf '\033[0;32mPassed:\033[0m 1\n'
  printf '\033[0;33mWarnings:\033[0m 0\n'
  printf '\033[0;31mFailed:\033[0m 0\n'
fi
printf '%s\n' "$SUITE_DIAGNOSTIC"
exit "$SUITE_EXIT"
EOF
  chmod +x "$TEST_ROOT/suite.sh"
}

teardown() {
  for pid_file in "$TEST_ROOT"/*.grandchild.pid; do
    [[ -f "$pid_file" ]] || continue
    kill "$(<"$pid_file")" 2>/dev/null || true
  done
  rm -rf "$TEST_ROOT"
}

suite_command() {
  local name="$1" exit_code="$2" diagnostic="$3" mode="${4:-complete}"
  local peer="${5:-}"

  printf 'env SUITE_NAME=%q SUITE_EXIT=%q SUITE_DIAGNOSTIC=%q SUITE_MODE=%q STARTED_FILE=%q PEER_STARTED=%q PID_FILE=%q TERM_FILE=%q GRANDCHILD_PID_FILE=%q bash %q' \
    "$name" "$exit_code" "$diagnostic" "$mode" \
    "$TEST_ROOT/$name.started" "$peer" "$TEST_ROOT/$name.pid" \
    "$TEST_ROOT/$name.term" "$TEST_ROOT/$name.grandchild.pid" \
    "$TEST_ROOT/suite.sh"
}

run_runner() {
  local bats_command="$1" repo_command="$2"
  shift 2
  run env \
    VERIFY_LOCAL_BATS_COMMAND="$bats_command" \
    VERIFY_LOCAL_REPO_COMMAND="$repo_command" \
    VERIFY_LOCAL_BATS_TIMEOUT_SECONDS="${VERIFY_LOCAL_BATS_TIMEOUT_SECONDS:-10}" \
    VERIFY_LOCAL_REPO_TIMEOUT_SECONDS="${VERIFY_LOCAL_REPO_TIMEOUT_SECONDS:-10}" \
    VERIFY_LOCAL_PREREQUISITE_COMMAND="${VERIFY_LOCAL_PREREQUISITE_COMMAND:-:}" \
    VERIFY_LOCAL_LOG_DIR="$LOG_DIR" \
    bash "$RUNNER" "$@"
}

@test "failed prerequisite check prevents every expensive suite from starting" {
  bats_command="touch $TEST_ROOT/bats-unexpected"
  repo_command="touch $TEST_ROOT/repository-unexpected"
  VERIFY_LOCAL_PREREQUISITE_COMMAND="printf MISSING_UVX >&2; exit 9"

  run_runner "$bats_command" "$repo_command" --full

  [ "$status" -eq 1 ]
  [ ! -e "$TEST_ROOT/bats-unexpected" ]
  [ ! -e "$TEST_ROOT/repository-unexpected" ]
  [[ "$output" == *"MISSING_UVX"* ]]
  [[ "$output" == *"prerequisites: exit=9 elapsed="* ]]
}

wait_for_file() {
  local path="$1"
  for _ in $(seq 1 200); do
    [[ -f "$path" ]] && return 0
    sleep 0.01
  done
  return 1
}

assert_stopped() {
  local pid state
  pid="$(<"$1")"
  state="$(ps -o stat= -p "$pid" 2>/dev/null || true)"
  [[ -z "$state" || "$state" == Z* ]]
}

@test "complete local verification starts both suites before either completes" {
  bats_command="$(suite_command bats 0 BATS_SUCCESS complete "$TEST_ROOT/repository.started")"
  repo_command="$(suite_command repository 0 REPO_SUCCESS complete "$TEST_ROOT/bats.started")"

  run_runner "$bats_command" "$repo_command" --full

  [ "$status" -eq 0 ]
  [ -f "$TEST_ROOT/bats.started" ]
  [ -f "$TEST_ROOT/repository.started" ]
  [[ "$output" == *"Verification mode: full"* ]]
  [[ "$output" == *"bats: passed=1 failed=0 exit=0"* ]]
  [[ "$output" == *"repository: passed=1 warnings=0 failed=0 exit=0"* ]]
  [[ "$output" != *"BATS_SUCCESS"* ]]
  [[ "$output" != *"REPO_SUCCESS"* ]]
  [ "${#lines[@]}" -le 8 ]
  [ ! -e "$LOG_DIR" ]
}

@test "fast verification runs repository checks without starting Bats" {
  bats_command="touch $TEST_ROOT/bats-unexpected"
  repo_command="$(suite_command repository 0 REPO_SUCCESS)"

  run_runner "$bats_command" "$repo_command"

  [ "$status" -eq 0 ]
  [ ! -e "$TEST_ROOT/bats-unexpected" ]
  [[ "$output" == *"Verification mode: fast"* ]]
  [[ "$output" == *"timeout: repository=10s"* ]]
  [[ "$output" != *"bats=10s"* ]]
  [[ "$output" == *"repository: passed=1 warnings=0 failed=0 exit=0"* ]]
  [[ "$output" != *"bats: passed="* ]]
}

@test "complete local verification uses the bounded twelve-worker Bats default" {
  cat >"$TEST_ROOT/bats" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >"$TEST_ROOT/bats.args"
printf '1..1\nok 1 fixture\n'
EOF
  chmod +x "$TEST_ROOT/bats"
  repo_command="$(suite_command repository 0 REPO_SUCCESS)"

  run env -u VERIFY_LOCAL_BATS_COMMAND -u VERIFY_LOCAL_BATS_LABEL \
    -u VERIFY_LOCAL_BATS_TIMEOUT_SECONDS -u VERIFY_LOCAL_REPO_TIMEOUT_SECONDS \
    PATH="$TEST_ROOT:$PATH" \
    VERIFY_LOCAL_REPO_COMMAND="$repo_command" \
    VERIFY_LOCAL_PREREQUISITE_COMMAND=: \
    VERIFY_LOCAL_LOG_DIR="$LOG_DIR" \
    bash "$RUNNER" --full

  [ "$status" -eq 0 ]
  [ "$(<"$TEST_ROOT/bats.args")" = "--jobs 12 scripts/tests/" ]
  [[ "$output" == *'command="bats --jobs 12 scripts/tests/"'* ]]
  [[ "$output" == *"timeouts: bats=300s repository=300s"* ]]
}

@test "complete local verification retains logs for a Bats-only failure" {
  bats_command="$(suite_command bats 7 BATS_COMPLETE_DIAGNOSTIC)"
  repo_command="$(suite_command repository 0 REPO_SUCCESS)"

  run_runner "$bats_command" "$repo_command" --full

  [ "$status" -eq 1 ]
  [[ "$output" == *"bats: passed=1 failed=0 exit=7"* ]]
  [[ "$output" == *"repository: passed=1 warnings=0 failed=0 exit=0"* ]]
  [[ "$output" == *"Failure logs: $LOG_DIR"* ]]
  grep -Fq BATS_COMPLETE_DIAGNOSTIC "$LOG_DIR/bats.log"
  grep -Fq REPO_SUCCESS "$LOG_DIR/repository.log"
}

@test "complete local verification retains logs for a repository-only failure" {
  bats_command="$(suite_command bats 0 BATS_SUCCESS)"
  repo_command="$(suite_command repository 9 REPO_COMPLETE_DIAGNOSTIC)"

  run_runner "$bats_command" "$repo_command" --full

  [ "$status" -eq 1 ]
  [[ "$output" == *"bats: passed=1 failed=0 exit=0"* ]]
  [[ "$output" == *"repository: passed=1 warnings=0 failed=0 exit=9"* ]]
  grep -Fq BATS_SUCCESS "$LOG_DIR/bats.log"
  grep -Fq REPO_COMPLETE_DIAGNOSTIC "$LOG_DIR/repository.log"
}

@test "complete local verification reports dual failure statuses" {
  bats_command="$(suite_command bats 7 BATS_COMPLETE_DIAGNOSTIC)"
  repo_command="$(suite_command repository 9 REPO_COMPLETE_DIAGNOSTIC)"

  run_runner "$bats_command" "$repo_command" --full

  [ "$status" -eq 1 ]
  [[ "$output" == *"bats: passed=1 failed=0 exit=7"* ]]
  [[ "$output" == *"repository: passed=1 warnings=0 failed=0 exit=9"* ]]
  grep -Fq BATS_COMPLETE_DIAGNOSTIC "$LOG_DIR/bats.log"
  grep -Fq REPO_COMPLETE_DIAGNOSTIC "$LOG_DIR/repository.log"
}

@test "complete local verification times out and terminates a stuck suite" {
  bats_command="$(suite_command bats 0 BATS_UNREACHABLE hang)"
  repo_command="$(suite_command repository 0 REPO_SUCCESS)"
  VERIFY_LOCAL_BATS_TIMEOUT_SECONDS=1

  run_runner "$bats_command" "$repo_command" --full

  [ "$status" -eq 1 ]
  [[ "$output" == *"bats: passed=0 failed=0 exit=124"* ]]
  [[ "$output" == *"repository: passed=1 warnings=0 failed=0 exit=0"* ]]
  [ -f "$TEST_ROOT/bats.term" ]
  assert_stopped "$TEST_ROOT/bats.pid"
  assert_stopped "$TEST_ROOT/bats.grandchild.pid"
}

@test "interrupting complete local verification terminates both suites" {
  bats_command="$(suite_command bats 0 BATS_UNREACHABLE hang)"
  repo_command="$(suite_command repository 0 REPO_UNREACHABLE hang)"
  output_file="$TEST_ROOT/runner.out"

  env \
    VERIFY_LOCAL_BATS_COMMAND="$bats_command" \
    VERIFY_LOCAL_REPO_COMMAND="$repo_command" \
    VERIFY_LOCAL_BATS_TIMEOUT_SECONDS=30 \
    VERIFY_LOCAL_REPO_TIMEOUT_SECONDS=30 \
    VERIFY_LOCAL_LOG_DIR="$LOG_DIR" \
    bash "$RUNNER" --full >"$output_file" 2>&1 &
  runner_pid=$!

  wait_for_file "$TEST_ROOT/bats.pid"
  wait_for_file "$TEST_ROOT/repository.pid"
  wait_for_file "$TEST_ROOT/bats.grandchild.pid"
  wait_for_file "$TEST_ROOT/repository.grandchild.pid"
  kill -TERM "$runner_pid"
  runner_status=0
  wait "$runner_pid" || runner_status=$?

  [ "$runner_status" -eq 143 ]
  [ -f "$TEST_ROOT/bats.term" ]
  [ -f "$TEST_ROOT/repository.term" ]
  assert_stopped "$TEST_ROOT/bats.pid"
  assert_stopped "$TEST_ROOT/repository.pid"
  assert_stopped "$TEST_ROOT/bats.grandchild.pid"
  assert_stopped "$TEST_ROOT/repository.grandchild.pid"
  grep -Fq "Failure logs: $LOG_DIR" "$output_file"
}
