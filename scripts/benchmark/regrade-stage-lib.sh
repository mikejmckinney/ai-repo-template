#!/usr/bin/env bash
# regrade-stage-lib.sh — shared config and helpers for canonical stage regrades.
# Sourced by regrade-stage.sh (not executed directly).

set -euo pipefail

regrade_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

# stage_id -> config (tab-separated fields)
# Fields: score_set|stage_flag|grader_legacy|responses_subdir|rubric_rel|tasks_csv|mode
# mode: simple | stage1e
REGRADE_STAGE_CONFIG_simple_1() {
  printf '%s' "stage-1-canonical-v1|1|results-md-legacy-v1|stage-1-responses||opfit-281-class-a-premerge,opfit-326-class-b-premerge|simple"
}
REGRADE_STAGE_CONFIG_simple_1c() {
  printf '%s' "stage-1c-canonical-v1|1c|results-md-legacy-v1|stage-1c-responses||opfit-281-class-a-premerge-context-injected,opfit-326-class-b-premerge-context-injected|simple"
}
REGRADE_STAGE_CONFIG_simple_1d() {
  printf '%s' "stage-1d-canonical-v1|1d|results-md-legacy-v1|stage-1d-responses||opfit-281-class-a-premerge,opfit-326-class-b-premerge|simple"
}
REGRADE_STAGE_CONFIG_simple_pipeline() {
  printf '%s' "stage-1-pipeline-canonical-v1|pipeline|results-md-legacy-v1|stage-1-pipeline-responses|../../.context/benchmarks/model-roi/grading/rubric.pipeline.v1.json|opfit-281-class-a-premerge-pipeline,opfit-326-class-b-premerge-pipeline|simple"
}
REGRADE_STAGE_CONFIG_stage1e_1e() {
  printf '%s' "stage-1e-canonical-v1|1e|results-md-legacy-v1|stage-1e-responses||ctx-a-baseline:opfit-281-class-a-premerge,ctx-a-core-min:opfit-281-class-a-premerge,ctx-a-class-a-process:opfit-281-class-a-premerge,ctx-a-full-rules:opfit-281-class-a-premerge,ctx-b-baseline:opfit-326-class-b-premerge,ctx-b-core-min:opfit-326-class-b-premerge,ctx-b-class-b-implementation:opfit-326-class-b-premerge,ctx-b-full-rules:opfit-326-class-b-premerge|stage1e"
}

regrade_load_config() {
  local stage="$1"
  local fn="REGRADE_STAGE_CONFIG_simple_${stage}"
  if declare -f "$fn" >/dev/null 2>&1; then
    REGRADE_CFG="$("$fn")"
    return 0
  fi
  fn="REGRADE_STAGE_CONFIG_stage1e_${stage}"
  if declare -f "$fn" >/dev/null 2>&1; then
    REGRADE_CFG="$("$fn")"
    return 0
  fi
  echo "error: unknown stage: ${stage} (expected: 1, 1c, 1d, pipeline, 1e)" >&2
  return 2
}

regrade_parse_config() {
  IFS='|' read -r SCORE_SET STAGE_FLAG GRADER_ID_LEGACY RESPONSES_SUBDIR RUBRIC_FILE TASKS_CSV MODE <<<"${REGRADE_CFG}"
  REPO_ROOT="$(regrade_repo_root)"
  MAKE="make -C ${REPO_ROOT}/scripts/benchmark"
  RESULTS_MD="${REPO_ROOT}/.context/benchmarks/model-roi/results/agent-roi-benchmark-results.md"
  RESPONSES_DIR="${REPO_ROOT}/scripts/benchmark/${RESPONSES_SUBDIR}"
  MANIFEST_DIR="${REPO_ROOT}/scripts/benchmark/grade-bundles/${SCORE_SET}-manifests"
  # shellcheck disable=SC2034  # STAGE_TASKS consumed by regrade-stage.sh after init
  IFS=',' read -ra STAGE_TASKS <<<"${TASKS_CSV}"
}

regrade_score_set_for_group() {
  if [[ "${MODE}" == "stage1e" ]]; then
    printf '%s-%s' "${SCORE_SET_PREFIX:-${SCORE_SET}}" "$1"
  else
    printf '%s' "${SCORE_SET}"
  fi
}

regrade_extract_manifests() {
  if [[ "${MODE}" == "stage1e" ]]; then
    return 0
  fi
  python3 "${REPO_ROOT}/scripts/benchmark/regrade-from-results-md.py" extract \
    --stage "${STAGE_FLAG}" \
    --results-md "${RESULTS_MD}" \
    --out-dir "${MANIFEST_DIR}"
}

regrade_prepare_task() {
  local task="$1"
  local score_set="${2:-${SCORE_SET}}"
  local manifest="${MANIFEST_DIR}/${task}-manifest.tsv"
  [[ -f "${manifest}" ]] || regrade_extract_manifests
  echo "========== PREPARE ${task} score_set=${score_set} =========="
  MANIFEST="${manifest}" ${MAKE} grade-bundles TASK="${task}" SCORE_SET="${score_set}"
  if [[ -n "${RUBRIC_FILE}" ]]; then
    RUBRIC="${RUBRIC_FILE}" ${MAKE} grade-objective TASK="${task}" SCORE_SET="${score_set}"
  else
    ${MAKE} grade-objective TASK="${task}" SCORE_SET="${score_set}"
  fi
  ${MAKE} grade-subjective-prompts TASK="${task}" SCORE_SET="${score_set}"
}

regrade_bootstrap_responses() {
  if [[ "${SKIP_LEGACY_RESPONSES:-}" == "1" ]]; then
    echo "Skipping legacy subjective bootstrap (SKIP_LEGACY_RESPONSES=1)"
    return 0
  fi
  python3 "${REPO_ROOT}/scripts/benchmark/regrade-from-results-md.py" responses \
    --stage "${STAGE_FLAG}" \
    --results-md "${RESULTS_MD}" \
    --score-set "${SCORE_SET}" \
    --grader-id "${GRADER_ID_LEGACY}" \
    --responses-dir "${RESPONSES_DIR}"
}

regrade_record_task() {
  local grader_id="$1" responses_dir="$2" task="$3" score_set="${4:-${SCORE_SET}}"
  if [[ "${responses_dir}" != /* ]]; then
    responses_dir="${REPO_ROOT}/${responses_dir}"
  fi
  local group_dir="${responses_dir}/${task}"
  [[ -d "${group_dir}" ]] || { echo "warn: skip ${task} — no ${group_dir}" >&2; return 0; }
  for response in "${group_dir}"/eval-*.json; do
    [[ -f "${response}" ]] || continue
    eval_id="$(basename "${response}" .json)"
    echo "  record ${score_set}/${eval_id} <- ${response}"
    ${MAKE} grade-subjective-record \
      TASK="${task}" SCORE_SET="${score_set}" \
      EVAL_ID="${eval_id}" GRADER_ID="${grader_id}" RESPONSE="${response}"
  done
}

regrade_compile_task() {
  local grader_id="$1" task="$2" score_set="${3:-${SCORE_SET}}"
  ${MAKE} grade-compile TASK="${task}" SCORE_SET="${score_set}" GRADER_ID="${grader_id}"
}

regrade_llm_responses_subdir() {
  if [[ "${STAGE}" == "1" ]]; then
    printf '%s' "stage-1-llm-responses-v1"
  else
    printf '%s' "stage-llm-responses-v1"
  fi
}

regrade_llm_grade_all() {
  local grader_id="${1:-cursor-llm-blind-v1}"
  local extra=()
  [[ "${BLIND_GRADE_HEURISTIC:-}" == "1" ]] && extra+=(--heuristic)
  [[ -n "${BLIND_GRADE_MODEL:-}" ]] && extra+=(--model "${BLIND_GRADE_MODEL}")
  [[ "${BLIND_GRADE_SKIP_EXISTING:-}" == "1" ]] && extra+=(--skip-existing)
  python3 "${REPO_ROOT}/scripts/benchmark/blind_grade_stage.py" \
    --stage "${STAGE}" \
    --grader-id "${grader_id}" \
    "${extra[@]}"
}
