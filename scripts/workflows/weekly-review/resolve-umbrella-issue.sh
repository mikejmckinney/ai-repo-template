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

if [[ -n "${UMBRELLA_ISSUE_NUM:-}" ]]; then
  echo "$UMBRELLA_ISSUE_NUM"
  exit 0
fi

if [[ -n "$WEEKLY_JSON" && -f "$WEEKLY_JSON" ]]; then
  issue_num="$(jq -r '.umbrella_issue // empty' "$WEEKLY_JSON" 2>/dev/null || true)"
  if [[ -n "$issue_num" && "$issue_num" != "null" ]]; then
    echo "$issue_num"
    exit 0
  fi
  sidecar="$(dirname "$WEEKLY_JSON")/umbrella-issue.txt"
  if [[ -f "$sidecar" ]]; then
    issue_num="$(tr -d '[:space:]' <"$sidecar")"
    if [[ -n "$issue_num" ]]; then
      echo "$issue_num"
      exit 0
    fi
  fi
fi

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  if issue_num="$(GH_TOKEN="$GITHUB_TOKEN" bash "$SCRIPT_DIR/find-umbrella-issue.sh" "$RUN_WEEK" 2>/dev/null)"; then
    echo "$issue_num"
    exit 0
  fi
fi

if issue_num="$(bash "$SCRIPT_DIR/find-umbrella-issue.sh" "$RUN_WEEK" 2>/dev/null)"; then
  echo "$issue_num"
  exit 0
fi

exit 1
