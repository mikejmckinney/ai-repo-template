#!/usr/bin/env bats
#
# scripts/tests/verify-pr.bats
#
# Phase 4b wrapper around scripts/test-verify-pr.sh.
# See scripts/tests/README.md for the migration approach.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export BATS_TEST_TIMEOUT=300
}

@test "verify-pr: legacy scripts/test-verify-pr.sh passes" {
  run bash "$REPO_ROOT/scripts/test-verify-pr.sh"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
  fi
  [ "$status" -eq 0 ]
}
