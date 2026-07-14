#!/usr/bin/env bash
# Persist umbrella issue number into weekly-review.json and sidecar.
# Usage: write-umbrella-issue-ref.sh <weekly-review.json> <issue-number>
set -euo pipefail

WEEKLY_JSON="${1:-}"
ISSUE_NUM="${2:-}"
usage() {
  echo "Usage: write-umbrella-issue-ref.sh <weekly-review.json> <issue-number>" >&2
  exit 2
}
[[ -n "$WEEKLY_JSON" && -f "$WEEKLY_JSON" && -n "$ISSUE_NUM" ]] || usage

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=../lib/umbrella-lifecycle.sh
source "$REPO_ROOT/scripts/workflows/lib/umbrella-lifecycle.sh"

umbrella_write_issue_ref \
  "$WEEKLY_JSON" "$ISSUE_NUM" \
  python3 "$REPO_ROOT/scripts/workflows/weekly-review/validate-weekly-review-batch.py"
echo "Recorded umbrella_issue=${ISSUE_NUM} in ${WEEKLY_JSON}"
