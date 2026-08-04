#!/usr/bin/env bash
# Replace umbrella Meta placeholder with the draft fix PR URL.
# Usage: update-umbrella-fix-link.sh <run-date> <fix-pr-url> [daily-retro.json]
set -euo pipefail

usage() {
  echo "Usage: update-umbrella-fix-link.sh <run-date> <fix-pr-url> [daily-retro.json]" >&2
  exit 2
}

RUN_DATE="${1:-}"
FIX_PR_URL="${2:-}"
DAILY_JSON="${3:-${DAILY_JSON:-}}"
[[ -n "$RUN_DATE" && -n "$FIX_PR_URL" ]] || usage

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER="<!-- postmerge-retro:daily:${RUN_DATE} -->"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../lib/umbrella-lifecycle.sh
source "$REPO_ROOT/scripts/workflows/lib/umbrella-lifecycle.sh"

issue_num=""
if issue_num="$(bash "$SCRIPT_DIR/resolve-umbrella-issue.sh" "$RUN_DATE" "$DAILY_JSON" 2>/dev/null)"; then
  :
else
  issue_num=""
fi
[[ -n "$issue_num" ]] || {
  echo "::warning::No umbrella issue found for ${RUN_DATE}; skipping fix-link update"
  exit 0
}

umbrella_update_fix_link "$REPO" "$issue_num" "$MARKER" "$FIX_PR_URL"
