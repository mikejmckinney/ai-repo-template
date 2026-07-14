#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.opencode/skills/local-consensus/scripts/common.sh
source "$SCRIPT_DIR/common.sh"

PROMPT_FILE=
INVOKING_SESSION=
TITLE="local-fusion-$(date +%Y%m%d-%H%M%S)"
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
OUTPUT_DIR="${OUTPUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/local-fusion.XXXXXX")}"
mkdir -p "$OUTPUT_DIR"

RUNTIME_PROMPT="$OUTPUT_DIR/panel-prompt.md"
append_session_context "$PROMPT_FILE" "$INVOKING_SESSION" "$RUNTIME_PROMPT"
PANEL_TIMEOUT_SECONDS="${LOCAL_CONSENSUS_PANEL_TIMEOUT:-${LOCAL_CONSENSUS_TIMEOUT:-600}}"

invoke_panel_engine() {
  local previous_timeout="$TIMEOUT_SECONDS" result
  TIMEOUT_SECONDS="$PANEL_TIMEOUT_SECONDS"
  if invoke_engine "$@"; then
    result=0
  else
    result=$?
  fi
  TIMEOUT_SECONDS="$previous_timeout"
  return "$result"
}

primary_engines=(sol fable glm)
fallback_engines=(mm mi ds)
pids=()
panel_engines=(sol fable glm)
panel_statuses=(success success success)
panel_files=(
  "$OUTPUT_DIR/panel-1.md"
  "$OUTPUT_DIR/panel-2.md"
  "$OUTPUT_DIR/panel-3.md"
)

for index in "${!primary_engines[@]}"; do
  engine="${primary_engines[$index]}"
  invoke_panel_engine "$engine" "${TITLE}-panel-$((index + 1))" \
    "$RUNTIME_PROMPT" "${panel_files[$index]}" &
  pids+=("$!")
done

PANELS_SUCCEEDED=0
fallback_cursor=0
for index in "${!pids[@]}"; do
  if wait "${pids[$index]}" && [[ -s "${panel_files[$index]}" ]]; then
    PANELS_SUCCEEDED=$((PANELS_SUCCEEDED + 1))
    continue
  fi

  panel_statuses[index]=failed
  while [[ "$fallback_cursor" -lt "${#fallback_engines[@]}" ]]; do
    fallback_engine="${fallback_engines[$fallback_cursor]}"
    fallback_cursor=$((fallback_cursor + 1))
    if invoke_panel_engine "$fallback_engine" "${TITLE}-panel-$((index + 1))" \
      "$RUNTIME_PROMPT" "${panel_files[$index]}"; then
      panel_engines[index]="$fallback_engine"
      panel_statuses[index]=fallback
      PANELS_SUCCEEDED=$((PANELS_SUCCEEDED + 1))
      break
    fi
  done
done
[[ "$PANELS_SUCCEEDED" -ge 2 ]] \
  || fail "fewer than two panels succeeded; inspect $OUTPUT_DIR"

JUDGE_PROMPT="$OUTPUT_DIR/judge-prompt.md"
cat "$SKILL_ROOT/prompts/judge.md" >"$JUDGE_PROMPT"
panel_labels=(A B C)
for index in "${!panel_files[@]}"; do
  if [[ "${panel_statuses[$index]}" != failed && -s "${panel_files[$index]}" ]]; then
    printf '\n## Panel %s\n' "${panel_labels[$index]}" >>"$JUDGE_PROMPT"
    cat "${panel_files[$index]}" >>"$JUDGE_PROMPT"
  fi
done

ANSWER_FILE="$OUTPUT_DIR/answer.md"
invoke_with_fallback "${TITLE}-judge" "$JUDGE_PROMPT" "$ANSWER_FILE" \
  || fail "all judge engines failed; inspect $OUTPUT_DIR"

panel_records=()
for index in "${!panel_engines[@]}"; do
  panel_records+=("$(jq -n \
    --arg slot "${primary_engines[$index]}" \
    --arg engine "${panel_engines[$index]}" \
    --arg status "${panel_statuses[$index]}" \
    '{slot: $slot, engine: $engine, status: $status}')")
done
PANELS_JSON=$(printf '%s\n' "${panel_records[@]}" | jq -s .)

JUDGE_OVERLAP=false
for engine in "${panel_engines[@]}"; do
  if [[ "$engine" == "$SELECTED_ENGINE" ]]; then
    JUDGE_OVERLAP=true
    break
  fi
done

emit_result fusion "$ANSWER_FILE" "$PANELS_SUCCEEDED" \
  | jq --argjson panels "$PANELS_JSON" \
    --argjson judge_overlap "$JUDGE_OVERLAP" \
    '. + {panels: $panels, judge_overlap: $judge_overlap}'
