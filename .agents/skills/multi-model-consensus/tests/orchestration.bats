#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  SKILL_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/multi-model-consensus-test.XXXXXX")"
  BIN_DIR="$TEST_ROOT/bin"
  mkdir -p "$BIN_DIR"
  export PATH="$BIN_DIR:$PATH"
  export MULTI_MODEL_CONSENSUS_TIMEOUT=5
  export MULTI_MODEL_CONSENSUS_SESSION_LIMIT=100
  export MOCK_LOG="$TEST_ROOT/calls.log"
  export MOCK_SOL_MODE=success
  export MOCK_KIMI_MODE=success
  export MOCK_GROK_MODE=success
  export MOCK_GLM_MODE=success
  printf '%s\n' 'Analyze this problem.' >"$TEST_ROOT/prompt.md"
  cat >"$BIN_DIR/opencode" <<'EOF'
#!/usr/bin/env bash
printf 'opencode %s\n' "$*" >>"$MOCK_LOG"
if [[ "$1 $2" == "session list" ]]; then
  printf '[{"id":"ses_sol","title":"multi-model-advisor-test-sol"},{"id":"ses_kimi","title":"multi-model-fusion-test-panel-1-kimi"},{"id":"ses_panel_sol","title":"multi-model-fusion-test-panel-2-sol"},{"id":"ses_judge","title":"multi-model-fusion-test-judge-sol"}]\n'
  exit 0
fi
if [[ "$1 $2" == "models openai" ]]; then
  printf 'openai/gpt-5.6-sol\n'
  exit 0
fi
if [[ "$1 $2" == "models openrouter" ]]; then
  printf 'openrouter/moonshotai/kimi-k3\n'
  printf 'openrouter/moonshotai/kimi-k3@preset/consensus\n'
  exit 0
fi
model=
title=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) model="$2"; shift 2 ;;
    --title) title="$2"; shift 2 ;;
    *) shift ;;
  esac
done
prompt=$(cat)
printf 'prompt-bytes=%s\n' "${#prompt}" >>"$MOCK_LOG"
marker='<!-- multi-model-panel-complete:v1 -->'
panel=false
[[ "$prompt" == *"$marker"* ]] && panel=true
if [[ "$model" == "openai/gpt-5.6-sol" ]]; then
  [[ "$MOCK_SOL_MODE" == success ]] || exit 7
  printf 'Sol answer\n'
  if $panel; then printf '%s\n' "$marker"; fi
elif [[ "$model" == "openrouter/moonshotai/kimi-k3@preset/consensus" ]]; then
  [[ "$MOCK_KIMI_MODE" != fail ]] || exit 12
  sleep "${MOCK_KIMI_DELAY:-0}"
  case "$MOCK_KIMI_MODE" in
    preamble) printf 'I will inspect the evidence before answering.\n' ;;
    marker-only) printf '%s\n' "$marker" ;;
    marker-not-final) printf 'Kimi answer\n%s\ntrailing output\n' "$marker" ;;
    marked-fail)
      printf 'Kimi answer\n%s\n' "$marker"
      exit 12
      ;;
    *)
      printf 'Kimi answer\n'
      if $panel; then printf '%s\n' "$marker"; fi
      ;;
  esac
elif [[ "$title" == *-glm ]]; then
  [[ "$MOCK_GLM_MODE" == success ]] || exit 10
  printf 'GLM answer\n'
  if $panel; then printf '%s\n' "$marker"; fi
elif [[ "$title" == *-mi || "$title" == *-ds ]]; then
  printf 'Panel answer from %s\n' "$title"
  if $panel; then printf '%s\n' "$marker"; fi
elif [[ "$title" == *-mm ]]; then
  [[ "${MOCK_MM_MODE:-success}" == success ]] || exit 9
  printf 'Panel answer from %s\n' "$title"
  if $panel; then printf '%s\n' "$marker"; fi
else
  printf 'OpenCode answer\n'
  if $panel; then printf '%s\n' "$marker"; fi
fi
EOF
  chmod +x "$BIN_DIR/opencode"

  cat >"$BIN_DIR/agent" <<'EOF'
#!/usr/bin/env bash
printf 'agent %s\n' "$*" >>"$MOCK_LOG"
if [[ "$1" == "--list-models" ]]; then
  printf 'cursor-grok-4.5-medium - Cursor Grok 4.5 Medium\n'
  exit 0
fi
prompt=$(cat)
printf 'prompt-bytes=%s\n' "${#prompt}" >>"$MOCK_LOG"
sleep "${MOCK_GROK_DELAY:-0}"
[[ "$MOCK_GROK_MODE" == success ]] || exit 11
result='Grok answer'
[[ "$prompt" != *'<!-- multi-model-panel-complete:v1 -->'* ]] || result="$result
<!-- multi-model-panel-complete:v1 -->"
jq -cn --arg result "$result" '{type:"result",subtype:"success",is_error:false,result:$result,session_id:"ses_grok"}'
EOF
  chmod +x "$BIN_DIR/agent"

  cat >"$BIN_DIR/claude" <<'EOF'
#!/usr/bin/env bash
printf 'claude %s\n' "$*" >>"$MOCK_LOG"
prompt=$(cat)
  sleep "${MOCK_OPUS_DELAY:-0}"
  if [[ "${MOCK_OPUS_MODE:-success}" == fail ]]; then exit 8; fi
  if [[ "${MOCK_OPUS_MODE:-success}" == api-error ]]; then
    jq -cn '{is_error:true,result:"spend limit",session_id:"ses_opus"}'
  exit 0
fi
  result='Opus answer'
[[ "$prompt" != *'<!-- multi-model-panel-complete:v1 -->'* ]] || result="$result
<!-- multi-model-panel-complete:v1 -->"
  jq -cn --arg result "$result" '{result:$result,session_id:"ses_opus"}'
EOF
  chmod +x "$BIN_DIR/claude"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "advisor uses OpenAI Sol and emits a structured result" {
  run "$SKILL_ROOT/scripts/run-advisor.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-advisor-test \
    --output-dir "$TEST_ROOT/advisor"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.status' <<<"$output")" = success ]
  [ "$(jq -r '.engine' <<<"$output")" = sol ]
  [ "$(jq -r '.session_id' <<<"$output")" = ses_sol ]
  grep -q -- '--model openai/gpt-5.6-sol' "$MOCK_LOG"
}

@test "advisor falls back to Opus when Sol fails" {
  export MOCK_SOL_MODE=fail
  run "$SKILL_ROOT/scripts/run-advisor.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-advisor-test \
    --output-dir "$TEST_ROOT/advisor"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.engine' <<<"$output")" = opus ]
  [ "$(jq -r '.failed_engines[0]' <<<"$output")" = sol ]
  grep -q -- '--model opus' "$MOCK_LOG"
}

@test "advisor falls back to Cursor Grok before GLM" {
  export MOCK_SOL_MODE=fail
  export MOCK_OPUS_MODE=fail
  run "$SKILL_ROOT/scripts/run-advisor.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-advisor-test \
    --output-dir "$TEST_ROOT/advisor"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.engine' <<<"$output")" = grok ]
  [ "$(jq -r '.session_id' <<<"$output")" = ses_grok ]
  grep -q -- '--model cursor-grok-4.5-medium' "$MOCK_LOG"
  run ! grep -q -- '-glm' "$MOCK_LOG"
}

@test "advisor transports a large prompt through stdin" {
  dd if=/dev/zero bs=1024 count=256 2>/dev/null | tr '\0' x >"$TEST_ROOT/large.md"
  run "$SKILL_ROOT/scripts/run-advisor.sh" \
    --prompt-file "$TEST_ROOT/large.md" \
    --invoking-session ses_parent \
    --title multi-model-advisor-test \
    --output-dir "$TEST_ROOT/advisor"

  [ "$status" -eq 0 ]
  prompt_bytes=$(grep 'prompt-bytes=' "$MOCK_LOG" | cut -d= -f2)
  [ "$prompt_bytes" -ge 262144 ]
}

@test "fusion uses Kimi, Opus, and Cursor Grok as its primary panel" {
  run "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.status' <<<"$output")" = success ]
  [ "$(jq -r '.panels_succeeded' <<<"$output")" -eq 3 ]
  [ "$(jq -r '.engine' <<<"$output")" = sol ]
  [ "$(jq -r '[.panels[].engine] | join(",")' <<<"$output")" = "kimi,opus,grok" ]
  [ "$(jq -r '[.panels[].session_id | length > 0] | all' <<<"$output")" = true ]
  [ "$(jq -r '[.panels[].output_file | length > 0] | all' <<<"$output")" = true ]
  [ "$(jq -r '.judge_continued' <<<"$output")" = false ]
  [ "$(jq -r '[.panels[].reused] | any' <<<"$output")" = false ]
  cmp -s <(jq -S . <<<"$output") <(jq -S . "$TEST_ROOT/fusion/result.json")
  grep -q -- '--model openrouter/moonshotai/kimi-k3' "$MOCK_LOG"
  grep -q -- 'agent -p --trust' "$MOCK_LOG"
  run ! grep -q '## Panel SOL\|## Panel OPUS\|## Panel GLM' "$TEST_ROOT/fusion/judge-prompt.md"
}

@test "fusion backfills a failed primary with Sol" {
  run env MOCK_OPUS_MODE=fail "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.panels_succeeded' <<<"$output")" -eq 3 ]
  [ "$(jq -r '.panels[1].slot' <<<"$output")" = opus ]
  [ "$(jq -r '.panels[1].engine' <<<"$output")" = sol ]
  [ "$(jq -r '.panels[1].status' <<<"$output")" = fallback ]
  grep -q -- '--model openai/gpt-5.6-sol' "$MOCK_LOG"
}

@test "fusion rejects a zero-exit Opus API error" {
  run env MOCK_OPUS_MODE=api-error "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.panels[1].engine' <<<"$output")" = sol ]
  [ "$(jq -r '.panels[1].status' <<<"$output")" = fallback ]
  rejected=("$TEST_ROOT"/fusion/panel-2.rejected-opus.*.md)
  grep -q 'spend limit' "${rejected[0]}"
}

@test "fusion rejects a zero-exit preamble and backfills the panel" {
  run env MOCK_KIMI_MODE=preamble "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.panels_succeeded' <<<"$output")" -eq 3 ]
  [ "$(jq -r '.panels[0].engine' <<<"$output")" = sol ]
  [ "$(jq -r '.panels[0].status' <<<"$output")" = fallback ]
  [ "$(jq -r '.panels[0].rejected_engines[0]' <<<"$output")" = kimi ]
  [ "$(jq -r '.panels[0].rejection_reasons[0]' <<<"$output")" = missing_completion_marker ]
  rejected=("$TEST_ROOT"/fusion/panel-1.rejected-kimi.*.md)
  [ -s "${rejected[0]}" ]
  run grep -q 'I will inspect the evidence' "$TEST_ROOT/fusion/judge-prompt.md"
  [ "$status" -ne 0 ]
}

@test "fusion rejects marker-only output" {
  run env MOCK_KIMI_MODE=marker-only "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.panels[0].rejection_reasons[0]' <<<"$output")" = empty_answer_before_marker ]
  [ "$(jq -r '.panels[0].engine' <<<"$output")" = sol ]
}

@test "fusion rejects a completion marker that is not final" {
  run env MOCK_KIMI_MODE=marker-not-final "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.panels[0].rejection_reasons[0]' <<<"$output")" = missing_completion_marker ]
  [ "$(jq -r '.panels[0].engine' <<<"$output")" = sol ]
}

@test "fusion rejects and preserves marked output from a failed invocation" {
  run env MOCK_KIMI_MODE=marked-fail "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.panels[0].rejection_reasons[0]' <<<"$output")" = invocation_failed ]
  [ "$(jq -r '.panels[0].engine' <<<"$output")" = sol ]
  rejected=("$TEST_ROOT"/fusion/panel-1.rejected-kimi.*.md)
  grep -q 'Kimi answer' "${rejected[0]}"
}

@test "fusion advances from Sol to GLM without reuse" {
  run env MOCK_OPUS_MODE=fail MOCK_SOL_MODE=fail \
    "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.panels[1].engine' <<<"$output")" = glm ]
  [ "$(jq -r '.panels[1].status' <<<"$output")" = fallback ]
  grep -q -- '--model openrouter/z-ai/glm-5.2@preset/default' "$MOCK_LOG"
}

@test "fusion resumes explicit panel and judge sessions with provenance" {
  run "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test \
    --panel-session 1:kimi:ses_kimi_old \
    --panel-session 2:opus:ses_opus_old \
    --panel-session 3:grok:ses_grok_old \
    --judge-session sol:ses_judge_old \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '[.panels[].session_id] | join(",")' <<<"$output")" = \
    "ses_kimi_old,ses_opus_old,ses_grok_old" ]
  [ "$(jq -r '[.panels[].continued] | all' <<<"$output")" = true ]
  [ "$(jq -r '.session_id' <<<"$output")" = ses_judge_old ]
  [ "$(jq -r '.judge_continued' <<<"$output")" = true ]
  [ "$(jq -r '.output_dir' <<<"$output")" = "$TEST_ROOT/fusion" ]
  grep -q -- '--session ses_kimi_old --continue' "$MOCK_LOG"
  grep -q -- '-r ses_opus_old' "$MOCK_LOG"
  grep -q -- '--resume ses_grok_old' "$MOCK_LOG"
  grep -q -- '--session ses_judge_old --continue' "$MOCK_LOG"
}

@test "fusion records failed resume before accepting a fallback panel" {
  run env MOCK_OPUS_MODE=fail "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test \
    --panel-session 2:opus:ses_opus_old \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.panels[1].status' <<<"$output")" = fallback ]
  [ "$(jq -r '.panels[1].requested_session_id' <<<"$output")" = ses_opus_old ]
  [ "$(jq -r '.panels[1].session_id' <<<"$output")" = ses_panel_sol ]
  [ "$(jq -r '.panels[1].continued' <<<"$output")" = false ]
}

@test "fusion rejects malformed explicit session specifications" {
  run "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --panel-session latest \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -ne 0 ]
  [[ "$output" == *"panel session must be SLOT:ENGINE:SESSION_ID"* ]]
  [ ! -e "$MOCK_LOG" ]
}

@test "fusion rejects duplicate panel session slots" {
  run "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --panel-session 1:kimi:ses_one \
    --panel-session 1:sol:ses_two \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -ne 0 ]
  [[ "$output" == *"panel session slot specified more than once"* ]]
}

@test "fusion defaults to durable artifact output" {
  export MULTI_MODEL_CONSENSUS_ARTIFACT_ROOT="$TEST_ROOT/artifacts"
  run "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test

  [ "$status" -eq 0 ]
  [ "$(jq -r '.output_dir' <<<"$output")" = "$TEST_ROOT/artifacts/multi-model-fusion-test" ]
  [ -s "$TEST_ROOT/artifacts/multi-model-fusion-test/answer.md" ]
  [ -s "$TEST_ROOT/artifacts/multi-model-fusion-test/result.json" ]
}

@test "fusion reuses a completed panel after interruption" {
  run env MOCK_OPUS_DELAY=3 MOCK_GROK_DELAY=3 timeout 1 \
    "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 124 ]
  [ -s "$TEST_ROOT/fusion/panel-1.md" ]
  [ "$(<"$TEST_ROOT/fusion/panel-1.session")" = ses_kimi ]

  : >"$MOCK_LOG"
  run "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test \
    --reuse-completed \
    --panel-session 1:kimi:ses_kimi \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.panels[0].status' <<<"$output")" = reused ]
  [ "$(jq -r '.panels[0].reused' <<<"$output")" = true ]
  run grep -q -- '--session ses_kimi' "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "environment validation confirms configured Kimi, Sol, and Grok models" {
  run "$SKILL_ROOT/scripts/validate-environment.sh"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.status' <<<"$output")" = success ]
  [ "$(jq -r '.kimi_model' <<<"$output")" = openrouter/moonshotai/kimi-k3@preset/consensus ]
  [ "$(jq -r '.opus_model' <<<"$output")" = opus ]
}

@test "panel completion contract ends with the bare unfenced marker" {
  contract="$SKILL_ROOT/prompts/panel-completion.md"

  [ "$(grep -v '^[[:space:]]*$' "$contract" | tail -1)" = '<!-- multi-model-panel-complete:v1 -->' ]
  run grep -q '^```' "$contract"
  [ "$status" -ne 0 ]
}
