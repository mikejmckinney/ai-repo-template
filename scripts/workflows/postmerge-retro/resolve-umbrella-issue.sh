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

if [[ -n "${UMBRELLA_ISSUE_NUM:-}" ]]; then
  echo "$UMBRELLA_ISSUE_NUM"
  exit 0
fi

if [[ -n "$DAILY_JSON" && -f "$DAILY_JSON" ]]; then
  issue_num="$(jq -r '.umbrella_issue // empty' "$DAILY_JSON" 2>/dev/null || true)"
  if [[ -n "$issue_num" && "$issue_num" != "null" ]]; then
    echo "$issue_num"
    exit 0
  fi
  sidecar="$(dirname "$DAILY_JSON")/umbrella-issue.txt"
  if [[ -f "$sidecar" ]]; then
    issue_num="$(tr -d '[:space:]' <"$sidecar")"
    if [[ -n "$issue_num" ]]; then
      echo "$issue_num"
      exit 0
    fi
  fi
fi

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  if issue_num="$(GH_TOKEN="$GITHUB_TOKEN" bash "$SCRIPT_DIR/find-umbrella-issue.sh" "$RUN_DATE" 2>/dev/null)"; then
    echo "$issue_num"
    exit 0
  fi
fi

if issue_num="$(bash "$SCRIPT_DIR/find-umbrella-issue.sh" "$RUN_DATE" 2>/dev/null)"; then
  echo "$issue_num"
  exit 0
fi

exit 1
