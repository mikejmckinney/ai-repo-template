#!/usr/bin/env bash
# scripts/workflows/advisory-review/run-advisory-review.sh — advisory snapshot dispatch.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

PR="${1:-${PR_NUMBER:-}}"
HEAD_SHA="${2:-${HEAD_SHA:-}}"
FULL_MODE="${3:-${FULL_MODE:-false}}"

usage() {
  echo "Usage: run-advisory-review.sh <pr-number> <head-sha> [full-mode:true|false]" >&2
  exit 2
}

[[ -n "$PR" && -n "$HEAD_SHA" ]] || usage

parse_positive_int() {
  local name="$1" default="$2" raw="${3:-}"
  if [[ -z "$raw" ]]; then
    echo "$default"
    return
  fi
  if [[ "$raw" =~ ^[0-9]+$ ]] && [[ "$raw" -gt 0 ]]; then
    echo "$raw"
    return
  fi
  echo "::warning::Invalid ${name}=${raw}; using default ${default}" >&2
  echo "$default"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$REPO_ROOT/scripts/workflows/lib"
MARKER='<!-- ai-advisory-review:v1 -->'
MARKER_TOKEN='ai-advisory-review:v1'
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

DEFAULT_DIFF_LIVE=120000
DEFAULT_DIFF_FULL=300000
DEFAULT_COMMENT_LIMIT=65000

diff_limit_live="$(parse_positive_int ADVISORY_REVIEW_DIFF_LIMIT_LIVE "$DEFAULT_DIFF_LIVE" "${ADVISORY_REVIEW_DIFF_LIMIT_LIVE:-}")"
diff_limit_full="$(parse_positive_int ADVISORY_REVIEW_DIFF_LIMIT_FULL "$DEFAULT_DIFF_FULL" "${ADVISORY_REVIEW_DIFF_LIMIT_FULL:-}")"
comment_limit="$(parse_positive_int ADVISORY_REVIEW_COMMENT_LIMIT "$DEFAULT_COMMENT_LIMIT" "${ADVISORY_REVIEW_COMMENT_LIMIT:-}")"
context_profile="${ADVISORY_CONTEXT_PROFILE:-pr-review}"

if [[ "$FULL_MODE" == "true" ]]; then
  diff_limit="$diff_limit_full"
  advisory_mode="full"
else
  diff_limit="$diff_limit_live"
  advisory_mode="live"
fi

pr_json="$(gh api "repos/${REPO}/pulls/${PR}")"
pr_title="$(printf '%s' "$pr_json" | jq -r .title)"
pr_body="$(printf '%s' "$pr_json" | jq -r .body)"
pr_url="$(printf '%s' "$pr_json" | jq -r .html_url)"
base_sha="$(printf '%s' "$pr_json" | jq -r .base.sha)"

printf '%s\n' "$pr_body" >"$WORKDIR/pr-body.md"
git fetch origin "$HEAD_SHA" "$base_sha" 2>/dev/null || true

existing_snapshot=""
existing_snapshot=$(
  gh api "repos/${REPO}/issues/${PR}/comments" --paginate \
    | jq -s 'if length == 0 then [] else add end' \
    | jq -r --arg token "$MARKER_TOKEN" \
      '[.[] | select((.body | type) == "string" and (.body | contains($token)))] | last | .body // empty' \
      2>/dev/null || true
)
printf '%s\n' "$existing_snapshot" >"$WORKDIR/existing-snapshot.md"

# shellcheck disable=SC2034 # Provider routing reads this global after sourcing.
antigravity_enabled=false
if [[ "${ADVISORY_ANTIGRAVITY_ENABLED:-}" == "true" ]]; then
  antigravity_enabled=true
fi
export antigravity_enabled

# shellcheck disable=SC1090,SC1091
source "${ADVISORY_PROVIDER_LIB:-$LIB_DIR/pick-advisory-provider.sh}"
# shellcheck disable=SC1090,SC1091
source "${ADVISORY_INVOKE_LIB:-$LIB_DIR/invoke-advisory-llm.sh}"
# shellcheck disable=SC2034 # Provider routing initializes and reads these globals.
has_opencode=0 has_cursor=0 has_gemini=0
init_advisory_provider_credentials
mapfile -t provider_candidates < <(list_advisory_providers advisory)
if [[ ${#provider_candidates[@]} -eq 0 ]]; then
  echo "::error::No advisory review provider configured. Configure OpenCode, Cursor, or Gemini credentials."
  exit 1
fi
expected_provider="${provider_candidates[0]}"

range_args=(
  --repo "$REPO_ROOT"
  --snapshot "$WORKDIR/existing-snapshot.md"
  --base "$base_sha"
  --head "$HEAD_SHA"
  --expected-provider "$expected_provider"
  --event-action "${GITHUB_EVENT_ACTION:-}"
)
if [[ "$FULL_MODE" == "true" ]]; then
  range_args+=(--full)
fi
range_json=$(python3 "$SCRIPT_DIR/select-advisory-range.py" "${range_args[@]}")
diff_base=$(jq -r .diff_base <<<"$range_json")
review_basis=$(jq -r .review_basis <<<"$range_json")
review_reason=$(jq -r .reason <<<"$range_json")

git diff --name-only "${diff_base}...${HEAD_SHA}" >"$WORKDIR/changed-files.txt"

full_diff_file="$WORKDIR/full.diff"
git diff "${diff_base}...${HEAD_SHA}" >"$full_diff_file" 2>/dev/null || true
full_diff_bytes="$(wc -c <"$full_diff_file" | tr -d ' ')"
truncated=false
if [[ "$full_diff_bytes" -gt "$diff_limit" ]]; then
  truncated=true
fi
diff_included="$full_diff_bytes"
if [[ "$truncated" == "true" ]]; then
  diff_included="$diff_limit"
fi
diff_text="$(head -c "$diff_limit" "$full_diff_file")"

truncated_word="no"
if [[ "$truncated" == "true" ]]; then
  truncated_word="yes"
fi

cat >"$WORKDIR/diff-coverage.md" <<EOF
### Diff coverage (automation-supplied)

- Diff bytes total: \`${full_diff_bytes}\`
- Diff bytes included: \`${diff_included}\`
- Diff truncated: \`${truncated}\`
- Advisory mode: \`${advisory_mode}\`
- Review basis: \`${review_basis}\` (\`${review_reason}\`)
- Diff base: \`${diff_base}\`
- Review scope: if truncated, review only the included diff plus changed-file list; suggest \`ai-review:full\`.
EOF

changed_file_count="$(wc -l <"$WORKDIR/changed-files.txt" | tr -d ' ')"
if [[ "$full_diff_bytes" -eq 0 && "$changed_file_count" -gt 0 ]]; then
  echo "::warning::Advisory diff is empty (${changed_file_count} changed files listed) — review quality may be degraded (fetch/sha mismatch?)" >&2
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

prompt_file="$WORKDIR/prompt.md"
{
  cat "$REPO_ROOT/.github/prompts/pr-advisory-review.md"
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
  echo "- Head SHA: \`${HEAD_SHA}\`"
  echo "- Advisory mode: \`${advisory_mode}\`"
  echo ""
  cat "$WORKDIR/diff-coverage.md"
  echo ""
  echo "### PR body"
  echo ""
  printf '%s\n' "$pr_body"
  echo ""
  echo "### Changed files"
  echo ""
  sed 's/^/- /' "$WORKDIR/changed-files.txt"
  echo ""
  echo "### ${review_basis^} diff (truncated excerpt for prompt)"
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

out_file="$WORKDIR/advisory-body.md"
raw_out_file="$WORKDIR/advisory-raw.md"
provider_metadata_file="$WORKDIR/provider-metadata.json"
provider_succeeded=false
for provider in "${provider_candidates[@]}"; do
  rm -f "$raw_out_file" "$provider_metadata_file"
  if ADVISORY_FULL_DIFF_BYTES="$full_diff_bytes" \
    ADVISORY_PROVIDER_METADATA_FILE="$provider_metadata_file" \
    invoke_advisory_llm "$prompt_file" "$raw_out_file" "$provider" "$SCRIPT_DIR" "$REPO_ROOT" "$WORKDIR" "$LIB_DIR"; then
    PROVIDER="${ADVISORY_PROVIDER_USED:-$provider}"
    if ! jq -e '.provider | type == "string" and length > 0' "$provider_metadata_file" >/dev/null 2>&1 \
      || ! jq -e '.model | type == "string" and length > 0' "$provider_metadata_file" >/dev/null 2>&1; then
      echo "::warning::Advisory provider ${provider} omitted provider/model metadata; trying next available provider" >&2
      continue
    fi
    if ! python3 "$SCRIPT_DIR/normalize-advisory-snapshot.py" \
      --input "$raw_out_file" \
      --output "$out_file" \
      --provider-metadata "$provider_metadata_file" \
      --head "$HEAD_SHA" \
      --base "$base_sha" \
      --review-basis "$review_basis" \
      --diff-included "$diff_included" \
      --diff-total "$full_diff_bytes" \
      --truncated "$truncated_word" \
      --changed-files "$changed_file_count"; then
      echo "::warning::Advisory provider ${provider} returned malformed snapshot output; trying next available provider" >&2
      continue
    fi
    provider_succeeded=true
    break
  fi
  echo "::warning::Advisory provider ${provider} failed; trying next available provider" >&2
done
if [[ "$provider_succeeded" != true ]]; then
  echo "::error::Advisory provider cascade exhausted" >&2
  exit 1
fi

provider_label=$(jq -r '"\(.provider) / \(.model)"' "$provider_metadata_file")

comment_bytes="$(wc -c <"$out_file" | tr -d ' ')"
if [[ "$comment_bytes" -gt "$comment_limit" ]]; then
  cat >"$out_file.tmp" <<EOF
$MARKER

## Advisory Review Snapshot

Head: \`${HEAD_SHA}\`
Provider: \`${provider_label}\`
Mode: advisory, non-blocking
Diff coverage: \`${diff_included}/${full_diff_bytes}\` bytes, truncated: \`${truncated_word}\`, basis: \`${review_basis}\`

### Findings to consider

| ID | Band | Lens | Area | AP11 evidence | Finding | Suggested action | Still present at head? |
|---|---|---|---|---|---|---|---|
| ADV-01 | defer | Reliability and performance | Advisory output | bounded/edge/limited/easy/trivial/high; uncertainty: none | The normalized advisory output exceeded the ${comment_limit}-byte comment limit, so model findings were not published and reviewed-head memory was omitted. | Run a full advisory review after reducing provider output or increasing the configured comment limit. | yes |

### Not blocking

These findings are optional input while implementation continues. CI and maintainer decisions remain authoritative.

EOF
  bounded_bytes="$(wc -c <"$out_file.tmp" | tr -d ' ')"
  if [[ "$bounded_bytes" -gt "$comment_limit" ]]; then
    echo "::error::Canonical over-limit advisory warning requires ${bounded_bytes} bytes, above configured limit ${comment_limit}" >&2
    exit 1
  fi
  mv "$out_file.tmp" "$out_file"
  echo "::warning::Advisory output exceeded ${comment_limit} bytes (was ${comment_bytes}); published bounded warning without reviewed-head memory" >&2
fi

"${ADVISORY_UPSERT_SCRIPT:-$SCRIPT_DIR/upsert-pr-comment.sh}" "$PR" "$MARKER" "$out_file"
echo "Advisory snapshot posted via ${PROVIDER} for PR #${PR} @ ${HEAD_SHA}"
