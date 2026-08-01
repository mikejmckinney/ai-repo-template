#!/usr/bin/env bash

set -o pipefail

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SKILL_ROOT
TIMEOUT_SECONDS="${MULTI_MODEL_CONSENSUS_TIMEOUT:-600}"
SESSION_LIMIT="${MULTI_MODEL_CONSENSUS_SESSION_LIMIT:-100}"
KIMI_MODEL="${MULTI_MODEL_CONSENSUS_KIMI_MODEL:-openrouter/moonshotai/kimi-k3@preset/consensus}"
SOL_MODEL="${MULTI_MODEL_CONSENSUS_SOL_MODEL:-openai/gpt-5.6-sol}"
GROK_MODEL="${MULTI_MODEL_CONSENSUS_GROK_MODEL:-cursor-grok-4.5-medium}"
GLM_MODEL="${MULTI_MODEL_CONSENSUS_GLM_MODEL:-openrouter/z-ai/glm-5.2@preset/default}"
MM_MODEL="${MULTI_MODEL_CONSENSUS_MM_MODEL:-openrouter/minimax/minimax-m3@preset/default}"
MI_MODEL="${MULTI_MODEL_CONSENSUS_MI_MODEL:-openrouter/xiaomi/mimo-v2.5-pro@preset/default}"
DS_MODEL="${MULTI_MODEL_CONSENSUS_DS_MODEL:-openrouter/deepseek/deepseek-v4-pro@preset/default}"
PANEL_COMPLETION_MARKER='<!-- multi-model-panel-complete:v1 -->'

fail() {
  printf 'multi-model-consensus: %s\n' "$*" >&2
  exit 1
}

require_value() {
  [[ $# -ge 2 && -n "$2" ]] || fail "$1 requires a value"
}

# shellcheck disable=SC2034 # Rejection reason is consumed by scripts that source this library.
validate_panel_output() {
  local output_file="$1" line trimmed last='' content=false
  PANEL_REJECTION_REASON=
  if [[ ! -s "$output_file" ]]; then
    PANEL_REJECTION_REASON=empty_output
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    trimmed="${line#"${line%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    [[ -n "$trimmed" ]] || continue
    last="$trimmed"
    [[ "$trimmed" == "$PANEL_COMPLETION_MARKER" ]] || content=true
  done <"$output_file"

  if [[ "$last" != "$PANEL_COMPLETION_MARKER" ]]; then
    PANEL_REJECTION_REASON=missing_completion_marker
    return 1
  fi
  if [[ "$content" != true ]]; then
    PANEL_REJECTION_REASON=empty_answer_before_marker
    return 1
  fi
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
    kimi)
      if run_with_timeout "$TIMEOUT_SECONDS" opencode run --title "${title}-kimi" \
        --model "$KIMI_MODEL" <"$prompt_file" >"$output_file" 2>"$error_file" \
        && [[ -s "$output_file" ]]; then
        ENGINE_SESSION=$(session_id_for_title "${title}-kimi")
        return 0
      fi
      ;;
    sol)
      if run_with_timeout "$TIMEOUT_SECONDS" opencode run --title "${title}-sol" \
        --model "$SOL_MODEL" --variant medium \
        <"$prompt_file" >"$output_file" 2>"$error_file" \
        && [[ -s "$output_file" ]]; then
        ENGINE_SESSION=$(session_id_for_title "${title}-sol")
        return 0
      fi
      ;;
    opus)
      if run_with_timeout "$TIMEOUT_SECONDS" claude -p --model opus \
        --effort medium --output-format json --dangerously-skip-permissions \
        <"$prompt_file" >"${output_file}.json" 2>"$error_file"; then
        jq -r '.result // empty' "${output_file}.json" >"$output_file"
        ENGINE_SESSION=$(jq -r '.session_id // empty' "${output_file}.json")
        if jq -e '.is_error != true and ((.result // "") | length > 0)' \
          "${output_file}.json" >/dev/null && [[ -s "$output_file" ]]; then
          return 0
        fi
      fi
      ;;
    grok)
      if run_with_timeout "$TIMEOUT_SECONDS" agent -p --trust --model "$GROK_MODEL" \
        --output-format json <"$prompt_file" >"${output_file}.json" 2>"$error_file"; then
        jq -r '.result // empty' "${output_file}.json" >"$output_file"
        ENGINE_SESSION=$(jq -r '.session_id // empty' "${output_file}.json")
        if jq -e '.is_error != true and ((.result // "") | length > 0)' \
          "${output_file}.json" >/dev/null && [[ -s "$output_file" ]]; then
          return 0
        fi
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

invoke_engine_session() {
  local engine="$1" session_id="$2" prompt_file="$3" output_file="$4"
  local error_file="${output_file%.md}.err"
  ENGINE_SESSION="$session_id"

  case "$engine" in
    kimi | glm | mm | mi | ds)
      run_with_timeout "$TIMEOUT_SECONDS" opencode run \
        --session "$session_id" --continue \
        <"$prompt_file" >"$output_file" 2>"$error_file" \
        && [[ -s "$output_file" ]]
      ;;
    sol)
      run_with_timeout "$TIMEOUT_SECONDS" opencode run \
        --session "$session_id" --continue --variant medium \
        <"$prompt_file" >"$output_file" 2>"$error_file" \
        && [[ -s "$output_file" ]]
      ;;
    opus)
      if run_with_timeout "$TIMEOUT_SECONDS" claude -p --model opus \
        --effort medium --output-format json --dangerously-skip-permissions -r "$session_id" \
        <"$prompt_file" >"${output_file}.json" 2>"$error_file"; then
        jq -r '.result // empty' "${output_file}.json" >"$output_file"
        jq -e '.is_error != true and ((.result // "") | length > 0)' \
          "${output_file}.json" >/dev/null && [[ -s "$output_file" ]]
      else
        return 1
      fi
      ;;
    grok)
      if run_with_timeout "$TIMEOUT_SECONDS" agent -p --trust --resume "$session_id" \
        --model "$GROK_MODEL" --output-format json \
        <"$prompt_file" >"${output_file}.json" 2>"$error_file"; then
        jq -r '.result // empty' "${output_file}.json" >"$output_file"
        jq -e '.is_error != true and ((.result // "") | length > 0)' \
          "${output_file}.json" >/dev/null && [[ -s "$output_file" ]]
      else
        return 1
      fi
      ;;
    *) fail "unknown engine: $engine" ;;
  esac
}

invoke_with_fallback() {
  local title="$1" prompt_file="$2" output_file="$3"
  local engine
  FAILED_ENGINES=()
  for engine in sol opus grok glm; do
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
