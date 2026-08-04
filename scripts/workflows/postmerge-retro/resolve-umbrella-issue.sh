#!/usr/bin/env bash
# Resolve umbrella issue number for a daily retro run (no gh search when known).
# Usage: resolve-umbrella-issue.sh <run-date> [daily-retro.json]
# Prints issue number to stdout; exit 0 on success, 1 if not found.
set -euo pipefail

RUN_DATE="${1:-}"
DAILY_JSON="${2:-${DAILY_JSON:-}}"
usage() {
  echo "Usage: resolve-umbrella-issue.sh <run-date> [daily-retro.json]" >&2
  exit 2
}
[[ -n "$RUN_DATE" ]] || usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../lib/umbrella-lifecycle.sh
source "$REPO_ROOT/scripts/workflows/lib/umbrella-lifecycle.sh"

umbrella_resolve_issue "$RUN_DATE" "$DAILY_JSON" "$SCRIPT_DIR/find-umbrella-issue.sh"
