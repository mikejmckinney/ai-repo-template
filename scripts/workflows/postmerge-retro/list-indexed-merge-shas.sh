#!/usr/bin/env bash
# List merge_commit_sha values already indexed in umbrella issues.
# Usage: list-indexed-merge-shas.sh
# Prints one lowercase full SHA per line (sorted unique).
set -euo pipefail

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

bodies="$(
  gh search issues "postmerge-retro:merge:" --repo "$REPO" --json body --limit 100 2>/dev/null \
    | jq -r '.[].body // empty' 2>/dev/null || true
)"

if [[ -z "${bodies//[$'\t\r\n ']/}" ]]; then
  exit 0
fi

printf '%s\n' "$bodies" \
  | grep -oE 'postmerge-retro:merge:[0-9a-fA-F]{7,40}' \
  | sed 's/postmerge-retro:merge://' \
  | tr '[:upper:]' '[:lower:]' \
  | sort -u
