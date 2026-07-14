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
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=../lib/umbrella-lifecycle.sh
source "$REPO_ROOT/scripts/workflows/lib/umbrella-lifecycle.sh"

umbrella_write_issue_ref \
  "$DAILY_JSON" "$ISSUE_NUM" \
  python3 "$REPO_ROOT/scripts/workflows/postmerge-retro/validate-postmerge-retro-daily.py"
echo "Recorded umbrella issue #${ISSUE_NUM} in ${DAILY_JSON}"
