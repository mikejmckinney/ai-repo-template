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

claude_oauth_token="${CLAUDE_CODE_OAUTH_TOKEN:-}"
advisory_github_token="${OPENCODE_GITHUB_TOKEN:-}"
CLAUDE_OAUTH_AVAILABLE=false
if [[ -n "$claude_oauth_token" ]]; then
  CLAUDE_OAUTH_AVAILABLE=true
fi
export CLAUDE_OAUTH_AVAILABLE
unset CLAUDE_CODE_OAUTH_TOKEN

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

DEFAULT_COMMENT_LIMIT=65000

comment_limit="$(parse_positive_int ADVISORY_REVIEW_COMMENT_LIMIT "$DEFAULT_COMMENT_LIMIT" "${ADVISORY_REVIEW_COMMENT_LIMIT:-}")"
candidate_timeout="$(parse_positive_int ADVISORY_CANDIDATE_TIMEOUT_SECONDS 300 "${ADVISORY_CANDIDATE_TIMEOUT_SECONDS:-}")"
export ADVISORY_CANDIDATE_TIMEOUT_SECONDS="$candidate_timeout"

if [[ "$FULL_MODE" == "true" ]]; then
  advisory_mode="full"
else
  advisory_mode="live"
fi

pr_json="$(gh api "repos/${REPO}/pulls/${PR}")"
pr_url="$(printf '%s' "$pr_json" | jq -r .html_url)"
base_sha="$(printf '%s' "$pr_json" | jq -r .base.sha)"

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

# shellcheck disable=SC1090,SC1091
source "${ADVISORY_PROVIDER_LIB:-$LIB_DIR/pick-advisory-provider.sh}"
# shellcheck disable=SC1090,SC1091
source "${ADVISORY_INVOKE_LIB:-$LIB_DIR/invoke-advisory-llm.sh}"
# shellcheck disable=SC2034 # Provider routing initializes and reads these globals.
has_claude=0 has_opencode=0 has_opencode_sol=0 has_opencode_kimi=0 has_cursor=0 has_gemini=0
init_advisory_provider_credentials
mapfile -t provider_candidates < <(list_advisory_providers advisory)
if [[ ${#provider_candidates[@]} -eq 0 ]]; then
  echo "::error::No advisory review provider configured. Configure Claude, Sol, Grok, or Kimi credentials."
  exit 1
fi
expected_provider="${provider_candidates[0]}"
if declare -F advisory_candidate_provider >/dev/null 2>&1; then
  expected_provider="$(advisory_candidate_provider "${provider_candidates[0]}")"
fi

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

changed_files_file="$WORKDIR/changed-files.txt"
if ! git diff --name-only "${diff_base}...${HEAD_SHA}" >"$changed_files_file"; then
  echo "::error::Failed to compute advisory changed-file list for ${diff_base}...${HEAD_SHA}" >&2
  exit 1
fi
full_diff_file="$WORKDIR/full.diff"
if ! git diff "${diff_base}...${HEAD_SHA}" >"$full_diff_file"; then
  echo "::error::Failed to compute advisory diff for ${diff_base}...${HEAD_SHA}" >&2
  exit 1
fi
changed_file_count="$(wc -l <"$changed_files_file" | tr -d ' ')"
full_diff_bytes="$(wc -c <"$full_diff_file" | tr -d ' ')"
diff_included="$full_diff_bytes"
truncated_word="no"

prompt_file="$WORKDIR/prompt.md"
{
  cat "$REPO_ROOT/.github/prompts/pr-advisory-review.md"
  echo ""
  echo "---"
  echo ""
  echo "## Invocation coordinates"
  echo ""
  echo "- Repository: \`${REPO}\`"
  echo "- Pull request: [#${PR}](${pr_url})"
  echo "- Expected head SHA: \`${HEAD_SHA}\`"
  echo "- Base SHA: \`${base_sha}\`"
  echo "- Diff base: \`${diff_base}\`"
  echo "- Review basis: \`${review_basis}\` (\`${review_reason}\`)"
  echo "- Advisory mode: \`${advisory_mode}\`"
} >"$prompt_file"

out_file="$WORKDIR/advisory-body.md"
raw_out_file="$WORKDIR/advisory-raw.md"
provider_metadata_file="$WORKDIR/provider-metadata.json"

invoke_provider_candidate() {
  local candidate="$1"
  if [[ "$candidate" == claude ]]; then
    CLAUDE_CODE_OAUTH_TOKEN="$claude_oauth_token" \
      ADVISORY_GITHUB_TOKEN="$advisory_github_token" \
      ADVISORY_FULL_DIFF_BYTES="$full_diff_bytes" \
      ADVISORY_PROVIDER_METADATA_FILE="$provider_metadata_file" \
      invoke_advisory_llm "$prompt_file" "$raw_out_file" "$candidate" "$SCRIPT_DIR" "$REPO_ROOT" "$WORKDIR" "$LIB_DIR"
    return
  fi
  if [[ "$candidate" == cursor ]]; then
    ADVISORY_GITHUB_TOKEN="$advisory_github_token" \
      ADVISORY_FULL_DIFF_BYTES="$full_diff_bytes" \
      ADVISORY_PROVIDER_METADATA_FILE="$provider_metadata_file" \
      invoke_advisory_llm "$prompt_file" "$raw_out_file" "$candidate" "$SCRIPT_DIR" "$REPO_ROOT" "$WORKDIR" "$LIB_DIR"
    return
  fi
  ADVISORY_FULL_DIFF_BYTES="$full_diff_bytes" \
    ADVISORY_PROVIDER_METADATA_FILE="$provider_metadata_file" \
    invoke_advisory_llm "$prompt_file" "$raw_out_file" "$candidate" "$SCRIPT_DIR" "$REPO_ROOT" "$WORKDIR" "$LIB_DIR"
}

provider_succeeded=false
for provider in "${provider_candidates[@]}"; do
  rm -f "$raw_out_file" "$provider_metadata_file"
  if invoke_provider_candidate "$provider"; then
    if ! jq -e '.provider | type == "string" and length > 0' "$provider_metadata_file" >/dev/null 2>&1 \
      || ! jq -e '.model | type == "string" and length > 0' "$provider_metadata_file" >/dev/null 2>&1; then
      echo "::warning::Advisory provider ${provider} omitted provider/model metadata; trying next available provider" >&2
      continue
    fi
    PROVIDER="$(jq -r .provider "$provider_metadata_file")"
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
