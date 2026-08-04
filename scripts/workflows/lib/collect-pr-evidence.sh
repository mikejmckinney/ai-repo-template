#!/usr/bin/env bash
# scripts/workflows/lib/collect-pr-evidence.sh — deterministic PR evidence harvest.
# Usage: collect-pr-feedback.sh <pr-number> <out-dir>
# Read-only: uses gh api / gh pr view (no write permissions required).
set -euo pipefail
umask 077

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
  raw="$(gh api "$endpoint" --paginate)"
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

checks_endpoint="repos/${REPO}/commits/${head_sha}/check-runs?per_page=100&filter=all"
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  checks_json="$(GH_TOKEN="$GITHUB_TOKEN" gh api "$checks_endpoint" 2>/dev/null)" || checks_json=""
else
  checks_json="$(gh api "$checks_endpoint" 2>/dev/null)" || checks_json=""
fi
if [[ -n "$checks_json" ]]; then
  printf '%s\n' "$checks_json" >"$OUT_DIR/checks.json"
else
  echo '{"total_count":0,"check_runs":[],"collection_error":"unavailable"}' >"$OUT_DIR/checks.json"
  echo "::warning::Check-run collection unavailable for PR #${PR} head ${head_sha}" >&2
fi

git fetch origin "$head_sha" "$base_sha" 2>/dev/null || true
git diff "${base_sha}...${head_sha}" >"$OUT_DIR/diff.patch" 2>/dev/null || : >"$OUT_DIR/diff.patch"

changed_file_count="$(jq 'length' "$OUT_DIR/changed-files.json" 2>/dev/null || echo 0)"
if [[ ! -s "$OUT_DIR/diff.patch" && "$changed_file_count" -gt 0 ]]; then
  echo "::notice::Local git diff empty with ${changed_file_count} changed files; fetching PR diff via GitHub API" >&2
  if ! gh api "repos/${REPO}/pulls/${PR}" -H "Accept: application/vnd.github.v3.diff" >"$OUT_DIR/diff.patch" 2>/dev/null; then
    echo "::warning::GitHub PR diff fallback failed; diff may remain empty" >&2
    : >"$OUT_DIR/diff.patch"
  fi
fi

ADVISORY_MARKER='<!-- ai-advisory-review:v1 -->'
INBOX_MARKER='<!-- ai-feedback-inbox:v1 -->'

jq -r --arg marker "$ADVISORY_MARKER" '
  [.[] | select((.body | type) == "string" and (.body | contains($marker)))] as $matches
  | if ($matches | length) == 0 then ""
    else
      (["## Advisory snapshot comment(s)", ""]
        + ($matches | map("### Comment \(.id) — \((.user?.login // "unknown")) @ \(.created_at)\n\n\(.body)")))
      | join("\n\n")
    end
' "$OUT_DIR/comments.json" >"$OUT_DIR/advisory-comments.md"

jq -r --arg marker "$INBOX_MARKER" '
  [.[] | select((.body | type) == "string" and (.body | contains($marker)))] as $matches
  | if ($matches | length) == 0 then ""
    else
      (["## Prior feedback inbox comment(s)", ""]
        + ($matches | map("### Comment \(.id) — \((.user?.login // "unknown")) @ \(.created_at)\n\n\(.body)")))
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
Check runs: $(jq '.total_count // (.check_runs | length) // 0' "$OUT_DIR/checks.json")
Changed files: $(wc -l <"$OUT_DIR/changed-files.txt" | tr -d ' ')
Diff bytes: $(wc -c <"$OUT_DIR/diff.patch" | tr -d ' ')
EOF

echo "Collected feedback for PR #${PR} @ ${head_sha} → ${OUT_DIR}"
