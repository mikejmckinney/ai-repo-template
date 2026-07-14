#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck source=scripts/workflows/lib/pick-advisory-provider.sh
  source "$REPO_ROOT/scripts/workflows/lib/pick-advisory-provider.sh"
  unset CURSOR_API_KEY GEMINI_API_KEY GOOGLE_API_KEY WEEKLY_REVIEW_PROVIDER
  unset POSTMERGE_RETRO_PROVIDER ADVISORY_REVIEW_PROVIDER
  antigravity_enabled=false
}

@test "weekly scan auto routing prefers Cursor" {
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
