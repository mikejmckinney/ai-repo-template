#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

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
  [ "$(grep -c 'OPENCODE_OAUTH_MIN_TTL_SECONDS: 4500' "$weekly")" -eq 2 ]

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

@test "generated OpenCode CI profiles allow OAuth and use Kimi as small model" {
  for profile in base review fix; do
    run jq -e '
      .enabled_providers == ["openai", "openrouter"] and
      .small_model == "openrouter/moonshotai/kimi-k3@preset/consensus"
    ' "$REPO_ROOT/.github/agent-runtime/${profile}.json"
    [ "$status" -eq 0 ]
  done
}

@test "template installation includes OAuth and provider isolation helpers" {
  run python3 - "$REPO_ROOT/install.sh" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(r"MULTIAGENT_FILES=\(\n(?P<body>.*?)\n\)", text, re.DOTALL)
assert match is not None
for path in (
    "scripts/sync-opencode-oauth-secret.sh",
    "scripts/workflows/lib/opencode-oauth.sh",
    "scripts/workflows/lib/run-cursor-fix.sh",
    "scripts/workflows/lib/run-fix-provider-cascade.sh",
):
    assert f'"{path}"' in match.group("body"), path
PY

  [ "$status" -eq 0 ]
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
  cat >"$TEST_ROOT/mock-cursor.mjs" <<'EOF'
import { writeFileSync } from "node:fs"
const [, , , output] = process.argv
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
    OPENCODE_AUTH_CONTENT="$(jq '.openai.refresh = "ci-refresh-disabled"' "$AUTH_FILE")" \
    GITHUB_TOKEN=publisher-secret-test \
    bash "$REPO_ROOT/scripts/workflows/lib/run-cursor-fix.sh" \
    "$TEST_ROOT/prompt.md" "$TEST_ROOT/output.txt" "$repo"

  [ "$status" -eq 0 ]
  [ "$(cat "$repo/result.txt")" = cursor-verified ]
  [ "$(cat "$TEST_ROOT/output.txt")" = success ]
}

@test "fix provider fallback discards failed edits before promoting Cursor" {
  repo="$TEST_ROOT/cascade-repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name Test
  printf 'base\n' >"$repo/result.txt"
  git -C "$repo" add result.txt
  git -C "$repo" commit -qm base
  printf 'fix this' >"$TEST_ROOT/cascade-prompt.md"
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
        printf "%s:%s\n" "$provider" "$PWD" >>"$ATTEMPT_LOG"
        if [[ "$provider" == opencode ]]; then
          printf "failed-provider-edit\n" >result.txt
          return 1
        fi
        printf "cursor-verified\n" >result.txt
        printf "success\n" >"$output_file"
      }
      apply_noop() { return 0; }
      source "$1"
      FIX_PROVIDER_VERIFY_COMMAND="$2" run_fix_provider_cascade \
        retro-fix "$3" "$4" "$5" "$5" "$6" "$7" apply_noop
    ' _ \
    "$REPO_ROOT/scripts/workflows/lib/run-fix-provider-cascade.sh" \
    "$TEST_ROOT/cascade-verify.sh" "$TEST_ROOT/cascade-prompt.md" \
    "$TEST_ROOT/cascade-output.txt" "$repo" "$TEST_ROOT" \
    "$REPO_ROOT/scripts/workflows/lib"

  [ "$status" -eq 0 ]
  [ "$(cat "$repo/result.txt")" = cursor-verified ]
  [ "$(cat "$TEST_ROOT/cascade-output.txt")" = success ]
  [ "$(cut -d: -f1 "$TEST_ROOT/attempts.log" | tr '\n' ' ')" = "opencode cursor " ]
  [ "$(cut -d: -f2- "$TEST_ROOT/attempts.log" | sort -u | wc -l | tr -d ' ')" -eq 2 ]
}
