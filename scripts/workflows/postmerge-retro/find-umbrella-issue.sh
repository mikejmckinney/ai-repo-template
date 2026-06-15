#!/usr/bin/env bash
# Resolve the daily umbrella issue number for a run date.
# Usage: find-umbrella-issue.sh <run-date>
set -euo pipefail

RUN_DATE="${1:-}"
[[ -n "$RUN_DATE" ]] || {
  echo "Usage: find-umbrella-issue.sh <run-date>" >&2
  exit 2
}

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
MARKER="<!-- postmerge-retro:daily:${RUN_DATE} -->"

while read -r candidate; do
  [[ -z "$candidate" ]] && continue
  if gh api "repos/${REPO}/issues/${candidate}" --jq -e '.pull_request != null' >/dev/null 2>&1; then
    continue
  fi
  body="$(gh issue view "$candidate" -R "$REPO" --json body --jq .body 2>/dev/null || true)"
  [[ -n "$body" ]] || continue
  if grep -Fq "$MARKER" <<<"$body" && grep -Eq "^[[:space:]]*<!-- postmerge-retro:daily:" <<<"$body"; then
    echo "$candidate"
    exit 0
  fi
done < <(gh search issues "postmerge-retro:daily:${RUN_DATE}" --repo "$REPO" --json number --limit 10 --jq '.[].number' 2>/dev/null || true)

exit 1
