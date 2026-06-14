#!/usr/bin/env bash
# scripts/workflows/pr-feedback/run-feedback-consolidation.sh — final feedback inbox dispatch.
set -euo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

PR="${1:-${PR_NUMBER:-}}"
HEAD_SHA="${2:-${HEAD_SHA:-}}"

usage() {
  echo "Usage: run-feedback-consolidation.sh <pr-number> [head-sha]" >&2
  exit 2
}

[[ -n "$PR" ]] || usage

parse_positive_int() {
  local name="$1" default="$2" raw="${3:-}"
  if [[ -z "$raw" ]]; then
    echo "$default"
    return
  fi
  if [[ "$raw" =~ ^[0-9]+$ ]] && [[ $((10#$raw)) -gt 0 ]]; then
    echo "$((10#$raw))"
    return
  fi
  echo "::warning::Invalid ${name}=${raw}; using default ${default}" >&2
  echo "$default"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$REPO_ROOT/scripts/workflows/lib"
ADVISORY_DIR="$REPO_ROOT/scripts/workflows/advisory-review"
MARKER='<!-- ai-feedback-inbox:v1 -->'
MARKER_TOKEN='ai-feedback-inbox:v1'
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

DEFAULT_DIFF_LIMIT=300000
DEFAULT_COMMENT_LIMIT=65000
DEFAULT_JSON_CAP=120000

diff_limit="$(parse_positive_int FINALIZE_REVIEW_DIFF_LIMIT "$DEFAULT_DIFF_LIMIT" "${FINALIZE_REVIEW_DIFF_LIMIT:-}")"
comment_limit="$(parse_positive_int FINALIZE_REVIEW_COMMENT_LIMIT "$DEFAULT_COMMENT_LIMIT" "${FINALIZE_REVIEW_COMMENT_LIMIT:-}")"
json_cap="$(parse_positive_int FINALIZE_REVIEW_JSON_CAP "$DEFAULT_JSON_CAP" "${FINALIZE_REVIEW_JSON_CAP:-}")"
context_profile="${FINALIZE_CONTEXT_PROFILE:-pr-review}"

bash "$SCRIPT_DIR/collect-pr-feedback.sh" "$PR" "$WORKDIR"

HEAD_SHA="$(jq -r .head.sha "$WORKDIR/pr.json")"

pr_json="$(cat "$WORKDIR/pr.json")"
pr_title="$(printf '%s' "$pr_json" | jq -r '.title // ""')"
pr_body="$(printf '%s' "$pr_json" | jq -r '.body // ""')"
pr_url="$(printf '%s' "$pr_json" | jq -r '.html_url // ""')"
labels="$(jq -r '.[]?.name // empty' "$WORKDIR/labels.json" 2>/dev/null | paste -sd ', ' - || true)"

full_diff_bytes="$(wc -c <"$WORKDIR/diff.patch" | tr -d ' ')"
changed_file_count="$(wc -l <"$WORKDIR/changed-files.txt" | tr -d ' ')"
if [[ "$full_diff_bytes" -eq 0 && "$changed_file_count" -gt 0 ]]; then
  echo "::warning::Finalize diff is empty (${changed_file_count} changed files listed) — review quality may be degraded (fetch/sha mismatch?)" >&2
fi

truncated=false
diff_included="$full_diff_bytes"
if [[ "$full_diff_bytes" -gt "$diff_limit" ]]; then
  truncated=true
  diff_included="$diff_limit"
fi
diff_text="$(head -c "$diff_limit" "$WORKDIR/diff.patch")"
truncated_word="no"
[[ "$truncated" == "true" ]] && truncated_word="yes"

reviews_json_compact="$(
  python3 "$LIB_DIR/prompt_helpers.py" cap-json \
    --input "$WORKDIR/reviews.json" \
    --jq-filter 'map({id, user: (.user?.login // null), body, state, commit_id})' \
    --max-bytes "$json_cap"
)"
comments_json_compact="$(
  python3 "$LIB_DIR/prompt_helpers.py" cap-json \
    --input "$WORKDIR/review-comments.json" \
    --jq-filter 'map({id, path, line, user: (.user?.login // null), body, diff_hunk})' \
    --max-bytes "$json_cap"
)"

if ! python3 "$LIB_DIR/prompt_helpers.py" select-context \
  --profile "$context_profile" \
  --changed-files "$WORKDIR/changed-files.txt" >"$WORKDIR/context-files.txt"; then
  echo "::error::select-context failed for profile ${context_profile}" >&2
  exit 1
fi
if [[ ! -s "$WORKDIR/context-files.txt" ]]; then
  echo "::error::select-context returned no files for profile ${context_profile}" >&2
  exit 1
fi
mapfile -t context_files <"$WORKDIR/context-files.txt"

context_file_count="${#context_files[@]}"
context_bytes=0
for rel in "${context_files[@]}"; do
  if [[ -f "$REPO_ROOT/$rel" ]]; then
    context_bytes=$((context_bytes + $(wc -c <"$REPO_ROOT/$rel" | tr -d ' ')))
  fi
done

prompt_file="$WORKDIR/prompt.md"
{
  cat "$REPO_ROOT/.github/prompts/pr-final-feedback-consolidation.md"
  echo ""
  echo "---"
  echo ""
  echo "## Repo startup context (automation-supplied, catalog-driven ${context_profile} + path triggers)"
  echo ""
  echo "- Context profile: \`${context_profile}\`"
  echo "- Context files injected: \`${context_file_count}\`"
  echo "- Context bytes injected: \`${context_bytes}\`"
  echo ""
  for rel in "${context_files[@]}"; do
    echo "### ${rel}"
    echo ""
    cat "$REPO_ROOT/$rel"
    echo ""
  done
  echo "---"
  echo ""
  echo "## PR context (automation-supplied)"
  echo ""
  echo "- Repository: \`${REPO}\`"
  echo "- PR: #${PR} — ${pr_title}"
  echo "- URL: ${pr_url}"
  echo "- Head SHA under review: \`${HEAD_SHA}\`"
  echo "- Labels: \`${labels}\`"
  echo "- Diff bytes total: \`${full_diff_bytes}\`"
  echo "- Diff bytes included: \`${diff_included}\`"
  echo "- Diff truncated: \`${truncated_word}\`"
  echo ""
  echo "### Collection summary"
  echo ""
  cat "$WORKDIR/summary.txt"
  echo ""
  echo "### PR body"
  echo ""
  printf '%s\n' "$pr_body"
  echo ""
  echo "### Changed files"
  echo ""
  sed 's/^/- /' "$WORKDIR/changed-files.txt"
  echo ""
  echo "### Formal PR reviews (JSON)"
  echo ""
  echo '```json'
  printf '%s\n' "$reviews_json_compact"
  echo ""
  echo '```'
  echo ""
  echo "### Inline review comments (JSON)"
  echo ""
  echo '```json'
  printf '%s\n' "$comments_json_compact"
  echo ""
  echo '```'
  echo ""
  if [[ -s "$WORKDIR/advisory-comments.md" ]]; then
    echo "### Advisory snapshots"
    echo ""
    cat "$WORKDIR/advisory-comments.md"
    echo ""
  fi
  if [[ -s "$WORKDIR/prior-inbox.md" ]]; then
    echo "### Prior feedback inbox"
    echo ""
    cat "$WORKDIR/prior-inbox.md"
    echo ""
  fi
  echo "### Diff (truncated excerpt for prompt)"
  echo ""
  echo '```diff'
  printf '%s\n' "$diff_text"
  echo '```'
} >"$prompt_file"

has_cursor=0
has_gemini=0
[[ -n "${CURSOR_API_KEY:-}" ]] && has_cursor=1
[[ -n "${GEMINI_API_KEY:-}" || -n "${GOOGLE_API_KEY:-}" ]] && has_gemini=1

pick_provider() {
  local want="${FINALIZE_REVIEW_PROVIDER:-${ADVISORY_REVIEW_PROVIDER:-auto}}"
  if [[ "$want" == "antigravity" ]]; then
    echo "::notice::ADVISORY_REVIEW_PROVIDER=antigravity is advisory-only; finalize uses auto (cursor, else gemini)." >&2
    want=auto
  fi
  case "$want" in
    cursor)
      echo cursor
      ;;
    gemini)
      echo gemini
      ;;
    auto)
      if [[ "$has_cursor" -eq 1 ]]; then
        echo cursor
      elif [[ "$has_gemini" -eq 1 ]]; then
        echo gemini
      else
        echo ""
      fi
      ;;
    *)
      echo "::error::Unknown FINALIZE_REVIEW_PROVIDER=${want} (use auto, cursor, or gemini)"
      exit 1
      ;;
  esac
}

PROVIDER="$(pick_provider)"
if [[ -z "$PROVIDER" ]]; then
  echo "::error::No finalize provider configured. Set CURSOR_API_KEY and/or GEMINI_API_KEY (or GOOGLE_API_KEY)."
  exit 1
fi

case "$PROVIDER" in
  cursor)
    [[ "$has_cursor" -eq 1 ]] || {
      echo "::error::FINALIZE_REVIEW_PROVIDER=cursor but CURSOR_API_KEY is unset"
      exit 1
    }
    ;;
  gemini)
    [[ "$has_gemini" -eq 1 ]] || {
      echo "::error::FINALIZE_REVIEW_PROVIDER=gemini but GEMINI_API_KEY/GOOGLE_API_KEY is unset"
      exit 1
    }
    ;;
esac

out_file="$WORKDIR/inbox-body.md"
run_gemini() {
  GEMINI_ADVISORY_MODEL="${GEMINI_FINALIZE_MODEL:-${GEMINI_ADVISORY_MODEL:-gemini-3.5-flash}}" \
    python3 "$ADVISORY_DIR/run-advisory-gemini.py" "$prompt_file" "$out_file"
}

case "$PROVIDER" in
  cursor)
    if ! npm install --no-save @cursor/sdk >"$WORKDIR/npm-install.log" 2>&1; then
      echo "::error::npm install @cursor/sdk failed for finalize Cursor path" >&2
      tail -20 "$WORKDIR/npm-install.log" >&2 || true
      exit 1
    fi
    echo "::notice::Installed @cursor/sdk for finalize Cursor path"
    CURSOR_ADVISORY_MODEL="${CURSOR_FINALIZE_MODEL:-${CURSOR_ADVISORY_MODEL:-composer-2.5}}" \
      node "$ADVISORY_DIR/run-advisory-cursor.mjs" "$prompt_file" "$out_file"
    ;;
  gemini)
    run_gemini
    ;;
esac

if ! grep -qF "$MARKER" "$out_file"; then
  {
    printf '%s\n\n' "$MARKER"
    cat "$out_file"
  } >"$out_file.tmp"
  mv "$out_file.tmp" "$out_file"
fi

awk -v sha="$HEAD_SHA" '
  /^Head reviewed:/ { next }
  /^Mode:/ { next }
  { print }
' "$out_file" >"$out_file.tmp"
mv "$out_file.tmp" "$out_file"

if grep -qE '^#{1,3}[[:space:]]*Final Feedback Inbox' "$out_file"; then
  awk -v sha="$HEAD_SHA" '
    /^Head reviewed:/ { next }
    /^Mode:/ { next }
    /^#{1,3}[[:space:]]*Final Feedback Inbox/ {
      print "## Final Feedback Inbox"
      print ""
      print "Head reviewed: `" sha "`"
      print "Mode: final consolidation, non-blocking unless a human applies `review:blocking-ai`"
      next
    }
    { print }
  ' "$out_file" >"$out_file.tmp"
  mv "$out_file.tmp" "$out_file"
fi

if ! grep -q '^Head reviewed:' "$out_file"; then
  {
    cat "$out_file"
    echo ""
    echo "## Final Feedback Inbox (workflow metadata)"
    echo ""
    echo "Head reviewed: \`${HEAD_SHA}\`"
    echo "Mode: final consolidation, non-blocking unless a human applies \`review:blocking-ai\`"
  } >"$out_file.tmp"
  mv "$out_file.tmp" "$out_file"
fi

comment_bytes="$(wc -c <"$out_file" | tr -d ' ')"
if [[ "$comment_bytes" -gt "$comment_limit" ]]; then
  header_file="$WORKDIR/cap-header.md"
  cat >"$header_file" <<EOF
$MARKER

## Final Feedback Inbox

Head reviewed: \`${HEAD_SHA}\`
Mode: final consolidation, non-blocking unless a human applies \`review:blocking-ai\`

⚠️ Feedback inbox output exceeded ${comment_limit} bytes and was truncated by automation.

EOF
  header_bytes="$(wc -c <"$header_file" | tr -d ' ')"
  body_budget=$((comment_limit - header_bytes))
  if [[ "$body_budget" -lt 0 ]]; then
    body_budget=0
  fi
  grep -v 'ai-feedback-inbox:v1' "$out_file" >"$WORKDIR/body-stripped.md" || cp "$out_file" "$WORKDIR/body-stripped.md"
  {
    cat "$header_file"
    head -c "$body_budget" "$WORKDIR/body-stripped.md" | iconv -f utf-8 -t utf-8 -c
  } >"$out_file.tmp"
  mv "$out_file.tmp" "$out_file"
  echo "::warning::Feedback inbox truncated to ${comment_limit} bytes (was ${comment_bytes})" >&2
fi

"$ADVISORY_DIR/upsert-pr-comment.sh" "$PR" "$MARKER" "$out_file"
echo "Final feedback inbox posted via ${PROVIDER} for PR #${PR} @ ${HEAD_SHA}"
