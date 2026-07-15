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

antigravity_enabled=false
if [[ "${ADVISORY_ANTIGRAVITY_ENABLED:-}" == "true" ]]; then
  antigravity_enabled=true
fi

# shellcheck source=../lib/pick-advisory-provider.sh
source "$LIB_DIR/pick-advisory-provider.sh"
# shellcheck source=../lib/invoke-advisory-llm.sh
source "$LIB_DIR/invoke-advisory-llm.sh"
init_advisory_provider_credentials
PROVIDER="$(pick_advisory_provider weekly-scan)"
[[ -n "$PROVIDER" ]] || {
  echo "::error::No weekly review provider configured. Configure OpenCode, Cursor, or Gemini credentials."
  exit 1
}

llm_raw="$WORKDIR/llm-output.txt"
case "$PROVIDER" in
  opencode | cursor | gemini)
    OPENCODE_OUTPUT_SCHEMA="$REPO_ROOT/.github/schemas/weekly-review.schema.json" \
      invoke_advisory_llm \
      "$prompt_file" "$llm_raw" "$PROVIDER" "$ADVISORY_DIR" \
      "$REPO_ROOT" "$WORKDIR" "$LIB_DIR"
    ;;
  antigravity)
    [[ -n "${GEMINI_API_KEY:-}${GOOGLE_API_KEY:-}" ]] || {
      echo "::error::WEEKLY_REVIEW_PROVIDER=antigravity but GEMINI_API_KEY/GOOGLE_API_KEY is unset"
      exit 1
    }
    [[ "$antigravity_enabled" == "true" ]] || {
      echo "::error::WEEKLY_REVIEW_PROVIDER=antigravity but ADVISORY_ANTIGRAVITY_ENABLED is not true"
      exit 1
    }
    if ! python3 "$SCRIPT_DIR/run-weekly-antigravity.py" "$REPO_ROOT" "$WORKDIR" "$llm_raw"; then
      echo "::error::Antigravity weekly review failed"
      exit 1
    fi
    ;;
esac

review_json="$WORKDIR/review.json"
python3 "$SCRIPT_DIR/extract-weekly-json.py" "$llm_raw" "$review_json"
python3 "$SCRIPT_DIR/validate-weekly-review.py" "$review_json"

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
