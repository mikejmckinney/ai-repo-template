#!/usr/bin/env bash
# prepare-grade-bundle.sh — create blinded grading bundles for a task/score-set.
#
# Usage:
#   ./prepare-grade-bundle.sh --task <id> --score-set <id> [--stage 1] [--run-group G] [--run-index N]
#   ./prepare-grade-bundle.sh ... --manifest <alias-run.tsv>
#
# Manifest TSV (header optional): alias<TAB>run_index — limits bundles to scored rows only.

set -euo pipefail
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TASK="" STAGE="1" SCORE_SET="" RUN_INDEX_FILTER="" MANIFEST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task) TASK="$2"; shift 2;;
    --stage) STAGE="$2"; shift 2;;
    --score-set) SCORE_SET="$2"; shift 2;;
    --run-group) RUN_GROUP="$2"; shift 2;;
    --run-index) RUN_INDEX_FILTER="$2"; shift 2;;
    --manifest) MANIFEST="$2"; shift 2;;
    *) die "unknown arg: $1";;
  esac
done
[[ -n "${TASK}" && -n "${SCORE_SET}" ]] \
  || die "usage: --task <id> --score-set <id> [--stage 1] [--run-group G] [--run-index N]"
have_jq || die "prepare-grade-bundle.sh needs jq"

BUNDLE_ROOT="${RUNNER_DIR}/grade-bundles/${TASK}/${SCORE_SET}"
SEALED_MAP="${BUNDLE_ROOT}/sealed-eval-map.tsv"
GRADE_SET_JSON="${BUNDLE_ROOT}/grade-set.json"
TASK_MD="${REPO_DIR}/.context/benchmarks/model-roi/tasks/${TASK}.md"
[[ -f "${TASK_MD}" ]] || die "task file missing: ${TASK_MD}"

runs_base="$(runs_task_base "${TASK}")"
[[ -d "${runs_base}" ]] || die "no runs at ${runs_base}"

declare -A MANIFEST_KEYS=()
if [[ -n "${MANIFEST}" ]]; then
  [[ -f "${MANIFEST}" ]] || die "manifest not found: ${MANIFEST}"
  while IFS=$'\t' read -r m_alias m_run _rest; do
    [[ -z "${m_alias}" || "${m_alias}" == \#* || "${m_alias}" == alias ]] && continue
    MANIFEST_KEYS["${m_alias}-r${m_run}"]=1
  done < "${MANIFEST}"
  [[ "${#MANIFEST_KEYS[@]}" -gt 0 ]] || die "manifest has no rows: ${MANIFEST}"
fi

declare -a CANDIDATE_DIRS=()
while IFS= read -r result; do
  [[ -n "${result}" ]] || continue
  d="$(dirname "${result}")"
  alias="$(jq -r '.alias // "unknown"' "${d}/meta-blind.json" 2>/dev/null || echo unknown)"
  ri="$(jq -r '.run_index' "${d}/meta-blind.json" 2>/dev/null || echo "")"
  if [[ -n "${RUN_INDEX_FILTER}" ]]; then
    [[ "${ri}" == "${RUN_INDEX_FILTER}" ]] || continue
  fi
  if [[ "${#MANIFEST_KEYS[@]}" -gt 0 ]]; then
    [[ -n "${MANIFEST_KEYS[${alias}-r${ri}]+x}" ]] || continue
  fi
  CANDIDATE_DIRS+=("${d}")
done < <(find "${runs_base}" -name result.json 2>/dev/null | sort)

[[ "${#CANDIDATE_DIRS[@]}" -gt 0 ]] || die "no candidate runs found under ${runs_base}"

# Deterministic order: alias + run_index (from sealed if present, else blind)
declare -a SORT_KEYS=()
declare -a SORT_DIRS=()
for d in "${CANDIDATE_DIRS[@]}"; do
  alias="$(jq -r '.alias // "unknown"' "${d}/meta-sealed.json" 2>/dev/null || jq -r '.alias // "unknown"' "${d}/meta-blind.json")"
  ri="$(jq -r '.run_index // 0' "${d}/meta-blind.json" 2>/dev/null || echo 0)"
  SORT_KEYS+=("${alias}-r${ri}")
  SORT_DIRS+=("${d}")
done

# Simple deterministic sort by key
mapfile -t ORDERED < <(printf '%s\n' "${SORT_KEYS[@]}" | awk '{print NR-1 "|" $0}' | sort -t'|' -k2,2 | cut -d'|' -f1)
declare -a ORDERED_DIRS=()
for idx in "${ORDERED[@]}"; do
  ORDERED_DIRS+=("${SORT_DIRS[$idx]}")
done

# Build context_condition map from unique variants (sealed preferred)
declare -A VARIANT_TO_COND=()
cond_n=0
for d in "${ORDERED_DIRS[@]}"; do
  variant="baseline"
  if [[ -f "${d}/meta-sealed.json" ]]; then
    variant="$(jq -r '.context_variant // "baseline"' "${d}/meta-sealed.json")"
  elif [[ -f "${d}/meta-blind.json" ]]; then
    variant="$(jq -r '.context_variant // "baseline"' "${d}/meta-blind.json")"
  fi
  if [[ -z "${VARIANT_TO_COND[$variant]+x}" ]]; then
    cond_n=$((cond_n + 1))
    VARIANT_TO_COND["${variant}"]="$(printf 'cond-%03d' "${cond_n}")"
  fi
done

mkdir -p "${BUNDLE_ROOT}"
BUNDLE_SEED="$(printf '%s|%s|%s' "${TASK}" "${SCORE_SET}" "${RUN_GROUP:-}")"
printf '# SEALED — do not show to graders\neval_candidate_id\ttask_id\talias\trun_index\trun_group\tcontext_condition\tcontext_variant\tcontext_pack_id\tartifact_dir\tsealed_candidate_key\n' > "${SEALED_MAP}"

eval_n=0
for d in "${ORDERED_DIRS[@]}"; do
  eval_n=$((eval_n + 1))
  eval_id="$(printf 'eval-%03d' "${eval_n}")"
  bundle_dir="${BUNDLE_ROOT}/${eval_id}"
  mkdir -p "${bundle_dir}/verification"

  alias="$(jq -r '.alias' "${d}/meta-blind.json")"
  ri="$(jq -r '.run_index' "${d}/meta-blind.json")"
  variant="$(jq -r '.context_variant // "baseline"' "${d}/meta-sealed.json" 2>/dev/null || jq -r '.context_variant // "baseline"' "${d}/meta-blind.json")"
  cond="${VARIANT_TO_COND[$variant]}"
  pack_id=""
  [[ "${variant}" == pack:* ]] && pack_id="${variant#pack:}"
  rg="${RUN_GROUP:-}"
  sealed_key="${alias}-r${ri}"

  # Sanitized blind metadata (no variant/orchestration/alias leakage to grader)
  jq -n \
    --arg eval_id "${eval_id}" \
    --arg task "${TASK}" \
    --arg stage "${STAGE}" \
    --arg cond "${cond}" \
    --arg base "$(jq -r '.base_sha // ""' "${d}/meta-blind.json")" \
    --argjson wall "$(jq '.wall_clock_seconds // 0' "${d}/meta-blind.json")" \
    --argjson rc "$(jq '.adapter_exit_code // 0' "${d}/meta-blind.json")" \
    --argjson files "$(jq '.diff_files_changed // 0' "${d}/meta-blind.json")" \
    --argjson work "$(jq '.work_produced // false' "${d}/meta-blind.json")" \
    '{
      eval_candidate_id: $eval_id,
      task_id: $task,
      stage: $stage,
      context_condition: $cond,
      base_sha: $base,
      wall_clock_seconds: $wall,
      adapter_exit_code: $rc,
      diff_files_changed: $files,
      work_produced: $work
    }' > "${bundle_dir}/meta-blind-sanitized.json"

  jq -n \
    --arg score_set "${SCORE_SET}" \
    --arg eval_id "${eval_id}" \
    --arg task "${TASK}" \
    --arg cond "${cond}" \
  '{
    score_set_id: $score_set,
    eval_candidate_id: $eval_id,
    task_id: $task,
    context_condition: $cond
  }' > "${bundle_dir}/objective-input.json"

  cp -f "${d}/diff.patch" "${bundle_dir}/diff.patch" 2>/dev/null || printf '' > "${bundle_dir}/diff.patch"
  if [[ -f "${d}/diff.patch" ]]; then
    grep -E '^\+\+\+ b/' "${d}/diff.patch" 2>/dev/null | sed 's|^+++ b/||' | sort -u > "${bundle_dir}/files-changed.txt" || true
  else
    : > "${bundle_dir}/files-changed.txt"
  fi

  task_class="$(awk -F': ' '/^task_class:/{print $2; exit}' "${TASK_MD}" | tr -d '\r')"
  {
    printf '# Blinded candidate evidence\n\n'
    printf '**Eval ID:** %s\n' "${eval_id}"
    printf '**Task ID:** %s\n' "${TASK}"
    printf '**Task class:** %s\n' "${task_class:-unknown}"
    printf '**Context condition:** %s\n\n' "${cond}"
    printf '## Task body\n\n'
    awk '/^## Candidate task$/,/^## Reference solution/' "${TASK_MD}" | sed '$d'
    printf '\n## Sanitized run metadata\n\n```json\n'
    cat "${bundle_dir}/meta-blind-sanitized.json"
    printf '\n```\n\n## Changed files\n\n'
    sed 's/^/- /' "${bundle_dir}/files-changed.txt"
    printf '\n## Diff\n\n```diff\n'
    head -c 200000 "${bundle_dir}/diff.patch" 2>/dev/null || true
    printf '\n```\n'
  } > "${bundle_dir}/candidate.md"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${eval_id}" "${TASK}" "${alias}" "${ri}" "${rg}" "${cond}" "${variant}" "${pack_id}" "${d}" "${sealed_key}" \
    >> "${SEALED_MAP}"

  log "bundle ${eval_id} <- ${alias} r${ri}"
done

conds_joined="$(jq -n '[]')"
for variant in "${!VARIANT_TO_COND[@]}"; do
  cond="${VARIANT_TO_COND[$variant]}"
  pack_id=""
  [[ "${variant}" == pack:* ]] && pack_id="${variant#pack:}"
  conds_joined="$(jq --arg c "${cond}" --arg v "${variant}" --arg p "${pack_id}" \
    '. + [{context_condition:$c, context_variant:$v, context_pack_id: (if $p=="" then null else $p end)}]' \
    <<<"${conds_joined}")"
done

jq -n \
  --arg schema "benchmark-grade-set.v1" \
  --arg score_set "${SCORE_SET}" \
  --arg task "${TASK}" \
  --arg stage "${STAGE}" \
  --arg rg "${RUN_GROUP:-}" \
  --argjson run_idx "${RUN_INDEX_FILTER:-null}" \
  --arg seed "${BUNDLE_SEED}" \
  --argjson eval_count "${eval_n}" \
  --arg created "$(_ts)" \
  --argjson conds "${conds_joined}" \
  '{
    schema_version: $schema,
    score_set_id: $score_set,
    task_id: $task,
    stage: $stage,
    run_group: (if $rg == "" then null else $rg end),
    run_index_filter: $run_idx,
    rubric_id: "rubric.v1",
    grader_prompt_id: "model-roi-grader-v1",
    bundle_seed: $seed,
    eval_count: $eval_count,
    context_conditions: $conds,
    created_at: $created
  }' > "${GRADE_SET_JSON}"

log "grade bundles -> ${BUNDLE_ROOT} (${eval_n} evals)"
log "SEALED map -> ${SEALED_MAP}"
