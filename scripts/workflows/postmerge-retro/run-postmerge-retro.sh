#!/usr/bin/env bash
# scripts/workflows/postmerge-retro/run-postmerge-retro.sh — post-merge retro dispatch.
set -euo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

PR="${1:-${PR_NUMBER:-}}"
CREATE_ISSUES="${2:-${CREATE_ISSUES:-true}}"

usage() {
  echo "Usage: run-postmerge-retro.sh <pr-number> [create_issues=true|false]" >&2
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
ADVISORY_DIR="$REPO_ROOT/scripts/workflows/advisory-review"
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

DEFAULT_DIFF_LIMIT=300000
diff_limit="$(parse_positive_int POSTMERGE_RETRO_DIFF_LIMIT "$DEFAULT_DIFF_LIMIT" "${POSTMERGE_RETRO_DIFF_LIMIT:-}")"
context_profile="${POSTMERGE_RETRO_CONTEXT_PROFILE:-full}"

bash "$SCRIPT_DIR/collect-postmerge-evidence.sh" "$PR" "$WORKDIR"

merged_at="$(jq -r '.merged_at // ""' "$WORKDIR/pr.json")"
if [[ -z "$merged_at" || "$merged_at" == "null" ]]; then
  echo "::error::PR #${PR} is not merged (merged_at=${merged_at})"
  exit 1
fi

HEAD_SHA="$(jq -r .head.sha "$WORKDIR/pr.json")"
MERGE_SHA="$(jq -r '.merge_commit_sha // .head.sha' "$WORKDIR/pr.json")"

pr_json="$(cat "$WORKDIR/pr.json")"
pr_title="$(printf '%s' "$pr_json" | jq -r '.title // ""')"
pr_body="$(printf '%s' "$pr_json" | jq -r '.body // ""')"
pr_url="$(printf '%s' "$pr_json" | jq -r '.html_url // ""')"
merged_at="$(printf '%s' "$pr_json" | jq -r '.merged_at // ""')"
labels="$(jq -r '.[]?.name // empty' "$WORKDIR/labels.json" 2>/dev/null | paste -sd ', ' - || true)"

full_diff_bytes="$(wc -c <"$WORKDIR/diff.patch" | tr -d ' ')"
truncated=false
diff_included="$full_diff_bytes"
if [[ "$full_diff_bytes" -gt "$diff_limit" ]]; then
  truncated=true
  diff_included="$diff_limit"
fi
diff_text="$(head -c "$diff_limit" "$WORKDIR/diff.patch")"
truncated_word="no"
[[ "$truncated" == "true" ]] && truncated_word="yes"

LIB_DIR="$REPO_ROOT/scripts/workflows/lib"
reviews_json_compact="$(
  python3 "$LIB_DIR/prompt_helpers.py" cap-json \
    --input "$WORKDIR/reviews.json" \
    --jq-filter 'map({id, user: (.user?.login // null), body, state, commit_id})' \
    --max-bytes 120000
)"
comments_json_compact="$(
  python3 "$LIB_DIR/prompt_helpers.py" cap-json \
    --input "$WORKDIR/review-comments.json" \
    --jq-filter 'map({id, path, line, user: (.user?.login // null), body})' \
    --max-bytes 120000
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

# Retro prompt cites ADR-027; inject after catalog selection (not in full-rules floor).
RETRO_EXTRA_CONTEXT=(
  "docs/decisions/adr-027-opportunity-feedback-channel.md"
)
for extra in "${RETRO_EXTRA_CONTEXT[@]}"; do
  found=0
  for rel in "${context_files[@]}"; do
    [[ "$rel" == "$extra" ]] && found=1 && break
  done
  if [[ "$found" -eq 0 && -f "$REPO_ROOT/$extra" ]]; then
    context_files+=("$extra")
    context_bytes=$((context_bytes + $(wc -c <"$REPO_ROOT/$extra" | tr -d ' ')))
    context_file_count="${#context_files[@]}"
  fi
done

prompt_file="$WORKDIR/prompt.md"
{
  cat "$REPO_ROOT/.github/prompts/post-merge-retro.md"
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
  echo "## Merged PR context (automation-supplied)"
  echo ""
  echo "- Repository: \`${REPO}\`"
  echo "- PR: #${PR} — ${pr_title}"
  echo "- URL: ${pr_url}"
  echo "- Head SHA: \`${HEAD_SHA}\`"
  echo "- Merge commit SHA: \`${MERGE_SHA}\`"
  echo "- Merged at: ${merged_at}"
  echo "- Labels at merge: \`${labels}\`"
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
  echo "### Formal PR reviews (JSON excerpt)"
  echo ""
  echo '```json'
  printf '%s\n' "$reviews_json_compact"
  echo ""
  echo '```'
  echo ""
  echo "### Inline review comments (JSON excerpt)"
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
    echo "### Feedback inbox comments"
    echo ""
    cat "$WORKDIR/prior-inbox.md"
    echo ""
  fi
  echo "### Diff (truncated excerpt)"
  echo ""
  echo '```diff'
  printf '%s\n' "$diff_text"
  echo '```'
  echo ""
  echo "---"
  echo ""
  echo "## Output instruction (automation-supplied)"
  echo ""
  echo "Respond with **JSON only** matching the required shape. Set \`pr\` to ${PR}."
} >"$prompt_file"

has_cursor=0
has_gemini=0
[[ -n "${CURSOR_API_KEY:-}" ]] && has_cursor=1
[[ -n "${GEMINI_API_KEY:-}" || -n "${GOOGLE_API_KEY:-}" ]] && has_gemini=1

pick_provider() {
  local want="${POSTMERGE_RETRO_PROVIDER:-${ADVISORY_REVIEW_PROVIDER:-auto}}"
  if [[ "$want" == "antigravity" ]]; then
    echo "::notice::ADVISORY_REVIEW_PROVIDER=antigravity is advisory-only; post-merge retro uses auto (cursor, else gemini)." >&2
    want=auto
  fi
  case "$want" in
    cursor) echo cursor ;;
    gemini) echo gemini ;;
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
      echo "::error::Unknown POSTMERGE_RETRO_PROVIDER=${want} (use auto, cursor, or gemini)"
      exit 1
      ;;
  esac
}

PROVIDER="$(pick_provider)"
if [[ -z "$PROVIDER" ]]; then
  echo "::error::No post-merge retro provider configured. Set CURSOR_API_KEY and/or GEMINI_API_KEY (or GOOGLE_API_KEY)."
  exit 1
fi

llm_raw="$WORKDIR/llm-output.txt"
case "$PROVIDER" in
  cursor)
    npm install --no-save @cursor/sdk >/dev/null 2>&1
    CURSOR_ADVISORY_MODEL="${POSTMERGE_RETRO_MODEL:-${CURSOR_ADVISORY_MODEL:-composer-2.5}}" \
      node "$ADVISORY_DIR/run-advisory-cursor.mjs" "$prompt_file" "$llm_raw"
    ;;
  gemini)
    GEMINI_ADVISORY_MODEL="${POSTMERGE_RETRO_MODEL:-${GEMINI_ADVISORY_MODEL:-gemini-3.5-flash}}" \
      python3 "$ADVISORY_DIR/run-advisory-gemini.py" "$prompt_file" "$llm_raw"
    ;;
esac

retro_json="$WORKDIR/retro.json"
python3 "$SCRIPT_DIR/extract-retro-json.py" "$llm_raw" "$PR" "$retro_json"
python3 "$SCRIPT_DIR/validate-postmerge-retro.py" "$retro_json"

cp -f "$retro_json" "$WORKDIR/retro.json.final"
if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
  artifact_dir="${GITHUB_WORKSPACE}/.artifacts/postmerge-retro/pr-${PR}"
  mkdir -p "$artifact_dir"
  cp -f "$retro_json" "$artifact_dir/retro.json"
  cp -f "$llm_raw" "$artifact_dir/llm-output.txt" 2>/dev/null || true
  cp -f "$WORKDIR/pr.json" "$artifact_dir/pr.json" 2>/dev/null || true
fi
echo "Post-merge retro JSON written for PR #${PR} via ${PROVIDER}"

if [[ "$CREATE_ISSUES" == "true" || "$CREATE_ISSUES" == "1" ]]; then
  bash "$SCRIPT_DIR/postmerge-retro-create-issues.sh" "$retro_json"
else
  echo "CREATE_ISSUES=${CREATE_ISSUES}; skipping issue creation"
  cat "$retro_json"
fi

echo "Post-merge retrospective complete for PR #${PR} @ merge ${MERGE_SHA}"
