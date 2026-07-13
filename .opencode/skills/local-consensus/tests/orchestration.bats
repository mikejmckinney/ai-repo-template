#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  SKILL_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/local-consensus-test.XXXXXX")"
  BIN_DIR="$TEST_ROOT/bin"
  mkdir -p "$BIN_DIR"
  export PATH="$BIN_DIR:$PATH"
  export LOCAL_CONSENSUS_TIMEOUT=5
  export LOCAL_CONSENSUS_SESSION_LIMIT=100
  export MOCK_LOG="$TEST_ROOT/calls.log"
  export MOCK_SOL_MODE=success
  printf '%s\n' 'Analyze this problem.' >"$TEST_ROOT/prompt.md"
  cat >"$BIN_DIR/opencode" <<'EOF'
#!/usr/bin/env bash
printf 'opencode %s\n' "$*" >>"$MOCK_LOG"
if [[ "$1 $2" == "session list" ]]; then
  printf '[{"id":"ses_sol","title":"local-advisor-test-sol"},{"id":"ses_judge","title":"local-fusion-test-judge-sol"}]\n'
  exit 0
fi
if [[ "$1 $2" == "models openai" ]]; then
  printf 'openai/gpt-5.6-sol\n'
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
if [[ "$model" == "openai/gpt-5.6-sol" ]]; then
  [[ "$MOCK_SOL_MODE" == success ]] || exit 7
  printf 'Sol answer\n'
elif [[ "$title" == *-mi || "$title" == *-ds ]]; then
  printf 'Panel answer from %s\n' "$title"
elif [[ "$title" == *-mm ]]; then
  [[ "${MOCK_MM_MODE:-success}" == success ]] || exit 9
  printf 'Panel answer from %s\n' "$title"
else
  printf 'GLM answer\n'
fi
EOF
  chmod +x "$BIN_DIR/opencode"

  cat >"$BIN_DIR/claude" <<'EOF'
#!/usr/bin/env bash
printf 'claude %s\n' "$*" >>"$MOCK_LOG"
cat >/dev/null
[[ "${MOCK_FABLE_MODE:-success}" == success ]] || exit 8
printf '{"result":"Fable answer","session_id":"ses_fable"}\n'
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
    --title local-advisor-test \
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
    --title local-advisor-test \
    --output-dir "$TEST_ROOT/advisor"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.engine' <<<"$output")" = fable ]
  [ "$(jq -r '.failed_engines[0]' <<<"$output")" = sol ]
}

@test "advisor transports a large prompt through stdin" {
  dd if=/dev/zero bs=1024 count=256 2>/dev/null | tr '\0' x >"$TEST_ROOT/large.md"
  run "$SKILL_ROOT/scripts/run-advisor.sh" \
    --prompt-file "$TEST_ROOT/large.md" \
    --invoking-session ses_parent \
    --title local-advisor-test \
    --output-dir "$TEST_ROOT/advisor"

  [ "$status" -eq 0 ]
  prompt_bytes=$(grep 'prompt-bytes=' "$MOCK_LOG" | cut -d= -f2)
  [ "$prompt_bytes" -ge 262144 ]
}

@test "fusion uses Sol, Fable, and GLM as its primary panel" {
  run "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title local-fusion-test \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.status' <<<"$output")" = success ]
  [ "$(jq -r '.panels_succeeded' <<<"$output")" -eq 3 ]
  [ "$(jq -r '.engine' <<<"$output")" = sol ]
  [ "$(jq -r '[.panels[].engine] | join(",")' <<<"$output")" = "sol,fable,glm" ]
  [ "$(jq -r '.judge_overlap' <<<"$output")" = true ]
  run ! grep -q '## Panel SOL\|## Panel FABLE\|## Panel GLM' "$TEST_ROOT/fusion/judge-prompt.md"
}

@test "fusion backfills a failed primary with the first legacy fallback" {
  run env MOCK_FABLE_MODE=fail "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title local-fusion-test \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.panels_succeeded' <<<"$output")" -eq 3 ]
  [ "$(jq -r '.panels[1].slot' <<<"$output")" = fable ]
  [ "$(jq -r '.panels[1].engine' <<<"$output")" = mm ]
  [ "$(jq -r '.panels[1].status' <<<"$output")" = fallback ]
  grep -q -- '--model openrouter/minimax/minimax-m3@preset/default' "$MOCK_LOG"
}

@test "fusion advances through the legacy fallback pool without reuse" {
  run env MOCK_FABLE_MODE=fail MOCK_MM_MODE=fail \
    "$SKILL_ROOT/scripts/run-fusion.sh" \
    --prompt-file "$TEST_ROOT/prompt.md" \
    --invoking-session ses_parent \
    --title local-fusion-test \
    --output-dir "$TEST_ROOT/fusion"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.panels[1].engine' <<<"$output")" = mi ]
  [ "$(jq -r '.panels[1].status' <<<"$output")" = fallback ]
  grep -q -- '--model openrouter/minimax/minimax-m3@preset/default' "$MOCK_LOG"
  grep -q -- '--model openrouter/xiaomi/mimo-v2.5-pro@preset/default' "$MOCK_LOG"
}

@test "environment validation confirms configured Sol model" {
  run "$SKILL_ROOT/scripts/validate-environment.sh"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.status' <<<"$output")" = success ]
}
