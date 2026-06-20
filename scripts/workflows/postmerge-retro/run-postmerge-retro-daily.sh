#!/usr/bin/env bash
# Daily post-merge retro: scan merges in last 24h, per-PR retro (sequential), umbrella issue.
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

RETRO_FILES=()
for pr in "${SELECTED_PRS[@]}"; do
  echo "Running retro for PR #${pr}..."
  bash "$SCRIPT_DIR/run-postmerge-retro.sh" "$pr" false
  pr_artifact="${GITHUB_WORKSPACE:-$REPO_ROOT}/.artifacts/postmerge-retro/pr-${pr}/retro.json"
  if [[ ! -f "$pr_artifact" ]]; then
    echo "::warning::Missing retro.json for PR #${pr}; skipping"
    continue
  fi
  cp -f "$pr_artifact" "$ARTIFACT_ROOT/pr-${pr}-retro.json"
  pr_changed="${GITHUB_WORKSPACE:-$REPO_ROOT}/.artifacts/postmerge-retro/pr-${pr}/changed-files.txt"
  pr_coverage="${GITHUB_WORKSPACE:-$REPO_ROOT}/.artifacts/postmerge-retro/pr-${pr}/evidence-coverage.json"
  if [[ -f "$pr_changed" ]]; then
    cp -f "$pr_changed" "$ARTIFACT_ROOT/pr-${pr}-changed-files.txt"
  fi
  if [[ -f "$pr_coverage" ]]; then
    cp -f "$pr_coverage" "$ARTIFACT_ROOT/pr-${pr}-evidence-coverage.json"
  fi
  RETRO_FILES+=("$ARTIFACT_ROOT/pr-${pr}-retro.json")
done

bash "$SCRIPT_DIR/daily-retro-finalize.sh" "$RUN_DATE" "$ARTIFACT_ROOT" "${RETRO_FILES[@]}"
