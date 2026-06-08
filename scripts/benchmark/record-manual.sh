#!/usr/bin/env bash
# record-manual.sh — capture results for a MANUALLY-run candidate.
#
# All five bundled adapters (copilot, codex, claude-code, cursor, gemini-cli) aim
# to run headlessly. This script is the explicit audited fallback after a
# documented headless failure left the alias in the terminal 'blocked' state.
#
# Usage:
#   ./record-manual.sh --task <T> --base <SHA> --alias <cand-NN> [--run-index N] \
#       [--rc 0] [--start <epoch>] [--end <epoch>] \
#       [--tokens-in N] [--tokens-out N] [--cost-src "cursor-dashboard"]
#
# Assumes you created the worktree with 'make worktree' and ran the agent inside
# it. Captures the diff + your telemetry into the SAME meta-blind/meta-sealed
# layout the automated adapters produce, so manual candidates stay comparable.

set -euo pipefail
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TASK="" BASE_SHA="" ALIAS="" RUN_INDEX="1" RC="0"
START="" END="" TIN="" TOUT="" COST_SRC="manual"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)
      TASK="$2"
      shift 2
      ;;
    --base)
      BASE_SHA="$2"
      shift 2
      ;;
    --alias)
      ALIAS="$2"
      shift 2
      ;;
    --run-index)
      RUN_INDEX="$2"
      shift 2
      ;;
    --rc)
      RC="$2"
      shift 2
      ;;
    --start)
      START="$2"
      shift 2
      ;;
    --end)
      END="$2"
      shift 2
      ;;
    --tokens-in)
      TIN="$2"
      shift 2
      ;;
    --tokens-out)
      TOUT="$2"
      shift 2
      ;;
    --cost-src)
      COST_SRC="$2"
      shift 2
      ;;
    *) die "unknown arg: $1" ;;
  esac
done
[[ -n "${TASK}" && -n "${BASE_SHA}" && -n "${ALIAS}" ]] || die "need --task --base --alias"

preflight
require_base "${BASE_SHA}"
row="$(manifest_lookup "${ALIAS}")" || die "alias not in manifest: ${ALIAS}"
require_alias_stage_one "${ALIAS}" "${row}" || exit 2
IFS=$'\t' read -r PLATFORM MODEL AGENT STAGE EFFORT EFFORT_MECH <<<"${row}"

WT="$(worktree_path "${TASK}" "${ALIAS}" "${RUN_INDEX}")"
[[ -d "${WT}" ]] || die "no worktree at ${WT} — run 'make worktree TASK=${TASK} BASE=${BASE_SHA} ALIAS=${ALIAS}' first"
OUTDIR="$(run_outdir "${TASK}" "${ALIAS}" "${RUN_INDEX}")"
mkdir -p "${OUTDIR}/logs"
RESULT_FILE="$(result_file_path "${TASK}" "${ALIAS}" "${RUN_INDEX}")"
[[ -f "${RESULT_FILE}" ]] \
  || die "manual capture requires a prior documented blocked state at ${RESULT_FILE}"
if have_jq; then
  prev_state="$(jq -r '.terminal_state' "${RESULT_FILE}")"
  prev_manual_ok="$(jq -r '.manual_fallback_allowed' "${RESULT_FILE}")"
else
  prev_state="$(grep -E '"terminal_state"' "${RESULT_FILE}" | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')"
  prev_manual_ok="$(grep -E '"manual_fallback_allowed"' "${RESULT_FILE}" | head -n1 | sed -E 's/.*: (true|false).*/\1/')"
fi
[[ "${prev_state}" == "blocked" && "${prev_manual_ok}" == "true" ]] \
  || die "manual capture is only allowed after a documented blocked result with manual fallback enabled"

git -C "${WT}" add -A 2>/dev/null || true
git -C "${WT}" diff --binary "${BASE_SHA}" >"${OUTDIR}/diff.patch" 2>/dev/null || true
HEAD_SHA="$(git -C "${WT}" rev-parse HEAD 2>/dev/null || echo "")"
DIFF_FILES="$(git -C "${WT}" diff --name-only "${BASE_SHA}" | wc -l | tr -d ' ')"
COMMITTED_AHEAD="$(git -C "${WT}" rev-list --count "${BASE_SHA}..HEAD" 2>/dev/null || echo 0)"
WORK_PRODUCED=$([[ "${COMMITTED_AHEAD}" -gt 0 || "${DIFF_FILES}" -gt 0 ]] && echo true || echo false)
WALL="null"
[[ -n "${START}" && -n "${END}" ]] && WALL=$((END - START))
DIFF_LINES="$(git -C "${WT}" diff --shortstat "${BASE_SHA}" 2>/dev/null || echo '')"
EFFORT_APPLIED="manual:${EFFORT}(set-by-hand)"
EFFORT_STATUS="$(derive_effort_status "${EFFORT}" "${EFFORT_MECH}" "${EFFORT_APPLIED}")"

{
  printf '{\n'
  printf '  "alias": %s,\n' "$(json_escape "${ALIAS}")"
  printf '  "task_id": %s,\n' "$(json_escape "${TASK}")"
  printf '  "run_index": %s,\n' "${RUN_INDEX}"
  printf '  "stage": %s,\n' "$(json_escape "${STAGE}")"
  printf '  "base_sha": %s,\n' "$(json_escape "${BASE_SHA}")"
  printf '  "head_sha": %s,\n' "$(json_escape "${HEAD_SHA}")"
  printf '  "wall_clock_seconds": %s,\n' "${WALL}"
  printf '  "adapter_exit_code": %s,\n' "${RC}"
  printf '  "diff_files_changed": %s,\n' "${DIFF_FILES}"
  printf '  "work_produced": %s,\n' "${WORK_PRODUCED}"
  printf '  "manual_run": true,\n'
  printf '  "shortstat": %s\n' "$(json_escape "${DIFF_LINES}")"
  printf '}\n'
} >"${OUTDIR}/meta-blind.json"

{
  printf '{\n'
  printf '  "alias": %s,\n' "$(json_escape "${ALIAS}")"
  printf '  "platform": %s,\n' "$(json_escape "${PLATFORM}")"
  printf '  "model": %s,\n' "$(json_escape "${MODEL}")"
  printf '  "agent": %s,\n' "$(json_escape "${AGENT}")"
  printf '  "effort_requested": %s,\n' "$(json_escape "${EFFORT}")"
  printf '  "effort_mechanism": %s,\n' "$(json_escape "${EFFORT_MECH}")"
  printf '  "effort_applied": %s,\n' "$(json_escape "${EFFORT_APPLIED}")"
  printf '  "effort_status": %s,\n' "$(json_escape "${EFFORT_STATUS}")"
  printf '  "manual_run": true,\n'
  printf '  "telemetry_tokens_in": %s,\n' "${TIN:-null}"
  printf '  "telemetry_tokens_out": %s,\n' "${TOUT:-null}"
  printf '  "cost_source": %s,\n' "$(json_escape "${COST_SRC}")"
  printf '  "head_sha": %s\n' "$(json_escape "${HEAD_SHA}")"
  printf '}\n'
} >"${OUTDIR}/meta-sealed.json"

write_result_file "${OUTDIR}" "${ALIAS}" "${TASK}" "${RUN_INDEX}" "${STAGE}" \
  "manual-capture-approved" "${HEAD_SHA}" "${RC}" "false" "meta-blind.json" "meta-sealed.json" "diff.patch"

log "recorded manual run: ${ALIAS} files=${DIFF_FILES} work_produced=${WORK_PRODUCED}"
