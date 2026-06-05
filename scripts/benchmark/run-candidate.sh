#!/usr/bin/env bash
# run-candidate.sh — run ONE benchmark candidate, deterministically.
#
# Usage:
#   ./run-candidate.sh --task <TASKID> --base <BASE_SHA> --alias <cand-NN> [--run-index N] [--keep-worktree] [--context-variant baseline|full-rules-injected] [--orchestration-variant none|pipeline-existing-overlays|pipeline-same-model]
#
# What it does:
#   1. Looks up alias -> platform/model/agent in the sealed manifest.
#   2. Materializes an isolated git worktree at BASE_SHA on the aliased branch.
#   3. Runs doctor, then dispatches to the platform adapter (model pinned, prompt piped, headless).
#   4. Captures: exit code, wall-clock, git diff/commit, raw agent output, logs.
#   5. Writes TWO metadata files:
#        meta-blind.json   — alias, task, timing, git SHA, rc, telemetry. NO model identity.
#        meta-sealed.json  — adds platform/model/agent. For post-unseal only.
#   6. GRADES NOTHING. Success/failure is decided later by the evaluator's
#      independent acceptance check, not here.
#
# It does NOT push and does NOT open a PR. The runner owns push (see make push)
# so blinding stays intact and no agent can force-push a shared branch.

set -euo pipefail
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TASK="" BASE_SHA="" ALIAS="" RUN_INDEX="1" KEEP_WT="0" RUN_CONTEXT_VARIANT="${CONTEXT_VARIANT}" RUN_ORCHESTRATION_VARIANT="${ORCHESTRATION_VARIANT}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)        TASK="$2"; shift 2;;
    --base)        BASE_SHA="$2"; shift 2;;
    --alias)       ALIAS="$2"; shift 2;;
    --run-index)   RUN_INDEX="$2"; shift 2;;
    --keep-worktree) KEEP_WT="1"; shift;;
    --context-variant) RUN_CONTEXT_VARIANT="$2"; shift 2;;
    --orchestration-variant) RUN_ORCHESTRATION_VARIANT="$2"; shift 2;;
    *) die "unknown arg: $1";;
  esac
done
[[ -n "${TASK}" && -n "${BASE_SHA}" && -n "${ALIAS}" ]] \
  || die "usage: --task <id> --base <sha> --alias <cand-NN> [--run-index N] [--keep-worktree]"

preflight
require_base "${BASE_SHA}"
require_task_file "${TASK}"

# Resolve the sealed mapping.
row="$(manifest_lookup "${ALIAS}")" || die "alias not in manifest: ${ALIAS}"
require_alias_stage_one "${ALIAS}" "${row}" || exit 2
IFS=$'\t' read -r PLATFORM MODEL AGENT STAGE EFFORT EFFORT_MECH <<<"${row}"
log "candidate=${ALIAS} task=${TASK} run=${RUN_INDEX} platform=${PLATFORM} effort=${EFFORT}(${EFFORT_MECH}) (model sealed)"

if [[ "${BENCHMARK_DOCTOR_DONE:-0}" != "1" ]]; then
  "${RUNNER_DIR}/doctor.sh" --alias "${ALIAS}" --base "${BASE_SHA}"
fi

ADAPTER="$(adapter_path "${PLATFORM}")"
[[ -f "${ADAPTER}" ]] || die "no adapter for platform '${PLATFORM}': ${ADAPTER}"
# shellcheck source=/dev/null
source "${ADAPTER}"

OUTDIR="$(run_outdir "${TASK}" "${ALIAS}" "${RUN_INDEX}")"
mkdir -p "${OUTDIR}/logs"
prepare_git_push_guard "${OUTDIR}"

WT="$(make_worktree "${TASK}" "${ALIAS}" "${RUN_INDEX}" "${BASE_SHA}")"
log "worktree: ${WT}"
RUN_CONTEXT_VARIANT="$(context_variant_slug "${RUN_CONTEXT_VARIANT}")"
apply_context_variant "${WT}" "${OUTDIR}" "${RUN_CONTEXT_VARIANT}"
log "context_variant=${RUN_CONTEXT_VARIANT}"
RUN_ORCHESTRATION_VARIANT="$(orchestration_variant_slug "${RUN_ORCHESTRATION_VARIANT}")"
apply_orchestration_variant "${WT}" "${OUTDIR}" "${RUN_ORCHESTRATION_VARIANT}" "${PLATFORM}" "${MODEL}" "${EFFORT}"
log "orchestration_variant=${RUN_ORCHESTRATION_VARIANT}"

# ---- dispatch with timing --------------------------------------------------
# Adapter contract is now:
#   adapter_run WORKDIR MODEL PROMPT_FILE OUTDIR EFFORT EFFORT_MECH
# The adapter is responsible for applying effort by its mechanism and writing
# OUTDIR/effort-applied.txt with what it ACTUALLY did (so we can detect silent
# drops — e.g. Cursor ignoring a suffix). If it can't set effort, it records
# "uncontrolled". Any non-zero adapter exit becomes an audited blocked state
# with the worktree preserved for optional manual capture.
START_EPOCH="$(date +%s)"; START_TS="$(_ts)"
RENDERED_PROMPT="$(render_prompt_for_run "${TASK}" "${ALIAS}" "${PLATFORM}" "${MODEL}" "${AGENT}" "${BASE_SHA}" "${RUN_INDEX}" "${OUTDIR}")"
set +e
adapter_run "${WT}" "${MODEL}" "${RENDERED_PROMPT}" "${OUTDIR}" "${EFFORT}" "${EFFORT_MECH}"
RC=$?
set -e
END_EPOCH="$(date +%s)"; END_TS="$(_ts)"
WALL=$(( END_EPOCH - START_EPOCH ))
EFFORT_APPLIED="$(cat "${OUTDIR}/effort-applied.txt" 2>/dev/null || echo "unknown")"
EFFORT_STATUS="$(derive_effort_status "${EFFORT}" "${EFFORT_MECH}" "${EFFORT_APPLIED}")"

if [[ ${RC} -ne 0 ]]; then
  # Any non-zero adapter exit is treated as an audited automated-run failure.
  # The failure is documented here, the worktree stays open, and 'make record'
  # is the only way to advance this alias from blocked ->
  # manual-capture-approved.
  HEAD_SHA="$(git -C "${WT}" rev-parse HEAD 2>/dev/null || echo "")"
  write_result_file "${OUTDIR}" "${ALIAS}" "${TASK}" "${RUN_INDEX}" "${STAGE}" \
    "blocked" "${HEAD_SHA}" "${RC}" "true" "" "" ""
  log "blocked (${PLATFORM}): automated run exited rc=${RC}. Use 'make record' only after a real manual rerun."
  log "(worktree kept at ${WT} so you can run the agent in it)"
  exit 64
fi

# ---- capture git result (no judgement, just facts) -------------------------
restore_orchestration_variant "${WT}" "${OUTDIR}" "${RUN_ORCHESTRATION_VARIANT}"
restore_context_variant "${WT}" "${OUTDIR}" "${RUN_CONTEXT_VARIANT}"
HEAD_SHA="$(git -C "${WT}" rev-parse HEAD 2>/dev/null || echo "")"
COMMITTED_AHEAD="$(git -C "${WT}" rev-list --count "${BASE_SHA}..HEAD" 2>/dev/null || echo 0)"
# Diff includes both committed work and any uncommitted working-tree changes vs base.
git -C "${WT}" add -A 2>/dev/null || true
git -C "${WT}" diff --binary "${BASE_SHA}" > "${OUTDIR}/diff.patch" 2>/dev/null || true
DIFF_FILES="$(git -C "${WT}" diff --name-only "${BASE_SHA}" | wc -l | tr -d ' ')"
DIFF_LINES="$(git -C "${WT}" diff --shortstat "${BASE_SHA}" 2>/dev/null || echo '')"
WORK_PRODUCED=$([[ "${COMMITTED_AHEAD}" -gt 0 || "${DIFF_FILES}" -gt 0 ]] && echo true || echo false)

# ---- write metadata --------------------------------------------------------
# meta-blind.json: everything the GRADER may see. Deliberately omits model/platform.
{
  printf '{\n'
  printf '  "alias": %s,\n'        "$(json_escape "${ALIAS}")"
  printf '  "task_id": %s,\n'      "$(json_escape "${TASK}")"
  printf '  "run_index": %s,\n'    "${RUN_INDEX}"
  printf '  "stage": %s,\n'        "$(json_escape "${STAGE}")"
  printf '  "context_variant": %s,\n' "$(json_escape "${RUN_CONTEXT_VARIANT}")"
  printf '  "orchestration_variant": %s,\n' "$(json_escape "${RUN_ORCHESTRATION_VARIANT}")"
  printf '  "base_sha": %s,\n'     "$(json_escape "${BASE_SHA}")"
  printf '  "head_sha": %s,\n'     "$(json_escape "${HEAD_SHA}")"
  printf '  "start_utc": %s,\n'    "$(json_escape "${START_TS}")"
  printf '  "end_utc": %s,\n'      "$(json_escape "${END_TS}")"
  printf '  "wall_clock_seconds": %s,\n' "${WALL}"
  printf '  "adapter_exit_code": %s,\n'  "${RC}"
  printf '  "commits_ahead_of_base": %s,\n' "${COMMITTED_AHEAD}"
  printf '  "diff_files_changed": %s,\n' "${DIFF_FILES}"
  printf '  "work_produced": %s,\n'  "${WORK_PRODUCED}"
  printf '  "shortstat": %s\n'      "$(json_escape "${DIFF_LINES}")"
  printf '}\n'
} > "${OUTDIR}/meta-blind.json"
validate_json_artifact "${OUTDIR}/meta-blind.json"

# meta-sealed.json: blind fields + sealed identity. Keep out of grading.
{
  printf '{\n'
  printf '  "alias": %s,\n'    "$(json_escape "${ALIAS}")"
  printf '  "platform": %s,\n' "$(json_escape "${PLATFORM}")"
  printf '  "model": %s,\n'    "$(json_escape "${MODEL}")"
  printf '  "agent": %s,\n'    "$(json_escape "${AGENT}")"
  printf '  "effort_requested": %s,\n' "$(json_escape "${EFFORT}")"
  printf '  "effort_mechanism": %s,\n' "$(json_escape "${EFFORT_MECH}")"
  printf '  "effort_applied": %s,\n'   "$(json_escape "${EFFORT_APPLIED}")"
  printf '  "effort_status": %s,\n'    "$(json_escape "${EFFORT_STATUS}")"
  printf '  "context_variant": %s,\n'  "$(json_escape "${RUN_CONTEXT_VARIANT}")"
  printf '  "orchestration_variant": %s,\n' "$(json_escape "${RUN_ORCHESTRATION_VARIANT}")"
  printf '  "task_id": %s,\n'  "$(json_escape "${TASK}")"
  printf '  "run_index": %s,\n' "${RUN_INDEX}"
  printf '  "head_sha": %s,\n' "$(json_escape "${HEAD_SHA}")"
  printf '  "wall_clock_seconds": %s,\n' "${WALL}"
  printf '  "adapter_exit_code": %s\n' "${RC}"
  printf '}\n'
} > "${OUTDIR}/meta-sealed.json"
validate_json_artifact "${OUTDIR}/meta-sealed.json"

write_result_file "${OUTDIR}" "${ALIAS}" "${TASK}" "${RUN_INDEX}" "${STAGE}" \
  "graded" "${HEAD_SHA}" "${RC}" "false" "meta-blind.json" "meta-sealed.json" "diff.patch"

log "captured: rc=${RC} wall=${WALL}s files=${DIFF_FILES} work_produced=${WORK_PRODUCED} effort=${EFFORT}->${EFFORT_APPLIED}"
log "  blind  -> ${OUTDIR}/meta-blind.json"
log "  sealed -> ${OUTDIR}/meta-sealed.json (do NOT show the grader)"
log "  state  -> ${OUTDIR}/result.json"
log "  diff   -> ${OUTDIR}/diff.patch"
log "  output -> ${OUTDIR}/agent-output.jsonl"

[[ "${KEEP_WT}" == "1" ]] || drop_worktree "${TASK}" "${ALIAS}" "${RUN_INDEX}"
log "done: ${ALIAS} (r${RUN_INDEX})"
exit 0
