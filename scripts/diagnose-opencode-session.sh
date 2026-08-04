#!/usr/bin/env bash
# Record process lifecycle evidence without capturing session content.
set -uo pipefail

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
diag_dir="${OPENCODE_DIAG_DIR:-/tmp/opencode-session-${timestamp}}"
opencode_bin="${OPENCODE_BIN:-opencode}"
database="${OPENCODE_DB_PATH:-$HOME/.local/share/opencode/opencode.db}"
sample_interval="${OPENCODE_SAMPLE_INTERVAL:-1}"
mkdir -p "$diag_dir"
record="$diag_dir/lifecycle.log"
child_pid=""
monitor_pid=""

record_event() {
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$record"
}

# shellcheck disable=SC2317 # Invoked by the signal traps below.
forward_signal() {
  local signal="$1"
  record_event "wrapper_signal=${signal} child_pid=${child_pid:-unset}"
  if [[ -n "$child_pid" ]]; then
    kill -s "$signal" "$child_pid" 2>/dev/null || true
  fi
}

file_size() {
  local path="$1"
  if [[ -f "$path" ]]; then
    stat -c %s "$path"
  else
    printf '0\n'
  fi
}

record_database_state() {
  local phase="$1"
  {
    printf 'db_bytes=%s\n' "$(file_size "$database")"
    printf 'wal_bytes=%s\n' "$(file_size "$database-wal")"
    printf 'shm_bytes=%s\n' "$(file_size "$database-shm")"
  } >"$diag_dir/database.$phase"
}

proc_value() {
  local file="$1" key="$2" label value _unit
  [[ -r "$file" ]] || return
  while read -r label value _unit; do
    if [[ "$label" == "$key:" ]]; then
      printf '%s\n' "$value"
      return
    fi
  done <"$file"
}

record_memory_sample() {
  local pid="$1" rss anon file
  rss="$(proc_value "/proc/$pid/status" VmRSS)"
  anon="$(proc_value "/proc/$pid/smaps_rollup" Pss_Anon)"
  file="$(proc_value "/proc/$pid/smaps_rollup" Pss_File)"
  printf '%s rss_kb=%s pss_anon_kb=%s pss_file_kb=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${rss:-0}" "${anon:-0}" "${file:-0}" \
    >>"$diag_dir/memory.samples"
}

sample_memory() {
  local pid="$1"
  while kill -0 "$pid" 2>/dev/null; do
    record_memory_sample "$pid"
    sleep "$sample_interval"
  done
}

summarize_memory() {
  local field value peak_rss=0 peak_anon=0 peak_file=0
  if [[ -r "$diag_dir/memory.samples" ]]; then
    while read -r _ fields; do
      for field in $fields; do
        value="${field#*=}"
        [[ "$value" =~ ^[0-9]+$ ]] || continue
        case "$field" in
          rss_kb=*) ((value > peak_rss)) && peak_rss="$value" ;;
          pss_anon_kb=*) ((value > peak_anon)) && peak_anon="$value" ;;
          pss_file_kb=*) ((value > peak_file)) && peak_file="$value" ;;
        esac
      done
    done <"$diag_dir/memory.samples"
  fi
  {
    printf 'peak_rss_kb=%s\n' "$peak_rss"
    printf 'peak_pss_anon_kb=%s\n' "$peak_anon"
    printf 'peak_pss_file_kb=%s\n' "$peak_file"
  } >"$diag_dir/memory.summary"
}

trap 'forward_signal INT' INT
trap 'forward_signal TERM' TERM

record_event "wrapper_pid=$$ parent_pid=$PPID command=$opencode_bin"
record_database_state before
if [[ -r /sys/fs/cgroup/memory.events ]]; then
  cp /sys/fs/cgroup/memory.events "$diag_dir/memory.events.before"
fi

"$opencode_bin" "$@" &
child_pid=$!
record_event "child_started pid=$child_pid"
ps -o pid=,ppid=,lstart=,etime=,rss=,comm= -p "$child_pid" >"$diag_dir/process.start" 2>/dev/null || true
record_memory_sample "$child_pid"
sample_memory "$child_pid" &
monitor_pid=$!

wait "$child_pid"
status=$?
wait "$monitor_pid" 2>/dev/null || true
signal="none"
if [[ "$status" -ge 128 && "$status" -le 192 ]]; then
  signal="$((status - 128))"
fi
record_event "child_exited pid=$child_pid status=$status signal=$signal"
summarize_memory
record_database_state after

if [[ -r /sys/fs/cgroup/memory.events ]]; then
  cp /sys/fs/cgroup/memory.events "$diag_dir/memory.events.after"
fi
printf 'OpenCode lifecycle record: %s\n' "$record" >&2
exit "$status"
