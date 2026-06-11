#!/usr/bin/env bash
# scripts/workflows/postmerge-retro/collect-postmerge-evidence.sh
# Wraps collect-pr-feedback.sh and normalizes artifact names for post-merge retro.
# Usage: collect-postmerge-evidence.sh <pr-number> <out-dir>
set -euo pipefail
umask 077

usage() {
  echo "Usage: collect-postmerge-evidence.sh <pr-number> <out-dir>" >&2
  exit 2
}

PR="${1:-}"
OUT_DIR="${2:-}"
[[ -n "$PR" && -n "$OUT_DIR" ]] || usage

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FEEDBACK_COLLECTOR="$REPO_ROOT/scripts/workflows/pr-feedback/collect-pr-feedback.sh"

[[ -f "$FEEDBACK_COLLECTOR" ]] || {
  echo "Missing $FEEDBACK_COLLECTOR" >&2
  exit 1
}

mkdir -p "$OUT_DIR"
bash "$FEEDBACK_COLLECTOR" "$PR" "$OUT_DIR"

# Normalize names expected by post-merge retro prompt/spec.
cp -f "$OUT_DIR/comments.json" "$OUT_DIR/issue-comments.json"
cp -f "$OUT_DIR/review-comments.json" "$OUT_DIR/review-comments.json"

merged="$(jq -r '.merged // false' "$OUT_DIR/pr.json")"
state="$(jq -r '.state // ""' "$OUT_DIR/pr.json")"
if [[ "$merged" != "true" ]]; then
  echo "::warning::PR #${PR} merged=${merged} state=${state} — retro collection continues but workflow should gate on merged PRs"
fi

echo "Post-merge evidence collected for PR #${PR} → ${OUT_DIR}"
