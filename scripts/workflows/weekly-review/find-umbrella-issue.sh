#!/usr/bin/env bash
# Resolve the weekly umbrella issue number for an ISO week id.
# Usage: find-umbrella-issue.sh <run-week>
set -euo pipefail

RUN_WEEK="${1:-}"
[[ -n "$RUN_WEEK" ]] || {
  echo "Usage: find-umbrella-issue.sh <run-week>" >&2
  exit 2
}

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
MARKER="<!-- weekly-review:${RUN_WEEK} -->"

while read -r candidate; do
  [[ -z "$candidate" ]] && continue
  if gh api "repos/${REPO}/issues/${candidate}" --jq -e '.pull_request != null' >/dev/null 2>&1; then
    continue
  fi
  body="$(gh issue view "$candidate" -R "$REPO" --json body --jq .body 2>/dev/null || true)"
  [[ -n "$body" ]] || continue
  if grep -Fq "$MARKER" <<<"$body" && grep -Eq "^[[:space:]]*<!-- weekly-review:" <<<"$body"; then
    echo "$candidate"
    exit 0
  fi
done < <(gh search issues "weekly-review:${RUN_WEEK}" --repo "$REPO" --json number --limit 10 --jq '.[].number' 2>/dev/null || true)

exit 1
