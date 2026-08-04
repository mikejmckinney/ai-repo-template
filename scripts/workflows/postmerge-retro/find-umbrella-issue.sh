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
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=../lib/umbrella-lifecycle.sh
source "$REPO_ROOT/scripts/workflows/lib/umbrella-lifecycle.sh"

umbrella_find_issue \
  "$REPO" "postmerge-retro:daily:${RUN_DATE}" "$MARKER" \
  '^[[:space:]]*<!-- postmerge-retro:daily:'
