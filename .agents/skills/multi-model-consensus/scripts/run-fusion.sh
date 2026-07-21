#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.agents/skills/multi-model-consensus/scripts/common.sh
source "$SCRIPT_DIR/common.sh"

PROMPT_FILE=
INVOKING_SESSION=
TITLE="multi-model-fusion-$(date +%Y%m%d-%H%M%S)"
OUTPUT_DIR=
PANEL_SESSION_SPECS=()
JUDGE_SESSION_SPEC=
REUSE_COMPLETED=false

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
    --panel-session)
      require_value "$1" "${2:-}"
      PANEL_SESSION_SPECS+=("$2")
      shift 2
      ;;
    --judge-session)
      require_value "$1" "${2:-}"
      JUDGE_SESSION_SPEC="$2"
      shift 2
      ;;
    --reuse-completed)
      REUSE_COMPLETED=true
      shift
      ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -f "$PROMPT_FILE" ]] || fail "--prompt-file must name a readable file"
[[ -n "$INVOKING_SESSION" ]] || fail "--invoking-session is required"

panel_resume_engines=("" "" "")
panel_resume_sessions=("" "" "")
for spec in "${PANEL_SESSION_SPECS[@]}"; do
  IFS=: read -r slot engine session_id extra <<<"$spec"
  [[ -z "${extra:-}" && "$slot" =~ ^[123]$ && -n "$engine" && -n "$session_id" ]] \
    || fail "panel session must be SLOT:ENGINE:SESSION_ID"
  case "$engine" in
    kimi | sol | opus | grok | glm | mm | mi | ds) ;;
    *) fail "unsupported panel session engine: $engine" ;;
  esac
  index=$((slot - 1))
  [[ -z "${panel_resume_sessions[$index]}" ]] \
    || fail "panel session slot specified more than once: $slot"
  panel_resume_engines[index]="$engine"
  panel_resume_sessions[index]="$session_id"
done

JUDGE_RESUME_ENGINE=
JUDGE_RESUME_SESSION=
if [[ -n "$JUDGE_SESSION_SPEC" ]]; then
  IFS=: read -r JUDGE_RESUME_ENGINE JUDGE_RESUME_SESSION extra <<<"$JUDGE_SESSION_SPEC"
  [[ -z "${extra:-}" && -n "$JUDGE_RESUME_ENGINE" && -n "$JUDGE_RESUME_SESSION" ]] \
    || fail "judge session must be ENGINE:SESSION_ID"
  case "$JUDGE_RESUME_ENGINE" in
    kimi | sol | opus | grok | glm | mm | mi | ds) ;;
    *) fail "unsupported judge session engine: $JUDGE_RESUME_ENGINE" ;;
  esac
fi

if [[ -z "$OUTPUT_DIR" ]]; then
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  artifact_root="${MULTI_MODEL_CONSENSUS_ARTIFACT_ROOT:-$repo_root/.artifacts/multi-model-consensus}"
  artifact_name="${TITLE//[^A-Za-z0-9._-]/-}"
  OUTPUT_DIR="$artifact_root/$artifact_name"
fi
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
RUN_ATTEMPT="$(date +%s)-$$"

RUNTIME_PROMPT="$OUTPUT_DIR/panel-prompt.md"
append_session_context "$PROMPT_FILE" "$INVOKING_SESSION" "$RUNTIME_PROMPT"
printf '\n' >>"$RUNTIME_PROMPT"
cat "$SKILL_ROOT/prompts/panel-completion.md" >>"$RUNTIME_PROMPT"
PANEL_TIMEOUT_SECONDS="${MULTI_MODEL_CONSENSUS_PANEL_TIMEOUT:-${MULTI_MODEL_CONSENSUS_TIMEOUT:-600}}"

invoke_panel_engine() {
  local output_file="$4" previous_timeout="$TIMEOUT_SECONDS" result
  TIMEOUT_SECONDS="$PANEL_TIMEOUT_SECONDS"
  if invoke_engine "$@"; then
    printf '%s\n' "$ENGINE_SESSION" >"${output_file%.md}.session"
    result=0
  else
    result=$?
  fi
  TIMEOUT_SECONDS="$previous_timeout"
  return "$result"
}

invoke_panel_session() {
  local engine="$1" session_id="$2" prompt_file="$3" output_file="$4"
  local previous_timeout="$TIMEOUT_SECONDS" result
  TIMEOUT_SECONDS="$PANEL_TIMEOUT_SECONDS"
  if invoke_engine_session "$engine" "$session_id" "$prompt_file" "$output_file"; then
    printf '%s\n' "$ENGINE_SESSION" >"${output_file%.md}.session"
    result=0
  else
    result=$?
  fi
  TIMEOUT_SECONDS="$previous_timeout"
  return "$result"
}

primary_engines=(kimi opus grok)
fallback_engines=(sol glm mm mi ds)
panel_pids=("" "" "")
panel_engines=(kimi opus grok)
panel_statuses=(success success success)
panel_rejected_engines=("" "" "")
panel_rejection_reasons=("" "" "")
panel_sessions=("" "" "")
panel_continued=(false false false)
panel_reused=(false false false)
panel_files=(
  "$OUTPUT_DIR/panel-1.md"
  "$OUTPUT_DIR/panel-2.md"
  "$OUTPUT_DIR/panel-3.md"
)
panel_attempt_files=(
  "$OUTPUT_DIR/.panel-1.${RUN_ATTEMPT}.md"
  "$OUTPUT_DIR/.panel-2.${RUN_ATTEMPT}.md"
  "$OUTPUT_DIR/.panel-3.${RUN_ATTEMPT}.md"
)

promote_panel() {
  local index="$1" source="$2" destination="${panel_files[$1]}"
  mv "$source" "$destination"
  mv "${source%.md}.session" "${destination%.md}.session"
}

preserve_rejected_panel() {
  local index="$1" engine="$2" reason="$3" source="$4"
  local rejected="$OUTPUT_DIR/panel-$((index + 1)).rejected-${engine}.${RUN_ATTEMPT}.md"
  if [[ -e "$source" ]]; then
    mv "$source" "$rejected"
  else
    : >"$rejected"
  fi
  if [[ -e "${source%.md}.session" ]]; then
    mv "${source%.md}.session" "${rejected%.md}.session"
  fi
  if [[ -e "${source}.json" ]]; then
    mv "${source}.json" "${rejected}.json"
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

PANELS_SUCCEEDED=0
for index in "${!primary_engines[@]}"; do
  if [[ "$REUSE_COMPLETED" == true &&
    -n "${panel_resume_sessions[$index]}" &&
    -s "${panel_files[$index]}" &&
    -s "${panel_files[$index]%.md}.session" &&
    "$(<"${panel_files[$index]%.md}.session")" == "${panel_resume_sessions[$index]}" ]] \
    && validate_panel_output "${panel_files[$index]}"; then
    panel_engines[index]="${panel_resume_engines[$index]}"
    panel_statuses[index]=reused
    panel_sessions[index]="${panel_resume_sessions[$index]}"
    panel_reused[index]=true
    PANELS_SUCCEEDED=$((PANELS_SUCCEEDED + 1))
    continue
  fi
  if [[ -n "${panel_resume_sessions[$index]}" ]]; then
    engine="${panel_resume_engines[$index]}"
    panel_engines[index]="$engine"
    invoke_panel_session "$engine" "${panel_resume_sessions[$index]}" \
      "$RUNTIME_PROMPT" "${panel_attempt_files[$index]}" &
  else
    engine="${primary_engines[$index]}"
    invoke_panel_engine "$engine" "${TITLE}-panel-$((index + 1))" \
      "$RUNTIME_PROMPT" "${panel_attempt_files[$index]}" &
  fi
  panel_pids[index]="$!"
done

fallback_cursor=0
for index in "${!primary_engines[@]}"; do
  [[ "${panel_reused[$index]}" == false ]] || continue
  attempt_file="${panel_attempt_files[$index]}"
  if wait "${panel_pids[$index]}"; then
    if validate_panel_output "$attempt_file"; then
      promote_panel "$index" "$attempt_file"
      panel_sessions[index]="$(<"${panel_files[$index]%.md}.session")"
      if [[ -n "${panel_resume_sessions[$index]}" ]]; then
        panel_statuses[index]=resumed
        panel_continued[index]=true
      fi
      PANELS_SUCCEEDED=$((PANELS_SUCCEEDED + 1))
      continue
    fi
    preserve_rejected_panel "$index" "${panel_engines[$index]}" "$PANEL_REJECTION_REASON" "$attempt_file"
  elif [[ -e "$attempt_file" ]]; then
    preserve_rejected_panel "$index" "${panel_engines[$index]}" invocation_failed "$attempt_file"
  fi

  panel_statuses[index]=failed
  while [[ "$fallback_cursor" -lt "${#fallback_engines[@]}" ]]; do
    fallback_engine="${fallback_engines[$fallback_cursor]}"
    fallback_cursor=$((fallback_cursor + 1))
    [[ "$fallback_engine" != "${panel_engines[$index]}" ]] || continue
    attempt_file="$OUTPUT_DIR/.panel-$((index + 1)).${RUN_ATTEMPT}-${fallback_engine}.md"
    if invoke_panel_engine "$fallback_engine" "${TITLE}-panel-$((index + 1))" \
      "$RUNTIME_PROMPT" "$attempt_file"; then
      if validate_panel_output "$attempt_file"; then
        promote_panel "$index" "$attempt_file"
        panel_engines[index]="$fallback_engine"
        panel_statuses[index]=fallback
        panel_sessions[index]="$(<"${panel_files[$index]%.md}.session")"
        panel_continued[index]=false
        PANELS_SUCCEEDED=$((PANELS_SUCCEEDED + 1))
        break
      fi
      preserve_rejected_panel "$index" "$fallback_engine" "$PANEL_REJECTION_REASON" "$attempt_file"
    elif [[ -e "$attempt_file" ]]; then
      preserve_rejected_panel "$index" "$fallback_engine" invocation_failed "$attempt_file"
    fi
  done
done
[[ "$PANELS_SUCCEEDED" -ge 2 ]] \
  || fail "fewer than two panels succeeded; inspect $OUTPUT_DIR"

build_panels_json() {
  local index checksum
  panel_records=()
  for index in "${!panel_engines[@]}"; do
    checksum=
    if [[ -s "${panel_files[$index]}" ]]; then
      checksum=$(sha256sum "${panel_files[$index]}" | cut -d' ' -f1)
    fi
    panel_records+=("$(jq -n \
      --arg slot "${primary_engines[$index]}" \
      --arg engine "${panel_engines[$index]}" \
      --arg status "${panel_statuses[$index]}" \
      --arg session_id "${panel_sessions[$index]}" \
      --arg requested_session_id "${panel_resume_sessions[$index]}" \
      --arg output_file "${panel_files[$index]}" \
      --arg sha256 "$checksum" \
      --argjson continued "${panel_continued[$index]}" \
      --argjson reused "${panel_reused[$index]}" \
      --arg rejected_engines "${panel_rejected_engines[$index]}" \
      --arg rejection_reasons "${panel_rejection_reasons[$index]}" \
      '{slot: $slot, engine: $engine, status: $status,
        session_id: $session_id, output_file: $output_file, sha256: $sha256,
        continued: $continued, reused: $reused}
        + (if $requested_session_id == "" then {} else
            {requested_session_id: $requested_session_id} end)
        + (if $rejected_engines == "" then {} else {
            rejected_engines: ($rejected_engines | split(",")),
            rejection_reasons: ($rejection_reasons | split(","))
          } end)')")
  done
  PANELS_JSON=$(printf '%s\n' "${panel_records[@]}" | jq -s .)
}

persist_result() {
  local content="$1" temp="$OUTPUT_DIR/.result.${RUN_ATTEMPT}.json"
  printf '%s\n' "$content" >"$temp"
  mv "$temp" "$OUTPUT_DIR/result.json"
}

build_panels_json
PARTIAL_RESULT=$(jq -n \
  --arg status panels_complete \
  --arg mode fusion \
  --arg output_dir "$OUTPUT_DIR" \
  --argjson panels_succeeded "$PANELS_SUCCEEDED" \
  --argjson panels "$PANELS_JSON" \
  '{status: $status, mode: $mode, output_dir: $output_dir,
    panels_succeeded: $panels_succeeded, panels: $panels}')
persist_result "$PARTIAL_RESULT"

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
ANSWER_ATTEMPT="$OUTPUT_DIR/.answer.${RUN_ATTEMPT}.md"
JUDGE_CONTINUED=false
if [[ -n "$JUDGE_RESUME_SESSION" ]]; then
  FAILED_ENGINES=()
  invoke_engine_session "$JUDGE_RESUME_ENGINE" "$JUDGE_RESUME_SESSION" \
    "$JUDGE_PROMPT" "$ANSWER_ATTEMPT" \
    || fail "explicit judge session failed; inspect $OUTPUT_DIR"
  SELECTED_ENGINE="$JUDGE_RESUME_ENGINE"
  SELECTED_SESSION="$JUDGE_RESUME_SESSION"
  JUDGE_CONTINUED=true
else
  invoke_with_fallback "${TITLE}-judge" "$JUDGE_PROMPT" "$ANSWER_ATTEMPT" \
    || fail "all judge engines failed; inspect $OUTPUT_DIR"
fi
mv "$ANSWER_ATTEMPT" "$ANSWER_FILE"

JUDGE_OVERLAP=false
for engine in "${panel_engines[@]}"; do
  if [[ "$engine" == "$SELECTED_ENGINE" ]]; then
    JUDGE_OVERLAP=true
    break
  fi
done

RESULT_JSON=$(emit_result fusion "$ANSWER_FILE" "$PANELS_SUCCEEDED" \
  | jq --argjson panels "$PANELS_JSON" \
    --argjson judge_overlap "$JUDGE_OVERLAP" \
    --argjson judge_continued "$JUDGE_CONTINUED" \
    --arg output_dir "$OUTPUT_DIR" \
    '. + {panels: $panels, judge_overlap: $judge_overlap,
      judge_continued: $judge_continued, output_dir: $output_dir}')
persist_result "$RESULT_JSON"
printf '%s\n' "$RESULT_JSON"
