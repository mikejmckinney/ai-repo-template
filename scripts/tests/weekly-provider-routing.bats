#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck source=scripts/workflows/lib/pick-advisory-provider.sh
  source "$REPO_ROOT/scripts/workflows/lib/pick-advisory-provider.sh"
  unset CURSOR_API_KEY GEMINI_API_KEY GOOGLE_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY
  unset WEEKLY_REVIEW_PROVIDER
  unset POSTMERGE_RETRO_PROVIDER ADVISORY_REVIEW_PROVIDER
  OPENCODE_BIN=/bin/true
  antigravity_enabled=false
}

@test "weekly scan auto routing prefers Cursor" {
  OPENROUTER_API_KEY=openrouter-test
  OPENCODE_GITHUB_TOKEN=github-read-test
  CURSOR_API_KEY=cursor-test
  GEMINI_API_KEY=gemini-test
  antigravity_enabled=true
  init_advisory_provider_credentials

  run pick_advisory_provider weekly-scan

  [ "$status" -eq 0 ]
  [ "$output" = cursor ]
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
  [[ "$stderr" == *"cursor, else opencode, else gemini"* ]]
}
