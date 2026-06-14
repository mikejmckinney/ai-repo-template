#!/usr/bin/env bash
# Post daily-retro.json snapshot as an umbrella issue comment (recovery artifact).
# Usage: post-daily-retro-json-comment.sh <daily-retro.json> [issue-number]
set -euo pipefail

DAILY_JSON="${1:-}"
ISSUE_NUM="${2:-}"
usage() {
  echo "Usage: post-daily-retro-json-comment.sh <daily-retro.json> [issue-number]" >&2
  exit 2
}
[[ -n "$DAILY_JSON" && -f "$DAILY_JSON" ]] || usage

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_DATE="$(jq -r .run_date "$DAILY_JSON")"
RUN_ID="${GITHUB_RUN_ID:-local}"
RUN_ATTEMPT="${GITHUB_RUN_ATTEMPT:-0}"
MARKER="<!-- postmerge-retro:daily-json:${RUN_DATE} run:${RUN_ID} attempt:${RUN_ATTEMPT} -->"

if [[ -z "$ISSUE_NUM" ]]; then
  ISSUE_NUM="$(bash "$SCRIPT_DIR/find-umbrella-issue.sh" "$RUN_DATE")" || {
    echo "::warning::No umbrella issue for ${RUN_DATE}; skipping daily JSON comment"
    exit 0
  }
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
body_file="$WORKDIR/comment.md"
{
  echo "$MARKER"
  echo ""
  echo "## Daily retro JSON snapshot"
  echo ""
  echo "Automation archive for fix-only recovery (\`workflow_dispatch fix_only\` + \`restore_json_from_issue\`)."
  echo ""
  echo '```json'
  cat "$DAILY_JSON"
  echo '```'
} >"$body_file"

gh issue comment "$ISSUE_NUM" -R "$REPO" --body-file "$body_file"
echo "Posted daily-retro.json snapshot comment on issue #${ISSUE_NUM} (${RUN_DATE})"
