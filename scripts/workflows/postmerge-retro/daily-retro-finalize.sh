#!/usr/bin/env bash
# Merge per-PR retro.json artifacts, validate, create umbrella, write findings count.
set -euo pipefail

RUN_DATE="${1:-}"
ARTIFACT_ROOT="${2:-}"
shift 2 || true

usage() {
  echo "Usage: daily-retro-finalize.sh <run-date> <artifact-root> <retro.json> [...]" >&2
  exit 2
}

[[ -n "$RUN_DATE" && -n "$ARTIFACT_ROOT" ]] || usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

RETRO_FILES=("$@")
if [[ ${#RETRO_FILES[@]} -eq 0 ]]; then
  echo "No new PR retros produced; skipping merge/umbrella"
  echo "0" >"$ARTIFACT_ROOT/findings-count.txt"
  exit 0
fi

DAILY_JSON="$ARTIFACT_ROOT/daily-retro.json"
python3 "$SCRIPT_DIR/merge-daily-retro-json.py" "$RUN_DATE" "${RETRO_FILES[@]}" >"$DAILY_JSON"
python3 "$SCRIPT_DIR/validate-postmerge-retro-daily.py" "$DAILY_JSON"

bash "$SCRIPT_DIR/create-umbrella-issue.sh" "$DAILY_JSON"

FINDINGS_COUNT="$(python3 "$SCRIPT_DIR/count-daily-retro-findings.py" "$DAILY_JSON")"
echo "$FINDINGS_COUNT" >"$ARTIFACT_ROOT/findings-count.txt"
echo "Daily retro complete for ${RUN_DATE} (${FINDINGS_COUNT} findings)"
