#!/usr/bin/env bash
# scripts/workflows/pr-feedback/collect-pr-feedback.sh — deterministic PR feedback harvest.
# Usage: collect-pr-feedback.sh <pr-number> <out-dir>
# Read-only: uses gh api / gh pr view (no write permissions required).
set -euo pipefail

usage() {
  echo "Usage: collect-pr-feedback.sh <pr-number> <out-dir>" >&2
  exit 2
}

PR="${1:-}"
OUT_DIR="${2:-}"

[[ -n "$PR" && -n "$OUT_DIR" ]] || usage

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
mkdir -p "$OUT_DIR"

gh api "repos/${REPO}/pulls/${PR}" >"$OUT_DIR/pr.json"
head_sha="$(jq -r .head.sha "$OUT_DIR/pr.json")"
base_sha="$(jq -r .base.sha "$OUT_DIR/pr.json")"

jq '.labels' "$OUT_DIR/pr.json" >"$OUT_DIR/labels.json"

paginate_to_array() {
  local endpoint="$1" outfile="$2"
  local raw
  raw="$(gh api "$endpoint" --paginate 2>/dev/null || true)"
  if [[ -z "$raw" ]]; then
    echo '[]' >"$outfile"
  else
    printf '%s\n' "$raw" | jq -s 'if length == 0 then [] else add end' >"$outfile"
  fi
}

paginate_to_array "repos/${REPO}/issues/${PR}/comments" "$OUT_DIR/comments.json"
paginate_to_array "repos/${REPO}/pulls/${PR}/reviews" "$OUT_DIR/reviews.json"
paginate_to_array "repos/${REPO}/pulls/${PR}/comments" "$OUT_DIR/review-comments.json"
paginate_to_array "repos/${REPO}/pulls/${PR}/files" "$OUT_DIR/changed-files.json"

git fetch origin "$head_sha" "$base_sha" 2>/dev/null || true
git diff "${base_sha}...${head_sha}" >"$OUT_DIR/diff.patch" 2>/dev/null || : >"$OUT_DIR/diff.patch"

ADVISORY_TOKEN='ai-advisory-review:v1'
INBOX_TOKEN='ai-feedback-inbox:v1'

jq -r --arg tok "$ADVISORY_TOKEN" '
  if length == 0 then ""
  else
    (["## Advisory snapshot comment(s)", ""]
      + ([.[] | select(.body | contains($tok))
          | "### Comment \(.id) — \(.user.login) @ \(.created_at)\n\n\(.body)"]))
    | join("\n\n")
  end
' "$OUT_DIR/comments.json" >"$OUT_DIR/advisory-comments.md"

jq -r --arg tok "$INBOX_TOKEN" '
  if length == 0 then ""
  else
    (["## Prior feedback inbox comment(s)", ""]
      + ([.[] | select(.body | contains($tok))
          | "### Comment \(.id) — \(.user.login) @ \(.created_at)\n\n\(.body)"]))
    | join("\n\n")
  end
' "$OUT_DIR/comments.json" >"$OUT_DIR/prior-inbox.md"

jq -r '.[].filename' "$OUT_DIR/changed-files.json" >"$OUT_DIR/changed-files.txt" 2>/dev/null || : >"$OUT_DIR/changed-files.txt"

cat >"$OUT_DIR/summary.txt" <<EOF
PR: #${PR}
Repository: ${REPO}
Head SHA: ${head_sha}
Base SHA: ${base_sha}
Issue comments: $(jq 'length' "$OUT_DIR/comments.json")
Formal reviews: $(jq 'length' "$OUT_DIR/reviews.json")
Inline review comments: $(jq 'length' "$OUT_DIR/review-comments.json")
Changed files: $(wc -l <"$OUT_DIR/changed-files.txt" | tr -d ' ')
Diff bytes: $(wc -c <"$OUT_DIR/diff.patch" | tr -d ' ')
EOF

echo "Collected feedback for PR #${PR} @ ${head_sha} → ${OUT_DIR}"
