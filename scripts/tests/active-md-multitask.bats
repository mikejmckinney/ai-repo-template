#!/usr/bin/env bats
#
# scripts/tests/active-md-multitask.bats
#
# Phase 4b wrapper around scripts/test-active-md-multitask.sh.
# See scripts/tests/README.md for the migration approach.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export BATS_TEST_TIMEOUT=300
}

@test "active-md-multitask: legacy scripts/test-active-md-multitask.sh passes" {
  run bash "$REPO_ROOT/scripts/test-active-md-multitask.sh"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
  fi
  [ "$status" -eq 0 ]
}
