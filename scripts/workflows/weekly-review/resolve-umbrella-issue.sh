#!/usr/bin/env bash
# Resolve umbrella issue number for a weekly review run.
# Usage: resolve-umbrella-issue.sh <run-week> [weekly-review.json]
set -euo pipefail

RUN_WEEK="${1:-}"
WEEKLY_JSON="${2:-${WEEKLY_JSON:-}}"
usage() {
  echo "Usage: resolve-umbrella-issue.sh <run-week> [weekly-review.json]" >&2
  exit 2
}
[[ -n "$RUN_WEEK" ]] || usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../lib/umbrella-lifecycle.sh
source "$REPO_ROOT/scripts/workflows/lib/umbrella-lifecycle.sh"

umbrella_resolve_issue "$RUN_WEEK" "$WEEKLY_JSON" "$SCRIPT_DIR/find-umbrella-issue.sh"
