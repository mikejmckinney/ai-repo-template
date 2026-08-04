#!/usr/bin/env bats

bats_require_minimum_version 1.7.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TEST_ROOT="$(mktemp -d)"
  AUTH_FILE="$TEST_ROOT/auth.json"
  future_ms="$((($(date +%s) + 7200) * 1000))"
  jq -n --argjson expires "$future_ms" '{
    openai: {
      type: "oauth",
      access: "access-secret-value",
      refresh: "refresh-secret-value",
      expires: $expires,
      accountId: "account-test"
    }
  }' >"$AUTH_FILE"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

prepare_cascade_gate_fixture() {
  CASCADE_REPO="$TEST_ROOT/gate-repo"
  mkdir -p "$CASCADE_REPO" "$TEST_ROOT/bin"
  git -C "$CASCADE_REPO" init -q
  git -C "$CASCADE_REPO" config user.email test@example.com
  git -C "$CASCADE_REPO" config user.name Test
  printf 'base\n' >"$CASCADE_REPO/result.txt"
  git -C "$CASCADE_REPO" add result.txt
  git -C "$CASCADE_REPO" commit -qm base
  printf 'fix this\n' >"$TEST_ROOT/gate-prompt.md"
  printf '%s\n' '{"findings":[{"category":"follow_up_issues","dedupe_key":"key-a","verification_capability":{"environment":"isolated-worktree","harness_id":"repository-test-suite","reason":"Fixture harness."}}]}' \
    >"$TEST_ROOT/gate-batch.json"

  cat >"$TEST_ROOT/baseline-verify.sh" <<'EOF'
#!/usr/bin/env bash
printf 'baseline\n' >>"$STAGE_LOG"
if [[ "$GATE_CASE" == baseline_failure ]]; then
  exit 1
fi
EOF
  cat >"$TEST_ROOT/candidate-verify.sh" <<'EOF'
#!/usr/bin/env bash
printf 'candidate\n' >>"$STAGE_LOG"
if [[ "$GATE_CASE" == deterministic_verification ]] ||
  [[ "$GATE_CASE" == fallback_after_verification && "$(cat result.txt)" == opencode-changed ]]; then
  exit 1
fi
EOF
  cat >"$TEST_ROOT/bin/python3" <<'EOF'
#!/usr/bin/env bash
case "${1##*/}" in
  validate-fix-verification.py)
    printf 'fix-verification\n' >>"$STAGE_LOG"
    [[ "$GATE_CASE" != fix_verification ]]
    ;;
  validate-outcome-evidence.py)
    printf 'outcome-evidence\n' >>"$STAGE_LOG"
    [[ "$GATE_CASE" != outcome_evidence ]]
    ;;
  *) exec /usr/bin/python3 "$@" ;;
esac
EOF
  chmod +x "$TEST_ROOT/baseline-verify.sh" "$TEST_ROOT/candidate-verify.sh" \
    "$TEST_ROOT/bin/python3"
}

run_cascade_gate_case() {
  local gate_case="$1"
  run env PATH="$TEST_ROOT/bin:$PATH" GATE_CASE="$gate_case" \
    STAGE_LOG="$TEST_ROOT/stages.log" bash -c '
      list_advisory_providers() {
        if [[ "$GATE_CASE" == gemini_application ]]; then
          printf "%s\n" gemini
        elif [[ "$GATE_CASE" == fallback_after_verification ]]; then
          printf "%s\n" opencode cursor
        else
          printf "%s\n" opencode
        fi
      }
      invoke_advisory_llm() {
        printf "provider\n" >>"$STAGE_LOG"
        printf "%s-changed\n" "$3" >result.txt
        printf "provider output\n" >"$2"
        [[ "$GATE_CASE" != provider_invocation ]]
      }
      apply_gemini() {
        printf "gemini-apply\n" >>"$STAGE_LOG"
        [[ "$GATE_CASE" != gemini_application ]]
      }
      source "$1"
      FIX_PROVIDER_BASELINE_VERIFY_COMMAND="$2" \
      FIX_PROVIDER_VERIFY_COMMAND="$3" \
        run_fix_provider_cascade retro-fix "$4" "$5" "$6" "$6" \
          "$7" "$8" apply_gemini "$9" retro/fix-verify-test.json
    ' _ \
    "$REPO_ROOT/scripts/workflows/lib/run-fix-provider-cascade.sh" \
    "$TEST_ROOT/baseline-verify.sh" "$TEST_ROOT/candidate-verify.sh" \
    "$TEST_ROOT/gate-prompt.md" "$TEST_ROOT/gate-output.txt" \
    "$CASCADE_REPO" "$TEST_ROOT" "$REPO_ROOT/scripts/workflows/lib" \
    "$TEST_ROOT/gate-batch.json"
}

@test "OAuth sync dry-run reports metadata without exposing token material" {
  run "$REPO_ROOT/scripts/sync-opencode-oauth-secret.sh" \
    --auth-file "$AUTH_FILE" --repo owner/repo

  [ "$status" -eq 0 ]
  [[ "$output" == *"OPENCODE_OPENAI_AUTH"* ]]
  [[ "$output" != *"access-secret-value"* ]]
  [[ "$output" != *"refresh-secret-value"* ]]
}

@test "OAuth sync apply uploads access-only JSON through stdin" {
  mkdir -p "$TEST_ROOT/bin"
  cat >"$TEST_ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"$GH_ARGS_FILE"
cat >"$GH_STDIN_FILE"
EOF
  chmod +x "$TEST_ROOT/bin/gh"

  run env PATH="$TEST_ROOT/bin:$PATH" \
    GH_ARGS_FILE="$TEST_ROOT/gh-args" GH_STDIN_FILE="$TEST_ROOT/gh-stdin" \
    "$REPO_ROOT/scripts/sync-opencode-oauth-secret.sh" \
    --apply --auth-file "$AUTH_FILE" --repo owner/repo

  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_ROOT/gh-args")" = "secret set OPENCODE_OPENAI_AUTH --repo owner/repo" ]
  [ "$(jq -r '.openai.access' "$TEST_ROOT/gh-stdin")" = "access-secret-value" ]
  [ "$(jq -r '.openai.refresh' "$TEST_ROOT/gh-stdin")" = "ci-refresh-disabled" ]
  [ "$(jq -r '.openai.expires' "$TEST_ROOT/gh-stdin")" = "$(jq -r '.openai.expires' "$AUTH_FILE")" ]
  [ "$(jq -r '.openai.accountId' "$TEST_ROOT/gh-stdin")" = "account-test" ]
  sync_output="$output"
  run grep -q 'refresh-secret-value' "$TEST_ROOT/gh-stdin"
  [ "$status" -ne 0 ]
  [[ "$sync_output" != *"access-secret-value"* ]]
  [[ "$sync_output" != *"refresh-secret-value"* ]]
}

@test "OAuth sync rejects expired access before upload" {
  expired_ms="$((($(date +%s) - 60) * 1000))"
  jq --argjson expires "$expired_ms" '.openai.expires = $expires' "$AUTH_FILE" >"$TEST_ROOT/expired.json"
  mkdir -p "$TEST_ROOT/bin"
  cat >"$TEST_ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo called >"$GH_CALLED_FILE"
EOF
  chmod +x "$TEST_ROOT/bin/gh"

  run env PATH="$TEST_ROOT/bin:$PATH" GH_CALLED_FILE="$TEST_ROOT/gh-called" \
    "$REPO_ROOT/scripts/sync-opencode-oauth-secret.sh" \
    --apply --auth-file "$TEST_ROOT/expired.json" --repo owner/repo

  [ "$status" -eq 1 ]
  [[ "$output" == *"OpenCode OAuth access token is expired"* ]]
  [ ! -e "$TEST_ROOT/gh-called" ]
  [[ "$output" != *"access-secret-value"* ]]
  [[ "$output" != *"refresh-secret-value"* ]]
}

@test "OAuth preflight enables Sol before Kimi when lifetime is sufficient" {
  run env \
    OPENCODE_AUTH_CONTENT="$(jq '.openai.refresh = "ci-refresh-disabled"' "$AUTH_FILE")" \
    OPENCODE_OAUTH_MIN_TTL_SECONDS=3600 \
    bash -c '
      source "$1"
      configure_opencode_oauth
      printf "models=%s\n" "$OPENCODE_MODELS"
      printf "auth=%s\n" "$(jq -r .openai.refresh <<<"$OPENCODE_AUTH_CONTENT")"
    ' _ "$REPO_ROOT/scripts/workflows/lib/opencode-oauth.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"models=openai/gpt-5.6-sol,openrouter/moonshotai/kimi-k3@preset/consensus"* ]]
  [[ "$output" == *"auth=ci-refresh-disabled"* ]]
  [[ "$output" != *"access-secret-value"* ]]
}

@test "OAuth preflight omits Sol and removes stale auth content" {
  stale_ms="$((($(date +%s) + 60) * 1000))"
  stale_auth="$(jq --argjson expires "$stale_ms" '.openai.expires = $expires | .openai.refresh = "ci-refresh-disabled"' "$AUTH_FILE")"

  run env \
    OPENCODE_AUTH_CONTENT="$stale_auth" \
    OPENCODE_OAUTH_MIN_TTL_SECONDS=3600 \
    bash -c '
      source "$1"
      configure_opencode_oauth
      printf "models=%s\n" "$OPENCODE_MODELS"
      printf "auth_set=%s\n" "${OPENCODE_AUTH_CONTENT:+true}"
    ' _ "$REPO_ROOT/scripts/workflows/lib/opencode-oauth.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"models=openrouter/moonshotai/kimi-k3@preset/consensus"* ]]
  [[ "$output" == *"auth_set="* ]]
  [[ "$output" != *"access-secret-value"* ]]
  [[ "$output" != *"refresh-secret-value"* ]]
}

@test "hosted workflows scope OAuth content to model invocation steps" {
  advisory="$REPO_ROOT/.github/workflows/agent-advisory-review.yml"
  daily="$REPO_ROOT/.github/workflows/agent-postmerge-retro.yml"
  weekly="$REPO_ROOT/.github/workflows/agent-weekly-review.yml"

  [ "$(grep -c 'OPENCODE_AUTH_CONTENT:.*secrets.OPENCODE_OPENAI_AUTH' "$advisory")" -eq 1 ]
  [ "$(grep -c 'OPENCODE_AUTH_CONTENT:.*secrets.OPENCODE_OPENAI_AUTH' "$daily")" -eq 2 ]
  [ "$(grep -c 'OPENCODE_AUTH_CONTENT:.*secrets.OPENCODE_OPENAI_AUTH' "$weekly")" -eq 2 ]
  grep -q 'OPENCODE_OAUTH_MIN_TTL_SECONDS: 2100' "$advisory"
  grep -q 'OPENCODE_OAUTH_MIN_TTL_SECONDS: 6300' "$daily"
  [ "$(grep -c 'OPENCODE_OAUTH_MIN_TTL_SECONDS: 8100' "$weekly")" -eq 1 ]
  [ "$(grep -c 'OPENCODE_OAUTH_MIN_TTL_SECONDS: 4500' "$weekly")" -eq 1 ]

  run python3 - "$advisory" "$daily" "$weekly" <<'PY'
import sys
from pathlib import Path

expected = {
    "agent-advisory-review.yml": ["Run advisory review"],
    "agent-postmerge-retro.yml": ["Run daily retrospective", "Run daily fix pass"],
    "agent-weekly-review.yml": ["Run weekly repository review", "Run weekly fix pass"],
}
for name in sys.argv[1:]:
    path = Path(name)
    text = path.read_text(encoding="utf-8")
    steps = text.split("      - name: ")[1:]
    credential_steps = [step for step in steps if "OPENCODE_AUTH_CONTENT:" in step]
    assert len(credential_steps) == len(expected[path.name]), path
    actual = [step.splitlines()[0] for step in credential_steps]
    assert actual == expected[path.name], (path, actual)
PY
  [ "$status" -eq 0 ]
}

@test "premerge workflow scopes Claude OAuth and pins the hosted CLI" {
  advisory="$REPO_ROOT/.github/workflows/agent-advisory-review.yml"

  [ "$(grep -c 'CLAUDE_CODE_OAUTH_TOKEN:.*secrets.CLAUDE_OAUTH_SECRET' "$advisory")" -eq 1 ]
  grep -q '@anthropic-ai/claude-code@2.1.220' "$advisory"
  grep -q 'CLAUDE_OAUTH_SECRET' "$advisory"
  grep -q 'has_claude' "$advisory"
  grep -q 'Claude, Sol, Grok, or Kimi credentials' "$advisory"

  run python3 - "$advisory" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
steps = text.split("      - name: ")[1:]
runtime = next(step for step in steps if step.startswith("Install agent runtime\n"))
claude = next(step for step in steps if step.startswith("Install Claude Code\n"))
assert "@anthropic-ai/claude-code" not in runtime
assert "if: env.CLAUDE_CANDIDATE == 'true'" in claude
assert "@anthropic-ai/claude-code@2.1.220" in claude
assert 'echo "CLAUDE_CANDIDATE=$claude_candidate" >> "$GITHUB_ENV"' in text
PY
  [ "$status" -eq 0 ]
}

@test "recurring workflows scope Claude OAuth and CLI installation to analysis" {
  daily="$REPO_ROOT/.github/workflows/agent-postmerge-retro.yml"
  weekly="$REPO_ROOT/.github/workflows/agent-weekly-review.yml"
  daily_runner="$REPO_ROOT/scripts/workflows/postmerge-retro/run-postmerge-retro.sh"
  monolithic_runner="$REPO_ROOT/scripts/workflows/postmerge-retro/run-postmerge-retro-monolithic.sh"
  weekly_runner="$REPO_ROOT/scripts/workflows/weekly-review/run-weekly-review-scan.sh"

  [ "$(grep -c 'CLAUDE_CODE_OAUTH_TOKEN:.*secrets.CLAUDE_OAUTH_SECRET' "$daily")" -eq 1 ]
  [ "$(grep -c 'CLAUDE_CODE_OAUTH_TOKEN:.*secrets.CLAUDE_OAUTH_SECRET' "$weekly")" -eq 1 ]
  grep -q 'path: .artifacts/postmerge-claude-session/' "$daily"
  grep -q 'path: .artifacts/weekly-claude-session/' "$weekly"
  ! grep -q 'path: .artifacts/postmerge-retro/claude-session/' "$daily"
  ! grep -q 'path: .artifacts/weekly-review/claude-session/' "$weekly"
  [ "$(grep -c 'retention-days: 7' "$daily")" -ge 1 ]
  [ "$(grep -c 'retention-days: 7' "$weekly")" -ge 1 ]
  grep -q 'ADVISORY_CANDIDATE_TIMEOUT_SECONDS="$provider_timeout_seconds"' "$daily_runner"
  grep -q 'if \[\[ "$provider" == "claude" || "$provider" == "cursor" \]\]; then' "$monolithic_runner"
  grep -q 'ADVISORY_CANDIDATE_TIMEOUT_SECONDS="$candidate_timeout"' "$monolithic_runner"
  grep -q 'WEEKLY_REVIEW_PROVIDER_TIMEOUT_SECONDS' "$weekly"
  grep -q 'weekly_provider_timeout_seconds="$(parse_positive_int WEEKLY_REVIEW_PROVIDER_TIMEOUT_SECONDS 900' "$weekly_runner"
  grep -q 'ADVISORY_CANDIDATE_TIMEOUT_SECONDS="$weekly_provider_timeout_seconds"' "$weekly_runner"

  run python3 - "$daily" "$weekly" <<'PY'
import sys
from pathlib import Path

for name in sys.argv[1:]:
    text = Path(name).read_text(encoding="utf-8")
    if name.endswith("agent-postmerge-retro.yml"):
        pipeline = text.split("  daily-pipeline:", 1)[1]
        review, fix = pipeline.split("      - name: Run daily fix pass", 1)
    else:
        review = text.split("  weekly-review:", 1)[1].split("  weekly-fix:", 1)[0]
        fix = text.split("  weekly-fix:", 1)[1]
    assert "@anthropic-ai/claude-code@2.1.220" in review
    steps = review.split("      - name: ")[1:]
    token_steps = [step for step in steps if "CLAUDE_CODE_OAUTH_TOKEN:" in step]
    assert len(token_steps) == 1, (name, len(token_steps))
    assert token_steps[0].startswith(("Run daily retrospective\n", "Run weekly repository review\n")), name
    preamble = review.split("      - name: ", 1)[0]
    assert "CLAUDE_CODE_OAUTH_TOKEN:" not in preamble
    assert "CLAUDE_CODE_OAUTH_TOKEN:" not in fix
    assert "CLAUDE_OAUTH_SECRET" not in fix
PY

  [ "$status" -eq 0 ]
}

@test "generated OpenCode CI profiles allow OAuth and use Kimi as small model" {
  for profile in base review fix; do
    run jq -e '
      .enabled_providers == ["openai", "openrouter"] and
      .small_model == "openrouter/moonshotai/kimi-k3@preset/consensus" and
      (if input_filename | endswith("/fix.json") then .permission.bash == "deny" else true end)
    ' "$REPO_ROOT/.github/agent-runtime/${profile}.json"
    [ "$status" -eq 0 ]
  done
}

@test "OpenCode review profile can research the web while its fix profile remains offline" {
  run jq -e '
    .permission.webfetch == "allow" and
    .permission.websearch == "allow" and
    .permission.bash == "deny" and
    .permission.edit == "deny" and
    .permission.external_directory == "deny"
  ' "$REPO_ROOT/.github/agent-runtime/review.json"
  [ "$status" -eq 0 ]

  run jq -e '
    .permission.webfetch == "deny" and
    .permission.websearch == "deny"
  ' "$REPO_ROOT/.github/agent-runtime/fix.json"
  [ "$status" -eq 0 ]

  for workflow in \
    agent-advisory-review.yml \
    agent-postmerge-retro.yml \
    agent-weekly-review.yml; do
    grep -q 'OPENCODE_ENABLE_EXA: 1' "$REPO_ROOT/.github/workflows/$workflow"
  done

  grep -q 'Exa AI' "$REPO_ROOT/docs/guides/agent-pipeline.md"
  grep -q 'OpenCode candidates only' "$REPO_ROOT/docs/guides/agent-pipeline.md"
  grep -q 'residual risk' \
    "$REPO_ROOT/docs/decisions/adr-030-non-blocking-review-pipeline.md"
}

@test "repository includes OAuth and provider isolation helpers" {
  for path in \
    scripts/sync-opencode-oauth-secret.sh \
    scripts/workflows/lib/opencode-oauth.sh \
    scripts/workflows/lib/run-cursor-fix.sh \
    scripts/workflows/lib/run-fix-provider-cascade.sh \
    scripts/workflows/lib/validate-fix-verification.py; do
    [ -f "$REPO_ROOT/$path" ]
  done
}

@test "advisory and weekly scans iterate provider candidates" {
  run python3 - \
    "$REPO_ROOT/scripts/workflows/advisory-review/run-advisory-review.sh" \
    "$REPO_ROOT/scripts/workflows/weekly-review/run-weekly-review-scan.sh" \
    "$REPO_ROOT/scripts/workflows/postmerge-retro/run-postmerge-retro-monolithic.sh" <<'PY'
import sys
from pathlib import Path

for name in sys.argv[1:]:
    text = Path(name).read_text(encoding="utf-8")
    assert "list_advisory_providers" in text, name
    assert 'for provider in "${provider_candidates[@]}"' in text, name

monolithic = Path(sys.argv[3]).read_text(encoding="utf-8")
assert "ADVISORY_PROVIDER_METADATA_FILE" in monolithic
assert "provider-provenance.py" in monolithic
assert "provider_attempts" in monolithic
assert "claude-session-diagnostics.sh" in monolithic
assert "CLAUDE_ADVISORY_SESSION_ID_FILE" in monolithic
PY

  [ "$status" -eq 0 ]
}

@test "daily and weekly fixes use the shared provider cascade" {
  run python3 - \
    "$REPO_ROOT/scripts/workflows/postmerge-retro/run-postmerge-retro-fix.sh" \
    "$REPO_ROOT/scripts/workflows/weekly-review/run-weekly-review-fix.sh" <<'PY'
import sys
from pathlib import Path

for name in sys.argv[1:]:
    text = Path(name).read_text(encoding="utf-8")
    assert "run_fix_provider_cascade" in text, name

helper = Path(sys.argv[1]).parents[1] / "lib" / "run-fix-provider-cascade.sh"
text = helper.read_text(encoding="utf-8")
assert "list_advisory_providers" in text
assert 'for provider in "${provider_candidates[@]}"' in text
PY

  [ "$status" -eq 0 ]
}

@test "Cursor fix attempts are isolated and only verified patches are promoted" {
  repo="$TEST_ROOT/repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name Test
  printf 'base\n' >"$repo/result.txt"
  git -C "$repo" add result.txt
  git -C "$repo" commit -qm base
  printf 'fix this' >"$TEST_ROOT/prompt.md"
  mkdir -p "$repo/.artifacts/postmerge-retro/daily-test"
  printf '{}\n' >"$repo/.artifacts/postmerge-retro/daily-test/daily-retro.json"
  cat >"$TEST_ROOT/mock-cursor.mjs" <<'EOF'
import { existsSync, writeFileSync } from "node:fs"
const [, , , output] = process.argv
const forbidden = [
  "GITHUB_TOKEN", "GH_TOKEN", "SANDBOX_BOOTSTRAP_TOKEN", "OPENCODE_GITHUB_TOKEN",
  "OPENCODE_AUTH_CONTENT", "OPENAI_API_KEY", "OPENROUTER_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY",
]
if (forbidden.some((name) => process.env[name])) process.exit(3)
if (process.env.FIX_PROVIDER_BATCH_JSON && !process.env.FIX_PROVIDER_BATCH_JSON.endsWith("/.artifacts/postmerge-retro/daily-test/daily-retro.json")) process.exit(4)
if (process.env.FIX_PROVIDER_BATCH_JSON && !process.env.FIX_PROVIDER_BATCH_JSON.startsWith(process.cwd())) process.exit(5)
if (process.env.FIX_PROVIDER_BATCH_JSON && !existsSync(process.env.FIX_PROVIDER_BATCH_JSON)) process.exit(6)
writeFileSync("result.txt", "cursor-verified\n")
writeFileSync(output, "success\n")
EOF
  cat >"$TEST_ROOT/verify.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ -z "${GITHUB_TOKEN:-}${GH_TOKEN:-}${OPENCODE_AUTH_CONTENT:-}${CURSOR_API_KEY:-}" ]]
[[ "$(cat result.txt)" == "cursor-verified" ]]
EOF
  chmod +x "$TEST_ROOT/verify.sh"

  run env \
    CURSOR_FIX_RUNNER="$TEST_ROOT/mock-cursor.mjs" \
    CURSOR_FIX_VERIFY_COMMAND="$TEST_ROOT/verify.sh" \
    CURSOR_API_KEY=cursor-secret-test \
    OPENCODE_GITHUB_TOKEN=opencode-github-secret-test \
    OPENROUTER_API_KEY=openrouter-secret-test \
    GEMINI_API_KEY=gemini-secret-test \
    GOOGLE_API_KEY=google-secret-test \
    FIX_PROVIDER_BATCH_JSON="$repo/.artifacts/postmerge-retro/daily-test/daily-retro.json" \
    OPENCODE_AUTH_CONTENT="$(jq '.openai.refresh = "ci-refresh-disabled"' "$AUTH_FILE")" \
    GITHUB_TOKEN=publisher-secret-test \
    bash "$REPO_ROOT/scripts/workflows/lib/run-cursor-fix.sh" \
    "$TEST_ROOT/prompt.md" "$TEST_ROOT/output.txt" "$repo"

  [ "$status" -eq 0 ]
  [ "$(cat "$repo/result.txt")" = cursor-verified ]
  [ "$(cat "$TEST_ROOT/output.txt")" = success ]
}

@test "provider invocation exposes only the selected provider credentials" {
  cat >"$TEST_ROOT/assert-provider-env.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
provider="$1"
case "$provider" in
  claude)
    [[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" && -n "${ADVISORY_GITHUB_TOKEN:-}" ]]
    [[ -z "${ANTHROPIC_API_KEY:-}${ANTHROPIC_AUTH_TOKEN:-}${CURSOR_API_KEY:-}${OPENROUTER_API_KEY:-}${OPENCODE_GITHUB_TOKEN:-}${OPENCODE_AUTH_CONTENT:-}${GEMINI_API_KEY:-}${GOOGLE_API_KEY:-}${GITHUB_TOKEN:-}${GH_TOKEN:-}${SANDBOX_BOOTSTRAP_TOKEN:-}" ]]
    ;;
  opencode)
    [[ -n "${OPENROUTER_API_KEY:-}" && -n "${OPENCODE_GITHUB_TOKEN:-}" && -n "${OPENCODE_AUTH_CONTENT:-}" ]]
    [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}${ANTHROPIC_API_KEY:-}${ANTHROPIC_AUTH_TOKEN:-}${CURSOR_API_KEY:-}${GEMINI_API_KEY:-}${GOOGLE_API_KEY:-}${GITHUB_TOKEN:-}${GH_TOKEN:-}${SANDBOX_BOOTSTRAP_TOKEN:-}" ]]
    ;;
  cursor)
    [[ -n "${CURSOR_API_KEY:-}" && -n "${ADVISORY_GITHUB_TOKEN:-}" ]]
    [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}${ANTHROPIC_API_KEY:-}${ANTHROPIC_AUTH_TOKEN:-}${OPENROUTER_API_KEY:-}${OPENCODE_GITHUB_TOKEN:-}${OPENCODE_AUTH_CONTENT:-}${GEMINI_API_KEY:-}${GOOGLE_API_KEY:-}${GITHUB_TOKEN:-}${GH_TOKEN:-}${SANDBOX_BOOTSTRAP_TOKEN:-}" ]]
    ;;
  gemini)
    [[ -n "${GEMINI_API_KEY:-}" && -n "${GOOGLE_API_KEY:-}" ]]
    [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}${ANTHROPIC_API_KEY:-}${ANTHROPIC_AUTH_TOKEN:-}${CURSOR_API_KEY:-}${OPENROUTER_API_KEY:-}${OPENCODE_GITHUB_TOKEN:-}${OPENCODE_AUTH_CONTENT:-}${GITHUB_TOKEN:-}${GH_TOKEN:-}${SANDBOX_BOOTSTRAP_TOKEN:-}" ]]
    ;;
esac
EOF
  chmod +x "$TEST_ROOT/assert-provider-env.sh"

  for provider in claude opencode cursor gemini; do
    run env \
      GITHUB_TOKEN=publisher-test GH_TOKEN=publisher-test SANDBOX_BOOTSTRAP_TOKEN=sandbox-test \
      CLAUDE_CODE_OAUTH_TOKEN=claude-test ANTHROPIC_API_KEY=anthropic-key-test \
      ANTHROPIC_AUTH_TOKEN=anthropic-auth-test \
      ADVISORY_GITHUB_TOKEN=github-read-test \
      OPENROUTER_API_KEY=openrouter-test OPENCODE_GITHUB_TOKEN=opencode-github-test \
      OPENCODE_AUTH_CONTENT=opencode-auth-test CURSOR_API_KEY=cursor-test \
      GEMINI_API_KEY=gemini-test GOOGLE_API_KEY=google-test \
      "$REPO_ROOT/scripts/workflows/lib/run-with-provider-credentials.sh" "$provider" \
      "$TEST_ROOT/assert-provider-env.sh" "$provider"

    [ "$status" -eq 0 ]
  done
  run "$REPO_ROOT/scripts/workflows/lib/run-with-provider-credentials.sh" antigravity /bin/true
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported provider 'antigravity'"* ]]
}

@test "provider credential isolation composes with the postmerge timeout" {
  run env \
    GITHUB_TOKEN=publisher-test OPENCODE_AUTH_CONTENT=opencode-auth-test \
    CURSOR_API_KEY=cursor-test GEMINI_API_KEY=gemini-test \
    timeout 5s "$REPO_ROOT/scripts/workflows/lib/run-with-provider-credentials.sh" cursor \
    bash -c '[[ "$CURSOR_API_KEY" == cursor-test && -z "${GITHUB_TOKEN:-}${OPENCODE_AUTH_CONTENT:-}${GEMINI_API_KEY:-}" ]]'

  [ "$status" -eq 0 ]
}

@test "fix provider fallback discards failed edits before promoting Cursor" {
  repo="$TEST_ROOT/cascade-repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name Test
  printf 'base\n' >"$repo/result.txt"
  printf '.artifacts/\n' >"$repo/.gitignore"
  git -C "$repo" add result.txt .gitignore
  git -C "$repo" commit -qm base
  printf 'fix this' >"$TEST_ROOT/cascade-prompt.md"
  mkdir -p "$repo/.artifacts/postmerge-retro/daily-test"
  cat >"$repo/.artifacts/postmerge-retro/daily-test/daily-retro.json" <<'EOF'
{"findings":[{"category":"follow_up_issues","dedupe_key":"key-a","verification_capability":{"environment":"isolated-worktree","harness_id":"repository-test-suite","reason":"Fixture harness."}},{"category":"follow_up_issues","dedupe_key":"key-b","verification_capability":{"environment":"isolated-worktree","harness_id":"repository-test-suite","reason":"Fixture harness."}}]}
EOF
  cat >"$TEST_ROOT/cascade-verify.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ -z "${OPENCODE_AUTH_CONTENT:-}${CURSOR_API_KEY:-}" ]]
[[ "$(cat result.txt)" == "cursor-verified" ]]
EOF
  chmod +x "$TEST_ROOT/cascade-verify.sh"

  run env ATTEMPT_LOG="$TEST_ROOT/attempts.log" \
    OPENCODE_AUTH_CONTENT='{"openai":{"access":"secret"}}' \
    CURSOR_API_KEY=cursor-secret \
    bash -c '
      list_advisory_providers() { printf "%s\n" opencode cursor; }
      invoke_advisory_llm() {
        local output_file="$2" provider="$3"
        [[ -f .artifacts/postmerge-retro/daily-test/daily-retro.json ]]
        printf "%s:%s\n" "$provider" "$PWD" >>"$ATTEMPT_LOG"
        if [[ "$provider" == opencode ]]; then
          printf "failed-provider-edit\n" >result.txt
          return 1
        fi
        printf "cursor-verified\n" >result.txt
        mkdir -p retro
        cat >retro/fix-verify-test.json <<"JSON"
{"findings":[{"dedupe_key":"key-a","verify":{"pre":"reproduced","post":"fixed","notes":"Verified after the edit."}},{"dedupe_key":"key-b","verify":{"pre":"skipped_collateral","post":"fixed","notes":"Fixed by the same edit."}}],"outcome_evidence":{"claims":[{"material_claim":"The candidate fixes both findings.","environment":"isolated fix worktree","why_representative":"The recorded repro runs against the candidate patch.","implementation_sha":"controller:current-head","action_performed":"Ran controller verification.","expected_result":"Both findings are fixed.","observed_result":"Both findings are fixed.","artifact":"embedded:fix-verification-table","artifact_type":"command-record","redaction":"No secrets present.","retention":"PR lifetime.","evidence_reuse":"none","result":"pass"}]}}
JSON
        printf "success\n" >"$output_file"
      }
      apply_noop() { return 0; }
      source "$1"
      FIX_PROVIDER_VERIFY_COMMAND="$2" run_fix_provider_cascade \
        retro-fix "$3" "$4" "$5" "$5" "$6" "$7" apply_noop \
        "$8" retro/fix-verify-test.json
    ' _ \
    "$REPO_ROOT/scripts/workflows/lib/run-fix-provider-cascade.sh" \
    "$TEST_ROOT/cascade-verify.sh" "$TEST_ROOT/cascade-prompt.md" \
    "$TEST_ROOT/cascade-output.txt" "$repo" "$TEST_ROOT" \
    "$REPO_ROOT/scripts/workflows/lib" ".artifacts/postmerge-retro/daily-test/daily-retro.json"

  [ "$status" -eq 0 ]
  [ "$(cat "$repo/result.txt")" = cursor-verified ]
  [ "$(cat "$TEST_ROOT/cascade-output.txt")" = success ]
  [ "$(cut -d: -f1 "$TEST_ROOT/attempts.log" | tr '\n' ' ')" = "opencode cursor " ]
  [ "$(cut -d: -f2- "$TEST_ROOT/attempts.log" | sort -u | wc -l | tr -d ' ')" -eq 2 ]
}

@test "fix provider cascade rejects a successful no-op without verification" {
  repo="$TEST_ROOT/noop-repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name Test
  printf 'base\n' >"$repo/result.txt"
  git -C "$repo" add result.txt
  git -C "$repo" commit -qm base
  printf 'fix this' >"$TEST_ROOT/noop-prompt.md"
  printf '%s\n' '{"findings":[{"category":"follow_up_issues","dedupe_key":"key-a","verification_capability":{"environment":"isolated-worktree","harness_id":"repository-test-suite","reason":"Fixture harness."}}]}' \
    >"$TEST_ROOT/noop-batch.json"

  run bash -c '
    list_advisory_providers() { printf "%s\n" opencode; }
    invoke_advisory_llm() { printf "success\n" >"$2"; }
    apply_noop() { return 0; }
    source "$1"
    FIX_PROVIDER_VERIFY_COMMAND=true run_fix_provider_cascade \
      retro-fix "$2" "$3" "$4" "$4" "$5" "$6" apply_noop \
      "$7" retro/fix-verify-test.json
  ' _ \
    "$REPO_ROOT/scripts/workflows/lib/run-fix-provider-cascade.sh" \
    "$TEST_ROOT/noop-prompt.md" "$TEST_ROOT/noop-output.txt" "$repo" \
    "$TEST_ROOT" "$REPO_ROOT/scripts/workflows/lib" "$TEST_ROOT/noop-batch.json"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Fix provider cascade exhausted"* ]]
  [ "$(cat "$repo/result.txt")" = base ]
}

@test "fix provider cascade rejects substantive edits with invalid verification" {
  repo="$TEST_ROOT/invalid-verify-repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name Test
  printf 'base\n' >"$repo/result.txt"
  git -C "$repo" add result.txt
  git -C "$repo" commit -qm base
  printf 'fix this' >"$TEST_ROOT/invalid-verify-prompt.md"
  printf '%s\n' '{"findings":[{"category":"follow_up_issues","dedupe_key":"key-a","verification_capability":{"environment":"isolated-worktree","harness_id":"repository-test-suite","reason":"Fixture harness."}}]}' \
    >"$TEST_ROOT/invalid-verify-batch.json"

  for verify_case in missing malformed pending incomplete all-cant-reproduce; do
    run env VERIFY_CASE="$verify_case" bash -c '
      list_advisory_providers() { printf "%s\n" opencode; }
      invoke_advisory_llm() {
        printf "changed\n" >result.txt
        mkdir -p retro
        case "$VERIFY_CASE" in
          missing) ;;
          malformed) printf "{\n" >retro/fix-verify-test.json ;;
          pending) printf "%s\n" '\''{"findings":[{"dedupe_key":"key-a","verify":{"pre":"pending","post":"pending","notes":"Not finished."}}]}'\'' >retro/fix-verify-test.json ;;
          incomplete) printf "%s\n" '\''{"findings":[]}'\'' >retro/fix-verify-test.json ;;
          all-cant-reproduce) printf "%s\n" '\''{"findings":[{"dedupe_key":"key-a","verify":{"pre":"cant_reproduce","post":"n/a","notes":"Already absent."}}]}'\'' >retro/fix-verify-test.json ;;
        esac
        printf "success\n" >"$2"
      }
      apply_noop() { return 0; }
      source "$1"
      FIX_PROVIDER_VERIFY_COMMAND=true run_fix_provider_cascade \
        retro-fix "$2" "$3" "$4" "$4" "$5" "$6" apply_noop \
        "$7" retro/fix-verify-test.json
    ' _ \
      "$REPO_ROOT/scripts/workflows/lib/run-fix-provider-cascade.sh" \
      "$TEST_ROOT/invalid-verify-prompt.md" "$TEST_ROOT/invalid-verify-output.txt" "$repo" \
      "$TEST_ROOT" "$REPO_ROOT/scripts/workflows/lib" "$TEST_ROOT/invalid-verify-batch.json"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Fix provider cascade exhausted"* ]]
    [ "$(cat "$repo/result.txt")" = base ]
  done
}

@test "fix provider cascade stops after provider invocation failure" {
  prepare_cascade_gate_fixture

  run_cascade_gate_case provider_invocation

  [ "$status" -ne 0 ]
  [ "$(cat "$TEST_ROOT/stages.log")" = $'baseline\nprovider' ]
  [ "$(cat "$CASCADE_REPO/result.txt")" = base ]
}

@test "fix provider cascade stops after Gemini application failure" {
  prepare_cascade_gate_fixture

  run_cascade_gate_case gemini_application

  [ "$status" -ne 0 ]
  [ "$(cat "$TEST_ROOT/stages.log")" = $'baseline\nprovider\ngemini-apply\nprovider\ngemini-apply' ]
  [ "$(cat "$CASCADE_REPO/result.txt")" = base ]
}

@test "fix provider cascade stops after deterministic verification failure" {
  prepare_cascade_gate_fixture

  run_cascade_gate_case deterministic_verification

  [ "$status" -ne 0 ]
  [ "$(cat "$TEST_ROOT/stages.log")" = $'baseline\nprovider\ncandidate' ]
  [ "$(cat "$CASCADE_REPO/result.txt")" = base ]
}

@test "fix provider cascade stops after fix-verification failure" {
  prepare_cascade_gate_fixture

  run_cascade_gate_case fix_verification

  [ "$status" -ne 0 ]
  [ "$(cat "$TEST_ROOT/stages.log")" = $'baseline\nprovider\ncandidate\nfix-verification' ]
  [ "$(cat "$CASCADE_REPO/result.txt")" = base ]
}

@test "fix provider cascade stops after outcome-evidence failure" {
  prepare_cascade_gate_fixture

  run_cascade_gate_case outcome_evidence

  [ "$status" -ne 0 ]
  [ "$(cat "$TEST_ROOT/stages.log")" = $'baseline\nprovider\ncandidate\nfix-verification\noutcome-evidence' ]
  [ "$(cat "$CASCADE_REPO/result.txt")" = base ]
}

@test "fix provider cascade records baseline and candidate verification separately" {
  prepare_cascade_gate_fixture

  run_cascade_gate_case baseline_failure

  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_ROOT/stages.log")" = $'baseline\nprovider\ncandidate\nfix-verification\noutcome-evidence' ]
  [[ "$output" == *"Baseline verification status: 1"* ]]
  [[ "$output" == *"Candidate verification status for opencode: 0"* ]]
  [ "$(cat "$CASCADE_REPO/result.txt")" = opencode-changed ]
}

@test "fix provider cascade continues after a candidate verification failure" {
  prepare_cascade_gate_fixture

  run_cascade_gate_case fallback_after_verification

  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_ROOT/stages.log")" = $'baseline\nprovider\ncandidate\nprovider\ncandidate\nfix-verification\noutcome-evidence' ]
  [ "$(cat "$CASCADE_REPO/result.txt")" = cursor-changed ]
}

@test "candidate-created files are visible during deterministic verification" {
  prepare_cascade_gate_fixture
  cat >"$TEST_ROOT/candidate-verify.sh" <<'EOF'
#!/usr/bin/env bash
if [[ "$(git status --porcelain -- created.txt)" != " A created.txt" ]]; then
  exit 1
fi
printf 'candidate-new-file-visible\n' >>"$STAGE_LOG"
EOF
  chmod +x "$TEST_ROOT/candidate-verify.sh"

  run env PATH="$TEST_ROOT/bin:$PATH" GATE_CASE=success \
    STAGE_LOG="$TEST_ROOT/stages.log" bash -c '
      list_advisory_providers() { printf "%s\n" opencode; }
      invoke_advisory_llm() {
        printf "new candidate file\n" >created.txt
        printf "provider output\n" >"$2"
      }
      apply_noop() { return 0; }
      source "$1"
      FIX_PROVIDER_BASELINE_VERIFY_COMMAND="$2" \
      FIX_PROVIDER_VERIFY_COMMAND="$3" \
        run_fix_provider_cascade retro-fix "$4" "$5" "$6" "$6" \
          "$7" "$8" apply_noop "$9" retro/fix-verify-test.json
    ' _ \
    "$REPO_ROOT/scripts/workflows/lib/run-fix-provider-cascade.sh" \
    "$TEST_ROOT/baseline-verify.sh" "$TEST_ROOT/candidate-verify.sh" \
    "$TEST_ROOT/gate-prompt.md" "$TEST_ROOT/gate-output.txt" \
    "$CASCADE_REPO" "$TEST_ROOT" "$REPO_ROOT/scripts/workflows/lib" \
    "$TEST_ROOT/gate-batch.json"

  [ "$status" -eq 0 ]
  grep -q '^candidate-new-file-visible$' "$TEST_ROOT/stages.log"
  [ "$(cat "$CASCADE_REPO/created.txt")" = "new candidate file" ]
}
