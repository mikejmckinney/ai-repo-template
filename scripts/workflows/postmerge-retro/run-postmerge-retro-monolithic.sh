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

# shellcheck source=scripts/workflows/lib/parse-positive-int.sh
source "$LIB_DIR/parse-positive-int.sh"

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
per_pr_diff="$(parse_positive_int POSTMERGE_RETRO_MONOLITHIC_DIFF_PER_PR "$diff_limit" "${POSTMERGE_RETRO_MONOLITHIC_DIFF_PER_PR:-}")"
provider_timeout_seconds="$(parse_positive_int POSTMERGE_RETRO_PROVIDER_TIMEOUT_SECONDS 900 "${POSTMERGE_RETRO_PROVIDER_TIMEOUT_SECONDS:-}")"
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
  python3 "$SCRIPT_DIR/compute-evidence-coverage.py" "$pr_dir" \
    --pr "$pr" \
    --repo-root "$REPO_ROOT" \
    --diff-limit "$per_pr_diff" \
    --head-file-cap 8000 \
    --head-total-cap 80000 \
    --warn \
    -o "$ARTIFACT_ROOT/pr-${pr}-evidence-coverage.json"
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
      "follow_up_issues": []
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

# shellcheck source=../lib/pick-advisory-provider.sh
source "$LIB_DIR/pick-advisory-provider.sh"
# shellcheck source=../lib/invoke-advisory-llm.sh
source "$LIB_DIR/invoke-advisory-llm.sh"
# shellcheck source=scripts/workflows/lib/claude-session-diagnostics.sh
source "$LIB_DIR/claude-session-diagnostics.sh"
init_advisory_provider_credentials
mapfile -t provider_candidates < <(list_advisory_providers retro)
if [[ ${#provider_candidates[@]} -eq 0 ]]; then
  echo "::error::No post-merge retro provider configured. Configure Claude, OpenCode, Cursor, or Gemini credentials."
  exit 1
fi

llm_raw="$WORKDIR/llm-output.txt"
candidate_dir="$WORKDIR/monolithic-candidate"
provider_metadata_file="$WORKDIR/provider-metadata.json"
normalized_provenance_file="$WORKDIR/provider-provenance.json"
claude_session_id_file="$WORKDIR/claude-session-id.txt"
claude_diagnostics_dir="${GITHUB_WORKSPACE:-$REPO_ROOT}/.artifacts/postmerge-claude-session"
provider_attempts='[]'
provider_succeeded=false
validate_monolithic_candidate() {
  local pr
  for pr in "${SELECTED_PRS[@]}"; do
    python3 "$SCRIPT_DIR/validate-postmerge-retro.py" "$candidate_dir/pr-${pr}-retro.json" \
      || return 1
  done
}

for provider in "${provider_candidates[@]}"; do
  rm -rf "$candidate_dir"
  mkdir -p "$candidate_dir"
  rm -f "$llm_raw" "$provider_metadata_file" "$normalized_provenance_file" \
    "$claude_session_id_file"
  echo "Monolithic retro LLM call via ${provider} for PR(s): ${SELECTED_PRS[*]}"
  candidate_timeout=""
  if [[ "$provider" == "claude" || "$provider" == "cursor" ]]; then
    candidate_timeout="$provider_timeout_seconds"
  fi
  if ADVISORY_CANDIDATE_TIMEOUT_SECONDS="$candidate_timeout" \
    CLAUDE_ADVISORY_SESSION_ID_FILE="$claude_session_id_file" \
    ADVISORY_PROVIDER_METADATA_FILE="$provider_metadata_file" \
    OPENCODE_OUTPUT_SCHEMA="$REPO_ROOT/.github/schemas/postmerge-retro-monolithic.schema.json" \
    invoke_advisory_llm \
    "$prompt_file" "$llm_raw" "$provider" "$ADVISORY_DIR" \
    "$REPO_ROOT" "$WORKDIR" "$LIB_DIR" \
    && python3 "$SCRIPT_DIR/split-monolithic-retro-json.py" \
      "$llm_raw" "$candidate_dir" "${SELECTED_PRS[@]}" \
    && validate_monolithic_candidate \
    && python3 "$LIB_DIR/provider-provenance.py" normalize \
      "$provider_metadata_file" >"$normalized_provenance_file"; then
    resolved_provider="$(jq -r .provider "$normalized_provenance_file")"
    provider_attempts="$(
      jq -cn --argjson attempts "$provider_attempts" --arg provider "$resolved_provider" \
        '$attempts + [{provider: $provider, status: "success", evidence_route: "bounded"}]'
    )"
    provider_succeeded=true
    break
  fi
  if [[ "$provider" == "claude" ]]; then
    preserve_claude_session "$claude_session_id_file" "$claude_diagnostics_dir"
  fi
  provider_attempts="$(
    jq -cn --argjson attempts "$provider_attempts" --arg provider "$provider" \
      '$attempts + [{provider: $provider, status: "failed", evidence_route: "bounded"}]'
  )"
  echo "::warning::Monolithic retro provider ${provider} failed; trying next available provider" >&2
done
if [[ "$provider_succeeded" != true ]]; then
  echo "::error::Monolithic retro provider cascade exhausted" >&2
  exit 1
fi

cp -f "$llm_raw" "$ARTIFACT_ROOT/monolithic-llm-output.txt"
cp -f "$normalized_provenance_file" "$ARTIFACT_ROOT/monolithic-provider-provenance.json"
cp -f "$candidate_dir"/pr-*-retro.json "$ARTIFACT_ROOT/"

for pr in "${SELECTED_PRS[@]}"; do
  coverage="$ARTIFACT_ROOT/pr-${pr}-evidence-coverage.json"
  jq \
    --argjson provenance "$(cat "$normalized_provenance_file")" \
    --argjson attempts "$provider_attempts" \
    '.routing_context.provider_resolved = $provenance.provider
      | .routing_context.provenance = $provenance
      | .provider_attempts = $attempts' \
    "$coverage" >"$coverage.tmp"
  mv "$coverage.tmp" "$coverage"
done

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
