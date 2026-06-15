#!/usr/bin/env bash
# Persist umbrella issue number into daily-retro.json and artifact sidecar.
# Usage: write-umbrella-issue-ref.sh <daily-retro.json> <issue-number>
set -euo pipefail

DAILY_JSON="${1:-}"
ISSUE_NUM="${2:-}"
usage() {
  echo "Usage: write-umbrella-issue-ref.sh <daily-retro.json> <issue-number>" >&2
  exit 2
}
[[ -n "$DAILY_JSON" && -f "$DAILY_JSON" && -n "$ISSUE_NUM" ]] || usage
[[ "$ISSUE_NUM" =~ ^[0-9]+$ ]] || {
  echo "issue-number must be a positive integer" >&2
  exit 2
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

jq --argjson n "$ISSUE_NUM" '. + {umbrella_issue: $n}' "$DAILY_JSON" >"$WORKDIR/daily-with-umbrella.json"
mv "$WORKDIR/daily-with-umbrella.json" "$DAILY_JSON"
echo "$ISSUE_NUM" >"$(dirname "$DAILY_JSON")/umbrella-issue.txt"
python3 "$REPO_ROOT/scripts/workflows/postmerge-retro/validate-postmerge-retro-daily.py" "$DAILY_JSON"
echo "Recorded umbrella issue #${ISSUE_NUM} in ${DAILY_JSON}"
