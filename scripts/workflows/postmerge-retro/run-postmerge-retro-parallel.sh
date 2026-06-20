#!/usr/bin/env bash
# Daily post-merge retro: parallel per-PR retro invocations, then merge umbrella.
set -euo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RUN_DATE="${RUN_DATE:-$(date -u +%Y-%m-%d)}"
ARTIFACT_ROOT="${GITHUB_WORKSPACE:-$REPO_ROOT}/.artifacts/postmerge-retro/daily-${RUN_DATE}"
mkdir -p "$ARTIFACT_ROOT"

mapfile -t SELECTED_PRS < <(bash "$SCRIPT_DIR/daily-retro-select-prs.sh" || true)
if [[ ${#SELECTED_PRS[@]} -eq 0 ]]; then
  if [[ ! -f "$ARTIFACT_ROOT/findings-count.txt" ]]; then
    echo "No merges to main in the last 24h; skipping daily retro"
    echo "0" >"$ARTIFACT_ROOT/findings-count.txt"
  fi
  exit 0
fi

max_parallel="${POSTMERGE_RETRO_PARALLEL_MAX:-6}"
echo "Parallel retro: ${#SELECTED_PRS[@]} PR(s), max_parallel=${max_parallel}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

run_one() {
  local pr="$1"
  local log="$tmpdir/pr-${pr}.log"
  if bash "$SCRIPT_DIR/run-postmerge-retro.sh" "$pr" false >"$log" 2>&1; then
    echo "ok" >"$tmpdir/pr-${pr}.status"
  else
    echo "fail" >"$tmpdir/pr-${pr}.status"
    echo "::error::Parallel retro failed for PR #${pr}" >&2
    tail -40 "$log" >&2 || true
  fi
}

active=0
fail=0
for pr in "${SELECTED_PRS[@]}"; do
  while [[ "$active" -ge "$max_parallel" ]]; do
    wait -n 2>/dev/null || wait || true
    active=$((active - 1))
  done
  run_one "$pr" &
  active=$((active + 1))
done
while [[ "$active" -gt 0 ]]; do
  wait -n 2>/dev/null || wait || true
  active=$((active - 1))
done

for pr in "${SELECTED_PRS[@]}"; do
  if [[ ! -f "$tmpdir/pr-${pr}.status" ]] || [[ "$(cat "$tmpdir/pr-${pr}.status")" != "ok" ]]; then
    fail=1
  fi
done
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

RETRO_FILES=()
for pr in "${SELECTED_PRS[@]}"; do
  pr_artifact="${GITHUB_WORKSPACE:-$REPO_ROOT}/.artifacts/postmerge-retro/pr-${pr}/retro.json"
  if [[ ! -f "$pr_artifact" ]]; then
    echo "::warning::Missing retro.json for PR #${pr}; skipping"
    continue
  fi
  cp -f "$pr_artifact" "$ARTIFACT_ROOT/pr-${pr}-retro.json"
  pr_changed="${GITHUB_WORKSPACE:-$REPO_ROOT}/.artifacts/postmerge-retro/pr-${pr}/changed-files.txt"
  if [[ -f "$pr_changed" ]]; then
    cp -f "$pr_changed" "$ARTIFACT_ROOT/pr-${pr}-changed-files.txt"
  fi
  RETRO_FILES+=("$ARTIFACT_ROOT/pr-${pr}-retro.json")
done

bash "$SCRIPT_DIR/daily-retro-finalize.sh" "$RUN_DATE" "$ARTIFACT_ROOT" "${RETRO_FILES[@]}"
