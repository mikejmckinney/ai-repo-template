#!/usr/bin/env bash
# Post weekly-review.json snapshot as an umbrella issue comment (recovery artifact).
# Usage: post-weekly-review-json-comment.sh <weekly-review.json> [issue-number]
set -euo pipefail

WEEKLY_JSON="${1:-}"
ISSUE_NUM="${2:-}"
usage() {
  echo "Usage: post-weekly-review-json-comment.sh <weekly-review.json> [issue-number]" >&2
  exit 2
}
[[ -n "$WEEKLY_JSON" && -f "$WEEKLY_JSON" ]] || usage

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_WEEK="$(jq -r .run_week "$WEEKLY_JSON")"
RUN_ID="${GITHUB_RUN_ID:-local}"
RUN_ATTEMPT="${GITHUB_RUN_ATTEMPT:-0}"
MARKER="<!-- weekly-review:json:${RUN_WEEK} run:${RUN_ID} attempt:${RUN_ATTEMPT} -->"

if [[ -z "$ISSUE_NUM" ]]; then
  ISSUE_NUM="$(bash "$SCRIPT_DIR/find-umbrella-issue.sh" "$RUN_WEEK")" || {
    echo "::warning::No umbrella issue for ${RUN_WEEK}; skipping weekly JSON comment"
    exit 0
  }
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
body_file="$WORKDIR/comment.md"
{
  echo "$MARKER"
  echo ""
  echo "## Weekly review JSON snapshot"
  echo ""
  echo "Automation archive for fix-only recovery (\`workflow_dispatch fix_only\` + \`restore_json_from_issue\`)."
  echo ""
  echo '```json'
  cat "$WEEKLY_JSON"
  echo '```'
} >"$body_file"

gh issue comment "$ISSUE_NUM" -R "$REPO" --body-file "$body_file"
echo "Posted weekly-review.json snapshot comment on issue #${ISSUE_NUM} (${RUN_WEEK})"
