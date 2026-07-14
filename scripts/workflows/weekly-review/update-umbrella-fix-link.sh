#!/usr/bin/env bash
# Replace umbrella Meta placeholder with the draft fix PR URL.
# Usage: update-umbrella-fix-link.sh <run-week> <fix-pr-url> [weekly-review.json]
set -euo pipefail

usage() {
  echo "Usage: update-umbrella-fix-link.sh <run-week> <fix-pr-url> [weekly-review.json]" >&2
  exit 2
}

RUN_WEEK="${1:-}"
FIX_PR_URL="${2:-}"
WEEKLY_JSON="${3:-${WEEKLY_JSON:-}}"
[[ -n "$RUN_WEEK" && -n "$FIX_PR_URL" ]] || usage

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER="<!-- weekly-review:${RUN_WEEK} -->"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../lib/umbrella-lifecycle.sh
source "$REPO_ROOT/scripts/workflows/lib/umbrella-lifecycle.sh"

issue_num=""
if issue_num="$(bash "$SCRIPT_DIR/resolve-umbrella-issue.sh" "$RUN_WEEK" "$WEEKLY_JSON" 2>/dev/null)"; then
  :
else
  issue_num=""
fi
[[ -n "$issue_num" ]] || {
  echo "::warning::No umbrella issue found for ${RUN_WEEK}; skipping fix-link update"
  exit 0
}

umbrella_update_fix_link "$REPO" "$issue_num" "$MARKER" "$FIX_PR_URL"
