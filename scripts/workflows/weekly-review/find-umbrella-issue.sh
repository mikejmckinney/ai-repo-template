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
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=../lib/umbrella-lifecycle.sh
source "$REPO_ROOT/scripts/workflows/lib/umbrella-lifecycle.sh"

umbrella_find_issue \
  "$REPO" "weekly-review:${RUN_WEEK}" "$MARKER" \
  '^[[:space:]]*<!-- weekly-review:'
