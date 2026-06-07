#!/usr/bin/env bash
# regrade-stage-1.sh — canonical regrade for Stage 1 monolithic Class A/B rows in results.md.
#
# Usage:
#   ./regrade-stage-1.sh prepare [score-set-id]
#   ./regrade-stage-1.sh status [score-set-id]
#   ./regrade-stage-1.sh record <grader-id> <responses-dir> [score-set-id]
#   ./regrade-stage-1.sh compile <grader-id> [score-set-id]
#   ./regrade-stage-1.sh all <grader-id> [score-set-id]
#
# Source rows: .context/benchmarks/model-roi/results/agent-roi-benchmark-results.md
# (Class A/B monolithic tables only — not Stage 1C/1D/pipeline/1E).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

SCORE_SET="${SCORE_SET:-stage-1-canonical-v1}"
GRADER_ID_LEGACY="${GRADER_ID_LEGACY:-results-md-legacy-v1}"
MAKE="make -C scripts/benchmark"
MANIFEST_DIR="scripts/benchmark/grade-bundles/${SCORE_SET}-manifests"
RESPONSES_DIR="scripts/benchmark/stage-1-responses"
RESULTS_MD=".context/benchmarks/model-roi/results/agent-roi-benchmark-results.md"

STAGE_1_TASKS=(
  "opfit-281-class-a-premerge"
  "opfit-326-class-b-premerge"
)

usage() {
  sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

cmd_extract_manifests() {
  python3 scripts/benchmark/regrade-from-results-md.py extract \
    --results-md "${REPO_ROOT}/${RESULTS_MD}" \
    --out-dir "${REPO_ROOT}/${MANIFEST_DIR}"
}

cmd_prepare_task() {
  local task="$1"
  local manifest="${REPO_ROOT}/${MANIFEST_DIR}/${task}-manifest.tsv"
  [[ -f "${manifest}" ]] || cmd_extract_manifests
  echo "========== PREPARE ${task} score_set=${SCORE_SET} =========="
  MANIFEST="${manifest}" ${MAKE} grade-bundles TASK="${task}" SCORE_SET="${SCORE_SET}"
  ${MAKE} grade-objective TASK="${task}" SCORE_SET="${SCORE_SET}"
  ${MAKE} grade-subjective-prompts TASK="${task}" SCORE_SET="${SCORE_SET}"
}

cmd_prepare_all() {
  cmd_extract_manifests
  for task in "${STAGE_1_TASKS[@]}"; do
    cmd_prepare_task "${task}"
  done
  python3 scripts/benchmark/regrade-from-results-md.py responses \
    --results-md "${REPO_ROOT}/${RESULTS_MD}" \
    --score-set "${SCORE_SET}" \
    --grader-id "${GRADER_ID_LEGACY}" \
    --responses-dir "${REPO_ROOT}/${RESPONSES_DIR}"
  echo ""
  echo "========== PREPARE complete =========="
  echo "Manifests: ${MANIFEST_DIR}/"
  echo "Responses: ${RESPONSES_DIR}/<task>/eval-NNN.json"
}

cmd_status() {
  printf '%-36s %-12s %-12s %-12s\n' "TASK" "bundles" "subjective" "compiled"
  for task in "${STAGE_1_TASKS[@]}"; do
    local root="scripts/benchmark/grade-bundles/${task}/${SCORE_SET}"
    local bundles=0 subj=0 compiled=no
    [[ -d "${root}" ]] && bundles=$(find "${root}" -maxdepth 1 -type d -name 'eval-*' 2>/dev/null | wc -l | tr -d ' ')
    [[ -d "${root}" ]] && subj=$(find "${root}" -name 'subjective-grade.*.json' 2>/dev/null | wc -l | tr -d ' ')
    [[ -f "${root}/final-grades.json" ]] && compiled=yes
    printf '%-36s %-12s %-12s %-12s\n' "${task}" "${bundles}" "${subj}" "${compiled}"
  done
}

cmd_record_task() {
  local grader_id="$1" responses_dir="$2" task="$3"
  if [[ "${responses_dir}" != /* ]]; then
    responses_dir="${REPO_ROOT}/${responses_dir}"
  fi
  local group_dir="${responses_dir}/${task}"
  [[ -d "${group_dir}" ]] || { echo "warn: skip ${task} — no ${group_dir}" >&2; return 0; }
  for response in "${group_dir}"/eval-*.json; do
    [[ -f "${response}" ]] || continue
    eval_id="$(basename "${response}" .json)"
    echo "  record ${SCORE_SET}/${eval_id} <- ${response}"
    ${MAKE} grade-subjective-record \
      TASK="${task}" SCORE_SET="${SCORE_SET}" \
      EVAL_ID="${eval_id}" GRADER_ID="${grader_id}" RESPONSE="${response}"
  done
}

cmd_record_all() {
  local grader_id="$1" responses_dir="$2"
  echo "========== RECORD grader=${grader_id} =========="
  for task in "${STAGE_1_TASKS[@]}"; do
    echo "--- ${task} ---"
    cmd_record_task "${grader_id}" "${responses_dir}" "${task}"
  done
}

cmd_compile_all() {
  local grader_id="$1"
  echo "========== COMPILE grader=${grader_id} =========="
  for task in "${STAGE_1_TASKS[@]}"; do
    echo "--- ${task} -> scripts/benchmark/grade-bundles/${task}/${SCORE_SET}/final-grades.json ---"
    ${MAKE} grade-compile TASK="${task}" SCORE_SET="${SCORE_SET}" GRADER_ID="${grader_id}"
  done
  echo "========== COMPILE complete =========="
  cmd_status
}

ACTION="${1:-}"
shift || true

case "${ACTION}" in
  prepare)
    [[ $# -ge 1 ]] && SCORE_SET="$1"
    MANIFEST_DIR="scripts/benchmark/grade-bundles/${SCORE_SET}-manifests"
    cmd_prepare_all
    ;;
  status)
    [[ $# -ge 1 ]] && SCORE_SET="$1"
    cmd_status
    ;;
  record)
    [[ $# -ge 2 ]] || usage 2
    GRADER_ID="$1"
    RESPONSES_DIR="$2"
    shift 2
    [[ $# -ge 1 ]] && SCORE_SET="$1"
    cmd_record_all "${GRADER_ID}" "${RESPONSES_DIR}"
    ;;
  compile)
    [[ $# -ge 1 ]] || usage 2
    GRADER_ID="$1"
    shift
    [[ $# -ge 1 ]] && SCORE_SET="$1"
    cmd_compile_all "${GRADER_ID}"
    ;;
  all)
    [[ $# -ge 1 ]] || usage 2
    GRADER_ID="${1:-${GRADER_ID_LEGACY}}"
    shift
    [[ $# -ge 1 ]] && SCORE_SET="$1"
    MANIFEST_DIR="scripts/benchmark/grade-bundles/${SCORE_SET}-manifests"
    cmd_prepare_all
    cmd_record_all "${GRADER_ID}" "${RESPONSES_DIR}"
    cmd_compile_all "${GRADER_ID}"
    ;;
  help|-h|--help|"")
    usage 0
    ;;
  *)
    echo "error: unknown action: ${ACTION}" >&2
    usage 2
    ;;
esac
