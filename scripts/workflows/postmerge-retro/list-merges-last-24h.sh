#!/usr/bin/env bash
# List PR numbers merged to main within the rolling last 24 hours (UTC).
set -euo pipefail

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
HOURS="${POSTMERGE_RETRO_WINDOW_HOURS:-24}"
CUTOFF="$(date -u -d "${HOURS} hours ago" +%Y-%m-%dT%H:%M:%SZ)"

gh pr list --repo "$REPO" --state merged --base main --limit 100 \
  --json number,mergedAt \
  --jq ".[] | select(.mergedAt != null and .mergedAt >= \"${CUTOFF}\") | .number" | sort -n
