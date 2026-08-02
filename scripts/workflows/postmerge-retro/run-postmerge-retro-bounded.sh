#!/usr/bin/env bash
# Bounded post-merge retro LLM pass (truncated diff/HEAD in prompt).
# Usage: run-postmerge-retro-bounded.sh <pr> <workdir> <llm-output-file> [coverage-json] [provider]
set -euo pipefail

PR="${1:-}"
WORKDIR="${2:-}"
LLM_OUT="${3:-}"
COVERAGE_JSON="${4:-${WORKDIR}/evidence-coverage.json}"
PROVIDER_OVERRIDE="${5:-}"

usage() {
  echo "Usage: run-postmerge-retro-bounded.sh <pr> <workdir> <llm-output-file> [coverage-json]" >&2
  exit 2
}

[[ -n "$PR" && -n "$WORKDIR" && -n "$LLM_OUT" ]] || usage

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADVISORY_DIR="$REPO_ROOT/scripts/workflows/advisory-review"
LIB_DIR="$REPO_ROOT/scripts/workflows/lib"

prompt_file="$WORKDIR/prompt.md"
bash "$SCRIPT_DIR/assemble-retro-prompt.sh" "$PR" "$WORKDIR" bounded "$prompt_file"

provider="$PROVIDER_OVERRIDE"
if [[ -z "$provider" && -f "$COVERAGE_JSON" ]]; then
  provider="$(jq -r '.routing_context.provider_resolved // ""' "$COVERAGE_JSON")"
fi
if [[ -z "$provider" || "$provider" == "null" || "$provider" == "unknown" ]]; then
  # shellcheck source=../lib/pick-advisory-provider.sh
  source "$LIB_DIR/pick-advisory-provider.sh"
  init_advisory_provider_credentials
  provider="$(pick_advisory_provider retro)"
fi
if [[ -z "$provider" ]]; then
  echo "::error::No post-merge retro provider configured. Configure Claude, OpenCode, Cursor, or Gemini credentials."
  exit 1
fi

case "$provider" in
  claude | opencode | cursor | gemini)
    # shellcheck source=../lib/invoke-advisory-llm.sh
    source "$LIB_DIR/invoke-advisory-llm.sh"
    OPENCODE_OUTPUT_SCHEMA="$REPO_ROOT/.github/schemas/postmerge-retro-bounded.schema.json" \
      invoke_advisory_llm \
      "$prompt_file" "$LLM_OUT" "$provider" "$ADVISORY_DIR" \
      "$REPO_ROOT" "$WORKDIR" "$LIB_DIR"
    ;;
  *)
    echo "::error::Bounded retro does not support provider=${provider}"
    exit 1
    ;;
esac

echo "Bounded post-merge retro LLM pass complete for PR #${PR} via ${provider}"
