#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.opencode/skills/local-consensus/scripts/common.sh
source "$SCRIPT_DIR/common.sh"

PROMPT_FILE=
INVOKING_SESSION=
TITLE="local-advisor-$(date +%Y%m%d-%H%M%S)"
OUTPUT_DIR=

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt-file)
      require_value "$1" "${2:-}"
      PROMPT_FILE="$2"
      shift 2
      ;;
    --invoking-session)
      require_value "$1" "${2:-}"
      INVOKING_SESSION="$2"
      shift 2
      ;;
    --title)
      require_value "$1" "${2:-}"
      TITLE="$2"
      shift 2
      ;;
    --output-dir)
      require_value "$1" "${2:-}"
      OUTPUT_DIR="$2"
      shift 2
      ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -f "$PROMPT_FILE" ]] || fail "--prompt-file must name a readable file"
[[ -n "$INVOKING_SESSION" ]] || fail "--invoking-session is required"
OUTPUT_DIR="${OUTPUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/local-advisor.XXXXXX")}"
mkdir -p "$OUTPUT_DIR"

RUNTIME_PROMPT="$OUTPUT_DIR/prompt.md"
ANSWER_FILE="$OUTPUT_DIR/answer.md"
append_session_context "$PROMPT_FILE" "$INVOKING_SESSION" "$RUNTIME_PROMPT"

invoke_with_fallback "$TITLE" "$RUNTIME_PROMPT" "$ANSWER_FILE" \
  || fail "all advisor engines failed; inspect $OUTPUT_DIR"
emit_result advisor "$ANSWER_FILE"
