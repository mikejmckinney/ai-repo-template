#!/usr/bin/env bash
# Build post-merge retro LLM prompt from collected evidence.
# Usage: assemble-retro-prompt.sh <pr> <workdir> <bounded|full-evidence> <output-prompt.md>
set -euo pipefail

PR="${1:-}"
WORKDIR="${2:-}"
PROMPT_MODE="${3:-bounded}"
OUT_PROMPT="${4:-}"

usage() {
  echo "Usage: assemble-retro-prompt.sh <pr> <workdir> <bounded|full-evidence> <output-prompt.md>" >&2
  exit 2
}

[[ -n "$PR" && -n "$WORKDIR" && -n "$OUT_PROMPT" ]] || usage
[[ "$PROMPT_MODE" == "bounded" || "$PROMPT_MODE" == "full-evidence" ]] || usage
[[ -d "$WORKDIR" ]] || {
  echo "Workdir not found: $WORKDIR" >&2
  exit 1
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/workflows/lib"
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
context_profile="${POSTMERGE_RETRO_CONTEXT_PROFILE:-full}"

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

DEFAULT_DIFF_LIMIT=300000
diff_limit="$(parse_positive_int POSTMERGE_RETRO_DIFF_LIMIT "$DEFAULT_DIFF_LIMIT" "${POSTMERGE_RETRO_DIFF_LIMIT:-}")"
head_file_cap=12000
head_total_cap=120000

pr_json="$(cat "$WORKDIR/pr.json")"
pr_title="$(printf '%s' "$pr_json" | jq -r '.title // ""')"
pr_body=""
if [[ "$PROMPT_MODE" == "bounded" ]]; then
  pr_body="$(printf '%s' "$pr_json" | jq -r '.body // ""')"
fi
pr_url="$(printf '%s' "$pr_json" | jq -r '.html_url // ""')"
HEAD_SHA="$(jq -r .head.sha "$WORKDIR/pr.json")"
MERGE_SHA="$(jq -r '.merge_commit_sha // .head.sha' "$WORKDIR/pr.json")"
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

reviews_json_compact=""
comments_json_compact=""
if [[ "$PROMPT_MODE" == "bounded" ]]; then
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
fi

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

{
  cat "$REPO_ROOT/.github/prompts/post-merge-retro.md"
  echo ""
  echo "---"
  echo ""
  echo "## Repo startup context (automation-supplied, catalog-driven ${context_profile} + path triggers)"
  echo ""
  echo "- Context profile: \`${context_profile}\`"
  if [[ "$PROMPT_MODE" == "full-evidence" ]]; then
    echo "- Context files addressable: \`${context_file_count}\`"
    echo "- Context bytes available: \`${context_bytes}\`"
  else
    echo "- Context files injected: \`${context_file_count}\`"
    echo "- Context bytes injected: \`${context_bytes}\`"
  fi
  echo "- Evidence prompt mode: \`${PROMPT_MODE}\`"
  echo ""
  if [[ "$PROMPT_MODE" == "full-evidence" ]]; then
    echo "- Context inventory: \`${WORKDIR}/context-files.txt\`"
    echo ""
    echo "Read these required startup files from the checked-out repository:"
    echo ""
    for rel in "${context_files[@]}"; do
      # shellcheck disable=SC2016 # Backticks are Markdown delimiters.
      printf -- '- `%s`\n' "$rel"
    done
    echo ""
  else
    for rel in "${context_files[@]}"; do
      echo "### ${rel}"
      echo ""
      cat "$REPO_ROOT/$rel"
      echo ""
    done
  fi
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
  if [[ "$PROMPT_MODE" == "full-evidence" ]]; then
    echo "- Diff bytes injected: \`0\`"
  else
    echo "- Diff bytes included in bounded excerpt: \`${diff_included}\`"
  fi
  echo "- Diff truncated at cap: \`${truncated_word}\`"
  echo ""
  if [[ "$PROMPT_MODE" == "full-evidence" ]]; then
    echo "### Required evidence inventory"
    echo ""
    for evidence_file in diff.patch pr.json summary.txt changed-files.txt reviews.json review-comments.json checks.json advisory-comments.md prior-inbox.md; do
      if [[ -f "$WORKDIR/$evidence_file" ]]; then
        evidence_size="$(wc -c <"$WORKDIR/$evidence_file" | tr -d ' ')"
        # shellcheck disable=SC2016 # Backticks are Markdown delimiters.
        printf -- '- `%s/%s` (%s bytes)\n' "$WORKDIR" "$evidence_file" "$evidence_size"
      fi
    done
    echo ""
    echo "Read every listed evidence source. The deterministic collector supplies check runs in checks.json using the workflow token; use read-only GitHub tools only to close remaining inventory gaps."
    echo ""
  else
    echo "### Collection summary"
    echo ""
    cat "$WORKDIR/summary.txt"
    echo ""
    echo "### PR body"
    echo ""
    printf '%s\n' "$pr_body"
    echo ""
  fi
  echo "### Changed files"
  echo ""
  sed 's/^/- /' "$WORKDIR/changed-files.txt"
  echo ""
  if [[ "$PROMPT_MODE" != "full-evidence" ]]; then
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
  fi
  if [[ "$PROMPT_MODE" != "full-evidence" && -s "$WORKDIR/advisory-comments.md" ]]; then
    echo "### Advisory snapshots"
    echo ""
    cat "$WORKDIR/advisory-comments.md"
    echo ""
  fi
  if [[ "$PROMPT_MODE" != "full-evidence" && -s "$WORKDIR/prior-inbox.md" ]]; then
    echo "### Feedback inbox comments"
    echo ""
    cat "$WORKDIR/prior-inbox.md"
    echo ""
  fi
  echo "### Current main (HEAD) state for PR-touched paths"
  echo ""
  echo "Compare against this section before emitting findings. **Do not emit a finding** when the issue is already resolved on \`main\` HEAD."
  echo ""
  if [[ "$PROMPT_MODE" == "full-evidence" ]]; then
    echo "For paths below marked _read from repo_, use your tools to read the **full** file on \`main\` HEAD — do not rely on excerpts alone."
    echo ""
  fi
  head_total=0
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    target="$REPO_ROOT/$rel"
    if [[ ! -f "$target" ]]; then
      echo "#### \`${rel}\`"
      echo ""
      echo "_File absent on main HEAD._"
      echo ""
      continue
    fi
    size="$(wc -c <"$target" | tr -d ' ')"
    if [[ "$PROMPT_MODE" == "full-evidence" ]]; then
      echo "#### \`${rel}\`"
      echo ""
      echo "_Full file on main HEAD (${size} bytes) — **read from repo**: \`${rel}\`_"
      echo ""
      continue
    fi
    if [[ "$head_total" -ge "$head_total_cap" ]]; then
      echo "_HEAD snapshot budget exhausted; remaining paths omitted._"
      break
    fi
    take="$size"
    if [[ "$take" -gt "$head_file_cap" ]]; then
      take="$head_file_cap"
    fi
    if [[ $((head_total + take)) -gt "$head_total_cap" ]]; then
      take=$((head_total_cap - head_total))
    fi
    echo "#### \`${rel}\`"
    echo ""
    echo '```'
    head -c "$take" "$target"
    if [[ "$take" -lt "$size" ]]; then
      printf '\n... (truncated; %s bytes total on HEAD)\n' "$size"
    fi
    echo '```'
    echo ""
    head_total=$((head_total + take))
  done <"$WORKDIR/changed-files.txt"

  if [[ "$PROMPT_MODE" == "full-evidence" ]]; then
    echo "### Diff (full — read from workspace)"
    echo ""
    echo "The complete unified diff is at \`${WORKDIR}/diff.patch\` (**${full_diff_bytes}** bytes)."
    echo "Use your tools to read this file in full. **Do not** rely on a truncated excerpt."
    echo ""
  else
    echo "### Diff (truncated excerpt)"
    echo ""
    echo '```diff'
    printf '%s\n' "$diff_text"
    echo '```'
    echo ""
  fi
  echo "---"
  echo ""
  echo "## Output instruction (automation-supplied)"
  echo ""
  echo "Respond with **JSON only** matching the required shape. Set \`pr\` to ${PR}."
  if [[ "$PROMPT_MODE" == "full-evidence" ]]; then
    echo 'Add `"evidence_complete": true` only after reading every required evidence source, the complete diff, and every PR-touched path on current `main` HEAD.'
  fi
} >"$OUT_PROMPT"
