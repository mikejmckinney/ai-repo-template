#!/usr/bin/env bash
# regrade-stage.sh — unified canonical regrade driver for all benchmark stages.
#
# Usage:
#   ./regrade-stage.sh <stage> prepare [score-set-id]
#   ./regrade-stage.sh <stage> status [score-set-id]
#   ./regrade-stage.sh <stage> record <grader-id> <responses-dir> [score-set-id]
#   ./regrade-stage.sh <stage> compile <grader-id> [score-set-id]
#   ./regrade-stage.sh <stage> grade [grader-id]
#   ./regrade-stage.sh <stage> all <grader-id> [responses-dir] [score-set-id]
#
# Stages: 1 | 1c | 1d | pipeline | 1e
#
# `grade` runs true LLM blind grading (subjective-prompt.md via cursor agent).
# Responses land in scripts/benchmark/stage-llm-responses-v1/ unless overridden.
#
# Environment:
#   SKIP_LEGACY_RESPONSES=1  skip legacy bootstrap during prepare (use fresh blind JSON)
#
# Stage 1E delegates to regrade-stage-1e.sh (per-RUN_GROUP score sets).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/benchmark/regrade-stage-lib.sh
source "${HERE}/regrade-stage-lib.sh"

usage() {
  sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

STAGE="${1:-}"
ACTION="${2:-}"
shift 2 || true

[[ -n "${STAGE}" && -n "${ACTION}" ]] || usage 2

if [[ "${STAGE}" == "1e" ]]; then
  exec "${HERE}/regrade-stage-1e.sh" "${ACTION}" "$@"
fi

regrade_load_config "${STAGE}"
regrade_parse_config

if [[ $# -ge 1 && ( "${ACTION}" == "prepare" || "${ACTION}" == "status" ) ]]; then
  SCORE_SET="$1"
  MANIFEST_DIR="${REPO_ROOT}/scripts/benchmark/grade-bundles/${SCORE_SET}-manifests"
  shift || true
fi

cmd_prepare_all() {
  regrade_extract_manifests
  for task in "${STAGE_TASKS[@]}"; do
    regrade_prepare_task "${task}"
  done
  regrade_bootstrap_responses
  echo ""
  echo "========== PREPARE complete (stage=${STAGE}) =========="
  echo "Manifests: ${MANIFEST_DIR#${REPO_ROOT}/}/"
  echo "Responses: scripts/benchmark/${RESPONSES_SUBDIR}/<task>/eval-NNN.json"
  echo "LLM blind-grade: ./regrade-stage.sh ${STAGE} grade [grader-id]  (then record + compile)"
}

cmd_status() {
  printf '%-48s %-12s %-12s %-12s\n' "TASK" "bundles" "subjective" "compiled"
  for task in "${STAGE_TASKS[@]}"; do
    root="${REPO_ROOT}/scripts/benchmark/grade-bundles/${task}/${SCORE_SET}"
    bundles=0 subj=0 compiled=no
    [[ -d "${root}" ]] && bundles=$(find "${root}" -maxdepth 1 -type d -name 'eval-*' 2>/dev/null | wc -l | tr -d ' ')
    [[ -d "${root}" ]] && subj=$(find "${root}" -name 'subjective-grade.*.json' 2>/dev/null | wc -l | tr -d ' ')
    [[ -f "${root}/final-grades.json" ]] && compiled=yes
    printf '%-48s %-12s %-12s %-12s\n' "${task}" "${bundles}" "${subj}" "${compiled}"
  done
}

cmd_record_all() {
  local grader_id="$1" responses_dir="$2"
  echo "========== RECORD grader=${grader_id} stage=${STAGE} =========="
  for task in "${STAGE_TASKS[@]}"; do
    echo "--- ${task} ---"
    regrade_record_task "${grader_id}" "${responses_dir}" "${task}"
  done
}

cmd_compile_all() {
  local grader_id="$1"
  echo "========== COMPILE grader=${grader_id} stage=${STAGE} =========="
  for task in "${STAGE_TASKS[@]}"; do
    echo "--- ${task} -> grade-bundles/${task}/${SCORE_SET}/final-grades.json ---"
    regrade_compile_task "${grader_id}" "${task}"
  done
  echo "========== COMPILE complete =========="
  cmd_status
}

case "${ACTION}" in
  prepare)
    cmd_prepare_all
    ;;
  status)
    cmd_status
    ;;
  grade)
    GRADER_ID="${1:-cursor-llm-blind-v1}"
    regrade_llm_grade_all "${GRADER_ID}"
    echo ""
    echo "========== GRADE complete (stage=${STAGE}) =========="
    echo "Next: ./regrade-stage.sh ${STAGE} record ${GRADER_ID} scripts/benchmark/$(regrade_llm_responses_subdir)"
    ;;
  record)
    [[ $# -ge 2 ]] || usage 2
    cmd_record_all "$1" "$2"
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
    GRADER_ID="$1"
    shift
    RESPONSES_IN="${1:-${RESPONSES_DIR}}"
    [[ $# -ge 1 ]] && shift || true
    cmd_prepare_all
    cmd_record_all "${GRADER_ID}" "${RESPONSES_IN}"
    cmd_compile_all "${GRADER_ID}"
    ;;
  help|-h|--help)
    usage 0
    ;;
  *)
    echo "error: unknown action: ${ACTION}" >&2
    usage 2
    ;;
esac
