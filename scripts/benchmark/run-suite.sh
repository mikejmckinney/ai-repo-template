#!/usr/bin/env bash
# run-suite.sh — loop run-candidate.sh over every candidate in the manifest.
#
# Usage:
#   ./run-suite.sh --task <TASKID> --base <BASE_SHA> --stage 1 [--run-index N] [--continue-on-error]
#
# Runs candidates SEQUENTIALLY by default. Sequential is the safe choice: it
# keeps cost observable in real time, avoids hammering rate limits, and prevents
# parallel worktrees from competing for the same model quota (which would
# distort latency and cost measurements). Parallelism would corrupt the very
# metrics this benchmark exists to capture — don't add it without a reason.
#
# Exit 64 is the audited blocked/manual-fallback path. The run is documented as
# blocked, the worktree stays open, and the operator may choose `make record`
# only after a real manual rerun in that worktree.

set -euo pipefail
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

TASK="" BASE_SHA="" STAGE="" RUN_INDEX="1" CONT="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)             TASK="$2"; shift 2;;
    --base)             BASE_SHA="$2"; shift 2;;
    --stage)            STAGE="$2"; shift 2;;
    --run-index)        RUN_INDEX="$2"; shift 2;;
    --continue-on-error) CONT="1"; shift;;
    *) die "unknown arg: $1";;
  esac
done
[[ -n "${TASK}" && -n "${BASE_SHA}" ]] || die "usage: --task <id> --base <sha> --stage <N> [--run-index N]"

preflight
require_base "${BASE_SHA}"
require_stage "${STAGE}"
"${RUNNER_DIR}/doctor.sh" --stage "${STAGE}" --base "${BASE_SHA}"

mapfile -t ALIASES < <(manifest_aliases "${STAGE}")
[[ "${#ALIASES[@]}" -gt 0 ]] || die "no candidates in manifest for stage='${STAGE}'"

log "suite: task=${TASK} stage='${STAGE}' candidates=${#ALIASES[@]} run-index=${RUN_INDEX}"
declare -a CAPTURED=() FAIL=() BLOCKED=()

for alias in "${ALIASES[@]}"; do
  log "---- ${alias} ----"
  set +e
  BENCHMARK_DOCTOR_DONE=1 "${RUNNER_DIR}/run-candidate.sh" --task "${TASK}" --base "${BASE_SHA}" \
      --alias "${alias}" --run-index "${RUN_INDEX}"
  rc=$?
  set -e
  case ${rc} in
    0)  CAPTURED+=("${alias}");;
    64) BLOCKED+=("${alias}"); log "BLOCKED (documented headless failure): ${alias}";;
    *)  FAIL+=("${alias}"); log "adapter error rc=${rc}: ${alias}"
        [[ "${CONT}" == "1" ]] || die "stopping (use --continue-on-error to keep going)";;
  esac
done

log "==== suite summary ===="
log "  captured  : ${CAPTURED[*]:-none}"
log "  blocked   : ${BLOCKED[*]:-none}  (optional audited fallback: make worktree + make record)"
log "  errored   : ${FAIL[*]:-none}"
