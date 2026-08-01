#!/usr/bin/env bash

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bats_command="${VERIFY_LOCAL_BATS_COMMAND:-bats --jobs 4 scripts/tests/}"
repo_command="${VERIFY_LOCAL_REPO_COMMAND:-./test.sh}"
bats_label="${VERIFY_LOCAL_BATS_LABEL:-bats --jobs 4 scripts/tests/}"
repo_label="${VERIFY_LOCAL_REPO_LABEL:-./test.sh}"
bats_timeout="${VERIFY_LOCAL_BATS_TIMEOUT_SECONDS:-900}"
repo_timeout="${VERIFY_LOCAL_REPO_TIMEOUT_SECONDS:-900}"
log_dir="${VERIFY_LOCAL_LOG_DIR:-$repo_root/.artifacts/local-verification/run-$(date -u +%Y%m%dT%H%M%SZ)-$$}"

for value in "$bats_timeout" "$repo_timeout"; do
  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "verify-local: timeout values must be positive integers" >&2
    exit 2
  fi
done

command -v timeout >/dev/null 2>&1 || {
  echo "verify-local: GNU timeout is required" >&2
  exit 2
}
command -v setsid >/dev/null 2>&1 || {
  echo "verify-local: setsid is required" >&2
  exit 2
}

mkdir -p "$log_dir"
bats_log="$log_dir/bats.log"
repo_log="$log_dir/repository.log"
bats_elapsed_file="$log_dir/.bats-elapsed"
repo_elapsed_file="$log_dir/.repository-elapsed"
bats_pid=""
repo_pid=""

start_suite() {
  local command_text="$1" timeout_seconds="$2" log_file="$3" elapsed_file="$4"
  local pid_var="$5"

  setsid bash -c '
    started=$SECONDS
    cd "$1" || exit 2
    timeout --signal=TERM --kill-after=5 "${2}s" bash -c "$4" &
    timeout_pid=$!
    trap "kill -TERM -- -$timeout_pid 2>/dev/null || true" TERM INT
    wait "$timeout_pid"
    status=$?
    trap - TERM INT
    kill -TERM -- -$timeout_pid 2>/dev/null || true
    for ((attempt = 0; attempt < 50; attempt++)); do
      kill -0 -- -$timeout_pid 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL -- -$timeout_pid 2>/dev/null || true
    printf "%s\n" "$((SECONDS - started))" >"$3"
    exit "$status"
  ' verify-local-suite "$repo_root" "$timeout_seconds" "$elapsed_file" \
    "$command_text" >"$log_file" 2>&1 &
  printf -v "$pid_var" '%s' "$!"
}

stop_group() {
  local pid="$1"
  [[ -n "$pid" ]] || return 0
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM -- "-$pid" 2>/dev/null || true
  fi
}

wait_for_group() {
  local pid="$1" attempt
  [[ -n "$pid" ]] || return 0

  for ((attempt = 0; attempt < 50; attempt++)); do
    kill -0 -- "-$pid" 2>/dev/null || return 0
    sleep 0.1
  done
  kill -KILL -- "-$pid" 2>/dev/null || true
}

wait_status() {
  local pid="$1" status_var="$2"
  local status

  wait "$pid"
  status=$?
  printf -v "$status_var" '%s' "$status"
}

summarize_bats() {
  local log_file="$1" status="$2" elapsed="$3"
  local line passed=0 failed=0

  while IFS= read -r line; do
    case "$line" in
      "ok "*) passed=$((passed + 1)) ;;
      "not ok "*) failed=$((failed + 1)) ;;
    esac
  done <"$log_file"
  printf 'bats: passed=%d failed=%d exit=%s elapsed=%ss command="%s"\n' \
    "$passed" "$failed" "$status" "$elapsed" "$bats_label"
}

summarize_repository() {
  local log_file="$1" status="$2" elapsed="$3"
  local line passed=0 warnings=0 failed=0

  while IFS= read -r line; do
    if [[ "$line" =~ Passed:.*[[:space:]]([0-9]+)$ ]]; then
      passed="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ Warnings:.*[[:space:]]([0-9]+)$ ]]; then
      warnings="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ Failed:.*[[:space:]]([0-9]+)$ ]]; then
      failed="${BASH_REMATCH[1]}"
    fi
  done <"$log_file"
  printf 'repository: passed=%d warnings=%d failed=%d exit=%s elapsed=%ss command="%s"\n' \
    "$passed" "$warnings" "$failed" "$status" "$elapsed" "$repo_label"
}

report_results() {
  local bats_status="$1" repo_status="$2"
  local bats_elapsed=0 repo_elapsed=0

  [[ -f "$bats_elapsed_file" ]] && bats_elapsed="$(<"$bats_elapsed_file")"
  [[ -f "$repo_elapsed_file" ]] && repo_elapsed="$(<"$repo_elapsed_file")"
  summarize_bats "$bats_log" "$bats_status" "$bats_elapsed"
  summarize_repository "$repo_log" "$repo_status" "$repo_elapsed"
}

handle_signal() {
  local exit_code="$1"
  local bats_status=143 repo_status=143

  trap - INT TERM
  stop_group "$bats_pid"
  stop_group "$repo_pid"
  wait_for_group "$bats_pid"
  wait_for_group "$repo_pid"
  [[ -n "$bats_pid" ]] && wait_status "$bats_pid" bats_status
  [[ -n "$repo_pid" ]] && wait_status "$repo_pid" repo_status
  report_results "$bats_status" "$repo_status"
  echo "Failure logs: $log_dir"
  exit "$exit_code"
}

trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

echo "Starting Bats and repository verification concurrently."
start_suite "$bats_command" "$bats_timeout" "$bats_log" "$bats_elapsed_file" bats_pid
start_suite "$repo_command" "$repo_timeout" "$repo_log" "$repo_elapsed_file" repo_pid

wait_status "$bats_pid" bats_status
wait_status "$repo_pid" repo_status
trap - INT TERM
report_results "$bats_status" "$repo_status"

if [[ "$bats_status" -eq 0 && "$repo_status" -eq 0 ]]; then
  rm -f "$bats_log" "$repo_log" "$bats_elapsed_file" "$repo_elapsed_file"
  rmdir "$log_dir" 2>/dev/null || true
  echo "Complete local verification passed."
  exit 0
fi

rm -f "$bats_elapsed_file" "$repo_elapsed_file"
echo "Failure logs: $log_dir"
exit 1
