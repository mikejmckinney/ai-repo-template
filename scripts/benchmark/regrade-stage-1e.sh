#!/usr/bin/env bash
# regrade-stage-1e.sh — canonical regrade helper for Stage 1E CP-1 context-pack screen.
#
# Automates prepare-grade-bundle → grade-objective → grade-subjective-prompts for
# all eight Stage 1E RUN_GROUPs (issue #378). Subjective JSON grading still requires
# a human or locked LLM grader; this script records/compiles once responses exist.
#
# Usage:
#   ./regrade-stage-1e.sh prepare [score-set-prefix]
#   ./regrade-stage-1e.sh status [score-set-prefix]
#   ./regrade-stage-1e.sh grade [grader-id]
#   ./regrade-stage-1e.sh record <grader-id> <responses-dir> [score-set-prefix]
#   ./regrade-stage-1e.sh compile <grader-id> [score-set-prefix]
#   ./regrade-stage-1e.sh all <grader-id> <responses-dir> [score-set-prefix]
#
# score-set-prefix defaults to: stage-1e-canonical-v1
# Per-group score set id:        <prefix>-<run-group>  (e.g. stage-1e-canonical-v1-ctx-b-baseline)
#
# responses-dir layout (one JSON per eval):
#   <responses-dir>/ctx-a-baseline/eval-001.json
#   <responses-dir>/ctx-a-baseline/eval-002.json
#   <responses-dir>/ctx-b-core-min/eval-001.json
#   ...
#
# See: .context/benchmarks/model-roi/benchmark-runbook.md § "Regrade Stage 1E (CP-1)"

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

SCORE_SET_PREFIX="${SCORE_SET_PREFIX:-stage-1e-canonical-v1}"
MAKE="make -C scripts/benchmark"

# run_group:task pairs (order matches CP-1 matrix in benchmark-runbook.md)
STAGE_1E_GROUPS=(
  "ctx-a-baseline:opfit-281-class-a-premerge"
  "ctx-a-core-min:opfit-281-class-a-premerge"
  "ctx-a-class-a-process:opfit-281-class-a-premerge"
  "ctx-a-full-rules:opfit-281-class-a-premerge"
  "ctx-b-baseline:opfit-326-class-b-premerge"
  "ctx-b-core-min:opfit-326-class-b-premerge"
  "ctx-b-class-b-implementation:opfit-326-class-b-premerge"
  "ctx-b-full-rules:opfit-326-class-b-premerge"
)

usage() {
  sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

score_set_for() {
  printf '%s-%s' "${SCORE_SET_PREFIX}" "$1"
}

bundle_root() {
  printf 'scripts/benchmark/grade-bundles/%s/%s' "$2" "$(score_set_for "$1")"
}

parse_group_entry() {
  RUN_GROUP="${1%%:*}"
  TASK="${1##*:}"
  SCORE_SET="$(score_set_for "${RUN_GROUP}")"
}

require_runs() {
  local runs_base="scripts/benchmark/runs/${TASK}/groups/${RUN_GROUP}"
  if [[ ! -d "${runs_base}" ]]; then
    echo "error: missing run artifacts: ${runs_base}" >&2
    echo "       run CP-1 suites first (see run-stage-1e-cp1.sh)" >&2
    exit 2
  fi
}

cmd_prepare_group() {
  parse_group_entry "$1"
  require_runs
  echo "========== PREPARE ${RUN_GROUP} task=${TASK} score_set=${SCORE_SET} =========="
  RUN_GROUP="${RUN_GROUP}" ${MAKE} grade-bundles TASK="${TASK}" STAGE=1 SCORE_SET="${SCORE_SET}"
  ${MAKE} grade-objective TASK="${TASK}" SCORE_SET="${SCORE_SET}"
  ${MAKE} grade-subjective-prompts TASK="${TASK}" SCORE_SET="${SCORE_SET}"
}

cmd_prepare_all() {
  local manifest="scripts/benchmark/grade-bundles/stage-1e-regrade-manifest.txt"
  mkdir -p scripts/benchmark/grade-bundles
  {
    echo "# Stage 1E regrade manifest"
    echo "# score_set_prefix: ${SCORE_SET_PREFIX}"
    echo "# grader_prompt: .github/prompts/model-roi-grader-v1.md"
    echo "# rubric: rubric.v1"
    echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "#"
    echo "# Next: run subjective grader on each subjective-prompt.md; save JSON as:"
    echo "#   <responses-dir>/<run_group>/eval-00N.json"
    echo "# Then: ./regrade-stage-1e.sh record <grader-id> <responses-dir>"
    echo "#       ./regrade-stage-1e.sh compile <grader-id>"
    echo ""
    printf '%s\t%s\t%s\t%s\n' "run_group" "task" "score_set_id" "subjective_prompt"
  } >"${manifest}"

  for entry in "${STAGE_1E_GROUPS[@]}"; do
    cmd_prepare_group "${entry}"
    parse_group_entry "${entry}"
    local root
    root="$(bundle_root "${RUN_GROUP}" "${TASK}")"
    for prompt in "${root}"/eval-*/subjective-prompt.md; do
      [[ -f "${prompt}" ]] || continue
      eval_id="$(basename "$(dirname "${prompt}")")"
      printf '%s\t%s\t%s\t%s\n' \
        "${RUN_GROUP}" "${TASK}" "${SCORE_SET}" "${prompt}" >>"${manifest}"
    done
  done

  echo ""
  echo "========== PREPARE complete =========="
  echo "Manifest: ${manifest}"
  echo "Subjective prompts listed in manifest — grade with model-roi-grader-v1.md (JSON only)."
}

cmd_status() {
  printf '%-32s %-36s %-12s %-12s %-12s\n' "RUN_GROUP" "SCORE_SET" "bundles" "subjective" "compiled"
  for entry in "${STAGE_1E_GROUPS[@]}"; do
    parse_group_entry "${entry}"
    local root bundles subj compiled
    root="$(bundle_root "${RUN_GROUP}" "${TASK}")"
    bundles=0
    subj=0
    compiled=0
    [[ -d "${root}" ]] && bundles=$(find "${root}" -maxdepth 1 -type d -name 'eval-*' 2>/dev/null | wc -l | tr -d ' ')
    [[ -d "${root}" ]] && subj=$(find "${root}" -name 'subjective-grade.*.json' 2>/dev/null | wc -l | tr -d ' ')
    [[ -f "${root}/final-grades.json" ]] && compiled=1
    printf '%-32s %-36s %-12s %-12s %-12s\n' \
      "${RUN_GROUP}" "${SCORE_SET}" "${bundles}" "${subj}" "$([[ ${compiled} -eq 1 ]] && echo yes || echo no)"
  done
}

cmd_record_group() {
  local grader_id="$1" responses_dir="$2" entry="$3"
  parse_group_entry "${entry}"
  # Make runs from scripts/benchmark — pass absolute response paths.
  if [[ "${responses_dir}" != /* ]]; then
    responses_dir="${REPO_ROOT}/${responses_dir}"
  fi
  local group_dir="${responses_dir}/${RUN_GROUP}"
  if [[ ! -d "${group_dir}" ]]; then
    echo "warn: skip ${RUN_GROUP} — no ${group_dir}" >&2
    return 0
  fi
  for response in "${group_dir}"/eval-*.json; do
    [[ -f "${response}" ]] || continue
    eval_id="$(basename "${response}" .json)"
    echo "  record ${SCORE_SET}/${eval_id} <- ${response}"
    ${MAKE} grade-subjective-record \
      TASK="${TASK}" SCORE_SET="${SCORE_SET}" \
      EVAL_ID="${eval_id}" GRADER_ID="${grader_id}" RESPONSE="${response}"
  done
}

cmd_record_all() {
  local grader_id="$1" responses_dir="$2"
  [[ -d "${responses_dir}" ]] || {
    echo "error: responses dir not found: ${responses_dir}" >&2
    exit 2
  }
  echo "========== RECORD grader=${grader_id} dir=${responses_dir} =========="
  for entry in "${STAGE_1E_GROUPS[@]}"; do
    parse_group_entry "${entry}"
    echo "--- ${RUN_GROUP} ---"
    cmd_record_group "${grader_id}" "${responses_dir}" "${entry}"
  done
}

cmd_grade_all() {
  local grader_id="${1:-cursor-llm-blind-v1}"
  local extra=()
  [[ "${BLIND_GRADE_HEURISTIC:-}" == "1" ]] && extra+=(--heuristic)
  [[ -n "${BLIND_GRADE_MODEL:-}" ]] && extra+=(--model "${BLIND_GRADE_MODEL}")
  [[ "${BLIND_GRADE_SKIP_EXISTING:-}" == "1" ]] && extra+=(--skip-existing)
  python3 scripts/benchmark/blind_grade_stage.py \
    --stage 1e \
    --grader-id "${grader_id}" \
    "${extra[@]}"
  echo ""
  echo "========== GRADE complete (stage=1e) =========="
  echo "Next: ./regrade-stage-1e.sh record ${grader_id} scripts/benchmark/stage-1e-llm-responses-v1"
}

cmd_compile_all() {
  local grader_id="$1"
  echo "========== COMPILE grader=${grader_id} =========="
  for entry in "${STAGE_1E_GROUPS[@]}"; do
    parse_group_entry "${entry}"
    local root
    root="$(bundle_root "${RUN_GROUP}" "${TASK}")"
    if [[ ! -d "${root}" ]]; then
      echo "warn: skip compile ${RUN_GROUP} — no bundles at ${root}" >&2
      continue
    fi
    echo "--- ${RUN_GROUP} -> ${root}/final-grades.json ---"
    ${MAKE} grade-compile TASK="${TASK}" SCORE_SET="${SCORE_SET}" GRADER_ID="${grader_id}"
  done
  echo "========== COMPILE complete =========="
  cmd_status
}

# ---- main -------------------------------------------------------------------

ACTION="${1:-}"
shift || true

case "${ACTION}" in
  prepare)
    [[ $# -ge 1 ]] && SCORE_SET_PREFIX="$1"
    cmd_prepare_all
    ;;
  status)
    [[ $# -ge 1 ]] && SCORE_SET_PREFIX="$1"
    cmd_status
    ;;
  grade)
    GRADER_ID="${1:-cursor-llm-blind-v1}"
    cmd_grade_all "${GRADER_ID}"
    ;;
  record)
    [[ $# -ge 2 ]] || usage 2
    GRADER_ID="$1"
    RESPONSES_DIR="$2"
    shift 2
    [[ $# -ge 1 ]] && SCORE_SET_PREFIX="$1"
    cmd_record_all "${GRADER_ID}" "${RESPONSES_DIR}"
    ;;
  compile)
    [[ $# -ge 1 ]] || usage 2
    GRADER_ID="$1"
    shift
    [[ $# -ge 1 ]] && SCORE_SET_PREFIX="$1"
    cmd_compile_all "${GRADER_ID}"
    ;;
  all)
    [[ $# -ge 2 ]] || usage 2
    GRADER_ID="$1"
    RESPONSES_DIR="$2"
    shift 2
    [[ $# -ge 1 ]] && SCORE_SET_PREFIX="$1"
    cmd_prepare_all
    cmd_record_all "${GRADER_ID}" "${RESPONSES_DIR}"
    cmd_compile_all "${GRADER_ID}"
    ;;
  help | -h | --help | "")
    usage 0
    ;;
  *)
    echo "error: unknown action: ${ACTION}" >&2
    usage 2
    ;;
esac
