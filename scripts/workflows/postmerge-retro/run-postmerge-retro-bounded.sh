#!/usr/bin/env bash
# Bounded post-merge retro LLM pass (truncated diff/HEAD in prompt).
# Usage: run-postmerge-retro-bounded.sh <pr> <workdir> <llm-output-file> [coverage-json]
set -euo pipefail

PR="${1:-}"
WORKDIR="${2:-}"
LLM_OUT="${3:-}"
COVERAGE_JSON="${4:-${WORKDIR}/evidence-coverage.json}"

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

provider=""
if [[ -f "$COVERAGE_JSON" ]]; then
  provider="$(jq -r '.routing_context.provider_resolved // ""' "$COVERAGE_JSON")"
fi
if [[ -z "$provider" || "$provider" == "null" || "$provider" == "unknown" ]]; then
  # shellcheck source=../lib/pick-advisory-provider.sh
  source "$LIB_DIR/pick-advisory-provider.sh"
  init_advisory_provider_credentials
  provider="$(pick_advisory_provider retro)"
fi
if [[ -z "$provider" ]]; then
  echo "::error::No post-merge retro provider configured. Set CURSOR_API_KEY and/or GEMINI_API_KEY (or GOOGLE_API_KEY)."
  exit 1
fi

case "$provider" in
  cursor)
    # shellcheck source=../lib/cursor-sdk-version.sh
    source "$LIB_DIR/cursor-sdk-version.sh"
    npm install --no-save "@cursor/sdk@${CURSOR_SDK_VERSION}" >/dev/null 2>&1
    CURSOR_ADVISORY_MODEL="${POSTMERGE_RETRO_MODEL:-${CURSOR_ADVISORY_MODEL:-composer-2.5}}" \
      node "$ADVISORY_DIR/run-advisory-cursor.mjs" "$prompt_file" "$LLM_OUT"
    ;;
  gemini)
    GEMINI_ADVISORY_MODEL="${POSTMERGE_RETRO_MODEL:-${GEMINI_ADVISORY_MODEL:-gemini-3.5-flash}}" \
      python3 "$ADVISORY_DIR/run-advisory-gemini.py" "$prompt_file" "$LLM_OUT"
    ;;
  *)
    echo "::error::Bounded retro does not support provider=${provider}"
    exit 1
    ;;
esac

echo "Bounded post-merge retro LLM pass complete for PR #${PR} via ${provider}"
