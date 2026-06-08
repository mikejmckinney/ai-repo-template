#!/usr/bin/env bash
# run-duo-suite.sh - sequentially run Stage 1D duo benchmark candidates.

set -euo pipefail
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

DUO_MANIFEST="${DUO_MANIFEST:-${RUNNER_DIR}/duo-candidates.tsv}"

duo_suite_preflight() {
  command -v git >/dev/null 2>&1 || die "git not found"
  [[ -d "${REPO_DIR}/.git" ]] || die "REPO_DIR is not a git repo: ${REPO_DIR}"
  [[ -f "${DUO_MANIFEST}" ]] || die "duo manifest not found: ${DUO_MANIFEST} (copy duo-candidates.tsv.example)"
  mkdir -p "${RUNS_DIR}" "${WORKTREES_DIR}"
}

duo_manifest_aliases() {
  local filter_stage="${1:-}" a platform planner_model planner_agent planner_effort planner_mech impl_model impl_agent impl_effort impl_mech stage
  [[ -f "${DUO_MANIFEST}" ]] || die "duo manifest not found: ${DUO_MANIFEST} (copy duo-candidates.tsv.example)"
  # shellcheck disable=SC2034  # manifest columns parsed for forward compatibility; only alias + stage used here
  while IFS=$'\t' read -r a platform planner_model planner_agent planner_effort planner_mech impl_model impl_agent impl_effort impl_mech stage; do
    [[ "${a}" =~ ^#.*$ || -z "${a}" ]] && continue
    if [[ -z "${filter_stage}" || "${stage}" == "${filter_stage}" ]]; then
      printf '%s\n' "${a}"
    fi
  done <"${DUO_MANIFEST}"
}

TASK="" BASE_SHA="" STAGE="" RUN_INDEX="1" CONT="0" RESUME="0" RUN_CONTEXT_VARIANT="${CONTEXT_VARIANT}"
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
    --stage)
      STAGE="$2"
      shift 2
      ;;
    --run-index)
      RUN_INDEX="$2"
      shift 2
      ;;
    --continue-on-error)
      CONT="1"
      shift
      ;;
    --resume)
      RESUME="1"
      shift
      ;;
    --context-variant)
      RUN_CONTEXT_VARIANT="$2"
      shift 2
      ;;
    *) die "unknown arg: $1" ;;
  esac
done
[[ -n "${TASK}" && -n "${BASE_SHA}" && -n "${STAGE}" ]] \
  || die "usage: --task <id> --base <sha> --stage 1d [--run-index N] [--continue-on-error] [--resume]"
[[ "${STAGE}" == "1d" ]] || die "duo suite requires STAGE=1d"

duo_suite_preflight
require_base "${BASE_SHA}"
require_task_file "${TASK}"
RUN_CONTEXT_VARIANT="$(context_variant_slug "${RUN_CONTEXT_VARIANT}")"

alias_set_file="${RUNS_DIR}/${TASK}/stage-${STAGE}-duo-aliases.txt"
manifest_snapshot="${RUNS_DIR}/${TASK}/stage-${STAGE}-duo-manifest.tsv"
if [[ "${RESUME}" == "1" ]]; then
  [[ -f "${alias_set_file}" ]] || die "cannot resume: no recorded duo alias set: ${alias_set_file}"
  [[ -f "${manifest_snapshot}" ]] || die "cannot resume: no recorded duo manifest snapshot: ${manifest_snapshot}"
  mapfile -t ALIASES <"${alias_set_file}"
  log "duo resume: using recorded alias set -> ${alias_set_file}"
else
  mapfile -t ALIASES < <(duo_manifest_aliases "${STAGE}")
  [[ ! -e "${alias_set_file}" && ! -e "${manifest_snapshot}" ]] \
    || die "duo suite identity already exists for task=${TASK} stage=${STAGE}; choose a fresh TASK or remove prior run artifacts"
  mkdir -p "$(dirname "${alias_set_file}")"
  printf '%s\n' "${ALIASES[@]}" >"${alias_set_file}"
  cp "${DUO_MANIFEST}" "${manifest_snapshot}"
  log "recorded duo alias set -> ${alias_set_file}"
  log "recorded duo manifest snapshot -> ${manifest_snapshot}"
fi
[[ "${#ALIASES[@]}" -gt 0 ]] || die "no duo candidates for stage='${STAGE}'"

log "duo suite: task=${TASK} stage=${STAGE} candidates=${#ALIASES[@]} run-index=${RUN_INDEX} context_variant=${RUN_CONTEXT_VARIANT}"
declare -a CAPTURED=() FAIL=() BLOCKED=() SKIPPED=()

for alias in "${ALIASES[@]}"; do
  if [[ "${RESUME}" == "1" ]]; then
    mapfile -t existing_results < <(find "${RUNS_DIR}/${TASK}/${alias}" -name result.json 2>/dev/null | sort)
    if [[ "${#existing_results[@]}" -gt 0 ]]; then
      SKIPPED+=("${alias}")
      log "skip: ${alias} already has terminal result (${existing_results[0]})"
      continue
    fi
  fi
  log "---- ${alias} ----"
  set +e
  BENCHMARK_DOCTOR_DONE=1 "${RUNNER_DIR}/run-duo-candidate.sh" --task "${TASK}" --base "${BASE_SHA}" \
    --alias "${alias}" --run-index "${RUN_INDEX}" --context-variant "${RUN_CONTEXT_VARIANT}"
  rc=$?
  set -e
  case ${rc} in
    0) CAPTURED+=("${alias}") ;;
    64)
      BLOCKED+=("${alias}")
      log "BLOCKED (documented duo failure): ${alias}"
      ;;
    *)
      FAIL+=("${alias}")
      log "duo adapter error rc=${rc}: ${alias}"
      [[ "${CONT}" == "1" ]] || die "stopping (use --continue-on-error to keep going)"
      ;;
  esac
done

log "==== duo suite summary ===="
log "  captured  : ${CAPTURED[*]:-none}"
log "  skipped   : ${SKIPPED[*]:-none}"
log "  blocked   : ${BLOCKED[*]:-none}"
log "  errored   : ${FAIL[*]:-none}"
