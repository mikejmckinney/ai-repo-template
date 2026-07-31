#!/usr/bin/env bash
# Run weekly full-repo LLM review and write review.json.
set -euo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADVISORY_DIR="$REPO_ROOT/scripts/workflows/advisory-review"
LIB_DIR="$REPO_ROOT/scripts/workflows/lib"

RUN_DATE="${RUN_DATE:-$(date -u +%Y-%m-%d)}"
RUN_WEEK="${RUN_WEEK:-$(bash "$SCRIPT_DIR/resolve-run-week.sh")}"
OUT_JSON="${1:-}"
context_profile="${WEEKLY_REVIEW_CONTEXT_PROFILE:-full}"
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
HEAD_SHA="$(git rev-parse HEAD)"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# Full profile uses context-pack floor only (no path-trigger expansion).
: >"$WORKDIR/changed-files.txt"

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

{
  echo "- Repository: \`${REPO}\`"
  echo "- Run week: \`${RUN_WEEK}\`"
  echo "- Run date: \`${RUN_DATE}\`"
  echo "- HEAD SHA: \`${HEAD_SHA}\`"
  echo "- Context profile: \`${context_profile}\` (context pack only; inspect repo for code evidence)"
} >"$WORKDIR/run-meta.md"

prompt_file="$WORKDIR/prompt.md"
{
  cat "$REPO_ROOT/.github/prompts/weekly-repo-review.md"
  echo ""
  echo "---"
  echo ""
  echo "## Repo startup context (automation-supplied, catalog-driven ${context_profile})"
  echo ""
  echo "- Context files injected: \`${context_file_count}\`"
  echo "- Context bytes injected: \`${context_bytes}\`"
  echo ""
  for rel in "${context_files[@]}"; do
    echo "### ${rel}"
    echo ""
    if [[ -f "$REPO_ROOT/$rel" ]]; then
      cat "$REPO_ROOT/$rel"
    else
      echo "(missing on disk)"
    fi
    echo ""
  done
  echo "---"
  echo ""
  echo "## Run metadata (automation-supplied)"
  echo ""
  cat "$WORKDIR/run-meta.md"
  echo ""
  echo "---"
  echo ""
  echo "## Output instruction (automation-supplied)"
  echo ""
  echo "Respond with **JSON only** matching the required weekly review shape."
  echo "Inspect the repository working tree on \`main\` for code/scripts/workflows/checks evidence."
} >"$prompt_file"

# shellcheck disable=SC2034 # Provider routing reads this global after sourcing.
antigravity_enabled=false
if [[ "${ADVISORY_ANTIGRAVITY_ENABLED:-}" == "true" ]]; then
  antigravity_enabled=true
fi
export antigravity_enabled

# shellcheck source=../lib/pick-advisory-provider.sh
source "$LIB_DIR/pick-advisory-provider.sh"
# shellcheck source=../lib/invoke-advisory-llm.sh
source "$LIB_DIR/invoke-advisory-llm.sh"
init_advisory_provider_credentials
mapfile -t provider_candidates < <(list_advisory_providers weekly-scan)
[[ ${#provider_candidates[@]} -gt 0 ]] || {
  echo "::error::No weekly review provider configured. Configure OpenCode, Cursor, or Gemini credentials."
  exit 1
}

llm_raw="$WORKDIR/llm-output.txt"
review_json="$WORKDIR/review.json"
provider_metadata_file="$WORKDIR/provider-metadata.json"
normalized_provenance_file="$WORKDIR/provider-provenance.json"
provider_attempts='[]'
provider_succeeded=false
for provider in "${provider_candidates[@]}"; do
  rm -f "$llm_raw" "$review_json" "$provider_metadata_file" "$normalized_provenance_file"
  # shellcheck disable=SC2034 # Sourced provider dispatch reads this selection.
  ADVISORY_PROVIDER_USED="$provider"
  provider_invoked=false
  case "$provider" in
    opencode | cursor | gemini)
      if ADVISORY_PROVIDER_METADATA_FILE="$provider_metadata_file" \
        OPENCODE_OUTPUT_SCHEMA="$REPO_ROOT/.github/schemas/weekly-review.schema.json" \
        invoke_advisory_llm \
        "$prompt_file" "$llm_raw" "$provider" "$ADVISORY_DIR" \
        "$REPO_ROOT" "$WORKDIR" "$LIB_DIR"; then
        provider_invoked=true
      fi
      ;;
    antigravity)
      if ADVISORY_PROVIDER_METADATA_FILE="$provider_metadata_file" \
        python3 "$SCRIPT_DIR/run-weekly-antigravity.py" "$REPO_ROOT" "$WORKDIR" "$llm_raw"; then
        provider_invoked=true
      fi
      ;;
  esac
  if [[ "$provider_invoked" == true ]] \
    && python3 "$SCRIPT_DIR/extract-weekly-json.py" "$llm_raw" "$review_json" \
    && python3 "$SCRIPT_DIR/validate-weekly-review.py" "$review_json" \
    && python3 "$LIB_DIR/provider-provenance.py" normalize \
      "$provider_metadata_file" >"$normalized_provenance_file"; then
    PROVIDER="$(jq -r .provider "$normalized_provenance_file")"
    provider_attempts="$(
      jq -cn \
        --argjson attempts "$provider_attempts" \
        --arg provider "$PROVIDER" \
        '$attempts + [{provider: $provider, status: "success"}]'
    )"
    jq \
      --argjson provenance "$(cat "$normalized_provenance_file")" \
      --argjson attempts "$provider_attempts" \
      '. + {provenance: $provenance, provider_attempts: $attempts}' \
      "$review_json" >"$review_json.tmp"
    mv "$review_json.tmp" "$review_json"
    provider_succeeded=true
    break
  fi
  provider_attempts="$(
    jq -cn \
      --argjson attempts "$provider_attempts" \
      --arg provider "$provider" \
      '$attempts + [{provider: $provider, status: "failed"}]'
  )"
  echo "::warning::Weekly review provider ${provider} failed; trying next available provider" >&2
done
if [[ "$provider_succeeded" != true ]]; then
  echo "::error::Weekly review provider cascade exhausted" >&2
  exit 1
fi

if [[ -n "$OUT_JSON" ]]; then
  cp -f "$review_json" "$OUT_JSON"
fi

if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
  artifact_dir="${GITHUB_WORKSPACE}/.artifacts/weekly-review/week-${RUN_WEEK}"
  mkdir -p "$artifact_dir"
  cp -f "$review_json" "$artifact_dir/review.json"
  cp -f "$llm_raw" "$artifact_dir/llm-output.txt" 2>/dev/null || true
fi

echo "Weekly review JSON written for ${RUN_WEEK} via ${PROVIDER}" >&2
