#!/usr/bin/env bash
# collect.sh — assemble a BLIND grading sheet for a task from meta-blind.json.
#
# Usage: ./collect.sh --task <TASKID> [--stage 1]
#
# Emits a TSV to runs/<task>/grading-sheet-blind.tsv with one row per alias,
# containing ONLY blind fields (alias, timing, git facts). No model/platform.
# This is the file you hand to the grader (or open yourself while grading) so
# scoring stays blind. The diff to grade for each row is at
# runs/<task>/<alias>/r<N>/diff.patch.
#
# Unsealing (AFTER scores are locked): ./collect.sh --task <T> --stage 1 --unseal
# joins in meta-sealed.json to reveal alias->model for analysis.

set -euo pipefail
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TASK="" STAGE="1" UNSEAL="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task) TASK="$2"; shift 2;;
    --stage) STAGE="$2"; shift 2;;
    --unseal) UNSEAL="1"; shift;;
    *) die "unknown arg: $1";;
  esac
done
[[ -n "${TASK}" ]] || die "usage: --task <id> [--stage N] [--unseal]"
have_jq || die "collect.sh needs jq"
require_stage "${STAGE}"

base="${RUNS_DIR}/${TASK}"
[[ -d "${base}" ]] || die "no runs for task ${TASK} at ${base}"
mapfile -t ALIASES < <(manifest_aliases "${STAGE}")
[[ "${#ALIASES[@]}" -gt 0 ]] || die "no manifest aliases for stage='${STAGE}'"

declare -a RESULT_FILES=()
for alias in "${ALIASES[@]}"; do
  mapfile -t matches < <(find "${base}/${alias}" -name result.json 2>/dev/null | sort)
  case "${#matches[@]}" in
    0) die "alias ${alias} has no terminal result for stage ${STAGE}";;
    1) RESULT_FILES+=("${matches[0]}");;
    *) die "alias ${alias} has multiple terminal results; Phase A expects exactly one terminal state";;
  esac
done

if [[ "${UNSEAL}" == "0" ]]; then
  out="${base}/grading-sheet-blind.tsv"
  printf 'alias\trun\tstage\tterminal_state\teffort_req\teffort_status\twall_s\trc\tfiles\twork_produced\tdiff_path\n' > "${out}"
  for result in "${RESULT_FILES[@]}"; do
    d="$(dirname "${result}")"
    mb="${d}/meta-blind.json"
    alias="$(jq -r '.alias' "${result}")"
    state="$(jq -r '.terminal_state' "${result}")"
    blind_diff=""
    if [[ -f "${mb}" ]]; then
      blind_diff="${d}/diff.patch"
      jq -r --arg st "${state}" --arg dp "${blind_diff}" '
        [ .alias, (.run_index|tostring), .stage, $st,
          (.effort_requested // "?"), (.effort_status // "?"),
          (.wall_clock_seconds|tostring),
          (.adapter_exit_code|tostring), (.diff_files_changed|tostring),
          (.work_produced|tostring), $dp ] | @tsv' "${mb}" >> "${out}"
    else
      effort_req="$(manifest_lookup "${alias}" | awk -F '\t' '{print $6}')"
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${alias}" "$(jq -r '.run_index' "${result}")" "${STAGE}" "${state}" \
        "${effort_req:-?}" "?" "?" "$(jq -r '.adapter_exit_code // "?"' "${result}")" \
        "0" "false" "" >> "${out}"
    fi
  done
  log "blind grading sheet -> ${out}"
  log "effort_status is neutral (applied|approximated|requested|not-applied|default) so it"
  log "does NOT leak the harness; the verbose mechanism string stays in meta-sealed.json."
  log "grade each row from its diff_path; do NOT open meta-sealed.json until scores are locked."
else
  out="${base}/unsealed-map.tsv"
  printf 'alias\tplatform\tmodel\tagent\trun\tterminal_state\twall_s\trc\tfiles\n' > "${out}"
  for result in "${RESULT_FILES[@]}"; do
    alias="$(jq -r '.alias' "${result}")"
    row="$(manifest_lookup "${alias}")" || die "alias not in manifest during unseal: ${alias}"
    IFS=$'\t' read -r -a fields <<<"${row}"
    platform="${fields[0]}"
    model="${fields[1]}"
    agent="${fields[2]}"
    d="$(dirname "${result}")"
    mb="${d}/meta-blind.json"
    if [[ -f "${mb}" ]]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${alias}" "${platform}" "${model}" "${agent}" \
        "$(jq -r '.run_index' "${result}")" "$(jq -r '.terminal_state' "${result}")" \
        "$(jq -r '.wall_clock_seconds // "?"' "${mb}")" "$(jq -r '.adapter_exit_code // "?"' "${mb}")" \
        "$(jq -r '.diff_files_changed // "?"' "${mb}")" >> "${out}"
    else
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${alias}" "${platform}" "${model}" "${agent}" \
        "$(jq -r '.run_index' "${result}")" "$(jq -r '.terminal_state' "${result}")" \
        "?" "$(jq -r '.adapter_exit_code // "?"' "${result}")" "0" >> "${out}"
    fi
  done
  log "UNSEALED map -> ${out} (only do this after grading is locked)"
fi
