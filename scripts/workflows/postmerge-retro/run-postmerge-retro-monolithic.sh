#!/usr/bin/env bash
# Daily post-merge retro: one LLM call with bundled multi-PR evidence (benchmark Arm B).
set -euo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADVISORY_DIR="$REPO_ROOT/scripts/workflows/advisory-review"
LIB_DIR="$REPO_ROOT/scripts/workflows/lib"

RUN_DATE="${RUN_DATE:-$(date -u +%Y-%m-%d)}"
ARTIFACT_ROOT="${GITHUB_WORKSPACE:-$REPO_ROOT}/.artifacts/postmerge-retro/daily-${RUN_DATE}"
mkdir -p "$ARTIFACT_ROOT"
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

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

mapfile -t SELECTED_PRS < <(bash "$SCRIPT_DIR/daily-retro-select-prs.sh" || true)
if [[ ${#SELECTED_PRS[@]} -eq 0 ]]; then
  if [[ ! -f "$ARTIFACT_ROOT/findings-count.txt" ]]; then
    echo "No merges to main in the last 24h; skipping daily retro"
    echo "0" >"$ARTIFACT_ROOT/findings-count.txt"
  fi
  exit 0
fi

DEFAULT_DIFF_LIMIT=300000
diff_limit="$(parse_positive_int POSTMERGE_RETRO_DIFF_LIMIT "$DEFAULT_DIFF_LIMIT" "${POSTMERGE_RETRO_DIFF_LIMIT:-}")"
per_pr_diff="$(parse_positive_int POSTMERGE_RETRO_MONOLITHIC_DIFF_PER_PR "$((diff_limit / 4))" "${POSTMERGE_RETRO_MONOLITHIC_DIFF_PER_PR:-}")"
context_profile="${POSTMERGE_RETRO_CONTEXT_PROFILE:-full}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

EVIDENCE_ROOT="$WORKDIR/evidence"
mkdir -p "$EVIDENCE_ROOT"
ALL_CHANGED="$WORKDIR/all-changed-files.txt"
: >"$ALL_CHANGED"

declare -A MERGE_SHAS=()

for pr in "${SELECTED_PRS[@]}"; do
  pr_dir="$EVIDENCE_ROOT/pr-${pr}"
  mkdir -p "$pr_dir"
  echo "Collecting evidence for PR #${pr}..."
  bash "$SCRIPT_DIR/collect-postmerge-evidence.sh" "$pr" "$pr_dir"
  merged_at="$(jq -r '.merged_at // ""' "$pr_dir/pr.json")"
  if [[ -z "$merged_at" || "$merged_at" == "null" ]]; then
    echo "::error::PR #${pr} is not merged (merged_at=${merged_at})"
    exit 1
  fi
  merge_sha="$(jq -r '.merge_commit_sha // .head.sha' "$pr_dir/pr.json")"
  MERGE_SHAS["$pr"]="$merge_sha"
  if [[ -s "$pr_dir/changed-files.txt" ]]; then
    cat "$pr_dir/changed-files.txt" >>"$ALL_CHANGED"
  fi
done

sort -u "$ALL_CHANGED" -o "$ALL_CHANGED"

if ! python3 "$LIB_DIR/prompt_helpers.py" select-context \
  --profile "$context_profile" \
  --changed-files "$ALL_CHANGED" >"$WORKDIR/context-files.txt"; then
  echo "::error::select-context failed for profile ${context_profile}" >&2
  exit 1
fi
mapfile -t context_files <"$WORKDIR/context-files.txt"
RETRO_EXTRA_CONTEXT=("docs/decisions/adr-027-opportunity-feedback-channel.md")
for extra in "${RETRO_EXTRA_CONTEXT[@]}"; do
  found=0
  for rel in "${context_files[@]}"; do
    [[ "$rel" == "$extra" ]] && found=1 && break
  done
  if [[ "$found" -eq 0 && -f "$REPO_ROOT/$extra" ]]; then
    context_files+=("$extra")
  fi
done

append_head_snapshots() {
  local changed_file="$1"
  local head_file_cap=8000
  local head_total_cap=80000
  local head_total=0
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    local target="$REPO_ROOT/$rel"
    if [[ ! -f "$target" ]]; then
      echo "#### \`${rel}\`"
      echo ""
      echo "_File absent on main HEAD._"
      echo ""
      continue
    fi
    local size
    size="$(wc -c <"$target" | tr -d ' ')"
    if [[ "$head_total" -ge "$head_total_cap" ]]; then
      echo "_HEAD snapshot budget exhausted; remaining paths omitted._"
      break
    fi
    local take="$size"
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
  done <"$changed_file"
}

prompt_file="$WORKDIR/prompt.md"
{
  cat "$REPO_ROOT/.github/prompts/post-merge-retro.md"
  echo ""
  echo "---"
  echo ""
  echo "## Monolithic batch mode (automation-supplied)"
  echo ""
  echo "You are reviewing **multiple merged PRs in one pass**. Output one JSON object with a \`retros\` array — one element per PR, each matching the single-PR shape from the prompt above."
  echo ""
  echo "### Required monolithic JSON shape"
  echo ""
  echo '```json'
  cat <<'JSON'
{
  "prs": [90, 87],
  "retros": [
    {
      "pr": 90,
      "summary": "brief summary",
      "follow_up_issues": [],
      "adr_updates": [],
      "context_pack_updates": []
    }
  ]
}
JSON
  echo '```'
  echo ""
  echo "PRs in this batch: ${SELECTED_PRS[*]}"
  echo ""
  echo "## Repo startup context (catalog-driven ${context_profile} + path triggers)"
  echo ""
  for rel in "${context_files[@]}"; do
    echo "### ${rel}"
    echo ""
    [[ -f "$REPO_ROOT/$rel" ]] && cat "$REPO_ROOT/$rel"
    echo ""
  done
  echo "---"
  echo ""

  for pr in "${SELECTED_PRS[@]}"; do
    pr_dir="$EVIDENCE_ROOT/pr-${pr}"
    pr_json="$(cat "$pr_dir/pr.json")"
    pr_title="$(printf '%s' "$pr_json" | jq -r '.title // ""')"
    pr_body="$(printf '%s' "$pr_json" | jq -r '.body // ""')"
    pr_url="$(printf '%s' "$pr_json" | jq -r '.html_url // ""')"
    merged_at="$(printf '%s' "$pr_json" | jq -r '.merged_at // ""')"
    labels="$(jq -r '.[]?.name // empty' "$pr_dir/labels.json" 2>/dev/null | paste -sd ', ' - || true)"
    full_diff_bytes="$(wc -c <"$pr_dir/diff.patch" | tr -d ' ')"
    truncated=false
    diff_included="$full_diff_bytes"
    if [[ "$full_diff_bytes" -gt "$per_pr_diff" ]]; then
      truncated=true
      diff_included="$per_pr_diff"
    fi
    diff_text="$(head -c "$per_pr_diff" "$pr_dir/diff.patch")"
    truncated_word="no"
    [[ "$truncated" == "true" ]] && truncated_word="yes"

    reviews_json_compact="$(
      python3 "$LIB_DIR/prompt_helpers.py" cap-json \
        --input "$pr_dir/reviews.json" \
        --jq-filter 'map({id, user: (.user?.login // null), body, state, commit_id})' \
        --max-bytes 80000
    )"
    comments_json_compact="$(
      python3 "$LIB_DIR/prompt_helpers.py" cap-json \
        --input "$pr_dir/review-comments.json" \
        --jq-filter 'map({id, path, line, user: (.user?.login // null), body})' \
        --max-bytes 80000
    )"

    echo "## Merged PR #${pr} bundle"
    echo ""
    echo "- Repository: \`${REPO}\`"
    echo "- PR: #${pr} — ${pr_title}"
    echo "- URL: ${pr_url}"
    echo "- Merge commit SHA: \`${MERGE_SHAS[$pr]}\`"
    echo "- Merged at: ${merged_at}"
    echo "- Labels at merge: \`${labels}\`"
    echo "- Diff bytes total: \`${full_diff_bytes}\`"
    echo "- Diff bytes included: \`${diff_included}\`"
    echo "- Diff truncated: \`${truncated_word}\`"
    echo ""
    echo "### Collection summary"
    echo ""
    cat "$pr_dir/summary.txt"
    echo ""
    echo "### PR body"
    echo ""
    printf '%s\n' "$pr_body"
    echo ""
    echo "### Changed files"
    echo ""
    sed 's/^/- /' "$pr_dir/changed-files.txt"
    echo ""
    echo "### Formal PR reviews (JSON excerpt)"
    echo ""
    echo '```json'
    printf '%s\n' "$reviews_json_compact"
    echo '```'
    echo ""
    echo "### Inline review comments (JSON excerpt)"
    echo ""
    echo '```json'
    printf '%s\n' "$comments_json_compact"
    echo '```'
    echo ""
    if [[ -s "$pr_dir/advisory-comments.md" ]]; then
      echo "### Advisory snapshots"
      echo ""
      cat "$pr_dir/advisory-comments.md"
      echo ""
    fi
    echo "### Current main (HEAD) state for PR-touched paths"
    echo ""
    append_head_snapshots "$pr_dir/changed-files.txt"
    echo "### Diff (truncated excerpt)"
    echo ""
    echo '```diff'
    printf '%s\n' "$diff_text"
    echo '```'
    echo ""
    echo "---"
    echo ""
  done

  echo "## Output instruction (automation-supplied)"
  echo ""
  echo "Respond with **JSON only** matching the monolithic shape. Include one \`retros[]\` entry for each PR: ${SELECTED_PRS[*]}."
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
      echo "::error::Unknown POSTMERGE_RETRO_PROVIDER=${want}"
      exit 1
      ;;
  esac
}

PROVIDER="$(pick_provider)"
if [[ -z "$PROVIDER" ]]; then
  echo "::error::No post-merge retro provider configured."
  exit 1
fi

llm_raw="$WORKDIR/llm-output.txt"
echo "Monolithic retro LLM call via ${PROVIDER} for PR(s): ${SELECTED_PRS[*]}"
case "$PROVIDER" in
  cursor)
    # shellcheck source=../lib/cursor-sdk-version.sh
    source "$LIB_DIR/cursor-sdk-version.sh"
    npm install --no-save "@cursor/sdk@${CURSOR_SDK_VERSION}" >/dev/null 2>&1
    CURSOR_ADVISORY_MODEL="${POSTMERGE_RETRO_MODEL:-${CURSOR_ADVISORY_MODEL:-composer-2.5}}" \
      node "$ADVISORY_DIR/run-advisory-cursor.mjs" "$prompt_file" "$llm_raw"
    ;;
  gemini)
    GEMINI_ADVISORY_MODEL="${POSTMERGE_RETRO_MODEL:-${GEMINI_ADVISORY_MODEL:-gemini-3.5-flash}}" \
      python3 "$ADVISORY_DIR/run-advisory-gemini.py" "$prompt_file" "$llm_raw"
    ;;
esac

cp -f "$llm_raw" "$ARTIFACT_ROOT/monolithic-llm-output.txt"
python3 "$SCRIPT_DIR/split-monolithic-retro-json.py" \
  "$llm_raw" "$ARTIFACT_ROOT" "${SELECTED_PRS[@]}"

RETRO_FILES=()
for pr in "${SELECTED_PRS[@]}"; do
  retro_path="$ARTIFACT_ROOT/pr-${pr}-retro.json"
  [[ -f "$retro_path" ]] || {
    echo "::error::Missing $retro_path after monolithic split"
    exit 1
  }
  jq --arg sha "${MERGE_SHAS[$pr]}" '. + {merge_commit_sha: $sha}' "$retro_path" >"$WORKDIR/pr-${pr}-retro.json"
  mv "$WORKDIR/pr-${pr}-retro.json" "$retro_path"
  python3 "$SCRIPT_DIR/validate-postmerge-retro.py" "$retro_path"
  pr_changed="$EVIDENCE_ROOT/pr-${pr}/changed-files.txt"
  if [[ -f "$pr_changed" ]]; then
    cp -f "$pr_changed" "$ARTIFACT_ROOT/pr-${pr}-changed-files.txt"
  fi
  RETRO_FILES+=("$retro_path")
done

bash "$SCRIPT_DIR/daily-retro-finalize.sh" "$RUN_DATE" "$ARTIFACT_ROOT" "${RETRO_FILES[@]}"
