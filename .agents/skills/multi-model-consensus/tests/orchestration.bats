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
  printf '[{"id":"ses_sol","title":"multi-model-advisor-test-sol"},{"id":"ses_judge","title":"multi-model-fusion-test-judge-sol"}]\n'
  exit 0
fi
if [[ "$1 $2" == "models openai" ]]; then
  printf 'openai/gpt-5.6-sol\n'
  exit 0
fi
if [[ "$1 $2" == "models openrouter" ]]; then
  printf 'openrouter/moonshotai/kimi-k3\n'
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
elif [[ "$model" == "openrouter/moonshotai/kimi-k3" ]]; then
  [[ "$MOCK_KIMI_MODE" != fail ]] || exit 12
  if [[ "$MOCK_KIMI_MODE" == preamble ]]; then
    printf 'I will inspect the evidence before answering.\n'
  else
    printf 'Kimi answer\n'
    if $panel; then printf '%s\n' "$marker"; fi
  fi
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
[[ "${MOCK_FABLE_MODE:-success}" == success ]] || exit 8
result='Fable answer'
[[ "$prompt" != *'<!-- multi-model-panel-complete:v1 -->'* ]] || result="$result
<!-- multi-model-panel-complete:v1 -->"
jq -cn --arg result "$result" '{result:$result,session_id:"ses_fable"}'
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

@test "advisor falls back to Fable when Sol fails" {
  export MOCK_SOL_MODE=fail
  run "$SKILL_ROOT/scripts/run-advisor.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-advisor-test \
    --output-dir "$TEST_ROOT/advisor"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.engine' <<<"$output")" = fable ]
  [ "$(jq -r '.failed_engines[0]' <<<"$output")" = sol ]
}

@test "advisor falls back to Cursor Grok before GLM" {
  export MOCK_SOL_MODE=fail
  export MOCK_FABLE_MODE=fail
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

@test "fusion uses Kimi, Fable, and Cursor Grok as its primary panel" {
  run "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.status' <<<"$output")" = success ]
  [ "$(jq -r '.panels_succeeded' <<<"$output")" -eq 3 ]
  [ "$(jq -r '.engine' <<<"$output")" = sol ]
  [ "$(jq -r '[.panels[].engine] | join(",")' <<<"$output")" = "kimi,fable,grok" ]
  grep -q -- '--model openrouter/moonshotai/kimi-k3' "$MOCK_LOG"
  run ! grep -q '## Panel SOL\|## Panel FABLE\|## Panel GLM' "$TEST_ROOT/fusion/judge-prompt.md"
}

@test "fusion backfills a failed primary with Sol" {
  run env MOCK_FABLE_MODE=fail "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title multi-model-fusion-test \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.panels_succeeded' <<<"$output")" -eq 3 ]
  [ "$(jq -r '.panels[1].slot' <<<"$output")" = fable ]
  [ "$(jq -r '.panels[1].engine' <<<"$output")" = sol ]
  [ "$(jq -r '.panels[1].status' <<<"$output")" = fallback ]
  grep -q -- '--model openai/gpt-5.6-sol' "$MOCK_LOG"
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
  [ -s "$TEST_ROOT/fusion/panel-1.rejected-kimi.md" ]
  run grep -q 'I will inspect the evidence' "$TEST_ROOT/fusion/judge-prompt.md"
  [ "$status" -ne 0 ]
}

@test "fusion advances from Sol to GLM without reuse" {
  run env MOCK_FABLE_MODE=fail MOCK_SOL_MODE=fail \
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

@test "environment validation confirms configured Kimi, Sol, and Grok models" {
  run "$SKILL_ROOT/scripts/validate-environment.sh"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.status' <<<"$output")" = success ]
  [ "$(jq -r '.kimi_model' <<<"$output")" = openrouter/moonshotai/kimi-k3 ]
}
