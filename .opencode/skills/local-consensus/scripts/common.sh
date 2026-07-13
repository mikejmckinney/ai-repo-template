#!/usr/bin/env bash

set -o pipefail

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SKILL_ROOT
TIMEOUT_SECONDS="${LOCAL_CONSENSUS_TIMEOUT:-300}"
SESSION_LIMIT="${LOCAL_CONSENSUS_SESSION_LIMIT:-100}"
SOL_MODEL="${LOCAL_CONSENSUS_SOL_MODEL:-openai/gpt-5.6-sol}"
GLM_MODEL="${LOCAL_CONSENSUS_GLM_MODEL:-openrouter/z-ai/glm-5.2@preset/default}"
MM_MODEL="${LOCAL_CONSENSUS_MM_MODEL:-openrouter/minimax/minimax-m3@preset/default}"
MI_MODEL="${LOCAL_CONSENSUS_MI_MODEL:-openrouter/xiaomi/mimo-v2.5-pro@preset/default}"
DS_MODEL="${LOCAL_CONSENSUS_DS_MODEL:-openrouter/deepseek/deepseek-v4-pro@preset/default}"

fail() {
  printf 'local-consensus: %s\n' "$*" >&2
  exit 1
}

require_value() {
  [[ $# -ge 2 && -n "$2" ]] || fail "$1 requires a value"
}

run_with_timeout() {
  perl -e 'alarm shift; exec @ARGV' "$@"
}

session_id_for_title() {
  local title="$1"
  opencode session list --format json --max-count "$SESSION_LIMIT" \
    | jq -r --arg title "$title" '.[] | select(.title == $title) | .id' \
    | head -1
}

append_session_context() {
  local source_file="$1" session_id="$2" target_file="$3"
  cat "$source_file" >"$target_file"
  cat >>"$target_file" <<EOF

## Invoking session context
The invoking agent session is ${session_id}. Query only targeted transcript
records from ~/.local/share/opencode/opencode.db when the supplied prompt and
referenced files are insufficient. Do not dump the complete transcript.
EOF
}

invoke_engine() {
  local engine="$1" title="$2" prompt_file="$3" output_file="$4"
  local error_file="${output_file%.md}.err"
  ENGINE_SESSION=

  case "$engine" in
    sol)
      if run_with_timeout "$TIMEOUT_SECONDS" opencode run --title "${title}-sol" \
        --model "$SOL_MODEL" <"$prompt_file" >"$output_file" 2>"$error_file" \
        && [[ -s "$output_file" ]]; then
        ENGINE_SESSION=$(session_id_for_title "${title}-sol")
        return 0
      fi
      ;;
    fable)
      if run_with_timeout "$TIMEOUT_SECONDS" claude -p --model fable \
        --output-format json --dangerously-skip-permissions \
        <"$prompt_file" >"${output_file}.json" 2>"$error_file"; then
        jq -r '.result // empty' "${output_file}.json" >"$output_file"
        ENGINE_SESSION=$(jq -r '.session_id // empty' "${output_file}.json")
        [[ -s "$output_file" ]] && return 0
      fi
      ;;
    glm)
      if run_with_timeout "$TIMEOUT_SECONDS" opencode run --title "${title}-glm" \
        --model "$GLM_MODEL" <"$prompt_file" >"$output_file" 2>"$error_file" \
        && [[ -s "$output_file" ]]; then
        ENGINE_SESSION=$(session_id_for_title "${title}-glm")
        return 0
      fi
      ;;
    mm | mi | ds)
      local model
      case "$engine" in
        mm) model="$MM_MODEL" ;;
        mi) model="$MI_MODEL" ;;
        ds) model="$DS_MODEL" ;;
      esac
      if run_with_timeout "$TIMEOUT_SECONDS" opencode run --title "${title}-${engine}" \
        --model "$model" <"$prompt_file" >"$output_file" 2>"$error_file" \
        && [[ -s "$output_file" ]]; then
        ENGINE_SESSION=$(session_id_for_title "${title}-${engine}")
        return 0
      fi
      ;;
    *) fail "unknown engine: $engine" ;;
  esac
  return 1
}

invoke_with_fallback() {
  local title="$1" prompt_file="$2" output_file="$3"
  local engine
  FAILED_ENGINES=()
  for engine in sol fable glm; do
    if invoke_engine "$engine" "$title" "$prompt_file" "$output_file"; then
      SELECTED_ENGINE="$engine"
      SELECTED_SESSION="$ENGINE_SESSION"
      return 0
    fi
    FAILED_ENGINES+=("$engine")
  done
  return 1
}

failed_engines_json() {
  if [[ ${#FAILED_ENGINES[@]} -eq 0 ]]; then
    printf '[]\n'
  else
    printf '%s\n' "${FAILED_ENGINES[@]}" | jq -R . | jq -s .
  fi
}

emit_result() {
  local mode="$1" output_file="$2" panels_succeeded="${3:-}"
  local failed
  failed=$(failed_engines_json)
  jq -n \
    --arg status success \
    --arg mode "$mode" \
    --arg engine "$SELECTED_ENGINE" \
    --arg session_id "$SELECTED_SESSION" \
    --arg output_file "$output_file" \
    --argjson failed_engines "$failed" \
    --arg panels_succeeded "$panels_succeeded" \
    '{status: $status, mode: $mode, engine: $engine,
      session_id: $session_id, output_file: $output_file,
      failed_engines: $failed_engines}
      + (if $panels_succeeded == "" then {} else
          {panels_succeeded: ($panels_succeeded | tonumber)} end)'
}
