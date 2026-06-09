#!/usr/bin/env bash
# .github/scripts/run-advisory-review.sh — provider dispatch for advisory snapshots.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

PR="${1:-${PR_NUMBER:-}}"
HEAD_SHA="${2:-${HEAD_SHA:-}}"
FULL_MODE="${3:-${FULL_MODE:-false}}"

usage() {
  echo "Usage: run-advisory-review.sh <pr-number> <head-sha> [full-mode:true|false]" >&2
  exit 2
}

[[ -n "$PR" && -n "$HEAD_SHA" ]] || usage

REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
MARKER='<!-- ai-advisory-review:v1 -->'
PROVIDER="${ADVISORY_REVIEW_PROVIDER:-auto}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

pr_json="$(gh api "repos/${REPO}/pulls/${PR}")"
pr_title="$(printf '%s' "$pr_json" | jq -r .title)"
pr_body="$(printf '%s' "$pr_json" | jq -r .body)"
pr_url="$(printf '%s' "$pr_json" | jq -r .html_url)"
base_sha="$(printf '%s' "$pr_json" | jq -r .base.sha)"

gh api "repos/${REPO}/pulls/${PR}/files" --paginate --jq '.[].filename' \
  >"$WORKDIR/changed-files.txt" || true

diff_limit=120000
if [[ "$FULL_MODE" == "true" ]]; then
  diff_limit=300000
fi

git fetch origin "$HEAD_SHA" "$base_sha" 2>/dev/null || true
diff_text="$(git diff "${base_sha}...${HEAD_SHA}" 2>/dev/null | head -c "$diff_limit" || true)"

existing_snapshot=""
existing_snapshot=$(
  gh api "repos/${REPO}/issues/${PR}/comments" --paginate \
    --jq ".[] | select(.body | contains(\"${MARKER}\")) | .body" 2>/dev/null | head -1
)

prompt_file="$WORKDIR/prompt.md"
{
  cat "$REPO_ROOT/.github/prompts/pr-advisory-review.md"
  echo ""
  echo "---"
  echo ""
  echo "## PR context (automation-supplied)"
  echo ""
  echo "- Repository: \`${REPO}\`"
  echo "- PR: #${PR} — ${pr_title}"
  echo "- URL: ${pr_url}"
  echo "- Head SHA: \`${HEAD_SHA}\`"
  echo "- Full depth: \`${FULL_MODE}\`"
  echo ""
  echo "### PR body"
  echo ""
  printf '%s\n' "$pr_body"
  echo ""
  echo "### Changed files"
  echo ""
  sed 's/^/- /' "$WORKDIR/changed-files.txt"
  echo ""
  echo "### Diff (truncated)"
  echo ""
  echo '```diff'
  printf '%s\n' "$diff_text"
  echo '```'
  if [[ -n "$existing_snapshot" ]]; then
    echo ""
    echo "### Existing advisory snapshot (dedupe against this)"
    echo ""
    printf '%s\n' "$existing_snapshot"
  fi
} >"$prompt_file"

pick_provider() {
  local want="${ADVISORY_REVIEW_PROVIDER:-auto}"
  case "$want" in
    cursor)
      echo cursor
      ;;
    gemini)
      echo gemini
      ;;
    auto)
      if [[ -n "${CURSOR_API_KEY:-}" ]]; then
        echo cursor
      elif [[ -n "${GEMINI_API_KEY:-}" || -n "${GOOGLE_API_KEY:-}" ]]; then
        echo gemini
      else
        echo ""
      fi
      ;;
    *)
      echo "::error::Unknown ADVISORY_REVIEW_PROVIDER=${want} (use auto, cursor, or gemini)"
      exit 1
      ;;
  esac
}

PROVIDER="$(pick_provider)"
if [[ -z "$PROVIDER" ]]; then
  echo "::error::No advisory review provider configured. Set CURSOR_API_KEY and/or GEMINI_API_KEY (or GOOGLE_API_KEY)."
  exit 1
fi

out_file="$WORKDIR/advisory-body.md"
case "$PROVIDER" in
  cursor)
    if [[ -z "${CURSOR_API_KEY:-}" ]]; then
      echo "::error::ADVISORY_REVIEW_PROVIDER=cursor but CURSOR_API_KEY is unset"
      exit 1
    fi
    npm install --no-save @cursor/sdk >/dev/null 2>&1
    node "$SCRIPT_DIR/run-advisory-cursor.mjs" "$prompt_file" "$out_file"
    ;;
  gemini)
    python3 "$SCRIPT_DIR/run-advisory-gemini.py" "$prompt_file" "$out_file"
    ;;
esac

# Normalize: ensure marker present; inject head/provider if model omitted them.
if ! grep -q "$MARKER" "$out_file"; then
  {
    printf '%s\n\n' "$MARKER"
    cat "$out_file"
  } >"$out_file.tmp"
  mv "$out_file.tmp" "$out_file"
fi

if ! grep -q "Head:" "$out_file"; then
  sed -i "s/## Advisory Review Snapshot/## Advisory Review Snapshot\n\nHead: \`${HEAD_SHA}\`\nProvider: \`${PROVIDER}\`/" "$out_file" 2>/dev/null || true
fi

"$SCRIPT_DIR/upsert-pr-comment.sh" "$PR" "$MARKER" "$out_file"
echo "Advisory snapshot posted via ${PROVIDER} for PR #${PR} @ ${HEAD_SHA}"
