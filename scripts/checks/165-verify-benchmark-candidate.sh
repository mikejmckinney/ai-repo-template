#!/usr/bin/env bash
# scripts/checks/165-verify-benchmark-candidate.sh — evaluator-side acceptance check for one
# benchmark candidate result bundle.
#
# Usage:
#   ./scripts/checks/165-verify-benchmark-candidate.sh --task <TASK> --alias <cand-NN> [--run-index N]
#     [--require-file path/to/file]...
#     [--require-heading path/to/file.md:## Heading]...
#     [--check-command 'command']...
#
# The script validates the benchmark result contract first, then optionally
# checks candidate-deliverable expectations against the captured HEAD.

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Checking benchmark candidate verifier..."

  if [[ -f "scripts/checks/165-verify-benchmark-candidate.sh" ]]; then
    pass "scripts/checks/165-verify-benchmark-candidate.sh exists"
  else
    fail "scripts/checks/165-verify-benchmark-candidate.sh is missing"
  fi

  if [[ -f "scripts/benchmark/lib.sh" ]]; then
    pass "scripts/benchmark/lib.sh exists for benchmark verifier"
  else
    fail "scripts/benchmark/lib.sh is missing for benchmark verifier"
  fi

  if [[ -f ".context/benchmarks/model-roi/result.schema.json" ]]; then
    pass ".context/benchmarks/model-roi/result.schema.json exists for benchmark verifier"
  else
    fail ".context/benchmarks/model-roi/result.schema.json is missing"
  fi

  if ! command -v jq >/dev/null 2>&1; then
    fail "jq is required for benchmark artifact fixture validation"
  elif (
    set -euo pipefail
    # shellcheck source=/dev/null
    source scripts/benchmark/lib.sh

    fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/benchmark-fixture.XXXXXX")"
    trap 'rm -rf "${fixture_root}"' EXIT

    fixture_wt="${fixture_root}/wt"
    mkdir -p "${fixture_wt}/.context/rules" "${fixture_root}/baseline" "${fixture_root}/injected" "${fixture_root}/pipeline" "${fixture_root}/duo"
    git -C "${fixture_wt}" init -q
    printf '# AGENTS\n' > "${fixture_wt}/AGENTS.md"
    printf '# CLAUDE\n' > "${fixture_wt}/CLAUDE.md"
    printf '# Rule\n\nFixture rule.\n' > "${fixture_wt}/.context/rules/process_fixture.md"
    git -C "${fixture_wt}" add -A

    cat > "${fixture_root}/baseline/meta-blind.json" <<'JSON'
{
  "alias": "cand-fixture",
  "task_id": "fixture-task",
  "run_index": 1,
  "stage": "1",
  "context_variant": "baseline",
  "orchestration_variant": "none",
  "base_sha": "0000000",
  "head_sha": "1111111",
  "start_utc": "2026-06-05T00:00:00Z",
  "end_utc": "2026-06-05T00:00:01Z",
  "wall_clock_seconds": 1,
  "adapter_exit_code": 0,
  "commits_ahead_of_base": 0,
  "diff_files_changed": 1,
  "work_produced": true,
  "shortstat": "1 file changed"
}
JSON
    cat > "${fixture_root}/baseline/meta-sealed.json" <<'JSON'
{
  "alias": "cand-fixture",
  "platform": "mock",
  "model": "mock-model",
  "agent": "mock-agent",
  "effort_requested": "medium",
  "effort_mechanism": "fixed",
  "effort_applied": "fixed",
  "effort_status": "clean",
  "context_variant": "baseline",
  "orchestration_variant": "none",
  "task_id": "fixture-task",
  "run_index": 1,
  "head_sha": "1111111",
  "wall_clock_seconds": 1,
  "adapter_exit_code": 0
}
JSON
    cat > "${fixture_root}/duo/meta-blind.json" <<'JSON'
{
  "alias": "cand-fixture-duo",
  "task_id": "fixture-task",
  "run_index": 1,
  "stage": "1d",
  "workflow": "duo-planner-implementer",
  "context_variant": "baseline",
  "base_sha": "0000000",
  "head_sha": "1111111",
  "planner_start_utc": "2026-06-05T00:00:00Z",
  "planner_end_utc": "2026-06-05T00:00:01Z",
  "planner_wall_clock_seconds": 1,
  "implementer_start_utc": "2026-06-05T00:00:01Z",
  "implementer_end_utc": "2026-06-05T00:00:02Z",
  "implementer_wall_clock_seconds": 1,
  "wall_clock_seconds": 2,
  "planner_exit_code": 0,
  "implementer_exit_code": 0,
  "commits_ahead_of_base": 0,
  "diff_files_changed": 1,
  "work_produced": true,
  "shortstat": "1 file changed",
  "planner_plan_artifact": "planner/plan.md"
}
JSON

    validate_json_artifact "${fixture_root}/baseline/meta-blind.json"
    validate_json_artifact "${fixture_root}/baseline/meta-sealed.json"
    validate_json_artifact "${fixture_root}/duo/meta-blind.json"
    apply_context_variant "${fixture_wt}" "${fixture_root}/injected" "full-rules-injected"
    apply_orchestration_variant "${fixture_wt}" "${fixture_root}/pipeline" "pipeline-existing-overlays" "cursor" "auto" "medium"

    jq -e . "${fixture_root}/injected/context-injection.json" >/dev/null
    jq -e . "${fixture_root}/pipeline/orchestration-overlay.json" >/dev/null
  ); then
    pass "benchmark generated-artifact fixtures are valid JSON"
  else
    fail "benchmark generated-artifact fixture validation failed"
  fi

  echo ""
  return 0
fi

set -euo pipefail
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../benchmark" && pwd)/lib.sh"

TASK="" ALIAS="" RUN_INDEX="1"
declare -a REQUIRED_FILES=()
declare -a REQUIRED_HEADINGS=()
declare -a CHECK_COMMANDS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task) TASK="$2"; shift 2;;
    --alias) ALIAS="$2"; shift 2;;
    --run-index) RUN_INDEX="$2"; shift 2;;
    --require-file) REQUIRED_FILES+=("$2"); shift 2;;
    --require-heading) REQUIRED_HEADINGS+=("$2"); shift 2;;
    --check-command) CHECK_COMMANDS+=("$2"); shift 2;;
    *) die "unknown arg: $1";;
  esac
done

[[ -n "${TASK}" && -n "${ALIAS}" ]] \
  || die "usage: --task <TASK> --alias <cand-NN> [--run-index N] [--require-file ...] [--require-heading path:heading] [--check-command ...]"
have_jq || die "165-verify-benchmark-candidate.sh needs jq"

SCHEMA_FILE="${REPO_DIR}/.context/benchmarks/model-roi/result.schema.json"
[[ -f "${SCHEMA_FILE}" ]] || die "result schema missing: ${SCHEMA_FILE}"

RESULT_FILE="$(result_file_path "${TASK}" "${ALIAS}" "${RUN_INDEX}")"
[[ -f "${RESULT_FILE}" ]] || die "result bundle missing: ${RESULT_FILE}"

if command -v check-jsonschema >/dev/null 2>&1; then
  check-jsonschema --schemafile "${SCHEMA_FILE}" "${RESULT_FILE}" >/dev/null
else
  jq -e '
    .schema_version == "benchmark-result.v1"
    and (.alias | type == "string")
    and (.task_id | type == "string")
    and (.run_index | type == "number")
    and (.stage | type == "string")
    and (.terminal_state == "graded" or .terminal_state == "blocked" or .terminal_state == "manual-capture-approved")
    and (.recorded_at | type == "string")
    and (.manual_fallback_allowed | type == "boolean")
    and (.artifacts | type == "object")
  ' "${RESULT_FILE}" >/dev/null
fi

STATE="$(jq -r '.terminal_state' "${RESULT_FILE}")"
HEAD_SHA="$(jq -r '.head_sha // empty' "${RESULT_FILE}")"
BLIND_REL="$(jq -r '.artifacts.blind_metadata // empty' "${RESULT_FILE}")"
SEALED_REL="$(jq -r '.artifacts.sealed_metadata // empty' "${RESULT_FILE}")"
DIFF_REL="$(jq -r '.artifacts.diff_patch // empty' "${RESULT_FILE}")"
OUTDIR="$(dirname "${RESULT_FILE}")"

case "${STATE}" in
  graded|manual-capture-approved)
    [[ -n "${HEAD_SHA}" ]] || die "captured result is missing head_sha"
    [[ -n "${BLIND_REL}" && -f "${OUTDIR}/${BLIND_REL}" ]] || die "blind metadata missing for ${ALIAS}"
    [[ -n "${SEALED_REL}" && -f "${OUTDIR}/${SEALED_REL}" ]] || die "sealed metadata missing for ${ALIAS}"
    [[ -n "${DIFF_REL}" && -f "${OUTDIR}/${DIFF_REL}" ]] || die "diff patch missing for ${ALIAS}"
    jq -e --arg alias "${ALIAS}" --arg task "${TASK}" --argjson run "${RUN_INDEX}" '
      .alias == $alias and .task_id == $task and .run_index == $run
    ' "${OUTDIR}/${BLIND_REL}" >/dev/null
    jq -e --arg alias "${ALIAS}" '
      .alias == $alias
    ' "${OUTDIR}/${SEALED_REL}" >/dev/null
    ;;
  blocked)
    [[ -z "${BLIND_REL}${SEALED_REL}${DIFF_REL}" ]] || die "blocked result must not advertise captured blind/sealed artifacts"
    ;;
  *)
    die "unexpected terminal state: ${STATE}"
    ;;
esac

if [[ ${#REQUIRED_FILES[@]} -gt 0 || ${#REQUIRED_HEADINGS[@]} -gt 0 || ${#CHECK_COMMANDS[@]} -gt 0 ]]; then
  [[ "${STATE}" != "blocked" ]] \
    || die "blocked candidates cannot satisfy evaluator content checks"
  [[ -n "${HEAD_SHA}" ]] || die "content checks require a captured head_sha"
fi

for required_file in "${REQUIRED_FILES[@]}"; do
  git -C "${REPO_DIR}" cat-file -e "${HEAD_SHA}:${required_file}" 2>/dev/null \
    || die "required file missing at ${HEAD_SHA}: ${required_file}"
done

for requirement in "${REQUIRED_HEADINGS[@]}"; do
  file_path="${requirement%%:*}"
  heading="${requirement#*:}"
  [[ -n "${file_path}" && -n "${heading}" && "${file_path}" != "${heading}" ]] \
    || die "invalid --require-heading value '${requirement}' (expected path:heading)"
  content="$(git -C "${REPO_DIR}" show "${HEAD_SHA}:${file_path}" 2>/dev/null)" \
    || die "required heading file missing at ${HEAD_SHA}: ${file_path}"
  printf '%s\n' "${content}" | grep -F -q -- "${heading}" \
    || die "required heading '${heading}' missing from ${file_path}"
done

VERIFY_WT=""
cleanup() {
  if [[ -n "${VERIFY_WT}" ]]; then
    git -C "${REPO_DIR}" worktree remove --force "${VERIFY_WT}" >/dev/null 2>&1 || rm -rf "${VERIFY_WT}"
  fi
}
trap cleanup EXIT

if [[ ${#CHECK_COMMANDS[@]} -gt 0 ]]; then
  VERIFY_WT="${WORKTREES_DIR}/verify-${TASK}-${ALIAS}-r${RUN_INDEX}"
  rm -rf "${VERIFY_WT}"
  git -C "${REPO_DIR}" worktree add --detach "${VERIFY_WT}" "${HEAD_SHA}" >/dev/null
  for cmd in "${CHECK_COMMANDS[@]}"; do
    ( cd "${VERIFY_WT}" && bash -c "${cmd}" )
  done
fi

log "verified candidate: task=${TASK} alias=${ALIAS} run=${RUN_INDEX} state=${STATE}"
