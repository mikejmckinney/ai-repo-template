#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.agents/skills/multi-model-consensus/scripts/common.sh
source "$SCRIPT_DIR/common.sh"

PROMPT_FILE=
INVOKING_SESSION=
TITLE="multi-model-fusion-$(date +%Y%m%d-%H%M%S)"
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
OUTPUT_DIR="${OUTPUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/multi-model-fusion.XXXXXX")}"
mkdir -p "$OUTPUT_DIR"

RUNTIME_PROMPT="$OUTPUT_DIR/panel-prompt.md"
append_session_context "$PROMPT_FILE" "$INVOKING_SESSION" "$RUNTIME_PROMPT"
printf '\n' >>"$RUNTIME_PROMPT"
cat "$SKILL_ROOT/prompts/panel-completion.md" >>"$RUNTIME_PROMPT"
PANEL_TIMEOUT_SECONDS="${MULTI_MODEL_CONSENSUS_PANEL_TIMEOUT:-${MULTI_MODEL_CONSENSUS_TIMEOUT:-600}}"

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

primary_engines=(kimi fable grok)
fallback_engines=(sol glm mm mi ds)
pids=()
panel_engines=(kimi fable grok)
panel_statuses=(success success success)
panel_rejected_engines=("" "" "")
panel_rejection_reasons=("" "" "")
panel_files=(
  "$OUTPUT_DIR/panel-1.md"
  "$OUTPUT_DIR/panel-2.md"
  "$OUTPUT_DIR/panel-3.md"
)

preserve_rejected_panel() {
  local index="$1" engine="$2" reason="$3"
  local source="${panel_files[$index]}"
  local rejected="$OUTPUT_DIR/panel-$((index + 1)).rejected-${engine}.md"
  if [[ -e "$source" ]]; then
    mv "$source" "$rejected"
  else
    : >"$rejected"
  fi
  printf '%s\n' "$reason" >"${rejected%.md}.validation.err"
  if [[ -n "${panel_rejected_engines[$index]}" ]]; then
    panel_rejected_engines[index]+=",$engine"
    panel_rejection_reasons[index]+=",$reason"
  else
    panel_rejected_engines[index]="$engine"
    panel_rejection_reasons[index]="$reason"
  fi
}

for index in "${!primary_engines[@]}"; do
  engine="${primary_engines[$index]}"
  invoke_panel_engine "$engine" "${TITLE}-panel-$((index + 1))" \
    "$RUNTIME_PROMPT" "${panel_files[$index]}" &
  pids+=("$!")
done

PANELS_SUCCEEDED=0
fallback_cursor=0
for index in "${!pids[@]}"; do
  if wait "${pids[$index]}"; then
    if validate_panel_output "${panel_files[$index]}"; then
      PANELS_SUCCEEDED=$((PANELS_SUCCEEDED + 1))
      continue
    fi
    preserve_rejected_panel "$index" "${panel_engines[$index]}" "$PANEL_REJECTION_REASON"
  elif [[ -e "${panel_files[$index]}" ]]; then
    preserve_rejected_panel "$index" "${panel_engines[$index]}" invocation_failed
  fi

  panel_statuses[index]=failed
  while [[ "$fallback_cursor" -lt "${#fallback_engines[@]}" ]]; do
    fallback_engine="${fallback_engines[$fallback_cursor]}"
    fallback_cursor=$((fallback_cursor + 1))
    if invoke_panel_engine "$fallback_engine" "${TITLE}-panel-$((index + 1))" \
      "$RUNTIME_PROMPT" "${panel_files[$index]}"; then
      if validate_panel_output "${panel_files[$index]}"; then
        panel_engines[index]="$fallback_engine"
        panel_statuses[index]=fallback
        PANELS_SUCCEEDED=$((PANELS_SUCCEEDED + 1))
        break
      fi
      preserve_rejected_panel "$index" "$fallback_engine" "$PANEL_REJECTION_REASON"
    elif [[ -e "${panel_files[$index]}" ]]; then
      preserve_rejected_panel "$index" "$fallback_engine" invocation_failed
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
    --arg rejected_engines "${panel_rejected_engines[$index]}" \
    --arg rejection_reasons "${panel_rejection_reasons[$index]}" \
    '{slot: $slot, engine: $engine, status: $status}
      + (if $rejected_engines == "" then {} else {
          rejected_engines: ($rejected_engines | split(",")),
          rejection_reasons: ($rejection_reasons | split(","))
        } end)')")
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
