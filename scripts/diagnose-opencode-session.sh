#!/usr/bin/env bash
# Record process lifecycle evidence without capturing session content.
set -uo pipefail

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
diag_dir="${OPENCODE_DIAG_DIR:-/tmp/opencode-session-${timestamp}}"
opencode_bin="${OPENCODE_BIN:-opencode}"
mkdir -p "$diag_dir"
record="$diag_dir/lifecycle.log"
child_pid=""

record_event() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$record"
}

forward_signal() {
  # shellcheck disable=SC2317 # Invoked by the signal traps below.
  local signal="$1"
  record_event "wrapper_signal=${signal} child_pid=${child_pid:-unset}"
  if [[ -n "$child_pid" ]]; then
    kill -s "$signal" "$child_pid" 2>/dev/null || true
  fi
}

trap 'forward_signal INT' INT
trap 'forward_signal TERM' TERM

record_event "wrapper_pid=$$ parent_pid=$PPID command=$opencode_bin"
if [[ -r /sys/fs/cgroup/memory.events ]]; then
  cp /sys/fs/cgroup/memory.events "$diag_dir/memory.events.before"
fi

"$opencode_bin" "$@" &
child_pid=$!
record_event "child_started pid=$child_pid"
ps -o pid=,ppid=,lstart=,etime=,rss=,command= -p "$child_pid" >"$diag_dir/process.start" 2>/dev/null || true

wait "$child_pid"
status=$?
signal="none"
if [[ "$status" -ge 128 && "$status" -le 192 ]]; then
  signal="$((status - 128))"
fi
record_event "child_exited pid=$child_pid status=$status signal=$signal"

if [[ -r /sys/fs/cgroup/memory.events ]]; then
  cp /sys/fs/cgroup/memory.events "$diag_dir/memory.events.after"
fi
printf 'OpenCode lifecycle record: %s\n' "$record" >&2
exit "$status"
