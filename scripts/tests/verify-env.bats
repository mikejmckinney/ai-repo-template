#!/usr/bin/env bats
#
# scripts/tests/verify-env.bats
#
# Phase 4b wrapper around scripts/test-verify-env.sh.
# See scripts/tests/README.md for the migration approach.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export BATS_TEST_TIMEOUT=300
}

@test "verify-env: legacy scripts/test-verify-env.sh passes" {
  run bash "$REPO_ROOT/scripts/test-verify-env.sh"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
  fi
  [ "$status" -eq 0 ]
}
