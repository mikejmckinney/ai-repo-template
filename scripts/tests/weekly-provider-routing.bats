#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck source=scripts/workflows/lib/pick-advisory-provider.sh
  source "$REPO_ROOT/scripts/workflows/lib/pick-advisory-provider.sh"
  unset CURSOR_API_KEY GEMINI_API_KEY GOOGLE_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY
  unset OPENCODE_AUTH_CONTENT OPENCODE_OAUTH_MIN_TTL_SECONDS OPENCODE_MODELS
  unset WEEKLY_REVIEW_PROVIDER
  unset POSTMERGE_RETRO_PROVIDER ADVISORY_REVIEW_PROVIDER
  OPENCODE_BIN=/bin/true
  antigravity_enabled=false
}

@test "weekly scan auto routing prefers OpenCode" {
  OPENROUTER_API_KEY=openrouter-test
  OPENCODE_GITHUB_TOKEN=github-read-test
  CURSOR_API_KEY=cursor-test
  GEMINI_API_KEY=gemini-test
  antigravity_enabled=true
  init_advisory_provider_credentials

  run pick_advisory_provider weekly-scan

  [ "$status" -eq 0 ]
  [ "$output" = opencode ]
}

@test "weekly scan auto routing uses Antigravity before Gemini" {
  GEMINI_API_KEY=gemini-test
  antigravity_enabled=true
  init_advisory_provider_credentials

  run pick_advisory_provider weekly-scan

  [ "$status" -eq 0 ]
  [ "$output" = antigravity ]
}

@test "weekly scan accepts explicit Antigravity" {
  WEEKLY_REVIEW_PROVIDER=antigravity
  GEMINI_API_KEY=gemini-test
  antigravity_enabled=true
  init_advisory_provider_credentials

  run pick_advisory_provider weekly-scan

  [ "$status" -eq 0 ]
  [ "$output" = antigravity ]

  run list_advisory_providers weekly-scan

  [ "$status" -eq 0 ]
  [ "$output" = antigravity ]
}

@test "weekly routing rejects unsupported configured providers" {
  WEEKLY_REVIEW_PROVIDER=unknown-provider
  init_advisory_provider_credentials

  run --separate-stderr pick_advisory_provider weekly-scan

  [ "$status" -eq 1 ]
  [[ "$stderr" == *"unknown-provider"* ]]
  [[ "$stderr" == *"unsupported"* ]]
}

@test "retro remap notices include OpenCode in the auto cascade" {
  ADVISORY_REVIEW_PROVIDER=antigravity
  init_advisory_provider_credentials

  run --separate-stderr pick_advisory_provider retro

  [ "$status" -eq 0 ]
  [[ "$stderr" == *"opencode, else cursor, else gemini"* ]]
}

@test "weekly review and fix retain independent timeout and OAuth budgets" {
  run python3 - "$REPO_ROOT/.github/workflows/agent-weekly-review.yml" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
review = text.split("  weekly-review:", 1)[1].split("  weekly-fix:", 1)[0]
fix = text.split("  weekly-fix:", 1)[1]
assert "timeout-minutes: 120" in review
assert "OPENCODE_OAUTH_MIN_TTL_SECONDS: 8100" in review
assert "timeout-minutes: 60" in fix
assert "OPENCODE_OAUTH_MIN_TTL_SECONDS: 4500" in fix
PY

  [ "$status" -eq 0 ]
}
