#!/usr/bin/env bash
# run-duo-candidate.sh - run one Stage 1D planner/implementer benchmark alias.

set -euo pipefail
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

DUO_MANIFEST="${DUO_MANIFEST:-${RUNNER_DIR}/duo-candidates.tsv}"
DUO_PLANNER_PROMPT_FILE="${DUO_PLANNER_PROMPT_FILE:-${REPO_DIR}/.github/prompts/model-roi-duo-planner.md}"
DUO_IMPLEMENTER_PROMPT_FILE="${DUO_IMPLEMENTER_PROMPT_FILE:-${REPO_DIR}/.github/prompts/model-roi-duo-implementer.md}"

duo_preflight() {
  command -v git >/dev/null 2>&1 || die "git not found"
  [[ -d "${REPO_DIR}/.git" ]] || die "REPO_DIR is not a git repo: ${REPO_DIR}"
  [[ -f "${DUO_MANIFEST}" ]] || die "duo manifest not found: ${DUO_MANIFEST} (copy duo-candidates.tsv.example)"
  [[ -f "${DUO_PLANNER_PROMPT_FILE}" ]] || die "duo planner prompt not found: ${DUO_PLANNER_PROMPT_FILE}"
  [[ -f "${DUO_IMPLEMENTER_PROMPT_FILE}" ]] || die "duo implementer prompt not found: ${DUO_IMPLEMENTER_PROMPT_FILE}"
  mkdir -p "${RUNS_DIR}" "${WORKTREES_DIR}"
}

duo_platform_preflight() {
  local alias="$1" platform="$2"
  case "${platform}" in
    claude-code)
      command -v claude >/dev/null 2>&1 || die "${alias}: claude binary missing" ;;
    codex)
      command -v codex >/dev/null 2>&1 || die "${alias}: codex binary missing" ;;
    copilot)
      command -v copilot >/dev/null 2>&1 || die "${alias}: copilot binary missing"
      [[ -n "${COPILOT_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}" ]] \
        || die "${alias}: copilot auth heuristic missing (COPILOT_GITHUB_TOKEN/GH_TOKEN/GITHUB_TOKEN)" ;;
    cursor)
      command -v cursor-agent >/dev/null 2>&1 || die "${alias}: cursor-agent binary missing"
      [[ -n "${CURSOR_API_KEY:-}" ]] || cursor-agent status >/dev/null 2>&1 \
        || die "${alias}: cursor auth heuristic missing (CURSOR_API_KEY or cursor-agent login)" ;;
    gemini-cli)
      command -v gemini >/dev/null 2>&1 || die "${alias}: gemini binary missing" ;;
    *)
      die "${alias}: unsupported duo platform '${platform}'" ;;
  esac
}

duo_manifest_lookup() {
  local want="$1"
  local a platform planner_model planner_agent planner_effort planner_mech impl_model impl_agent impl_effort impl_mech stage
  [[ -f "${DUO_MANIFEST}" ]] || return 1
  while IFS=$'\t' read -r a platform planner_model planner_agent planner_effort planner_mech impl_model impl_agent impl_effort impl_mech stage; do
    [[ "${a}" =~ ^#.*$ || -z "${a}" ]] && continue
    if [[ "${a}" == "${want}" ]]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${platform}" "${planner_model}" "${planner_agent}" "${planner_effort:-default}" "${planner_mech:-none}" \
        "${impl_model}" "${impl_agent}" "${impl_effort:-default}" "${impl_mech:-none}" "${stage}"
      return 0
    fi
  done < "${DUO_MANIFEST}"
  return 1
}

render_duo_prompt() {
  local template="$1" phase="$2" task="$3" alias="$4" platform="$5" planner_model="$6" impl_model="$7" base_sha="$8" run_index="$9" outdir="${10}" plan_file="${11:-}"
  local task_file task_class base_branch candidate_branch task_body prompt_out
  task_file="$(task_file_path "${task}")"
  require_task_file "${task}"
  task_class="$(task_meta_value "${task_file}" task_class)"
  base_branch="$(task_meta_value "${task_file}" base_branch)"
  [[ -n "${base_branch}" ]] || base_branch="benchmark/model-roi/base-${task}-YYYYMMDD"
  candidate_branch="$(branch_name "${task}" "${alias}")-r${run_index}"
  task_body="$(task_candidate_body "${task_file}")"
  prompt_out="${outdir}/${phase}-prompt-rendered.md"

  {
    sed -n '1,$p' "${template}"
    printf '\n\n## Benchmark harness metadata\n\n'
    printf '```yaml\n'
    printf 'candidate_alias: %s\n' "${alias}"
    printf 'candidate_platform: %s\n' "${platform}"
    printf 'planner_model: %s\n' "${planner_model}"
    printf 'implementer_model: %s\n' "${impl_model}"
    printf 'task_id: %s\n' "${task}"
    printf 'task_class: %s\n' "${task_class}"
    printf 'base_branch: %s\n' "${base_branch}"
    printf 'base_sha: %s\n' "${base_sha}"
    printf 'run_index: %s\n' "${run_index}"
    printf 'candidate_branch: %s\n' "${candidate_branch}"
    printf 'subissue: %s\n' "${BENCHMARK_SUBISSUE}"
    printf '```\n\n'
    printf '## Task\n\n'
    printf '%s\n' "${task_body}"
    if [[ -n "${plan_file}" ]]; then
      printf '\n\n## Planner artifact\n\n'
      sed -n '1,$p' "${plan_file}"
      printf '\n'
    fi
  } > "${prompt_out}"

  if grep -F -q 'INJECTED PER ROUND' "${prompt_out}"; then
    die "rendered duo prompt still contains benchmark placeholder text: ${prompt_out}"
  fi
  printf '%s' "${prompt_out}"
}

extract_duo_plan() {
  local planner_outdir="$1" plan_file="$2" text_file
  text_file="${planner_outdir}/planner-output-text.txt"
  : > "${text_file}"

  if have_jq; then
    while IFS= read -r line; do
      if jq -e . >/dev/null 2>&1 <<<"${line}"; then
        jq -r '.. | strings' <<<"${line}" >> "${text_file}" 2>/dev/null || printf '%s\n' "${line}" >> "${text_file}"
      else
        printf '%s\n' "${line}" >> "${text_file}"
      fi
    done < "${planner_outdir}/agent-output.jsonl"
  else
    sed -n '1,$p' "${planner_outdir}/agent-output.jsonl" > "${text_file}"
  fi

  awk '
    /DUO_PLAN_START/ { emit = 1; print; next }
    /DUO_PLAN_END/ { if (emit) print; found = 1; emit = 0; next }
    emit { print }
    END { if (!found) exit 1 }
  ' "${text_file}" > "${plan_file}" || {
    {
      printf 'DUO_PLAN_START\n'
      printf 'planner_extraction_status: marker_not_found\n'
      printf 'planner_output_artifact: planner/planner-output-text.txt\n'
      printf 'note: The implementer should use the full planner output artifact because the planner did not emit the requested markers.\n'
      printf 'DUO_PLAN_END\n'
    } > "${plan_file}"
  }
}

TASK="" BASE_SHA="" ALIAS="" RUN_INDEX="1" KEEP_WT="0" RUN_CONTEXT_VARIANT="${CONTEXT_VARIANT}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task) TASK="$2"; shift 2;;
    --base) BASE_SHA="$2"; shift 2;;
    --alias) ALIAS="$2"; shift 2;;
    --run-index) RUN_INDEX="$2"; shift 2;;
    --keep-worktree) KEEP_WT="1"; shift;;
    --context-variant) RUN_CONTEXT_VARIANT="$2"; shift 2;;
    *) die "unknown arg: $1";;
  esac
done
[[ -n "${TASK}" && -n "${BASE_SHA}" && -n "${ALIAS}" ]] \
  || die "usage: --task <id> --base <sha> --alias <cand-NN-duo> [--run-index N] [--keep-worktree]"

duo_preflight
require_base "${BASE_SHA}"
require_task_file "${TASK}"

row="$(duo_manifest_lookup "${ALIAS}")" || die "duo alias not in manifest: ${ALIAS}"
IFS=$'\t' read -r PLATFORM PLANNER_MODEL PLANNER_AGENT PLANNER_EFFORT PLANNER_MECH IMPL_MODEL IMPL_AGENT IMPL_EFFORT IMPL_MECH STAGE <<<"${row}"
[[ "${STAGE}" == "1d" ]] || die "duo alias ${ALIAS} resolves to stage ${STAGE}; expected 1d"
log "duo candidate=${ALIAS} task=${TASK} run=${RUN_INDEX} platform=${PLATFORM} planner_effort=${PLANNER_EFFORT} implementer_effort=${IMPL_EFFORT} (models sealed)"
duo_platform_preflight "${ALIAS}" "${PLATFORM}"

ADAPTER="$(adapter_path "${PLATFORM}")"
[[ -f "${ADAPTER}" ]] || die "no adapter for platform '${PLATFORM}': ${ADAPTER}"
# shellcheck source=/dev/null
source "${ADAPTER}"

OUTDIR="$(run_outdir "${TASK}" "${ALIAS}" "${RUN_INDEX}")"
PLANNER_OUTDIR="${OUTDIR}/planner"
IMPL_OUTDIR="${OUTDIR}/implementer"
mkdir -p "${PLANNER_OUTDIR}/logs" "${IMPL_OUTDIR}/logs"
prepare_git_push_guard "${OUTDIR}"

RUN_CONTEXT_VARIANT="$(context_variant_slug "${RUN_CONTEXT_VARIANT}")"

PLANNER_WT="$(make_worktree "${TASK}" "${ALIAS}-planner" "${RUN_INDEX}" "${BASE_SHA}")"
log "planner worktree: ${PLANNER_WT}"
apply_context_variant "${PLANNER_WT}" "${PLANNER_OUTDIR}" "${RUN_CONTEXT_VARIANT}"
PLANNER_PROMPT="$(render_duo_prompt "${DUO_PLANNER_PROMPT_FILE}" "planner" "${TASK}" "${ALIAS}" "${PLATFORM}" "${PLANNER_MODEL}" "${IMPL_MODEL}" "${BASE_SHA}" "${RUN_INDEX}" "${PLANNER_OUTDIR}")"

DUO_START_EPOCH="$(date +%s)"
PLANNER_START_EPOCH="$(date +%s)"; PLANNER_START_TS="$(_ts)"
set +e
adapter_run "${PLANNER_WT}" "${PLANNER_MODEL}" "${PLANNER_PROMPT}" "${PLANNER_OUTDIR}" "${PLANNER_EFFORT}" "${PLANNER_MECH}"
PLANNER_RC=$?
set -e
PLANNER_END_EPOCH="$(date +%s)"; PLANNER_END_TS="$(_ts)"
PLANNER_WALL=$(( PLANNER_END_EPOCH - PLANNER_START_EPOCH ))
PLANNER_EFFORT_APPLIED="$(cat "${PLANNER_OUTDIR}/effort-applied.txt" 2>/dev/null || echo "unknown")"

if [[ ${PLANNER_RC} -ne 0 ]]; then
  write_result_file "${OUTDIR}" "${ALIAS}" "${TASK}" "${RUN_INDEX}" "${STAGE}" \
    "blocked" "" "${PLANNER_RC}" "true" "" "" ""
  log "blocked (${PLATFORM} planner): planner phase exited rc=${PLANNER_RC}. Worktree kept at ${PLANNER_WT}."
  exit 64
fi

PLAN_FILE="${PLANNER_OUTDIR}/plan.md"
extract_duo_plan "${PLANNER_OUTDIR}" "${PLAN_FILE}"
restore_context_variant "${PLANNER_WT}" "${PLANNER_OUTDIR}" "${RUN_CONTEXT_VARIANT}"
[[ "${KEEP_WT}" == "1" ]] || drop_worktree "${TASK}" "${ALIAS}-planner" "${RUN_INDEX}"

WT="$(make_worktree "${TASK}" "${ALIAS}" "${RUN_INDEX}" "${BASE_SHA}")"
log "implementer worktree: ${WT}"
apply_context_variant "${WT}" "${IMPL_OUTDIR}" "${RUN_CONTEXT_VARIANT}"
IMPL_PROMPT="$(render_duo_prompt "${DUO_IMPLEMENTER_PROMPT_FILE}" "implementer" "${TASK}" "${ALIAS}" "${PLATFORM}" "${PLANNER_MODEL}" "${IMPL_MODEL}" "${BASE_SHA}" "${RUN_INDEX}" "${IMPL_OUTDIR}" "${PLAN_FILE}")"

IMPL_START_EPOCH="$(date +%s)"; IMPL_START_TS="$(_ts)"
set +e
adapter_run "${WT}" "${IMPL_MODEL}" "${IMPL_PROMPT}" "${IMPL_OUTDIR}" "${IMPL_EFFORT}" "${IMPL_MECH}"
IMPL_RC=$?
set -e
IMPL_END_EPOCH="$(date +%s)"; IMPL_END_TS="$(_ts)"
IMPL_WALL=$(( IMPL_END_EPOCH - IMPL_START_EPOCH ))
DUO_END_EPOCH="$(date +%s)"
DUO_WALL=$(( DUO_END_EPOCH - DUO_START_EPOCH ))
IMPL_EFFORT_APPLIED="$(cat "${IMPL_OUTDIR}/effort-applied.txt" 2>/dev/null || echo "unknown")"

if [[ ${IMPL_RC} -ne 0 ]]; then
  HEAD_SHA="$(git -C "${WT}" rev-parse HEAD 2>/dev/null || echo "")"
  write_result_file "${OUTDIR}" "${ALIAS}" "${TASK}" "${RUN_INDEX}" "${STAGE}" \
    "blocked" "${HEAD_SHA}" "${IMPL_RC}" "true" "" "" ""
  log "blocked (${PLATFORM} implementer): implementer phase exited rc=${IMPL_RC}. Worktree kept at ${WT}."
  exit 64
fi

restore_context_variant "${WT}" "${IMPL_OUTDIR}" "${RUN_CONTEXT_VARIANT}"
HEAD_SHA="$(git -C "${WT}" rev-parse HEAD 2>/dev/null || echo "")"
COMMITTED_AHEAD="$(git -C "${WT}" rev-list --count "${BASE_SHA}..HEAD" 2>/dev/null || echo 0)"
git -C "${WT}" add -A 2>/dev/null || true
git -C "${WT}" diff --binary "${BASE_SHA}" > "${OUTDIR}/diff.patch" 2>/dev/null || true
DIFF_FILES="$(git -C "${WT}" diff --name-only "${BASE_SHA}" | wc -l | tr -d ' ')"
DIFF_LINES="$(git -C "${WT}" diff --shortstat "${BASE_SHA}" 2>/dev/null || echo '')"
WORK_PRODUCED=$([[ "${COMMITTED_AHEAD}" -gt 0 || "${DIFF_FILES}" -gt 0 ]] && echo true || echo false)

PLANNER_EFFORT_STATUS="$(derive_effort_status "${PLANNER_EFFORT}" "${PLANNER_MECH}" "${PLANNER_EFFORT_APPLIED}")"
IMPL_EFFORT_STATUS="$(derive_effort_status "${IMPL_EFFORT}" "${IMPL_MECH}" "${IMPL_EFFORT_APPLIED}")"

{
  printf '{\n'
  printf '  "alias": %s,\n' "$(json_escape "${ALIAS}")"
  printf '  "task_id": %s,\n' "$(json_escape "${TASK}")"
  printf '  "run_index": %s,\n' "${RUN_INDEX}"
  printf '  "stage": %s,\n' "$(json_escape "${STAGE}")"
  printf '  "workflow": "duo-planner-implementer",\n'
  printf '  "context_variant": %s,\n' "$(json_escape "${RUN_CONTEXT_VARIANT}")"
  printf '  "base_sha": %s,\n' "$(json_escape "${BASE_SHA}")"
  printf '  "head_sha": %s,\n' "$(json_escape "${HEAD_SHA}")"
  printf '  "planner_start_utc": %s,\n' "$(json_escape "${PLANNER_START_TS}")"
  printf '  "planner_end_utc": %s,\n' "$(json_escape "${PLANNER_END_TS}")"
  printf '  "planner_wall_clock_seconds": %s,\n' "${PLANNER_WALL}"
  printf '  "implementer_start_utc": %s,\n' "$(json_escape "${IMPL_START_TS}")"
  printf '  "implementer_end_utc": %s,\n' "$(json_escape "${IMPL_END_TS}")"
  printf '  "implementer_wall_clock_seconds": %s,\n' "${IMPL_WALL}"
  printf '  "wall_clock_seconds": %s,\n' "${DUO_WALL}"
  printf '  "planner_exit_code": %s,\n' "${PLANNER_RC}"
  printf '  "implementer_exit_code": %s,\n' "${IMPL_RC}"
  printf '  "commits_ahead_of_base": %s,\n' "${COMMITTED_AHEAD}"
  printf '  "diff_files_changed": %s,\n' "${DIFF_FILES}"
  printf '  "work_produced": %s,\n' "${WORK_PRODUCED}"
  printf '  "shortstat": %s,\n' "$(json_escape "${DIFF_LINES}")"
  printf '  "planner_plan_artifact": "planner/plan.md"\n'
  printf '}\n'
} > "${OUTDIR}/meta-blind.json"

{
  printf '{\n'
  printf '  "alias": %s,\n' "$(json_escape "${ALIAS}")"
  printf '  "platform": %s,\n' "$(json_escape "${PLATFORM}")"
  printf '  "planner_model": %s,\n' "$(json_escape "${PLANNER_MODEL}")"
  printf '  "planner_agent": %s,\n' "$(json_escape "${PLANNER_AGENT}")"
  printf '  "planner_effort_requested": %s,\n' "$(json_escape "${PLANNER_EFFORT}")"
  printf '  "planner_effort_mechanism": %s,\n' "$(json_escape "${PLANNER_MECH}")"
  printf '  "planner_effort_applied": %s,\n' "$(json_escape "${PLANNER_EFFORT_APPLIED}")"
  printf '  "planner_effort_status": %s,\n' "$(json_escape "${PLANNER_EFFORT_STATUS}")"
  printf '  "implementer_model": %s,\n' "$(json_escape "${IMPL_MODEL}")"
  printf '  "implementer_agent": %s,\n' "$(json_escape "${IMPL_AGENT}")"
  printf '  "implementer_effort_requested": %s,\n' "$(json_escape "${IMPL_EFFORT}")"
  printf '  "implementer_effort_mechanism": %s,\n' "$(json_escape "${IMPL_MECH}")"
  printf '  "implementer_effort_applied": %s,\n' "$(json_escape "${IMPL_EFFORT_APPLIED}")"
  printf '  "implementer_effort_status": %s,\n' "$(json_escape "${IMPL_EFFORT_STATUS}")"
  printf '  "task_id": %s,\n' "$(json_escape "${TASK}")"
  printf '  "run_index": %s,\n' "${RUN_INDEX}"
  printf '  "head_sha": %s,\n' "$(json_escape "${HEAD_SHA}")"
  printf '  "wall_clock_seconds": %s,\n' "${DUO_WALL}"
  printf '  "planner_wall_clock_seconds": %s,\n' "${PLANNER_WALL}"
  printf '  "implementer_wall_clock_seconds": %s,\n' "${IMPL_WALL}"
  printf '  "planner_exit_code": %s,\n' "${PLANNER_RC}"
  printf '  "implementer_exit_code": %s\n' "${IMPL_RC}"
  printf '}\n'
} > "${OUTDIR}/meta-sealed.json"

write_result_file "${OUTDIR}" "${ALIAS}" "${TASK}" "${RUN_INDEX}" "${STAGE}" \
  "graded" "${HEAD_SHA}" "${IMPL_RC}" "false" "meta-blind.json" "meta-sealed.json" "diff.patch"

log "captured duo: rc=${IMPL_RC} total_wall=${DUO_WALL}s planner=${PLANNER_WALL}s implementer=${IMPL_WALL}s files=${DIFF_FILES} work_produced=${WORK_PRODUCED}"
log "  plan   -> ${PLAN_FILE}"
log "  blind  -> ${OUTDIR}/meta-blind.json"
log "  sealed -> ${OUTDIR}/meta-sealed.json (do NOT show the grader)"
log "  diff   -> ${OUTDIR}/diff.patch"

[[ "${KEEP_WT}" == "1" ]] || drop_worktree "${TASK}" "${ALIAS}" "${RUN_INDEX}"
log "done duo: ${ALIAS} (r${RUN_INDEX})"
